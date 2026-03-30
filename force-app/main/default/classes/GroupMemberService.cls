public with sharing class GroupMemberService {
    /**
     * Return Group Id by Group.Name for Public Group (type = 'Regular')
     */
    public static Id getGroupIdByName(String groupName) {
        if (String.isBlank(groupName)) {
            throw new IllegalArgumentException('groupName is required');
        }
        List<Group> groups = [
            SELECT Id, Name, Type
            FROM Group
            WHERE Type = 'Regular' AND Name = :groupName
            LIMIT 2
        ];
        if (groups.isEmpty()) {
            throw new AuraHandledException('Public Group not found: ' + groupName);
        }
        if (groups.size() > 1) {
            throw new AuraHandledException('Multiple Public Groups found for name: ' + groupName);
        }
        return groups[0].Id;
    }

    /**
     * Ensure a User is a member of the specified Public Group.
     * Idempotent: does nothing if already a member.
     */
    public static void ensureUserInGroup(String groupName, Id userId) {
        validateUserId(userId);
        Id groupId = getGroupIdByName(groupName);

        // already a member? do nothing
        if (isUserInGroup(groupId, userId)) {
            return;
        }

        GroupMember gm = new GroupMember();
        gm.GroupId = groupId;
        gm.UserOrGroupId = userId;
        insert gm;
    }

    /**
     * Remove a User from the specified Public Group.
     * Idempotent: does nothing if not a member.
     */
    public static void removeUserFromGroup(String groupName, Id userId) {
        validateUserId(userId);
        Id groupId = getGroupIdByName(groupName);

        GroupMember gm = [
            SELECT Id
            FROM GroupMember
            WHERE GroupId = :groupId AND UserOrGroupId = :userId
            LIMIT 1
        ];
        if (gm != null) {
            delete gm;
        }
    }

    /**
     * Helper: check membership existence
     */
    @TestVisible
    private static Boolean isUserInGroup(Id groupId, Id userId) {
        return [
            SELECT Id
            FROM GroupMember
            WHERE GroupId = :groupId AND UserOrGroupId = :userId
            LIMIT 1
        ].size() == 1;
    }

    private static void validateUserId(Id userId) {
        if (userId == null || String.valueOf(userId).length() == 0) {
            throw new IllegalArgumentException('userId is required');
        }
        if (String.valueOf(userId).substring(0, 3) != '005') {
            throw new IllegalArgumentException('userId must be a User Id');
        }
    }
}