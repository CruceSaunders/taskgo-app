import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Central Firestore service for all database operations
class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - User Profile

    private func userRef(_ userId: String) -> DocumentReference {
        db.collection("users").document(userId)
    }

    func createUserProfile(_ profile: UserProfile, userId: String) async throws {
        try userRef(userId).setData(from: profile)
    }

    func getUserProfile(userId: String) async throws -> UserProfile? {
        let doc = try await userRef(userId).getDocument()
        return try? doc.data(as: UserProfile.self)
    }

    func updateUserXP(userId: String, totalXP: Int, level: Int, weeklyXP: Int) async throws {
        try await userRef(userId).updateData([
            "totalXP": totalXP,
            "level": level,
            "weeklyXP": weeklyXP
        ])
    }

    // MARK: - Username Uniqueness

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let doc = try await db.collection("usernames").document(username.lowercased()).getDocument()
        return !doc.exists
    }

    func claimUsername(_ username: String, userId: String) async throws {
        let batch = db.batch()
        let usernameRef = db.collection("usernames").document(username.lowercased())

        // Check if already taken (race condition guard)
        let doc = try await usernameRef.getDocument()
        if doc.exists {
            throw NSError(domain: "TaskGo", code: 409, userInfo: [NSLocalizedDescriptionKey: "Username is already taken"])
        }

        batch.setData(["userId": userId], forDocument: usernameRef)
        try await batch.commit()
    }

    func lookupUserByUsername(_ username: String) async throws -> String? {
        let doc = try await db.collection("usernames").document(username.lowercased()).getDocument()
        return doc.data()?["userId"] as? String
    }

    // MARK: - Task Groups

    private func groupsRef(_ userId: String) -> CollectionReference {
        userRef(userId).collection("groups")
    }

    func createGroup(_ group: TaskGroup, userId: String) async throws -> String {
        let ref = try groupsRef(userId).addDocument(from: group)
        return ref.documentID
    }

    func getGroups(userId: String) async throws -> [TaskGroup] {
        let snapshot = try await groupsRef(userId)
            .order(by: "order")
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: TaskGroup.self) }
    }

    func updateGroup(_ group: TaskGroup, userId: String) async throws {
        guard let groupId = group.id else { return }
        try groupsRef(userId).document(groupId).setData(from: group, merge: true)
    }

    func deleteGroup(_ groupId: String, userId: String) async throws {
        // Delete all tasks in this group first
        let tasks = try await getTasksForGroup(groupId: groupId, userId: userId)
        let batch = db.batch()
        for task in tasks {
            if let taskId = task.id {
                batch.deleteDocument(tasksRef(userId).document(taskId))
            }
        }
        batch.deleteDocument(groupsRef(userId).document(groupId))
        try await batch.commit()
    }

    func listenToGroups(userId: String, completion: @escaping ([TaskGroup]) -> Void) -> ListenerRegistration {
        return groupsRef(userId)
            .order(by: "order")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let groups = documents.compactMap { try? $0.data(as: TaskGroup.self) }
                completion(groups)
            }
    }

    // MARK: - Tasks

    private func tasksRef(_ userId: String) -> CollectionReference {
        userRef(userId).collection("tasks")
    }

    func createTask(_ task: TaskItem, userId: String) async throws -> String {
        let ref = try tasksRef(userId).addDocument(from: task)
        return ref.documentID
    }

    func getTasksForGroup(groupId: String, userId: String) async throws -> [TaskItem] {
        let snapshot = try await tasksRef(userId)
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "position")
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: TaskItem.self) }
    }

    func updateTask(_ task: TaskItem, userId: String) async throws {
        guard let taskId = task.id else { return }
        try tasksRef(userId).document(taskId).setData(from: task, merge: true)
    }

    func deleteTask(_ taskId: String, userId: String) async throws {
        try await tasksRef(userId).document(taskId).delete()
    }

    func shiftTaskPositions(groupId: String, userId: String, fromPosition: Int) async throws {
        let snapshot = try await tasksRef(userId)
            .whereField("groupId", isEqualTo: groupId)
            .whereField("position", isGreaterThanOrEqualTo: fromPosition)
            .whereField("isComplete", isEqualTo: false)
            .getDocuments()

        let batch = db.batch()
        for doc in snapshot.documents {
            if let currentPosition = doc.data()["position"] as? Int {
                batch.updateData(["position": currentPosition + 1], forDocument: doc.reference)
            }
        }
        try await batch.commit()
    }

    func listenToTasks(userId: String, groupId: String, completion: @escaping ([TaskItem]) -> Void) -> ListenerRegistration {
        return tasksRef(userId)
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "position")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let tasks = documents.compactMap { try? $0.data(as: TaskItem.self) }
                completion(tasks)
            }
    }

    // MARK: - Social Groups

    func createSocialGroup(_ group: SocialGroup) async throws -> String {
        let ref = try db.collection("socialGroups").addDocument(from: group)
        return ref.documentID
    }

    func addMemberToSocialGroup(groupId: String, member: SocialGroupMember, userId: String) async throws {
        try db.collection("socialGroups").document(groupId)
            .collection("members").document(userId)
            .setData(from: member)
    }

    func removeMemberFromSocialGroup(groupId: String, userId: String) async throws {
        try await db.collection("socialGroups").document(groupId)
            .collection("members").document(userId).delete()
    }

    func getSocialGroupMembers(groupId: String) async throws -> [SocialGroupMember] {
        let snapshot = try await db.collection("socialGroups").document(groupId)
            .collection("members")
            .order(by: "weeklyXP", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: SocialGroupMember.self) }
    }

    func getSocialGroups(userId: String) async throws -> [SocialGroup] {
        // Get all groups where user is a member
        var groups: [SocialGroup] = []
        let allGroups = try await db.collection("socialGroups").getDocuments()

        for doc in allGroups.documents {
            let memberDoc = try await doc.reference.collection("members").document(userId).getDocument()
            if memberDoc.exists {
                if let group = try? doc.data(as: SocialGroup.self) {
                    groups.append(group)
                }
            }
        }
        return groups
    }

    // MARK: - Invites

    func createInvite(_ invite: GroupInvite, toUserId: String) async throws {
        try db.collection("users").document(toUserId)
            .collection("invites").addDocument(from: invite)
    }

    func getInvites(userId: String) async throws -> [GroupInvite] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("invites")
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: GroupInvite.self) }
    }

    func updateInviteStatus(userId: String, inviteId: String, status: String) async throws {
        try await db.collection("users").document(userId)
            .collection("invites").document(inviteId)
            .updateData(["status": status])
    }

    func listenToInvites(userId: String, completion: @escaping ([GroupInvite]) -> Void) -> ListenerRegistration {
        return db.collection("users").document(userId)
            .collection("invites")
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let invites = documents.compactMap { try? $0.data(as: GroupInvite.self) }
                completion(invites)
            }
    }
}
