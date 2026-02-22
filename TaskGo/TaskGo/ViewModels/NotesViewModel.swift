import Foundation
import AppKit
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedDate: String = Note.todayString
    @Published var attributedContent: NSAttributedString = NSAttributedString(string: "")

    private let firestoreService = FirestoreService.shared
    private var listener: ListenerRegistration?
    private var saveTask: DispatchWorkItem?
    private var isLoadingNote = false

    private static let defaultFont = NSFont.systemFont(ofSize: 13)

    func startListening() {
        stopListening()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        listener = firestoreService.listenToNotes(userId: userId) { [weak self] notes in
            Task { @MainActor in
                self?.notes = notes
            }
        }

        selectNote(date: Note.todayString)
    }

    func stopListening() {
        saveNow()
        listener?.remove()
        listener = nil
    }

    func selectNote(date: String) {
        saveNow()

        selectedDate = date
        isLoadingNote = true

        if let existing = notes.first(where: { $0.date == date }) {
            loadNoteContent(existing)
        } else if date == Note.todayString {
            attributedContent = NSAttributedString(string: "",
                                                    attributes: [.font: NotesViewModel.defaultFont])
            isLoadingNote = false
        } else {
            Task {
                guard let userId = Auth.auth().currentUser?.uid else { return }
                if let note = try? await firestoreService.getNote(date: date, userId: userId) {
                    loadNoteContent(note)
                } else {
                    attributedContent = NSAttributedString(string: "",
                                                            attributes: [.font: NotesViewModel.defaultFont])
                }
                isLoadingNote = false
            }
        }
    }

    private func loadNoteContent(_ note: Note) {
        if let rtfBase64 = note.rtfData,
           let attrString = NSAttributedString.fromRTFBase64(rtfBase64) {
            attributedContent = attrString
        } else {
            // Fall back to plain text
            attributedContent = NSAttributedString(string: note.content,
                                                    attributes: [.font: NotesViewModel.defaultFont])
        }
        isLoadingNote = false
    }

    /// Called by the RichTextEditor when content changes
    func onContentChanged() {
        scheduleSave()
    }

    private func scheduleSave() {
        guard !isLoadingNote else { return }

        saveTask?.cancel()
        let date = selectedDate
        let attrText = attributedContent

        // Cache locally immediately so it persists across tab switches
        cacheLocally(date: date, attrText: attrText)

        saveTask = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.save(date: date, attributedText: attrText)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: saveTask!)
    }

    func saveNow() {
        saveTask?.cancel()
        guard !isLoadingNote else { return }
        let date = selectedDate
        let attrText = attributedContent

        // Cache locally
        cacheLocally(date: date, attrText: attrText)

        // Save to Firestore synchronously (blocking)
        let plainText = attrText.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !plainText.isEmpty {
            let rtfBase64 = attrText.rtfBase64()
            let note = Note(date: date, content: plainText, rtfData: rtfBase64, updatedAt: Date())
            guard let userId = Auth.auth().currentUser?.uid else { return }
            // Use a semaphore to ensure this completes before we return
            let semaphore = DispatchSemaphore(value: 0)
            Task.detached {
                try? await FirestoreService.shared.saveNote(note, userId: userId)
                semaphore.signal()
            }
            // Wait up to 2 seconds for save to complete
            _ = semaphore.wait(timeout: .now() + 2)
        }
    }

    private func cacheLocally(date: String, attrText: NSAttributedString) {
        let plainText = attrText.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !plainText.isEmpty {
            let rtfBase64 = attrText.rtfBase64()
            let cachedNote = Note(date: date, content: plainText, rtfData: rtfBase64, updatedAt: Date())
            if let existingIndex = notes.firstIndex(where: { $0.date == date }) {
                notes[existingIndex] = cachedNote
            } else {
                notes.insert(cachedNote, at: 0)
            }
        }
    }

    private func save(date: String, attributedText: NSAttributedString) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("[Notes] save failed: no authenticated user")
            return
        }

        let plainText = attributedText.plainText.trimmingCharacters(in: .whitespacesAndNewlines)

        if plainText.isEmpty {
            try? await firestoreService.deleteNote(date: date, userId: userId)
        } else {
            let rtfBase64 = attributedText.rtfBase64()
            let note = Note(date: date, content: plainText, rtfData: rtfBase64, updatedAt: Date())
            do {
                try await firestoreService.saveNote(note, userId: userId)
                print("[Notes] saved note for \(date) (\(plainText.count) chars)")
            } catch {
                print("[Notes] SAVE ERROR: \(error)")
            }
        }
    }
}
