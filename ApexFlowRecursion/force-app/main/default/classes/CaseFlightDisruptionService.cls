/**
 * CaseFlightDisruptionService
 * Business logic specific to Flight Disruption cases.
 * Singleton — one instance per transaction.
 */
public inherited sharing class CaseFlightDisruptionService {

    private static CaseFlightDisruptionService instance;
    public static CaseFlightDisruptionService getInstance() {
        if (instance == null) instance = new CaseFlightDisruptionService();
        return instance;
    }

    public void setDefaultResolution(List<Case> cancellationCases) {
        for (Case c : cancellationCases) {
            if (String.isBlank(c.Resolution__c)) {
                c.Resolution__c = 'Refund';
            }
        }
    }

    public void applyFlightDisruptionDefaults(List<Case> flightDisruptionCases) {
        for (Case c : flightDisruptionCases) {
            if (c.Priority == null) c.Priority = 'High';
            if (c.Origin   == null) c.Origin   = 'Phone';
        }
    }
}