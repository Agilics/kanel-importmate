/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-19-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class ScheduleTaskUtils {
     /**
     * Calcule la prochaine date d’exécution selon la fréquence
     * @param schedule
     */
    public static Datetime calculateNextRun(Schedule__c schedule) {
       
         String frequency = schedule.Frequency__c.toUpperCase();

        //Exécution Journaliière
        if (frequency.equals(String.valueOf(FrequencyEnum.DAILY))) {
            return System.now().addDays(1);
        }
        
        //Exécution Hebdomadaire
        else if (frequency.equals(String.valueOf(FrequencyEnum.WEEKLY))) {
            return System.now().addDays(7);
        }

        //Exécution Mensuelle
        else if (frequency.equals(String.valueOf(FrequencyEnum.MONTHLY))) {
            return System.now().addMonths(1);
        }else {
            return null;
        }
        
    }
 

}