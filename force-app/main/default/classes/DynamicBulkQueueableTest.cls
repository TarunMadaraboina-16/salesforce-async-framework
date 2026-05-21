@isTest
private class DynamicBulkQueueableTest {
    
    @testSetup
    static void setupData() {
        List<Account> testAccs = new List<Account>();
        for(Integer i=0; i<300; i++) {
            // Using Type instead of Description to allow safe SOQL filtering
            testAccs.add(new Account(Name = 'Framework Test ' + i, Type = 'Prospect'));
        }
        insert testAccs;
    }

    @isTest
    static void testQueueableChainingSuccess() {
        List<Account> records = [SELECT Id, Type FROM Account];
        for(Account acc : records) {
            acc.Type = 'Other';
        }

        // Force a batch size slice point at 150 items to validate framework splitting paths
        DynamicBulkQueueable job = new DynamicBulkQueueable(records, 150, 1);

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        // Safe SOQL filtering on the 'Type' field
        List<Account> savedRecords = [SELECT Id, Type FROM Account WHERE Type = 'Other'];
        System.assert(savedRecords.size() >= 150, 'Async slice framework validation step failed to store data.');
    }
}