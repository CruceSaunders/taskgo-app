import SwiftUI

struct NotesTabView: View {
    @EnvironmentObject var notesVM: NotesViewModel
    @State private var editorTextView: NSTextView?

    var body: some View {
        HStack(spacing: 0) {
            notesSidebar
                .frame(width: 85)

            Divider()

            VStack(spacing: 0) {
                dateHeader
                Divider()
                formattingToolbar
                Divider()
                editorArea
            }
        }
        .onAppear {
            notesVM.startListening()
        }
        .onDisappear {
            notesVM.stopListening()
        }
    }

    // MARK: - Sidebar

    private var notesSidebar: some View {
        VStack(spacing: 0) {
            Button(action: {
                notesVM.selectNote(date: Note.todayString)
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Today")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(notesVM.selectedDate == Note.todayString ? .white : Color.calmTeal)
                        Text(Note(date: Note.todayString).displayDate)
                            .font(.system(size: 9))
                            .foregroundStyle(notesVM.selectedDate == Note.todayString ? .white.opacity(0.8) : .primary.opacity(0.4))
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(notesVM.selectedDate == Note.todayString ? Color.calmTeal : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            .padding(.top, 6)

            Divider()
                .padding(.vertical, 4)

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(notesVM.notes.filter { !$0.isToday }) { note in
                        Button(action: {
                            notesVM.selectNote(date: note.date)
                        }) {
                            HStack {
                                Text(note.displayDate)
                                    .font(.system(size: 10))
                                    .foregroundStyle(notesVM.selectedDate == note.date ? .white : .primary.opacity(0.7))
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(notesVM.selectedDate == note.date ? Color.calmTeal.opacity(0.8) : Color.clear)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .background(Color.secondary.opacity(0.04))
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack {
            if notesVM.selectedDate == Note.todayString {
                Text("Today's Note")
                    .font(.system(size: 12, weight: .semibold))
            } else {
                Text(Note(date: notesVM.selectedDate).displayDate)
                    .font(.system(size: 12, weight: .semibold))
            }
            Spacer()
            Text("auto-saved")
                .font(.system(size: 9))
                .foregroundStyle(.primary.opacity(0.3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    // MARK: - Formatting Toolbar

    private var formattingToolbar: some View {
        HStack(spacing: 4) {
            formatButton("B", weight: .bold) {
                RichTextEditor.toggleBold(in: editorTextView)
            }

            formatButton("I", weight: .regular, italic: true) {
                RichTextEditor.toggleItalic(in: editorTextView)
            }

            formatButton("U", weight: .regular, underline: true) {
                RichTextEditor.toggleUnderline(in: editorTextView)
            }

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 2)

            formatButton("H1", weight: .bold, fontSize: 9) {
                RichTextEditor.setHeader(1, in: editorTextView)
            }

            formatButton("H2", weight: .semibold, fontSize: 9) {
                RichTextEditor.setHeader(2, in: editorTextView)
            }

            formatButton("T", weight: .regular, fontSize: 9) {
                RichTextEditor.setHeader(0, in: editorTextView)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.04))
    }

    private func formatButton(_ label: String, weight: Font.Weight = .regular, italic: Bool = false, underline: Bool = false, fontSize: CGFloat = 11, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: fontSize, weight: weight))
                .italic(italic)
                .underline(underline)
                .foregroundStyle(.primary.opacity(0.6))
                .frame(width: 24, height: 20)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Editor

    private var editorArea: some View {
        RichTextEditor(
            attributedText: $notesVM.attributedContent,
            onTextChange: nil
        )
        .onAppear {
            // Get the text view reference after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApp.windows.first(where: { $0.isVisible }),
                   let textView = findTextView(in: window.contentView) {
                    editorTextView = textView
                }
            }
        }
    }

    private func findTextView(in view: NSView?) -> NSTextView? {
        guard let view = view else { return nil }
        if let tv = view as? NSTextView, tv.isRichText { return tv }
        for sub in view.subviews {
            if let found = findTextView(in: sub) { return found }
        }
        return nil
    }
}
