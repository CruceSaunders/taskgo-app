import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedDate: String = Note.todayString
    @Published var content: String = "" {
        didSet {
            scheduleSave()
        }
    }

    private let firestoreService = FirestoreService.shared
    private var listener: ListenerRegistration?
    private var saveTask: DispatchWorkItem?
    private var isLoadingNote = false

    func startListening() {
        stopListening()
        guard let userId = Auth.auth().currentUser?.uid else { return }

        listener = firestoreService.listenToNotes(userId: userId) { [weak self] notes in
            Task { @MainActor in
                self?.notes = notes
            }
        }

        // Load today's note
        selectNote(date: Note.todayString)
    }

    func stopListening() {
        // Save current content before stopping
        saveNow()
        listener?.remove()
        listener = nil
    }

    func selectNote(date: String) {
        // Save current note before switching
        saveNow()

        selectedDate = date
        isLoadingNote = true

        // Find in local cache first
        if let existing = notes.first(where: { $0.date == date }) {
            content = existing.content
            isLoadingNote = false
        } else if date == Note.todayString {
            // New note for today
            content = ""
            isLoadingNote = false
        } else {
            // Load from Firestore
            Task {
                guard let userId = Auth.auth().currentUser?.uid else { return }
                if let note = try? await firestoreService.getNote(date: date, userId: userId) {
                    content = note.content
                } else {
                    content = ""
                }
                isLoadingNote = false
            }
        }
    }

    private func scheduleSave() {
        guard !isLoadingNote else { return }

        saveTask?.cancel()
        let date = selectedDate
        let text = content
        saveTask = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                await self?.save(date: date, content: text)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: saveTask!)
    }

    func saveNow() {
        saveTask?.cancel()
        guard !isLoadingNote else { return }
        let date = selectedDate
        let text = content
        Task {
            await save(date: date, content: text)
        }
    }

    private func save(date: String, content: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Don't save blank notes -- delete if exists
            try? await firestoreService.deleteNote(date: date, userId: userId)
        } else {
            let note = Note(date: date, content: content, updatedAt: Date())
            try? await firestoreService.saveNote(note, userId: userId)
        }
    }
}
