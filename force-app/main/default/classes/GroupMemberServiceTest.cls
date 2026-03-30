@IsTest
private class GroupMemberServiceTest {

    private static User createStdUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'tuser',
            Email = 'tuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'tuser+' + System.now().getTime() + '@example.com',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    private static Id findTestGroupId() {
        // デプロイ済みの Public Group: TestGroup を前提
        Group g = [
            SELECT Id, Name, Type
            FROM Group
            WHERE Type = 'Regular' AND Name = 'TestGroup'
            LIMIT 1
        ];
        System.assertEquals('TestGroup', g.Name, 'Group name mismatch');
        return g.Id;
    }

    @IsTest
    static void testAddAndRemoveUser() {
        User u = createStdUser();

        System.runAs(u) {
            Test.startTest();
            // 追加（冪等性: 2回実行しても重複しない）
            GroupMemberService.ensureUserInGroup('TestGroup', u.Id);
            GroupMemberService.ensureUserInGroup('TestGroup', u.Id);
            Test.stopTest();
        }

        Id groupId = findTestGroupId();
        System.assertEquals(true, GroupMemberService.isUserInGroup(groupId, u.Id), 'user should be in group after ensure');

        // 削除（冪等性: 2回実行しても例外にならない）
        Test.startTest();
        GroupMemberService.removeUserFromGroup('TestGroup', u.Id);
        GroupMemberService.removeUserFromGroup('TestGroup', u.Id);
        Test.stopTest();

        System.assertEquals(false, GroupMemberService.isUserInGroup(groupId, u.Id), 'user should be removed from group');
    }

    @IsTest
    static void testInvalidParams() {
        // 無効ID（先頭が005でないものを使用）
        try {
            GroupMemberService.ensureUserInGroup('TestGroup', '001000000000001'); // Account Id 例
            System.assert(false, 'should have thrown');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('User Id'), 'message should mention User Id');
        }

        // 不正グループ名
        try {
            GroupMemberService.ensureUserInGroup(null, UserInfo.getUserId());
            System.assert(false, 'should have thrown');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('required'), 'message should mention required');
        }
    }
}