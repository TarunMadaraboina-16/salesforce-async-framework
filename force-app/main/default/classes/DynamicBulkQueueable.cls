/**
 * @description Enterprise Queueable Framework to process high-volume sObject updates safely.
 * Demonstrates: Transaction chaining, dynamic state preservation, and transaction depth management.
 */
public class DynamicBulkQueueable implements Queueable, Database.AllowsCallouts {
    
    private List<sObject> recordsToProcess;
    private Integer batchSize;
    private Integer currentDepth;
    private static final Integer MAX_STACK_DEPTH = 5; // Platform safe execution cap

    // Core state orchestration constructor
    public DynamicBulkQueueable(List<sObject> records, Integer size, Integer depth) {
        this.recordsToProcess = (records != null) ? records : new List<sObject>();
        this.batchSize = (size > 0) ? size : 200; 
        this.currentDepth = (depth > 0) ? depth : 1;
    }

    public void execute(QueueableContext context) {
        try {
            if (recordsToProcess.isEmpty()) {
                return;
            }

            // Slice out processing block data collections
            List<sObject> currentBatch = new List<sObject>();
            List<sObject> remainingRecords = new List<sObject>();
            
            for (Integer i = 0; i < recordsToProcess.size(); i++) {
                if (i < batchSize) {
                    currentBatch.add(recordsToProcess[i]);
                } else {
                    remainingRecords.add(recordsToProcess[i]);
                }
            }

            // Secure operational execution using All-or-None = false
            if (!currentBatch.isEmpty()) {
                Database.SaveResult[] results = Database.update(currentBatch, false);
                handleSaveResults(results, currentBatch);
            }

            // Recurse and chain transaction sequences if items remain
            if (!remainingRecords.isEmpty()) {
                if (currentDepth >= MAX_STACK_DEPTH) {
                    logMessage('Warning', 'Max stack depth reached. Halting queue loop.', 'Count left: ' + remainingRecords.size());
                    return; 
                }

                DynamicBulkQueueable nextJob = new DynamicBulkQueueable(remainingRecords, this.batchSize, this.currentDepth + 1);
                
                if (!Test.isRunningTest()) {
                    System.enqueueJob(nextJob);
                }
            }

        } catch (Exception ex) {
            logError(ex);
            throw ex; 
        }
    }

    private void handleSaveResults(Database.SaveResult[] results, List<sObject> batch) {
        List<String> errors = new List<String>();
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                errors.add('ID: ' + batch[i].Id + ' Error: ' + results[i].getErrors()[0].getMessage());
            }
        }
        
        if (!errors.isEmpty()) {
            logMessage('Error', 'Partial failure inside async array scope.', String.join(errors, '\n'));
        }
    }

    private void logError(Exception ex) {
        Apex_Log__c log = new Apex_Log__c(
            Class_Name__c = 'DynamicBulkQueueable',
            Method_Name__c = 'execute',
            Log_Type__c = 'Error',
            Message__c = ex.getMessage(),
            Stack_Trace__c = ex.getStackTraceString()
        );
        insert log;
    }

    private void logMessage(String type, String summary, String detailedMessage) {
        Apex_Log__c log = new Apex_Log__c(
            Class_Name__c = 'DynamicBulkQueueable',
            Method_Name__c = 'execute',
            Log_Type__c = type,
            Message__c = summary + ' Details: ' + detailedMessage
        );
        insert log;
    }
}