/**
 * CaseNotificationService
 * Handles all Case-related notifications and alerts.
 * Singleton — one instance per transaction.
 */
public inherited sharing class CaseNotificationService {

    private static CaseNotificationService instance;
    public static CaseNotificationService getInstance() {
        if (instance == null) instance = new CaseNotificationService();
        return instance;
    }

    public void notifyOperationsTeam(List<Case> flightDisruptionCases) {
        Set<Id> caseIds = new Map<Id, Case>(flightDisruptionCases).keySet();
        List<Case> casesWithDetails = CaseSelector.selectByIds(caseIds);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Case c : casesWithDetails) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ 'operations@airline.com' });
            email.setSubject('New Flight Disruption Case: ' + c.CaseNumber);
            email.setPlainTextBody(
                'A new Flight Disruption case has been created.\n' +
                'Case: '    + c.CaseNumber + '\n' +
                'Type: '    + c.Type       + '\n' +
                'Subject: ' + c.Subject
            );
            emails.add(email);
        }

        if (!emails.isEmpty() && !Test.isRunningTest()) {
            Messaging.sendEmail(emails);
        }
    }

}