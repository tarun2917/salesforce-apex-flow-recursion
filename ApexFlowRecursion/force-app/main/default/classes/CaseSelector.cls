/**
 * CaseSelector
 * Single source of truth for all Case SOQL.
 * No business logic. No DML.
 * Every query for Case records across the entire codebase lives here.
 */
public with sharing class CaseSelector {

    /**
     * Fetch cases with full detail by Id set.
     */
    public static List<Case> selectByIds(Set<Id> caseIds) {
        return [
            SELECT Id, CaseNumber, Subject, Status, Type, Priority,
                   Origin, Resolution__c,
                   RecordType.DeveloperName, AccountId,
                   OwnerId, CreatedDate
            FROM   Case
            WHERE  Id IN :caseIds WITH SECURITY_ENFORCED
        ];
    }

    /**
     * Fetch cases by status
     */
    public static List<Case> selectByStatus(String status) {
        return [
            SELECT Id, CaseNumber, Status, Priority, OwnerId
            FROM   Case
            WHERE  Status = :status WITH SECURITY_ENFORCED
        ];
    }
}