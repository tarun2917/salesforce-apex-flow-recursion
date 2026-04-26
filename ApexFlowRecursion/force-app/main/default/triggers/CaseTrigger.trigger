/**************************************************************************************************
(c) 2022 Salesforce
Name of the Trigger: CaseTrigger
Description : Case Trigger
Created by : Tarun Kumar || 13 March
**************************************************************************************************/
trigger CaseTrigger on Case (before insert, before update, before delete, after delete, after insert, after update, after undelete) {
    if (TriggerHandler.isActive('Case')) {
        new CaseTriggerHandler().run();
    }
}