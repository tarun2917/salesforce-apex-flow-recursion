/**
 * CaseTriggerHandler
 * Dispatcher only — no logic, no SOQL, no DML.
 * Builds domain (classify runs in constructor), hands off to CaseService facade.
 */
public with sharing class CaseTriggerHandler extends TriggerHandler {

    private List<Case> newList;
    private Map<Id, Case> oldMap;

    public CaseTriggerHandler() {
        this.newList = (List<Case>) Trigger.new;
        this.oldMap  = (Map<Id, Case>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        CaseService.handleBeforeInsert(new CaseDomain(newList, null));
    }

    public override void beforeUpdate() {
        CaseService.handleBeforeUpdate(new CaseDomain((List<Case>) filterNew(newList), oldMap));
    }

    public override void afterInsert() {
        CaseService.handleAfterInsert(new CaseDomain(newList, null));
    }

    public override void afterUpdate() {
        CaseService.handleAfterUpdate(new CaseDomain((List<Case>) filterNew(newList), oldMap));
    }
}