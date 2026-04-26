/**
 * @description  Bridge between Salesforce Flows and RecursionHandler.
 *               Provides two invocable methods:
 *               1. Check and Mark Recursion — per-record, per-key tracking
 *               2. Control Trigger Execution — skip/unskip objects, handlers, or all
 *
 *               These share the same static memory as Apex triggers within
 *               a single transaction, so Flow and Apex recursion control
 *               work together seamlessly.
 *
 * @usage        Flow → Action → search "Check and Mark Recursion"
 *               Flow → Action → search "Control Trigger Execution"
 *
 * @author       Your Name
 * @date         2026-03-15
 */
public class RecursionFlowHelper {

    // =========================================================================
    // Invocable 1: Check and Mark Recursion (Per-Record, Per-Key)
    // =========================================================================

    /**
     * @description  Checks if a record has already been processed for a given key.
     *               If NOT processed → marks it and returns TRUE (safe to proceed).
     *               If ALREADY processed → returns FALSE (stop, recursion detected).
     *
     * @param        inputs List of RecursionInput (flowKey + recordId)
     * @return       List of Boolean — TRUE = proceed, FALSE = stop
     *
     * @usage        Flow: Action → "Check and Mark Recursion"
     *               flowKey  = "Account_AF_Main" (unique per flow)
     *               recordId = {!$Record.Id}
     *               output   = var_ShouldProceed
     */
    @InvocableMethod(
        label='Check and Mark Recursion'
        description='Returns TRUE if safe to proceed. FALSE if already processed (recursion detected).'
    )
    public static List<Boolean> checkAndMark(List<RecursionInput> inputs) {
        List<Boolean> results = new List<Boolean>();

        for (RecursionInput input : inputs) {
            // Before-Save INSERT flows run before the record has an Id.
            // Nothing to track yet — always allow and let the flow proceed.
            if (input.recordId == null) {
                results.add(true);
                continue;
            }

            if (RecursionHandler.isProcessed(input.flowKey, input.recordId)) {
                results.add(false);  // Already processed → STOP
            } else {
                RecursionHandler.markProcessed(input.flowKey, input.recordId);
                results.add(true);   // First time → PROCEED
            }
        }

        return results;
    }

    /**
     * @description  Input wrapper for Check and Mark Recursion
     */
    public class RecursionInput {
        @InvocableVariable(
            label='Flow Key'
            description='Unique key per flow. e.g. Account_AF_Main, Case_BF_Main'
            required=true
        )
        public String flowKey;

        @InvocableVariable(
            label='Record Id'
            description='The Id of the triggering record. Use {!$Record.Id}'
            required=true
        )
        public Id recordId;
    }
}