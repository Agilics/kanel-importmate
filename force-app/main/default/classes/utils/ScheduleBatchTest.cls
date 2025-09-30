/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-29-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@IsTest
public with sharing class ScheduleBatchTest {
    @IsTest
    static void testScheduleBatchClass() {
        
        //GIVEN
        Integer batchSize = 200; 
        Schedule__c savedSchedule = TestDataFactory.createSchedule();//load data

        //WHEN
        Test.startTest();
        
        ScheduleBatch batchInstance = new ScheduleBatch();
        Id batchId = Database.executeBatch(batchInstance, batchSize);

        AsyncApexJob job = [
            SELECT Id,  Status, JobItemsProcessed,
            TotalJobItems, NumberOfErrors
            FROM AsyncApexJob
            WHERE ID = :batchId
        ];

        
        Test.stopTest();

        //THEN
        System.assertNotEquals(null, batchId);
        System.assertNotEquals(null,job);
    }
}