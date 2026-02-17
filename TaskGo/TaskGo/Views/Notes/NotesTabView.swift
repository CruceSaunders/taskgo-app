import SwiftUI

struct NotesTabView: View {
    @EnvironmentObject var notesVM: NotesViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar: date list
            notesSidebar
                .frame(width: 90)

            Divider()

            // Right: editor
            noteEditor
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
            // Today button (always at top)
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

            // Previous notes
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

    // MARK: - Editor

    private var noteEditor: some View {
        VStack(spacing: 0) {
            // Date header
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
            .padding(.vertical, 6)

            Divider()

            // Text area
            ScrollView {
                TextField("Start writing...", text: $notesVM.content, axis: .vertical)
                    .font(.system(size: 12))
                    .lineLimit(nil)
                    .textFieldStyle(.plain)
                    .padding(10)
            }
        }
    }
}
