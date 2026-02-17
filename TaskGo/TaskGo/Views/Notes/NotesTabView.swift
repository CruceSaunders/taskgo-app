import SwiftUI

struct NotesTabView: View {
    @EnvironmentObject var notesVM: NotesViewModel
    @StateObject private var editorCoordinator = RichTextEditorCoordinator()

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
                RichTextEditor(
                    attributedText: $notesVM.attributedContent,
                    coordinator: editorCoordinator
                )
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
            toolbarToggle("B", font: .system(size: 11, weight: .bold), isActive: editorCoordinator.isBold) {
                editorCoordinator.toggleBold()
            }
            toolbarToggle("I", font: .system(size: 11).italic(), isActive: editorCoordinator.isItalic) {
                editorCoordinator.toggleItalic()
            }
            toolbarToggle("U", font: .system(size: 11), underline: true, isActive: editorCoordinator.isUnderline) {
                editorCoordinator.toggleUnderline()
            }

            Divider().frame(height: 14).padding(.horizontal, 2)

            toolbarToggle("H1", font: .system(size: 9, weight: .bold)) {
                editorCoordinator.setHeader(1)
            }
            toolbarToggle("H2", font: .system(size: 9, weight: .semibold)) {
                editorCoordinator.setHeader(2)
            }
            toolbarToggle("T", font: .system(size: 9)) {
                editorCoordinator.setHeader(0)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.04))
    }

    private func toolbarToggle(_ label: String, font: Font, underline: Bool = false, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(font)
                .underline(underline)
                .foregroundStyle(isActive ? .white : .primary.opacity(0.6))
                .frame(width: 24, height: 20)
                .background(isActive ? Color.calmTeal : Color.secondary.opacity(0.08))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
