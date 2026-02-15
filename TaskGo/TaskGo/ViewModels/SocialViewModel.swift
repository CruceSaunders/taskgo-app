import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class SocialViewModel: ObservableObject {
    @Published var socialGroups: [SocialGroup] = []
    @Published var selectedSocialGroup: SocialGroup?
    @Published var members: [SocialGroupMember] = []
    @Published var pendingInvites: [GroupInvite] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private var inviteListener: ListenerRegistration?

    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        inviteListener = firestoreService.listenToInvites(userId: userId) { [weak self] invites in
            Task { @MainActor in
                self?.pendingInvites = invites
            }
        }
    }

    func stopListening() {
        inviteListener?.remove()
        inviteListener = nil
    }

    func loadSocialGroups() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        do {
            socialGroups = try await firestoreService.getSocialGroups(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createSocialGroup(name: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            // Get current user profile for member entry
            guard let profile = try await firestoreService.getUserProfile(userId: userId) else { return }

            let group = SocialGroup(name: name, hostUserId: userId)
            let groupId = try await firestoreService.createSocialGroup(group)

            // Add host as first member
            let hostMember = SocialGroupMember(
                role: "host",
                weeklyXP: profile.weeklyXP,
                displayName: profile.displayName,
                username: profile.username,
                level: profile.level
            )
            try await firestoreService.addMemberToSocialGroup(
                groupId: groupId,
                member: hostMember,
                userId: userId
            )

            await loadSocialGroups()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func inviteUser(username: String, toGroupId: String, groupName: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            // Look up user by username
            guard let targetUserId = try await firestoreService.lookupUserByUsername(username) else {
                errorMessage = "User '\(username)' not found"
                return
            }

            // Get inviter's profile for invite info
            guard let profile = try await firestoreService.getUserProfile(userId: userId) else { return }

            let invite = GroupInvite(
                groupId: toGroupId,
                groupName: groupName,
                invitedBy: userId,
                invitedByUsername: profile.username
            )

            try await firestoreService.createInvite(invite, toUserId: targetUserId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptInvite(_ invite: GroupInvite) async {
        guard let userId = Auth.auth().currentUser?.uid,
              let inviteId = invite.id else { return }

        do {
            guard let profile = try await firestoreService.getUserProfile(userId: userId) else { return }

            // Add user as member of the social group
            let member = SocialGroupMember(
                role: "member",
                weeklyXP: profile.weeklyXP,
                displayName: profile.displayName,
                username: profile.username,
                level: profile.level
            )
            try await firestoreService.addMemberToSocialGroup(
                groupId: invite.groupId,
                member: member,
                userId: userId
            )

            // Update invite status
            try await firestoreService.updateInviteStatus(userId: userId, inviteId: inviteId, status: "accepted")

            await loadSocialGroups()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineInvite(_ invite: GroupInvite) async {
        guard let userId = Auth.auth().currentUser?.uid,
              let inviteId = invite.id else { return }

        do {
            try await firestoreService.updateInviteStatus(userId: userId, inviteId: inviteId, status: "declined")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func kickMember(userId: String, fromGroupId: String) async {
        do {
            try await firestoreService.removeMemberFromSocialGroup(groupId: fromGroupId, userId: userId)
            await loadMembers(for: fromGroupId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMembers(for groupId: String) async {
        do {
            members = try await firestoreService.getSocialGroupMembers(groupId: groupId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectGroup(_ group: SocialGroup) {
        selectedSocialGroup = group
        Task {
            await loadMembers(for: group.id ?? "")
        }
    }
}
