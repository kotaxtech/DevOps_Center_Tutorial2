public with sharing class AccountOpportunityRollupService {
    public class RollupResult {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Integer openCount;
        @AuraEnabled public Integer closedWonCount;
        @AuraEnabled public Integer closedLostCount;

        public RollupResult(Id accountId, Decimal totalAmount, Integer openCount, Integer closedWonCount, Integer closedLostCount) {
            this.accountId = accountId;
            this.totalAmount = totalAmount;
            this.openCount = openCount;
            this.closedWonCount = closedWonCount;
            this.closedLostCount = closedLostCount;
        }
    }

    /**
     * Aggregates Opportunity metrics per Account for the specified Account Ids.
     * - totalAmount: SUM of Amount for open opportunities (where IsClosed = false)
     * - openCount: number of open opportunities
     * - closedWonCount: number of Closed Won opportunities
     * - closedLostCount: number of Closed Lost opportunities
     *
     * Notes:
     * - Uses a single grouped SOQL with rollup fields for performance.
     * - Returns a result for provided Account Ids that have at least one Opportunity.
     * - Callers may choose to merge the result into a full Id->default map if they need entries for accounts with zero opps.
     */
    @AuraEnabled(cacheable=true)
    public static Map<Id, RollupResult> getRollupsByAccountIds(List<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return new Map<Id, RollupResult>();
        }

        // Guardrail: only Account Ids
        Set<Id> filtered = new Set<Id>();
        for (Id i : new Set<Id>(accountIds)) {
            if (i != null && String.valueOf(i).startsWith('001')) {
                filtered.add(i);
            }
        }
        if (filtered.isEmpty()) {
            return new Map<Id, RollupResult>();
        }

        // Aggregation via single SOQL using conditional sums
        // We compute:
        // - SUM(CASE WHEN IsClosed = false THEN Amount ELSE 0 END)
        // - SUM(CASE WHEN IsClosed = false THEN 1 ELSE 0 END) as openCount
        // - SUM(CASE WHEN IsWon = true THEN 1 ELSE 0 END) as closedWonCount
        // - SUM(CASE WHEN IsClosed = true AND IsWon = false THEN 1 ELSE 0 END) as closedLostCount
        Map<Id, RollupResult> resultMap = new Map<Id, RollupResult>();

        // Apex SOQL doesn't support SQL-style CASE expressions directly in the SELECT list.
        // We'll query the necessary fields and aggregate in Apex instead.
        for (Opportunity opp : [
            SELECT Id, AccountId, Amount, IsClosed, IsWon
            FROM Opportunity
            WHERE AccountId IN :filtered
        ]) {
            Id accId = opp.AccountId;
            if (accId == null) continue;

            RollupResult current = resultMap.get(accId);
            if (current == null) {
                current = new RollupResult(accId, 0, 0, 0, 0);
                resultMap.put(accId, current);
            }

            // Open opp metrics
            if (!opp.IsClosed) {
                current.openCount = (current.openCount == null ? 0 : current.openCount) + 1;
                if (opp.Amount != null) {
                    current.totalAmount = (current.totalAmount == null ? 0 : current.totalAmount) + opp.Amount;
                }
            }

            // Closed statuses
            if (opp.IsWon) {
                current.closedWonCount = (current.closedWonCount == null ? 0 : current.closedWonCount) + 1;
            } else if (opp.IsClosed && !opp.IsWon) {
                current.closedLostCount = (current.closedLostCount == null ? 0 : current.closedLostCount) + 1;
            }
        }

        // Normalize totals scale (2) for consistency
        for (Id aid : resultMap.keySet()) {
            RollupResult rr = resultMap.get(aid);
            rr.totalAmount = (rr.totalAmount == null ? 0 : rr.totalAmount.setScale(2));
            rr.openCount = (rr.openCount == null ? 0 : rr.openCount);
            rr.closedWonCount = (rr.closedWonCount == null ? 0 : rr.closedWonCount);
            rr.closedLostCount = (rr.closedLostCount == null ? 0 : rr.closedLostCount);
        }

        return resultMap;
    }

    /**
     * Convenience method: compute rollup for a single Account Id.
     */
    @AuraEnabled(cacheable=true)
    public static RollupResult getRollupByAccountId(Id accountId) {
        Map<Id, RollupResult> m = getRollupsByAccountIds(new List<Id>{ accountId });
        return m.containsKey(accountId) ? m.get(accountId) : new RollupResult(accountId, 0, 0, 0, 0);
    }
}