@isTest
private class DynamicBulkQueueableTest {

    @testSetup
    static void setupData() {
        List<Account> testAccs = new List<Account>();
        for (Integer i = 0; i < 300; i++) {
            testAccs.add(new Account(
                Name = 'Framework Test ' + i,
                Type = 'Prospect'
            ));
        }
        insert testAccs;
    }

    @isTest
    static void testQueueableChainingSuccess() {

        List<Account> records =
            [SELECT Id, Type FROM Account];

        for (Account acc : records) {
            acc.Type = 'Customer - Direct';
        }

        DynamicBulkQueueable job =
            new DynamicBulkQueueable(records, 150, 1);

        Test.startTest();
            System.enqueueJob(job);
        Test.stopTest();

        List<Account> updated = [
            SELECT Id FROM Account
            WHERE Type = 'Customer - Direct'
        ];

        System.assert(
            updated.size() >= 150,
            'Expected at least first batch to update.'
        );

        List<Apex_Log__c> errorLogs = [
            SELECT Id FROM Apex_Log__c
            WHERE Log_Type__c = 'Error'
        ];

        System.assert(
            errorLogs.isEmpty(),
            'No errors should exist on clean run.'
        );
    }

    @isTest
    static void testMaxDepthGuardrailLogs() {

        List<Account> records =
            [SELECT Id, Type FROM Account LIMIT 10];

        for (Account acc : records) {
            acc.Type = 'Customer - Direct';
        }

        DynamicBulkQueueable job =
            new DynamicBulkQueueable(records, 1, 5);

        Test.startTest();
            System.enqueueJob(job);
        Test.stopTest();

        List<Apex_Log__c> warningLogs = [
            SELECT Id FROM Apex_Log__c
            WHERE Log_Type__c = 'Warning'
        ];

        System.assert(
            !warningLogs.isEmpty(),
            'Warning log should exist at max depth.'
        );
    }
@isTest
static void testPartialFailureCaptured() {

    // Insert one valid account
    Account validAccount = new Account(
        Name = 'Valid Account',
        Type = 'Prospect'
    );
    insert validAccount;

    // Create an invalid account update
    // Blank name triggers a validation failure
    Account invalidAccount = new Account(
        Id   = validAccount.Id,
        Name = ''
    );

    List<sObject> mixedBatch = new List<sObject>{
        invalidAccount
    };

    DynamicBulkQueueable job =
        new DynamicBulkQueueable(mixedBatch, 200, 1);

    Test.startTest();
        System.enqueueJob(job);
    Test.stopTest();

    // Error should be captured in Apex_Log__c
    List<Apex_Log__c> errorLogs = [
        SELECT Id, Log_Type__c, Message__c
        FROM Apex_Log__c
        WHERE Log_Type__c = 'Error'
    ];

    System.assert(
        !errorLogs.isEmpty(),
        'Error log should be created for failed record.'
    );
}
@isTest
static void testNullRecordsHandledCleanly() {

    // Pass null — tests the null safety 
    // in the constructor
    DynamicBulkQueueable job =
        new DynamicBulkQueueable(null, 200, 1);

    Test.startTest();
        System.enqueueJob(job);
    Test.stopTest();

    // No errors should be thrown
    // Empty list returns immediately
    List<Apex_Log__c> errorLogs = [
        SELECT Id FROM Apex_Log__c
        WHERE Log_Type__c = 'Error'
    ];

    System.assert(
        errorLogs.isEmpty(),
        'Null input should exit cleanly with no errors.'
    );
}	
@isTest
static void testRuntimeExceptionLogged() {

    DynamicBulkQueueable instance = 
        new DynamicBulkQueueable(
            new List<sObject>(), 
            200, 
            1
        );

    try {
        // Manufacture a real exception
        Integer x = 1 / 0;
    } catch (Exception ex) {
        // Directly invoke logError 
        // via @TestVisible access
        instance.logError(ex);
    }

    List<Apex_Log__c> errorLogs = [
        SELECT Id,
               Message__c,
               Stack_Trace__c
        FROM Apex_Log__c
        WHERE Log_Type__c = 'Error'
    ];

    System.assert(
        !errorLogs.isEmpty(),
        'logError should write to Apex_Log__c.'
    );

    System.assert(
        errorLogs[0].Message__c != null,
        'Message should be populated.'
    );

    System.assert(
        errorLogs[0].Stack_Trace__c != null,
        'Stack trace should be populated.'
    );
}
}
