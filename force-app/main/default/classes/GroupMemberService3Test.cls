@IsTest
private class GroupMemberService3Test {

    private static User createStdUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'tuser3',
            Email = 'tuser3@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User3',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'tuser3+' + System.now().getTime() + '@example.com',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    private static Id findTestGroup3Id() {
        // デプロイ済みの Public Group: TestGroup3 を前提
        Group g = [
            SELECT Id, Name, Type
            FROM Group
            WHERE Type = 'Regular' AND Name = 'TestGroup3'
            LIMIT 1
        ];
        System.assertEquals('TestGroup3', g.Name, 'Group name mismatch');
        return g.Id;
    }

    @IsTest
    static void testAddAndRemoveUser_Group3() {
        User u = createStdUser();

        System.runAs(u) {
            Test.startTest();
            // 追加（冪等性: 2回実行しても重複しない）
            GroupMemberService3.ensureUserInGroup('TestGroup3', u.Id);
            GroupMemberService3.ensureUserInGroup('TestGroup3', u.Id);
            Test.stopTest();
        }

        Id groupId = findTestGroup3Id();
        System.assertEquals(true, GroupMemberService3.isUserInGroup(groupId, u.Id), 'user should be in group after ensure');

        // 削除（冪等性: 2回実行しても例外にならない）
        Test.startTest();
        GroupMemberService3.removeUserFromGroup('TestGroup3', u.Id);
        GroupMemberService3.removeUserFromGroup('TestGroup3', u.Id);
        Test.stopTest();

        System.assertEquals(false, GroupMemberService3.isUserInGroup(groupId, u.Id), 'user should be removed from group');
    }

    @IsTest
    static void testInvalidParams_Group3() {
        // 無効ID（先頭が005でないものを使用）
        try {
            GroupMemberService3.ensureUserInGroup('TestGroup3', '001000000000001'); // Account Id 例
            System.assert(false, 'should have thrown');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('User Id'), 'message should mention User Id');
        }

        // 不正グループ名
        try {
            GroupMemberService3.ensureUserInGroup(null, UserInfo.getUserId());
            System.assert(false, 'should have thrown');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('required'), 'message should mention required');
        }
    }
}