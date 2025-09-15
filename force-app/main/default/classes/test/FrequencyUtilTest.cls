@isTest 
public with sharing class FrequencyUtilTest {
     @isTest
    public  static  testmethod void callTestData() {
        
        //Perform test
        Test.startTest();
        String excpetedFrequency = 'DAILY';
        FrequencyEnum actual =  FrequencyEnum.Frequency.DAILY;
        Test.stopTest();

        //Assertions
        System.assertEquals(expectedFrequency, actual);
     }
}