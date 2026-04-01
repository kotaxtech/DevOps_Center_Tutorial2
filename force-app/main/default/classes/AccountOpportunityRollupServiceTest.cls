@IsTest
private class AccountOpportunityRollupServiceTest {
    @TestSetup
    static void setup() {
        // Create Accounts
        Account a1 = new Account(Name = 'Acme 1');
        Account a2 = new Account(Name = 'Acme 2');
        Account a3 = new Account(Name = 'No Opps');
        insert new List<Account>{ a1, a2, a3 };

        // Opportunities for a1
        Opportunity a1o1 = new Opportunity(
            Name = 'A1 Open 10',
            AccountId = a1.Id,
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            Amount = 10
        );
        Opportunity a1o2 = new Opportunity(
            Name = 'A1 Won 50',
            AccountId = a1.Id,
            StageName = 'Closed Won',
            CloseDate = System.today(),
            Amount = 50
        );
        Opportunity a1o3 = new Opportunity(
            Name = 'A1 Lost',
            AccountId = a1.Id,
            StageName = 'Closed Lost',
            CloseDate = System.today(),
            Amount = 999 // should not affect totals as it's closed
        );

        // Opportunities for a2
        Opportunity a2o1 = new Opportunity(
            Name = 'A2 Open null',
            AccountId = a2.Id,
            StageName = 'Qualification',
            CloseDate = System.today().addDays(10),
            Amount = null
        );
        Opportunity a2o2 = new Opportunity(
            Name = 'A2 Open 20',
            AccountId = a2.Id,
            StageName = 'Value Proposition',
            CloseDate = System.today().addDays(20),
            Amount = 20
        );

        insert new List<Opportunity>{ a1o1, a1o2, a1o3, a2o1, a2o2 };
    }

    @IsTest
    static void test_getRollupsByAccountIds_multiple() {
        List<Account> accts = [SELECT Id, Name FROM Account WHERE Name IN ('Acme 1','Acme 2','No Opps')];
        System.assertEquals(3, accts.size(), 'Test data accounts not found');

        Id a1;
        Id a2;
        Id a3;
        for (Account a : accts) {
            if (a.Name == 'Acme 1') a1 = a.Id;
            else if (a.Name == 'Acme 2') a2 = a.Id;
            else if (a.Name == 'No Opps') a3 = a.Id;
        }
        System.assertNotEquals(null, a1, 'Acme 1 id not found');
        System.assertNotEquals(null, a2, 'Acme 2 id not found');
        System.assertNotEquals(null, a3, 'No Opps id not found');

        Test.startTest();
        Map<Id, AccountOpportunityRollupService.RollupResult> res =
            AccountOpportunityRollupService.getRollupsByAccountIds(new List<Id>{ a1, a2, a3 });
        Test.stopTest();

        // a1: open = 1 (10), won = 1, lost = 1
        System.assert(res.containsKey(a1), 'a1 should be present');
        AccountOpportunityRollupService.RollupResult r1 = res.get(a1);
        System.assertEquals(1, r1.openCount, 'a1 open count');
        System.assertEquals(1, r1.closedWonCount, 'a1 won count');
        System.assertEquals(1, r1.closedLostCount, 'a1 lost count');
        System.assertEquals(10, r1.totalAmount, 'a1 open total amount');

        // a2: open = 2 (null + 20 -> 20), won=0, lost=0
        System.assert(res.containsKey(a2), 'a2 should be present');
        AccountOpportunityRollupService.RollupResult r2 = res.get(a2);
        System.assertEquals(2, r2.openCount, 'a2 open count');
        System.assertEquals(0, r2.closedWonCount, 'a2 won count');
        System.assertEquals(0, r2.closedLostCount, 'a2 lost count');
        System.assertEquals(20, r2.totalAmount, 'a2 open total amount');

        // a3: has no opps; service returns only accounts with at least one opp
        System.assert(!res.containsKey(a3), 'a3 should not be present since no opportunities');
    }

    @IsTest
    static void test_getRollupByAccountId_single_account_with_no_opps() {
        Account a = [SELECT Id FROM Account WHERE Name = 'No Opps' LIMIT 1];

        Test.startTest();
        AccountOpportunityRollupService.RollupResult r = AccountOpportunityRollupService.getRollupByAccountId(a.Id);
        Test.stopTest();

        // Single-account helper returns a default result when no opps are found
        System.assertEquals(a.Id, r.accountId, 'account id passthrough');
        System.assertEquals(0, r.openCount, 'default open');
        System.assertEquals(0, r.closedWonCount, 'default won');
        System.assertEquals(0, r.closedLostCount, 'default lost');
        System.assertEquals(0, r.totalAmount, 'default amount');
    }

    @IsTest
    static void test_guardrail_filters_non_account_ids() {
        // Create a Contact and pass its Id mixed with an Account Id
        Account a = [SELECT Id FROM Account WHERE Name = 'Acme 1' LIMIT 1];
        Contact c = new Contact(LastName='X', AccountId=a.Id);
        insert c;

        Set<Id> mixed = new Set<Id>{ a.Id, c.Id, (Id) null };

        Test.startTest();
        Map<Id, AccountOpportunityRollupService.RollupResult> res =
            AccountOpportunityRollupService.getRollupsByAccountIds(new List<Id>(mixed));
        Test.stopTest();

        // Ensure only Account Ids are processed
        System.assert(res.containsKey(a.Id), 'must contain account');
        for (Id keyId : res.keySet()) {
            System.assert(String.valueOf(keyId).startsWith('001'), 'only Account Ids expected');
        }
    }
}