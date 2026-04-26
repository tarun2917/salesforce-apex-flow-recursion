/**
 * CaseStatusService
 * Handles consequences of Case status changes.
 * Singleton — one instance per transaction.
 */
public with sharing class CaseStatusService {

    private static CaseStatusService instance;
    public static CaseStatusService getInstance() {
        if (instance == null) instance = new CaseStatusService();
        return instance;
    }

    public void onStatusChanged(List<Case> statusChangedCases) {
        for (Case c : statusChangedCases) {
            System.debug('Status changed for Case: ' + c.Id + ' → ' + c.Status);
        }
    }
}