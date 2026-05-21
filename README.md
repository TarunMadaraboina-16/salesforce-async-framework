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
