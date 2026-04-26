/**
 * UtilityClass
 * Common org-wide utility methods.
 * Zero SOQL — uses Schema describe with transaction-level caching.
 */
public class UtilityClass {

    // ── Record Type ───────────────────────────────────────────────────────────

    // cache['Case'] = { 'Flight_Disruption' => '012...', 'Billing' => '012...' }
    private static Map<String, Map<String, Id>> recordTypeCache = new Map<String, Map<String, Id>>();

    public static Id getRecordTypeId(String sObjectType, String developerName) {
        loadRecordTypesIfAbsent(sObjectType);
        return recordTypeCache.get(sObjectType).get(developerName);
    }

    public static Boolean isRecordType(Id recordTypeId, String sObjectType, String developerName) {
        return recordTypeId == getRecordTypeId(sObjectType, developerName);
    }

    private static void loadRecordTypesIfAbsent(String sObjectType) {
        if (recordTypeCache.containsKey(sObjectType)) return;

        Map<String, Id> byName = new Map<String, Id>();
        for (Schema.RecordTypeInfo rti :
            Schema.getGlobalDescribe()
                  .get(sObjectType)
                  .getDescribe()
                  .getRecordTypeInfosByDeveloperName()
                  .values()
        ) {
            byName.put(rti.getDeveloperName(), rti.getRecordTypeId());
        }
        recordTypeCache.put(sObjectType, byName);
    }
}