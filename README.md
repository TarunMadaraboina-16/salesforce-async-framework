# Salesforce Async Framework
### Enterprise-Grade Queueable Chaining with Persistent Telemetry

![Apex](https://img.shields.io/badge/Salesforce-Apex-blue)
![Coverage](https://img.shields.io/badge/Test%20Coverage-95%25-brightgreen)
![License](https://img.shields.io/badge/license-MIT-green)

---

## The Problem

Standard Queueable Apex has no memory.

Pass it 1,000 records with a batch size of 200 
and it processes the first 200 then disappears — 
no error, no alert, no indication that 800 records 
were silently abandoned.

At low volume nobody notices.  
At enterprise scale this corrupts your data pipeline.

---

## What This Solves

A self-chaining Queueable framework that handles 
high-volume sObject processing safely across 
transaction boundaries.

**Core capabilities:**

- Dynamically slices any sObject collection into 
  configurable memory-safe chunks
- Chains itself automatically until all records 
  are processed
- Tracks execution depth with a MAX_STACK_DEPTH 
  guardrail — prevents infinite loops
- Uses partial success DML (allOrNone = false) — 
  one bad record does not kill the entire batch
- Streams every failure and termination event to 
  a persistent Apex_Log__c object for full RCA

---

## Architecture
Execute Anonymous / Trigger / Flow
│
▼
DynamicBulkQueueable (Depth 1)
├── Slice: records 1–250
├── Database.update(batch, false)
├── handleSaveResults → log failures
└── Enqueue next job if records remain
│
▼
DynamicBulkQueueable (Depth 2)
├── Slice: records 251–500
└── ...continues until all records processed
│
▼
MAX_STACK_DEPTH = 5 guardrail
└── Logs warning and exits cleanly

---

## Quick Start

**Step 1 — Create the custom logging object**

Create `Apex_Log__c` in your org with these fields:

| Field Label   | API Name         | Type           |
|---------------|------------------|----------------|
| Class Name    | Class_Name__c    | Text(255)      |
| Method Name   | Method_Name__c   | Text(255)      |
| Log Type      | Log_Type__c      | Picklist       |
| Message       | Message__c       | Long Text Area |
| Stack Trace   | Stack_Trace__c   | Long Text Area |

Picklist values for Log_Type__c: `Info`, `Warning`, `Error`

**Step 2 — Deploy the class**

Deploy `DynamicBulkQueueable.cls` to your org 
via VS Code + Salesforce CLI or Developer Console.

**Step 3 — Fire it**

```apex
List<Account> accounts =
    [SELECT Id, Type FROM Account LIMIT 1000];

for (Account acc : accounts) {
    acc.Type = 'Customer - Direct';
}

// Records, Batch Size, Starting Depth
DynamicBulkQueueable engine =
    new DynamicBulkQueueable(accounts, 250, 1);

System.enqueueJob(engine);
```

**Step 4 — Monitor**
Setup → Apex Jobs          (execution status)
App Launcher → Apex Logs   (failures and warnings)

---

## Key Design Decisions

**Partial success over all-or-none**

```apex
Database.SaveResult[] results =
    Database.update(currentBatch, false);
```

One validation failure does not abort 499 
successful records. Each failure is captured 
individually in Apex_Log__c.

**Depth guardrail**

```apex
private static final Integer MAX_STACK_DEPTH = 5;

if (currentDepth >= MAX_STACK_DEPTH) {
    logMessage(
        'Warning',
        'Max stack depth reached. Aborting chain.',
        'Remaining records: ' + remainingRecords.size()
    );
    return;
}
```

Salesforce allows a maximum of 5 chained 
Queueable levels. Without this guardrail 
your chain hits the platform ceiling and 
crashes silently.

**Persistent telemetry over debug logs**

System.debug logs expire in 24 hours.  
Apex_Log__c records persist indefinitely and 
are accessible via the App Launcher without 
needing Developer Console access.

---

## Test Coverage

**95% coverage — 5 test methods:**

| Test Method                   | What It Validates                        |
|-------------------------------|------------------------------------------|
| testQueueableChainingSuccess  | Happy path, chunking, startTest/stopTest |
| testMaxDepthGuardrailLogs     | MAX_STACK_DEPTH warning logged correctly |
| testPartialFailureCaptured    | Failed records logged individually       |
| testNullRecordsHandledCleanly | Null input exits cleanly, no errors      |
| testRuntimeExceptionLogged    | catch block writes to Apex_Log__c        |

---

## Business Impact

- Zero silent record abandonment in 
  high-volume async pipelines
- Full root cause analysis without 
  being on-call to capture expiring logs
- Partial failures captured individually — 
  not swallowed by the platform
- Production-safe exit at platform depth 
  limits with no unhandled LimitExceptions

---

## Tech Stack

- Salesforce Apex
- Queueable Interface
- Database.AllowsCallouts
- Custom sObject (Apex_Log__c)
- Salesforce DX

---

## Author

**Tarun Madaraboina**  
Salesforce Developer — FinTech & Insurance  
[LinkedIn](https://www.linkedin.com/in/tarun-madaraboina/)  
[GitHub](https://github.com/TarunMadaraboina-16)
