/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-19-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@IsTest 
public with sharing class ScheduleTaskUtilsTest {
    
    @IsTest
    static void testCalculateNextRun() {
        //Given 
        Schedule__c savedSchedule = TestDataFactory.createSchedule();
       
        //When
        Test.startTest();
            Datetime result = ScheduleTaskUtils.calculateNextRun(savedSchedule);
        Test.stopTest();

         System.debug('hey:'+result);
        //Then - Assertions
        Assert.isNotNull(savedSchedule, 'No schedule were found');
        Assert.isNotNull(result, 'No datetime were found ');
    }

 
}