@IsTest
private class GroupMemberService2Test {

    private static User createStdUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'tuser2',
            Email = 'tuser2@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User2',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'tuser2+' + System.now().getTime() + '@example.com',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    private static Id findTestGroup2Id() {
        // デプロイ済みの Public Group: TestGroup2 を前提
        Group g = [
            SELECT Id, Name, Type
            FROM Group
            WHERE Type = 'Regular' AND Name = 'TestGroup2'
            LIMIT 1
        ];
        System.assertEquals('TestGroup2', g.Name, 'Group name mismatch');
        return g.Id;
    }

    @IsTest
    static void testAddAndRemoveUser_Group2() {
        User u = createStdUser();

        System.runAs(u) {
            Test.startTest();
            // 追加（冪等性: 2回実行しても重複しない）
            GroupMemberService2.ensureUserInGroup('TestGroup2', u.Id);
            GroupMemberService2.ensureUserInGroup('TestGroup2', u.Id);
            Test.stopTest();
        }

        Id groupId = findTestGroup2Id();
        System.assertEquals(true, GroupMemberService2.isUserInGroup(groupId, u.Id), 'user should be in group after ensure');

        // 削除（冪等性: 2回実行しても例外にならない）
        Test.startTest();
        GroupMemberService2.removeUserFromGroup('TestGroup2', u.Id);
        GroupMemberService2.removeUserFromGroup('TestGroup2', u.Id);
        Test.stopTest();

        System.assertEquals(false, GroupMemberService2.isUserInGroup(groupId, u.Id), 'user should be removed from group');
    }

    @IsTest
    static void testInvalidParams_Group2() {
        // 無効ID（先頭が005でないものを使用）
        try {
            GroupMemberService2.ensureUserInGroup('TestGroup2', '001000000000001'); // Account Id 例
            System.assert(false, 'should have thrown');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('User Id'), 'message should mention User Id');
        }

        // 不正グループ名
        try {
            GroupMemberService2.ensureUserInGroup(null, UserInfo.getUserId());
            System.assert(false, 'should have thrown');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('required'), 'message should mention required');
        }
    }
}