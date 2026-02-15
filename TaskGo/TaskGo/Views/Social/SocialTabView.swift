import SwiftUI

struct SocialTabView: View {
    @EnvironmentObject var socialVM: SocialViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showCreateGroup = false
    @State private var newGroupName = ""
    @State private var showInvite = false
    @State private var inviteUsername = ""

    var body: some View {
        VStack(spacing: 0) {
            // Pending invites banner
            if !socialVM.pendingInvites.isEmpty {
                invitesBanner
                Divider()
            }

            if socialVM.socialGroups.isEmpty {
                emptyState
            } else {
                groupList
            }
        }
        .onAppear {
            Task { await socialVM.loadSocialGroups() }
        }
    }

    private var invitesBanner: some View {
        VStack(spacing: 6) {
            ForEach(socialVM.pendingInvites) { invite in
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.calmTeal)

                    Text("\(invite.invitedByUsername) invited you to \(invite.groupName)")
                        .font(.system(size: 11))
                        .lineLimit(1)

                    Spacer()

                    Button(action: {
                        Task { await socialVM.acceptInvite(invite) }
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.calmTeal)
                    .controlSize(.mini)

                    Button(action: {
                        Task { await socialVM.declineInvite(invite) }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.calmTeal.opacity(0.05))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No groups yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Create a group and invite friends to compete!")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("Create Group") {
                showCreateGroup = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.calmTeal)
            .controlSize(.small)
            Spacer()
        }
        .padding(.horizontal)
        .popover(isPresented: $showCreateGroup) {
            createGroupPopover
        }
    }

    private var groupList: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(socialVM.socialGroups) { group in
                        SocialGroupRow(group: group)
                        Divider()
                    }
                }
            }

            Divider()

            // Create group button
            Button(action: { showCreateGroup = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.calmTeal)
                    Text("Create group")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showCreateGroup) {
                createGroupPopover
            }
        }
    }

    private var createGroupPopover: some View {
        VStack(spacing: 8) {
            Text("Create Group")
                .font(.headline)
            TextField("Group name", text: $newGroupName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
            HStack {
                Button("Cancel") {
                    showCreateGroup = false
                    newGroupName = ""
                }
                Button("Create") {
                    Task {
                        await socialVM.createSocialGroup(name: newGroupName)
                        newGroupName = ""
                        showCreateGroup = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.calmTeal)
                .disabled(newGroupName.isEmpty)
            }
        }
        .padding()
    }
}

struct SocialGroupRow: View {
    @EnvironmentObject var socialVM: SocialViewModel
    @EnvironmentObject var authVM: AuthViewModel
    let group: SocialGroup

    @State private var showLeaderboard = false
    @State private var showInvite = false
    @State private var inviteUsername = ""

    var isHost: Bool {
        group.hostUserId == authVM.currentUser?.uid
    }

    var body: some View {
        Button(action: {
            socialVM.selectGroup(group)
            showLeaderboard = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.system(size: 13, weight: .medium))
                    if isHost {
                        Text("Host")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.calmTeal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.calmTeal.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showLeaderboard) {
            LeaderboardView(group: group, isHost: isHost)
                .frame(width: 280, height: 350)
        }
    }
}

struct LeaderboardView: View {
    @EnvironmentObject var socialVM: SocialViewModel
    @EnvironmentObject var authVM: AuthViewModel
    let group: SocialGroup
    let isHost: Bool

    @State private var showInvite = false
    @State private var inviteUsername = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(group.name)
                    .font(.headline)
                Spacer()
                if isHost {
                    Button(action: { showInvite = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)

            Text("Weekly Leaderboard")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)

            Divider()

            // Members ranked by weekly XP
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(socialVM.members.enumerated()), id: \.element.id) { index, member in
                        HStack(spacing: 8) {
                            // Rank
                            Text("#\(index + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(index < 3 ? Color.amber : .secondary)
                                .frame(width: 30)

                            // Name
                            VStack(alignment: .leading, spacing: 1) {
                                Text(member.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                Text("@\(member.username)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            // Level
                            Text("Lv.\(member.level)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)

                            // Weekly XP
                            Text("\(member.weeklyXP) XP")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.calmTeal)

                            // Kick button (host only, can't kick self)
                            if isHost && member.id != authVM.currentUser?.uid {
                                Button(action: {
                                    Task {
                                        await socialVM.kickMember(
                                            userId: member.id ?? "",
                                            fromGroupId: group.id ?? ""
                                        )
                                    }
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        Divider()
                            .padding(.leading, 42)
                    }
                }
            }
        }
        .onAppear {
            Task { await socialVM.loadMembers(for: group.id ?? "") }
        }
        .popover(isPresented: $showInvite) {
            VStack(spacing: 8) {
                Text("Invite User")
                    .font(.headline)
                TextField("Username", text: $inviteUsername)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                HStack {
                    Button("Cancel") {
                        showInvite = false
                        inviteUsername = ""
                    }
                    Button("Invite") {
                        Task {
                            await socialVM.inviteUser(
                                username: inviteUsername,
                                toGroupId: group.id ?? "",
                                groupName: group.name
                            )
                            inviteUsername = ""
                            showInvite = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.calmTeal)
                    .disabled(inviteUsername.isEmpty)
                }
            }
            .padding()
        }
    }
}
