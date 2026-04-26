/**
 * @description  Generic, org-wide recursion control.
 *               Uses a Map<String, Set<Id>> where any caller — trigger handler,
 *               flow, batch — registers its own unique key.
 *               No object-specific code. One class for the entire org.
 *
 * @usage        Apex:  RecursionHandler.isProcessed('CaseHandler.updateAccounts', recordId)
 *               Apex:  RecursionHandler.filterUnprocessed('CaseHandler.updateAccounts', records)
 *               Flow:  Via RecursionFlowHelper invocable
 *
 * @author       Your Name
 * @date         2026-03-16
 */
public class RecursionHandler {

    // Key   = unique string (handler.method, flow name, any identifier)
    // Value = Set of record Ids already processed for that key
    private static Map<String, Set<Id>> processedRecordsMap = 
        new Map<String, Set<Id>>();

    /**
     * @description  Check if a record has already been processed for a given key
     * @param        key      Unique identifier (e.g. 'CaseHandler.updateAccounts')
     * @param        recordId The record Id to check
     * @return       true if already processed, false if not
     */
    public static Boolean isProcessed(String key, Id recordId) {
        Boolean result = processedRecordsMap.containsKey(key) &&
                         processedRecordsMap.get(key).contains(recordId);
        System.debug('>> Is Recursion Handler Processed>> Key.Id: ' + key + recordId + '>>Result: ' + result);
        return result;
    }

    /**
     * @description  Mark a single record as processed for a given key
     * @param        key      Unique identifier
     * @param        recordId The record Id to mark
     */
    public static void markProcessed(String key, Id recordId) {
        if (!processedRecordsMap.containsKey(key)) {
            processedRecordsMap.put(key, new Set<Id>());
        }
        processedRecordsMap.get(key).add(recordId);
        System.debug('>> Marked Processed Recursion Handler>> Key.Id: ' + key + recordId +'processed details'+ processedRecordsMap.get(key).size());
    }

    /**
     * @description  Mark multiple records as processed for a given key
     * @param        key       Unique identifier
     * @param        recordIds Set of record Ids to mark
     */
    public static void markProcessed(String key, Set<Id> recordIds) {
        if (!processedRecordsMap.containsKey(key)) {
            processedRecordsMap.put(key, new Set<Id>());
        }
        processedRecordsMap.get(key).addAll(recordIds);
    }

    /**
     * @description  Filter a list of records, returning only unprocessed ones.
     *               Automatically marks returned records as processed.
     *               Use in trigger handlers to get clean records in one step.
     * @param        key     Unique identifier
     * @param        records List of SObjects to filter
     * @return       List of SObjects not yet processed
     */
    public static List<SObject> filterUnprocessed(String key, List<SObject> records) {
        List<SObject> unprocessed = new List<SObject>();

        for (SObject record : records) {
            Id recordId = record.Id;
            if (!isProcessed(key, recordId)) {
                markProcessed(key, recordId);
                unprocessed.add(record);
            }
        }

        return unprocessed;
    }

    /**
     * @description  Reset tracking for a specific key
     * @param        key The key to reset
     */
    public static void reset(String key) {
        processedRecordsMap.remove(key);
    }

    /**
     * @description  Reset all tracking. Use in test classes.
     */
    public static void resetAll() {
        processedRecordsMap.clear();
    }
}