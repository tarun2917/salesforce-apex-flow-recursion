# Salesforce Apex + Flow Recursion Control

A comprehensive solution for preventing infinite recursion loops between Salesforce Apex triggers and Flows, enabling seamless cross-technology automation without governance limits and stuck records.

## Table of Contents

- [The Problem](#the-problem)
- [The Solution](#the-solution)
  - [Recursion Handler](#recursion-handler)
  - [Recursion Flow Helper](#recursion-flow-helper)
  - [Trigger Handler Pattern Integration](#trigger-handler-pattern-integration)
- [How It Works](#how-it-works)
- [Benefits](#benefits)
- [Usage Examples](#usage-examples)
- [Architecture](#architecture)

---

## The Problem

Salesforce automation often requires cross-layer execution: a Flow updates a record → a Trigger fires → the Trigger calls a Flow → the Flow updates the record again → infinite loop.

### Common Recursion Scenarios

1. **Flow → Apex Trigger → Flow → Apex Trigger** (circular dependency)
2. **Batch Job → Trigger → Flow → Batch Job re-enqueued** (cascading loops)
3. **Flow on Insert → Apex creates child record → Flow on child → Parent record updated → Flow re-triggered**
4. **Integration callout updates record → Trigger enqueues Queueable → Queueable updates parent → Trigger re-fires**

### Business Impact

- **Governor Limit Failures**: Records stuck because governor limits exhausted mid-transaction
- **Data Inconsistency**: Partial updates when recursion is caught too late
- **Wasted Resources**: Unnecessary Queueable jobs, Flow executions, and Batch runs
- **Difficult Debugging**: Hard to trace which layer triggered the loop
- **Maintenance Burden**: Adding new automation means re-checking all existing recursion guards

---

## The Solution

This project provides **org-wide, layer-agnostic recursion control** that works across Apex, Flows, Queueables, and Batches in a single transaction.

### Core Components

#### 1. **RecursionHandler** — Generic Recursion Registry

Universal recursion tracker using `Map<String, Set<Id>>` pattern:
- **Key**: Unique identifier per automation path (e.g., `'CaseHandler.afterUpdate'`, `'Account_AF_Main'`)
- **Value**: Set of record Ids already processed for that key

```apex
// Mark a record as processed for a specific key
RecursionHandler.markProcessed('CaseHandler.updateAccounts', caseId);

// Check if already processed (returns true if yes, false if no)
Boolean alreadyProcessed = RecursionHandler.isProcessed('CaseHandler.updateAccounts', caseId);

// Filter a list to only unprocessed records (auto-marks them)
List<Case> unprocessed = (List<Case>) RecursionHandler.filterUnprocessed('CaseHandler.updateAccounts', caseList);
```

**Why It Works:**
- Static map persists for entire transaction — all layers share same memory
- Per-key tracking allows multiple independent automation paths in same transaction
- No hardcoded flags — flexible and reusable

---

#### 2. **RecursionFlowHelper** — Bridge Between Flow & Apex

Exposes `RecursionHandler` to Flows via Invocable Actions.

```
Flow → Action: "Check and Mark Recursion" → Returns TRUE/FALSE
TRUE  = Safe to proceed (first time)
FALSE = Stop (already processed — recursion detected)
```

**Flow Usage:**
```
Inputs:
  flowKey  = "Account_AF_Main" (unique per flow)
  recordId = {!$Record.Id}

Output:
  var_ShouldProceed = TRUE or FALSE

Decision:
  If var_ShouldProceed = TRUE
    → Continue with flow logic
  Else
    → Exit (recursion stop)
```

---

#### 3. **TriggerHandler Pattern Integration** — Automatic Recursion Gate

The `TriggerHandler` base class includes built-in recursion control:

```apex
public virtual class TriggerHandler {
    // Auto-gates records for UPDATE/DELETE only (INSERT has no Id yet)
    // Using RecursionHandler internally with key = "ClassName.TriggerContext"
    
    protected List<SObject> filterNew(List<SObject> records) {
        // Returns only records NOT yet processed for this handler context
        // Called in each handler method: beforeUpdate(), afterInsert(), etc.
    }
}

// Usage in handler:
public override void afterUpdate() {
    List<Case> toProcess = (List<Case>) filterNew(Trigger.new);
    // Only unprocessed records continue here
    if (!toProcess.isEmpty()) {
        CaseService.handleAfterUpdate(toProcess);
    }
}
```

**Key Feature:** Recursion gate is **automatic** — no per-method code needed. Just call `filterNew()` and you're protected.

---

## How It Works

### Scenario: Flow Updates Case → Trigger Fires → Flow Re-Triggered (PREVENTED)

```
1. User updates Case in UI
   ↓
2. Flight_Disruption_AF record-triggered flow fires (BEFORE save)
   → Invokes "Check and Mark Recursion" action
   → flowKey = "Case_BD_Main", recordId = {Case.Id}
   → RecursionHandler.markProcessed("Case_BD_Main", caseId)
   → Flow gets TRUE → proceeds
   ↓
3. Record saves
   ↓
4. Case trigger (CaseTriggerHandler) fires (AFTER save)
   → Automatically calls filterNew() with recursion gate
   → Key = "CaseTriggerHandler.AFTER_UPDATE"
   → RecursionHandler.markProcessed("CaseTriggerHandler.AFTER_UPDATE", caseId)
   → Handler gets the case in processableIds
   → CaseService.handleAfterUpdate() runs
   → Creates Child_Record__c
   ↓
5. Child_Record__c trigger fires (AFTER insert)
   → Flow checks: "Should I run on create?" YES (new record, different key)
   → Flow updates Parent Case
   ↓
6. Case trigger fires AGAIN (AFTER update)
   → GateCheck: Key "CaseTriggerHandler.AFTER_UPDATE", recordId = {original Case.Id}
   → KEY ALREADY IN SET FROM STEP 4!
   → RecursionHandler.isProcessed() returns TRUE
   → Handler calls filterNew() → returns EMPTY (case filtered out)
   → CaseService never called → NO infinite loop
   ✓ RECURSION PREVENTED
```

### Transaction State

```
RecursionHandler.processedRecordsMap at each step:

Step 2:  { "Case_BD_Main" : { caseId1 } }
Step 4:  { "Case_BD_Main" : { caseId1 }, "CaseTriggerHandler.AFTER_UPDATE" : { caseId1 } }
Step 5:  { "Case_BD_Main" : { caseId1 }, 
           "CaseTriggerHandler.AFTER_UPDATE" : { caseId1 },
           "Child_Record_AF_Main" : { childRecordId1, ... } }
Step 6:  Same map — case NOT added again (already there) → filtered out
```

---

## Benefits

### 1. **Eliminates Infinite Loops**
- Single source of truth for recursion tracking
- Works across Apex, Flow, Batches, Queueables
- No circular dependency between layers

### 2. **Prevents Governor Limit Exhaustion**
- Stops unnecessary re-processing in same transaction
- Fewer DML operations, fewer SOQL queries
- Records never get stuck mid-way

### 3. **Maintains Data Consistency**
- If a record is already being processed, it's skipped entirely
- No partial updates or orphaned child records
- Transaction atomicity preserved

### 4. **Improves Performance**
- Bulk operations remain bulk — one gate check per record
- Early exit when all records filtered (see line 47 of `TriggerHandler`)
- No additional queries needed (static map, no lookups)

### 5. **Scales with New Automation**
- New Flow? Just call `checkAndMark()` invocation with unique flowKey
- New Trigger? Extend `TriggerHandler` — recursion gate is automatic
- New Queueable? Call `RecursionHandler.markProcessed()` / `isProcessed()`
- No need to refactor existing code

### 6. **Clear, Auditable Trails**
- Each layer has unique key (e.g., `'Case_BD_Main'`, `'CaseTriggerHandler.AFTER_UPDATE'`)
- System.debug logs show exactly which key/recordId was blocked
- Easy to trace recursion path in logs

### 7. **Fail-Safe Design**
- Before-Insert flows (no Id yet) always proceed (no record to track)
- If a key doesn't exist in map, record is always allowed first time
- No silent failures — all blocks are logged

---

## Usage Examples

### Example 1: Apex Trigger (Automatic Protection)

```apex
public with sharing class CaseTriggerHandler extends TriggerHandler {
    public override void afterUpdate() {
        // filterNew() returns only records not yet processed for this handler context
        // RecursionHandler gate is built-in, no extra code needed
        List<Case> cases = (List<Case>) filterNew(Trigger.new);
        
        if (!cases.isEmpty()) {
            CaseService.handleAfterUpdate(cases); // Safe to call
        }
    }
}
```

**Behind the scenes:**
```
run() method (line 33-57 in TriggerHandler.cls):
  For each record in Trigger.new:
    Key = "CaseTriggerHandler.AFTER_UPDATE"
    if NOT RecursionHandler.isProcessed(key, recordId):
      RecursionHandler.markProcessed(key, recordId)
      Add to processableIds
  
  If processableIds empty → skip afterUpdate() entirely
```

### Example 2: Salesforce Flow (Explicit Check)

**Flow on Case (Record-Triggered, After-Save):**

```
1. Element: Decision "Check Recursion"
   - Label: "Check if this case already processed?"
   - Input from Action: Check and Mark Recursion
   
2. Action: Check and Mark Recursion
   - Flow Key = "Case_AF_Main"
   - Record Id = {!$Record.Id}
   - Output = var_ShouldProceed
   
3. Decision Outcome:
   TRUE → continue to "Update Parent Account" element
   FALSE → exit (recursion detected)
   
4. Element: Update Records "Update Parent Account"
   - Record: {!$Record.AccountId}
   - Field: Last_Flow_Update__c = NOW()
```

### Example 3: Queueable (Manual Control)

```apex
public class ProcessCaseAttachmentsQueueable implements Queueable, Database.AllowsCallouts {
    private List<Case> cases;
    
    public void execute(QueueableContext ctx) {
        String key = 'ProcessCaseAttachmentsQueueable.execute';
        
        // Filter to only unprocessed cases
        List<Case> toProcess = 
            (List<Case>) RecursionHandler.filterUnprocessed(key, cases);
        
        if (toProcess.isEmpty()) {
            System.debug('All cases already processed, skipping');
            return;
        }
        
        // Safe to process
        for (Case c : toProcess) {
            callExternalAPI(c);
        }
    }
}
```

---

## Architecture

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    RecursionHandler                         │
│            Map<String, Set<Id>> processedRecordsMap         │
│  (Static, persists entire transaction across all layers)   │
└─────────────────────────────────────────────────────────────┘
                            ▲
            ┌───────────────┼───────────────┐
            │               │               │
     ┌──────▼────────┐  ┌──▼────────────┐  ▼─────────────┐
     │  TriggerHandler │  │ RecursionFlow │  Queueable    │
     │  (Automatic)   │  │ Helper (Flow) │  (Manual)     │
     └────────────────┘  └───────────────┘  └─────────────┘
            │                    │                │
     ┌──────▼────────┐  ┌──▼────────────┐  ┌─────▼────────┐
     │ CaseTrigger   │  │ Case Record   │  │ Batch Jobs   │
     │ Handler       │  │ Triggered Flow│  │ Integration  │
     └────────────────┘  └───────────────┘  └──────────────┘
```

### File Structure

```
force-app/main/default/classes/
├── RecursionHandler.cls          ← Core: Tracks processed records per key
├── RecursionFlowHelper.cls       ← Bridge: Exposes RecursionHandler to Flows
├── TriggerHandler.cls            ← Base: Auto-gating via filterNew()
│
├── CaseTriggerHandler.cls        ← Example: Extends TriggerHandler
├── CaseService.cls               ← Example: Facade, receives filtered records
└── CaseDomain.cls                ← Example: Domain classification
```

### Key Design Principles

1. **Single Responsibility**: Each class has one purpose
   - `RecursionHandler`: Track processed records
   - `RecursionFlowHelper`: Flow integration only
   - `TriggerHandler`: Dispatch + recursion gating
   - `CaseService`: Business orchestration

2. **Transaction-Scoped**: Static map cleared after each transaction
   - No lingering state between records
   - Safe for bulk operations
   - Each transaction starts fresh

3. **Fail-Open**: Missing config doesn't block execution
   - No Master_Switch__c? Triggers run (safe default)
   - Key not in map? First-time always allowed
   - Flows without invocation still work

4. **Non-Invasive**: Add to existing code without refactor
   - `filterNew()` is optional wrapper
   - `RecursionHandler` is static utility
   - Flows just add one invocation

---

## Setup Instructions

### 1. Deploy Metadata
```bash
sf project deploy start --source-dir force-app/
```

### 2. Create Master_Switch__c Custom Object (Optional)
Allows org admins to disable all triggers per profile:
- Record Type: `Profile Name` (e.g., "System Administrator")
- Fields:
  - `Master_Switch_Active__c` (Checkbox, default = true)
  - `Trigger_Switch_Active__c` (Checkbox, default = true)

### 3. Use in Your Trigger
```apex
public with sharing class MyTriggerHandler extends TriggerHandler {
    public override void afterUpdate() {
        // Built-in recursion protection via filterNew()
        List<SObject> records = filterNew(Trigger.new);
        // Process only unprocessed records
    }
}

// In trigger:
trigger MyTrigger on MyObject__c (after update) {
    if (TriggerHandler.isActive('MyObject__c')) {
        new MyTriggerHandler().run();
    }
}
```

### 4. Use in Flow
- Add Action: "Check and Mark Recursion"
- Set `flowKey` to unique name (e.g., `'MyObject_AF_Main'`)
- Set `recordId` to `{!$Record.Id}`
- Use output in Decision → proceed or exit

---

## Testing

Run unit tests to verify recursion prevention:

```bash
npm run test:unit
```

Tests cover:
- ✅ Single record recursion prevention
- ✅ Bulk record filtering
- ✅ Cross-layer interaction (Apex + Flow)
- ✅ Multiple keys in same transaction
- ✅ Before-Insert handling (no Id)

---

## Key Takeaways

| Aspect | Before | After |
|--------|--------|-------|
| Recursion Loops | Common, hard to debug | Prevented automatically |
| Governance Limits | Exhausted quickly | Optimized, no wasted ops |
| New Automation | Risk of breaking existing code | Safe to add layers |
| Developer Experience | Manual guards everywhere | One filterNew() call |
| Cross-Layer Communication | Prone to infinite loops | Safe and explicit |

---

**This solution enables you to build complex, multi-layer automation safely — without recursion loops, without governor limit failures, and without maintenance burden.**
