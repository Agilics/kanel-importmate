@IsTest 
public with sharing class FrequencyUtilTest {
     
     @IsTest
    public  static  void callTestData() {
        
        //Perform test
        Test.startTest();
        String excpetedFrequency = 'DAILY';
        FrequencyEnum actual =  FrequencyEnum.DAILY;
        Test.stopTest();

        //Assertions
        System.assertEquals(excpetedFrequency, actual.Name());
     }
}