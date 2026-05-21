public class DynamicBulkQueueable
    implements Queueable, Database.AllowsCallouts {

    private List<sObject> recordsToProcess;
    private Integer batchSize;
    private Integer currentDepth;
    private static final Integer MAX_STACK_DEPTH = 5;

    public DynamicBulkQueueable(
        List<sObject> records,
        Integer size,
        Integer depth
    ) {
        this.recordsToProcess = records != null
            ? records
            : new List<sObject>();
        this.batchSize    = size  > 0 ? size  : 200;
        this.currentDepth = depth > 0 ? depth : 1;
    }

    public void execute(QueueableContext context) {
        try {
            if (recordsToProcess.isEmpty()) return;

            List<sObject> currentBatch     = new List<sObject>();
            List<sObject> remainingRecords = new List<sObject>();

            for (Integer i = 0; i < recordsToProcess.size(); i++) {
                if (i < batchSize) {
                    currentBatch.add(recordsToProcess[i]);
                } else {
                    remainingRecords.add(recordsToProcess[i]);
                }
            }

            if (!currentBatch.isEmpty()) {
                Database.SaveResult[] results =
                    Database.update(currentBatch, false);
                handleSaveResults(results, currentBatch);
            }

            if (!remainingRecords.isEmpty()) {
                if (currentDepth >= MAX_STACK_DEPTH) {
                    logMessage(
                        'Warning',
                        'Max stack depth reached. Aborting chain.',
                        'Remaining records: ' + remainingRecords.size()
                    );
                    return;
                }

                DynamicBulkQueueable nextJob =
                    new DynamicBulkQueueable(
                        remainingRecords,
                        this.batchSize,
                        this.currentDepth + 1
                    );

                if (!Test.isRunningTest()) {
                    System.enqueueJob(nextJob);
                }
            }

        } catch (Exception ex) {
            logError(ex);
            //throw ex;
        }
    }

    private void handleSaveResults(
        Database.SaveResult[] results,
        List<sObject> batch
    ) {
        List<String> errors = new List<String>();

        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                errors.add(
                    'Record: ' + batch[i].Id +
                    ' | Error: ' +
                    results[i].getErrors()[0].getMessage()
                );
            }
        }

        if (!errors.isEmpty()) {
            logMessage(
                'Error',
                'Partial failures in batch.',
                String.join(errors, '\n')
            );
        }
    }
    @TestVisible
    private void logError(Exception ex) {
        insert new Apex_Log__c(
            Class_Name__c  = 'DynamicBulkQueueable',
            Method_Name__c = 'execute',
            Log_Type__c    = 'Error',
            Message__c     = ex.getMessage(),
            Stack_Trace__c = ex.getStackTraceString()
        );
    }

    private void logMessage(
        String type,
        String summary,
        String detail
    ) {
        insert new Apex_Log__c(
            Class_Name__c  = 'DynamicBulkQueueable',
            Method_Name__c = 'execute',
            Log_Type__c    = type,
            Message__c     = summary + ' | ' + detail
        );
    }
}
