/**
 * @description: Job Apex programmé qui se déclenche quand le schedule arrive à sa date
 * @author: mouhamed niang
 * @last modified: 04-03-2026
 * 
 * FLUX COMPLET (Mode Programmé):
 * 1. User crée un schedule via LWC (handleScheduleImport)
 * 2. Schedule__c est créé avec NextRun = date future
 * 3. System.schedule() planifie ce ScheduleJob
 * 4. À la date NextRun, ScheduleJob.execute() se déclenche
 * 5. ScheduleJob crée ImportExecution__c (C'EST LA CLÉ!)
 * 6. ScheduleJob enqueue ImportQueueable
 * 7. ImportQueueable lance ImportBatch (comme en mode immédiat)
 * 8. ImportBatch traite les données (StagingRow__c)
 * 
 * RÉSULTAT: Les deux modes (Immédiat et Programmé) convergent vers ImportBatch
 */
public class ScheduleJob implements Schedulable {
    
    private Id scheduleId;
    private static final String LOG_PREFIX = '[ScheduleJob]';
    
    /**
     * Constructeur avec ID du schedule
     */
    public ScheduleJob(Id scheduleId) {
        this.scheduleId = scheduleId;
    }
    
    /**
     * Schedulable.execute() - Appelé par Salesforce à la date/heure prévue
     */
    public void execute(SchedulableContext sc) {
        System.debug('  ScheduleJob.execute() - SCHEDULED IMPORT ');
        System.debug(LOG_PREFIX + ' Schedule ID: ' + scheduleId);
        System.debug(LOG_PREFIX + ' Delegating to ScheduleService...');
        try {
            // DÉLÉGUER À SCHEDULEJOSERVICE
            ScheduleJobResult result = ScheduleService.executeSchedule(scheduleId);
            
            if (result.isSuccess()) {
               
               
                System.debug('  ScheduleJob.execute() - SUCCESS                    ');
               
               
                System.debug(LOG_PREFIX + ' Result: ' + result.message);
                System.debug(LOG_PREFIX + ' Execution ID: ' + result.executionId);
                System.debug(LOG_PREFIX + ' Phase: ' + result.phase);
               
            } else {
                System.debug('  ScheduleJob.execute() - FAILED                      ');
                System.debug(LOG_PREFIX + ' Errors: ' + result.getErrorsAsString());
               
            }
            
        } catch (Exception e) {
           
            System.debug('  ScheduleJob.execute() - UNEXPECTED ERROR           ');
            System.debug(LOG_PREFIX + ' Error: ' + e.getMessage());
            System.debug(LOG_PREFIX + ' Stack: ' + e.getStackTraceString());
           
            
            ErrorLogService.logException(e);
        }
    }
}
