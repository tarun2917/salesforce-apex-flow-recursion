/**
 * CaseDomain
 * Classifies Case records into named buckets in ONE loop.
 * No SOQL. No DML. No business logic.
 * classify() runs in the constructor — handler just reads the buckets.
 */
public class CaseDomain {

    private List<Case> newList;
    private Map<Id, Case> oldMap;

    // ── public buckets — read directly by CaseService ────────────────────────
    public List<Case> cancellationCases      = new List<Case>();
    public List<Case> flightDisruptionCases  = new List<Case>();
    public List<Case> statusChangedCases     = new List<Case>();
    public List<Case> closedCases            = new List<Case>();
    public List<Case> priorityEscalatedCases = new List<Case>();

    public CaseDomain(List<Case> newList, Map<Id, Case> oldMap) {
        this.newList = newList;
        this.oldMap  = oldMap;
        classify();
    }

    public List<Case> getAllCases() { return newList; }

    // ── private: one loop, one method per classification theme ───────────────

    private void classify() {
        for (Case c : newList) {
            Case old = oldMap != null ? oldMap.get(c.Id) : null;
            classifyByRecordType(c);
            classifyByStatusChange(c, old);
            classifyByPriority(c, old);
        }
    }

    private void classifyByRecordType(Case c) {
        if (!UtilityClass.isRecordType(c.RecordTypeId, 'Case', 'Flight_Disruption')) return;
        flightDisruptionCases.add(c);
        if (c.Type == 'Cancellation') cancellationCases.add(c);
    }

    private void classifyByStatusChange(Case c, Case old) {
        if (old == null || c.Status == old.Status) return;
        statusChangedCases.add(c);
        if (c.IsClosed) closedCases.add(c);
    }

    private void classifyByPriority(Case c, Case old) {
        if (old == null || !isPriorityEscalated(old.Priority, c.Priority)) return;
        priorityEscalatedCases.add(c);
    }

    // ── helpers ───────────────────────────────────────────────────────────────

    private static final List<String> PRIORITY_ORDER = new List<String>{
        'Low', 'Medium', 'High', 'Critical'
    };

    private Boolean isPriorityEscalated(String oldP, String newP) {
        Integer oldRank = PRIORITY_ORDER.indexOf(oldP);
        Integer newRank = PRIORITY_ORDER.indexOf(newP);
        return oldRank != -1 && newRank != -1 && newRank > oldRank;
    }
}