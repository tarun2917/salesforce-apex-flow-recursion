public virtual class TriggerHandler {

    private static Set<String> bypassedHandlers = new Set<String>();

    // Cache for Trigger_Object_Bypass__mdt — loaded once per transaction
    private static Map<String, Boolean> objectBypassCache;

    @TestVisible private TriggerContext context;
    @TestVisible private Boolean isTriggerExecuting;

    // Populated by run() before dispatch — handlers use filterNew() to get their typed list
    protected Set<Id> processableIds;

    public TriggerHandler() {
        isTriggerExecuting = Trigger.isExecuting;
        if(!Trigger.isExecuting) return;

        if     (Trigger.isBefore && Trigger.isInsert)   context = TriggerContext.BEFORE_INSERT;
        else if(Trigger.isBefore && Trigger.isUpdate)   context = TriggerContext.BEFORE_UPDATE;
        else if(Trigger.isBefore && Trigger.isDelete)   context = TriggerContext.BEFORE_DELETE;
        else if(Trigger.isAfter  && Trigger.isInsert)   context = TriggerContext.AFTER_INSERT;
        else if(Trigger.isAfter  && Trigger.isUpdate)   context = TriggerContext.AFTER_UPDATE;
        else if(Trigger.isAfter  && Trigger.isDelete)   context = TriggerContext.AFTER_DELETE;
        else if(Trigger.isAfter  && Trigger.isUndelete) context = TriggerContext.AFTER_UNDELETE;
    }

    public void run() {
        if(!isTriggerExecuting || context == null) {
            throw new TriggerHandlerException('Trigger handler called outside of Trigger execution');
        }
        if(bypassedHandlers.contains(getHandlerName())) return;

        // Recursion gate — automatic for every handler, no per-handler code needed.
        // INSERT is excluded: records have no Id before the first save.
        if (!Trigger.isInsert && Trigger.new != null) {
            String key = getHandlerName() + '.' + context.name();
            System.debug('[RECURSION GATE] Key: ' + key + ' | Records in trigger: ' + Trigger.new.size());
            processableIds = new Set<Id>();
            for (SObject rec : Trigger.new) {
                if (!RecursionHandler.isProcessed(key, rec.Id)) {
                    RecursionHandler.markProcessed(key, rec.Id);
                    processableIds.add(rec.Id);
                    System.debug('[RECURSION GATE] ALLOWED  | Key: ' + key + ' | Id: ' + rec.Id);
                } else {
                    System.debug('[RECURSION GATE] BLOCKED  | Key: ' + key + ' | Id: ' + rec.Id);
                }
            }
            if (processableIds.isEmpty()) {
                System.debug('[RECURSION GATE] ALL BLOCKED — skipping execution | Key: ' + key);
                return;
            }
            System.debug('[RECURSION GATE] Proceeding with ' + processableIds.size() + ' record(s) | Key: ' + key);
        }

        switch on context {
            when BEFORE_INSERT  { beforeInsert();  }
            when BEFORE_UPDATE  { beforeUpdate();  }
            when BEFORE_DELETE  { beforeDelete();  }
            when AFTER_INSERT   { afterInsert();   }
            when AFTER_UPDATE   { afterUpdate();   }
            when AFTER_DELETE   { afterDelete();   }
            when AFTER_UNDELETE { afterUndelete(); }
        }
    }

    /**
     * Filters a typed SObject list down to only records approved by the recursion gate.
     * Call at the top of any handler method that needs the filtered list.
     * On INSERT (processableIds is null), returns the original list unchanged.
     */
    protected List<SObject> filterNew(List<SObject> records) {
        if (processableIds == null || records == null) return records;
        List<SObject> result = new List<SObject>();
        for (SObject rec : records) {
            if (processableIds.contains(rec.Id)) result.add(rec);
        }
        return result;
    }

    // bypass controls — use in batch/integration to skip handler entirely
    public static void bypass(String handlerName)        { bypassedHandlers.add(handlerName);              }
    public static void clearBypass(String handlerName)   { bypassedHandlers.remove(handlerName);           }
    public static Boolean isBypassed(String handlerName) { return bypassedHandlers.contains(handlerName);  }
    public static void clearAllBypasses()                { bypassedHandlers.clear();                       }

    /**
     * Central bypass check — call from every trigger.
     *
     * Returns TRUE  → trigger should run.
     * Returns FALSE → trigger should be skipped.
     *
     * Evaluation order:
     *   1. No Master_Switch__c record for the running profile → fail-open (allow).
     *   2. Master_Switch_Active__c = false  OR  Trigger_Switch_Active__c = false
     *      → bypass ALL triggers (global kill switch).
     *   3. Trigger_Object_Bypass__mdt record for this sObject has Is_Bypassed__c = true
     *      → bypass only this object's trigger.
     *
     * Usage in any trigger:
     *   if (TriggerHandler.isActive('Case')) { new CaseTriggerHandler().run(); }
     *
     * To bypass a new object (e.g. Account):
     *   In Setup → Custom Metadata → Trigger Object Bypass, set Is_Bypassed__c = true
     *   on the Account_Bypass record. No deployment required.
     */
    public static Boolean isActive(String sObjectName) {
        // Fail-open: no custom-setting record configured for this profile → allow
        if (Master_Switch__c.getInstance(UserInfo.getProfileId()).Id == null) return true;

        Master_Switch__c settings = Master_Switch__c.getInstance();

        // Global kill switches
        if (!settings.Master_Switch_Active__c || !settings.Trigger_Switch_Active__c) return false;

        // Object-level bypass via Custom Metadata (cached for the transaction)
        if (getObjectBypassCache().get(sObjectName) == true) return false;

        return true;
    }

    private static Map<String, Boolean> getObjectBypassCache() {
        if (objectBypassCache == null) {
            objectBypassCache = new Map<String, Boolean>();
            for (Trigger_Object_Bypass__mdt rec : [
                SELECT Object_API_Name__c, Is_Bypassed__c
                FROM Trigger_Object_Bypass__mdt WHERE Is_Bypassed__c = TRUE
            ]) {
                objectBypassCache.put(rec.Object_API_Name__c, rec.Is_Bypassed__c);
            }
        }
        return objectBypassCache;
    }

    // override only the contexts your handler needs — rest are silent no-ops
    @TestVisible protected virtual void beforeInsert()  {}
    @TestVisible protected virtual void beforeUpdate()  {}
    @TestVisible protected virtual void beforeDelete()  {}
    @TestVisible protected virtual void afterInsert()   {}
    @TestVisible protected virtual void afterUpdate()   {}
    @TestVisible protected virtual void afterDelete()   {}
    @TestVisible protected virtual void afterUndelete() {}

    private String getHandlerName() {
        return String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
    }

    @TestVisible
    private enum TriggerContext {
        BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
        AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE, AFTER_UNDELETE
    }

    public class TriggerHandlerException extends Exception {}

}