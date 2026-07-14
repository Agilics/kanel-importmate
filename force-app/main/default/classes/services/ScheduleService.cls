/**
 * @description : Service for Schedule__c - logique métier complète
 * @author      : mouhamed niang
 * @modified    : 10-07-2026
 * @Modified: Remove unused methods , refactoring methods and add comments for clarity
 */
public with sharing class ScheduleService {

    private static final String LOG_PREFIX = '[ScheduleService]';
   
    // WRAPPER
    public class ScheduleWrapper {
        @AuraEnabled public ImportProject__c         project;
        @AuraEnabled public List<Schedule__c>        schedules        { get; set; }
        @AuraEnabled public List<ImportExecution__c> importExecutions { get; set; }
        public ScheduleWrapper() {}
    }

   
    // CRÉATION / MODIFICATION / SUPPRESSION
   

    /**
     * Créer et planifier un Schedule__c 
     */
    public static Id schedule(String frequence, Datetime nextRun, String projectId) {
        try {
            if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
                !SecurityUtils.isAccessible(Schema.ImportProject__c.SObjectType)) {
                throw new SchedulingException('Insufficient permissions');
            }
            if (String.isBlank(frequence) || nextRun == null || String.isBlank(projectId)) {
                throw new SchedulingException('Frequency, nextRun and projectId are required');
            }
            if (nextRun <= System.now()) {
                throw new SchedulingException('Next run date must be in the future');
            }

            // Si un schedule ACTIF (non terminé) existe déjà, le mettre à jour
            // Un schedule terminé (Completed/Failed/Cancelled) doit générer un nouveau record
            List<Schedule__c> existing = [
                SELECT Id, Frequency__c, NextRun__c
                FROM Schedule__c
                WHERE Project__c = :projectId
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                List<ImportExecution__c> lastExec = [
                    SELECT Status__c FROM ImportExecution__c
                    WHERE Project__c = :projectId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                String lastStatus = lastExec.isEmpty() ? '' : (lastExec[0].Status__c != null ? lastExec[0].Status__c : '');
                Set<String> terminalStatuses = new Set<String>{ 'Completed', 'Failed', 'Cancelled' };

                if (!terminalStatuses.contains(lastStatus)) {
                    // Schedule encore actif (Pending/InProgress/Suspended) → mettre à jour
                    Map<String, Object> result = reSchedule(existing[0].Id, frequence, nextRun);
                    if (result.get('success') == true) {
                        return existing[0].Id;
                    }
                    throw new SchedulingException(String.valueOf(result.get('error')));
                }
                // Statut terminal → on tombe dans la création d'un nouveau schedule ci-dessous
            }

            Schedule__c newSchedule = new Schedule__c(
                Frequency__c = frequence,
                Project__c   = projectId,
                NextRun__c   = nextRun
            );
            Schedule__c savedSchedule = ScheduleRepository.addSchedule(newSchedule);
            if (savedSchedule == null || savedSchedule.Id == null) {
                throw new ApplicationException('Failed to create schedule record');
            }
           
            ExecutionRepository.createImportExecution(
                Id.valueOf(savedSchedule.Project__c),
                Constants.EXECUTION_STATUS_PENDING,
                Constants.EXECUTION_TYPE_SCHEDULED,
                '',
                0
            );
           

            // Planifier le CronJob
            String cron    = buildCron(savedSchedule.NextRun__c);
            String jobName = 'Schedule_' + savedSchedule.Id ;
            System.schedule(jobName, cron, new ScheduleJob(savedSchedule.Id));

            System.debug(LOG_PREFIX + ' Schedule created: ' + savedSchedule.Id);
            return savedSchedule.Id;

        } catch (SchedulingException e) {
            throw e;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new SchedulingException(e.getMessage());
        }
    }

    /**
     * Reprogrammer OU Reporter une exécution planifiée (schedule) existante
     */
    public static Map<String, Object> reSchedule(String scheduleId, String frequency, Datetime nextRun) {
        try {
            if (String.isBlank(scheduleId)) {
                return new Map<String, Object>{ 'success' => false, 'error' => 'Schedule ID is required' };
            }
            if (String.isBlank(frequency) || nextRun == null) {
                return new Map<String, Object>{ 'success' => false, 'error' => 'Frequency and nextRun are required' };
            }
            if (nextRun <= System.now()) {
                return new Map<String, Object>{ 'success' => false, 'error' => 'Next run date must be in the future' };
            }

            Schedule__c existingSchedule = ScheduleRepository.getScheduleById(scheduleId);
            if (existingSchedule == null) {
                return new Map<String, Object>{ 'success' => false, 'error' => 'Schedule not found' };
            }

            cancelExistingJob(existingSchedule.Id);

            existingSchedule.Frequency__c = frequency;
            existingSchedule.NextRun__c   = nextRun;
            update existingSchedule;

            String newCron    = buildCron(nextRun);
            String newJobName = 'Schedule_' + existingSchedule.Id + '_' + Datetime.now().getTime();
            System.schedule(newJobName, newCron, new ScheduleJob(existingSchedule.Id));

            return new Map<String, Object>{ 'success' => true };

        } catch (Exception e) {
            ErrorLogService.logException(e);
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    /**
     * Supprimer un schedule et avorter son job
     */
    public static void deleteScheduleById(String scheduleId) {
        try {
            if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
                !SecurityUtils.isDeletable(Schema.Schedule__c.SObjectType)) return;

            cancelExistingJob(scheduleId);
            ScheduleRepository.deleteScheduleById(scheduleId);

        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new SchedulingException(e.getMessage());
        }
    }

    
    // PLAY / PAUSE

    /**
     * Toggle  suspension/reprise  d'une exécution planifiée  via l'identifiant (schedule)
     * @param isPause typeof Boole  true = pause | false = play
     * @param scheduleId typeof String
     */
    public static Map<String, Object> toggleSchedule(String scheduleId, Boolean isPause) {
        try {
            if (String.isBlank(scheduleId)) {
                return new Map<String, Object>{ 'success' => false, 'error' => 'Schedule ID is required' };
            }
            Schedule__c existing = ScheduleRepository.getScheduleById(scheduleId);
            if (existing == null) {
                return new Map<String, Object>{ 'success' => false, 'error' => 'Schedule not found' };
            }
            return isPause ? pauseSchedule(existing) : resumeSchedule(existing);
        } catch (Exception e) {
            ErrorLogService.logException(e); 
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    // Suspendre une exécution planifiée
    private static Map<String, Object> pauseSchedule(Schedule__c schedule) {
        cancelExistingJob(schedule.Id);

        // 1 seul schedule par projet → query via Project__c sans ambiguïté
        List<ImportExecution__c> executions = [
            SELECT Id, Status__c, EndTime__c
            FROM ImportExecution__c
            WHERE Project__c = :schedule.Project__c
            AND   Status__c IN ('InProgress', 'Pending')
            ORDER BY StartTime__c DESC
            LIMIT 1
        ];

        String executionId = null;
        if (!executions.isEmpty()) {
            executions[0].Status__c  = 'Suspended';
            executions[0].EndTime__c = Datetime.now();
            ExecutionRepository.updateImportExecution(executions[0]);
            executionId = executions[0].Id;
        }
        return new Map<String, Object>{
            'success'     => true,
            'action'      => 'paused',
            'executionId' => executionId
        };
    }

    // Reprendre une planification
    private static Map<String, Object> resumeSchedule(Schedule__c schedule) {
        if (schedule.NextRun__c == null || schedule.NextRun__c <= System.now()) {
            return new Map<String, Object>{
                'success' => false,
                'error'   => 'Next run date is in the past. Please reschedule first.'
            };
        }

        List<ImportExecution__c> executions = [
            SELECT Id, Status__c, EndTime__c
            FROM ImportExecution__c
            WHERE Project__c = :schedule.Project__c
            AND   Status__c  = 'Suspended'
            ORDER BY StartTime__c DESC
            LIMIT 1
        ];

        String executionId = null;
        if (!executions.isEmpty()) {
            executions[0].Status__c  = 'Pending';
            executions[0].EndTime__c = null;
            ExecutionRepository.updateImportExecution(executions[0]);
            executionId = executions[0].Id;
        }

        String newCron    = buildCron(schedule.NextRun__c);
        String newJobName = 'Schedule_' + schedule.Id + '_' + Datetime.now().getTime();
        System.schedule(newJobName, newCron, new ScheduleJob(schedule.Id));

        return new Map<String, Object>{
            'success'     => true,
            'action'      => 'resumed',
            'executionId' => executionId
        };
    }

    
    // *** EXÉCUTION ***

    /**
     * Exécuter un schedule (appelé par ScheduleJob)
     */    
    public static ScheduleJobResult executeSchedule(Id scheduleId) {
        System.debug(LOG_PREFIX + ' Starting execution for: ' + scheduleId);

        try {
            
            Schedule__c schedule = ScheduleRepository.getScheduleById(scheduleId);
            Id projectId = Id.valueOf(schedule.Project__c);
            List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentService.getProjectFiles(String.valueOf(projectId));

           // Validation
            ScheduleJobResult validationResult = validateExecution(schedule, projectId, files);
            if (!validationResult.isSuccess()) {
                return validationResult;
            }
           
            ImportExecution__c execution = updateExecution(projectId,scheduleId,files);

            Id executionId = Id.valueOf(execution.Id);

            // 5. Créer les lignes de staging
            createStagingRows(executionId, files);  
            launchImport(executionId, schedule);
          
            // 6. Notification
            PublisherService.publishExecutionStarted(String.valueOf(execution.Id));

            return ScheduleJobResult.ok('Scheduled import started')
                    .withExecutionId(execution.Id)
                    .withPhase(Constants.EXECUTION_PHASE_STAGING); // ou 'Staging'

        } catch (Exception e) {
            System.debug(LOG_PREFIX + ' ERROR: ' + e.getMessage());
            ErrorLogService.logException(e);
            return ScheduleJobResult.error('Scheduled import failed: ' + e.getMessage());
        }
    }

   
    // **** QUERIES  ****

    public static List<ScheduleWrapper> getSchedulesWithExecutionsByIdProject(Id idProject) {
        try {
            if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) || idProject == null) {
                return new List<ScheduleWrapper>();
            }
            return ScheduleRepository.getSchedulesWithExecutionsByprojectId(idProject);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    public static Schedule__c getScheduleById(Id id) {
        try {
            if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) return null;
            return ScheduleRepository.getScheduleById(id);
        } catch (Exception e) {
            throw new ApplicationException(e.getMessage());
        }
    }

    public static List<Schedule__c> getPastSchedules() {
        try {
            if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) return new List<Schedule__c>();
            return ScheduleRepository.getPastSchedules();
        } catch (Exception e) {
            throw new ApplicationException(e.getMessage());
        }
    }

    public static List<ScheduleWrapper> getSchedulesByExecutionStatusAndIdProject(
        String status, String idProject
    ) {
        try {
            if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
                String.isBlank(idProject)) {
                return new List<ScheduleWrapper>();
            }
            return ScheduleRepository.getSchedulesByExecutionStatusAndprojectId(status, idProject);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }


    public static List<ScheduleWrapper> getSchedulesByProjectName(String name) {
        try {
            if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
                String.isBlank(name)) return new List<ScheduleWrapper>();
            return ScheduleRepository.getSchedulesByProjectName(name);
        } catch (Exception e) {
            throw new ApplicationException(e.getMessage());
        }
    }

   
    // PRIVATE HELPERS

    // régle de validations 
    private static ScheduleJobResult validateExecution(Schedule__c schedule,Id projectId,List<ContentDocumentService.ContentFileWrapper> files){
        if (schedule == null) {
            return ScheduleJobResult.error('Schedule not found: ' + schedule.Id);
        }
            // 1. Vérifier si une exécution est en cours de suspension
        if (isExecutionSuspended(projectId)) {
            return ScheduleJobResult.error('Execution is suspended. Resume before running.');
        }
        
        if (files == null || files.isEmpty()) {
            return ScheduleJobResult.error('No data found for scheduled import');
        }
        return  ScheduleJobResult.ok();
    }

    //  mise à jour des données de l'exécution
    private  static ImportExecution__c updateExecution(Id projectId,Id scheduleId,List<ContentDocumentService.ContentFileWrapper> file){
       // 1. Récupérer ou créer l'exécution en cours (Pending) 
        ImportExecution__c execution = getOrderedExecutionSchedule(projectId, scheduleId,file.size());

        // 2. Mise à jour de l'exécution avant traitement
        execution.Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS;
        execution.Phase__c  = Constants.EXECUTION_PHASE_IMPORTING;
        execution.TotalRecords__c = file.size();   // important pour le suivi

        ExecutionRepository.updateImportExecution(execution);
        return execution;
    }

    //lancer l'importation  via une exécution batch
    private static void launchImport(Id executionId,Schedule__c schedule){
          // 6. Lancer le batch de prétraitement
            Id batchJobId = Database.executeBatch(
                new PreProcessBatch(executionId, false),
                Constants.PREPROCESS_BATCH_SIZE
            );

            // 7. Mise à jour du prochain run + sauvegarde
            recalculateNextRun(schedule);
            update schedule;
    }
   
    /**
     * Récupère l'exécution la plus adaptée pour ce Schedule
     * Priorité : Pending  la plus récente de type Scheduled
     */
    private static ImportExecution__c getOrderedExecutionSchedule(Id projectId, Id scheduleId,Integer totalRecords) {
        // On cherche d'abord une exécution Pending liée à ce projet et de type Scheduled
        List<ImportExecution__c> executions = ExecutionRepository.getExecutionHistory(
            String.valueOf(projectId), 
            Constants.EXECUTION_STATUS_PENDING, 
            Constants.EXECUTION_TYPE_SCHEDULED
        );

        if (!executions.isEmpty()) {
            return executions[0];   // la plus récente grâce au ORDER BY CreatedDate DESC
        }

        //  créer une nouvelle exécution s'il n'existe pas 
        return ExecutionRepository.createImportExecution(
            projectId,
            Constants.EXECUTION_STATUS_PENDING,
            Constants.EXECUTION_TYPE_SCHEDULED,
            Constants.EXECUTION_PHASE_STAGING,
            totalRecords != null ? totalRecords : 0
        );
    }
    // vérifier si l'ImportExecution a statut Suspendue
    private static Boolean isExecutionSuspended(Id projectId) {
        List<ImportExecution__c> suspended = ExecutionRepository.getExecutionHistory(
            String.valueOf(projectId), 'Suspended', null
        );
        return !suspended.isEmpty();
    }

    // annuler les tâches CRON Job
    private static void cancelExistingJob(String scheduleId) {
        if (String.isBlank(scheduleId)) return;
        try {
            List<CronTrigger> jobs = ScheduleRepository.findCronTriggerByName(scheduleId);
            if (!jobs.isEmpty()) System.abortJob(jobs[0].Id);
        } catch (Exception e) {
           ErrorLogService.logException(e);
            throw new SchedulingException(e.getMessage());
        }
    }

    // recalculer la prochaine exécution
    private static void recalculateNextRun(Schedule__c schedule) {
        try {
            ImportMateEnum.FrequencyEnum frequency =
                ImportMateEnum.FrequencyEnum.valueOf(schedule.Frequency__c);
            if (frequency == ImportMateEnum.FrequencyEnum.DAILY) {
                schedule.NextRun__c = schedule.NextRun__c.addDays(1);
            } else if (frequency == ImportMateEnum.FrequencyEnum.WEEKLY) {
                schedule.NextRun__c = schedule.NextRun__c.addDays(7);
            } else if (frequency == ImportMateEnum.FrequencyEnum.MONTHLY) {
                schedule.NextRun__c = schedule.NextRun__c.addMonths(1);
            }
        } catch (Exception e) {
           ErrorLogService.logException(e);
            throw new SchedulingException(e.getMessage());
        }
    }

    private static String buildCron(Datetime nextRun) {
        return String.format('{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(nextRun.second()),
                String.valueOf(nextRun.minute()),
                String.valueOf(nextRun.hour()),
                String.valueOf(nextRun.day()),
                String.valueOf(nextRun.month()),
                String.valueOf(nextRun.year())
            }
        );
    }

    //create new staging rows from csvdata
    private static void createStagingRows(Id executionId, List<ContentDocumentService.ContentFileWrapper> data) {
        List<StagingRow__c> rows = new List<StagingRow__c>();
        for (Integer i = 0; i < data.size(); i++) {
            rows.add(new StagingRow__c(
                Execution__c  = executionId,
                LineNumber__c = i + 2,
                RawData__c    = JSON.serialize(data[i]),
                Processed__c  = false
            ));
        }
        insert rows;
    }

    

     

    private static List<Map<String, String>> getDataFromQuery(Id projectId) {
        try {
            ImportProject__c project = [
                SELECT TargetObject__c FROM ImportProject__c WHERE Id = :projectId LIMIT 1
            ];
            if (String.isBlank(project.TargetObject__c)) return null;

            Map<String, Schema.SObjectField> fieldsMap =
                ObjectMetadataService.getFieldsForObject(project.TargetObject__c);
            if (fieldsMap == null || fieldsMap.isEmpty()) return null;

            List<String> fieldNames = new List<String>(fieldsMap.keySet());
            if (!fieldNames.contains('Id')) fieldNames.add('Id');

            String soql = 'SELECT ' + String.join(fieldNames, ', ')
                        + ' FROM ' + project.TargetObject__c
                        + ' LIMIT 10000';

            List<SObject> records = Database.query(soql);
            if (records == null || records.isEmpty()) return null;

            List<Map<String, String>> result = new List<Map<String, String>>();
            for (SObject record : records) {
                Map<String, String> row = new Map<String, String>();
                for (String fieldName : fieldNames) {
                    Object val = record.get(fieldName);
                    row.put(fieldName, val != null ? String.valueOf(val) : '');
                }
                result.add(row);
            }
            return result;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new SchedulingException(e.getMessage());
        }
    }

    private static List<Map<String, String>> parseCsvContent(String csvContent) {
        try {
            List<Map<String, String>> result = new List<Map<String, String>>();
            List<String> lines = csvContent.split('\n');
            if (lines.isEmpty()) return result;

            List<String> headers = lines[0].split(',');
            for (Integer i = 1; i < lines.size(); i++) {
                String line = lines[i].trim();
                if (String.isBlank(line)) continue;
                List<String> values = line.split(',');
                Map<String, String> row = new Map<String, String>();
                for (Integer j = 0; j < headers.size() && j < values.size(); j++) {
                    row.put(headers[j].trim(), values[j].trim());
                }
                result.add(row);
            }
            return result;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new SchedulingException(e.getMessage());
        }
    }
}