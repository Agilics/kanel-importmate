/**
 * @description : Service for Schedule__c - logique mÃ©tier complÃ¨te
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

    /**
     * DTO pour le rÃ©sultat de l'opÃ©ration "Programmer tout" (bulk execute).
     */
    public class BulkExecuteResult {
        @AuraEnabled public Integer totalSchedules    { get; set; }
        @AuraEnabled public Integer successCount      { get; set; }
        @AuraEnabled public Integer errorCount        { get; set; }
        @AuraEnabled public List<String> successMessages { get; set; }
        @AuraEnabled public List<String> errorMessages   { get; set; }
        public BulkExecuteResult() {
            this.totalSchedules   = 0;
            this.successCount     = 0;
            this.errorCount       = 0;
            this.successMessages  = new List<String>();
            this.errorMessages    = new List<String>();
        }
    }

   
    // CRÃ‰ATION / MODIFICATION / SUPPRESSION
   

    /**
     * CrÃ©er et planifier un Schedule__c 
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

            // Si un schedule ACTIF (non terminÃ©) existe dÃ©jÃ , le mettre Ã  jour
            // Un schedule terminÃ© (Completed/Failed/Cancelled) doit gÃ©nÃ©rer un nouveau record
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
                    // Schedule encore actif (Pending/InProgress/Suspended) â†’ mettre Ã  jour
                    Map<String, Object> result = reSchedule(existing[0].Id, frequence, nextRun);
                    if (result.get('success') == true) {
                        return existing[0].Id;
                    }
                    throw new SchedulingException(String.valueOf(result.get('error')));
                }
                // Statut terminal â†’ on tombe dans la crÃ©ation d'un nouveau schedule ci-dessous
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
           
            // NOTE: ImportExecution__c n'est PAS cree ici.
            // Elle est creee uniquement par bulkExecute() (bouton Execute Now).
           

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

    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    //  BULK EXECUTE â€” "Programmer tout" (Programmer)
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    /**
     * ExÃ©cute en masse tous les schedules actifs d'un projet.
     * Pour chaque schedule actif (Pending/Suspended), crÃ©e une ImportExecution__c
     * avec le type 'Scheduled' et le statut 'Pending'.
     *
     * @param projectId L'ID du projet dont on veut programmer les exÃ©cutions
     * @return BulkExecuteResult avec le rÃ©sumÃ© des opÃ©rations
     */
    public static BulkExecuteResult bulkExecute(Id projectId) {
        BulkExecuteResult result = new BulkExecuteResult();

        if (projectId == null) {
            result.errorMessages.add('ID du projet requis.');
            result.errorCount++;
            return result;
        }

        try {
            // 1. RÃ©cupÃ©rer tous les schedules liÃ©s Ã  ce projet
            List<Schedule__c> schedules = ScheduleRepository.getSchedulesByprojectId(String.valueOf(projectId));
            if (schedules == null || schedules.isEmpty()) {
                result.errorMessages.add('Aucune planification trouvÃ©e pour ce projet.');
                result.errorCount++;
                return result;
            }

            result.totalSchedules = schedules.size();

            // 2. VÃ©rifier les doublons â€” exÃ©cution active dÃ©jÃ  existante ?
            Set<Id> projectIds = new Set<Id>{ projectId };
            Set<Id> blockedProjects = ExecutionRepository.filterProjectsWithActiveExecutions(projectIds);

            if (blockedProjects.contains(projectId)) {
                result.errorMessages.add(
                    'Une exÃ©cution est dÃ©jÃ  en cours pour ce projet. ' +
                    'Veuillez attendre la fin de l\'exÃ©cution en cours.'
                );
                result.errorCount++;
                return result;
            }

            // 3. CrÃ©er une ImportExecution__c pour CHAQUE schedule
            List<ImportExecution__c> executionsToInsert = new List<ImportExecution__c>();

            for (Schedule__c sched : schedules) {
                ImportExecution__c exec = new ImportExecution__c(
                    Project__c          = projectId,
                    Status__c           = Constants.EXECUTION_STATUS_PENDING,
                    Type__c             = Constants.EXECUTION_TYPE_SCHEDULED,
                    StartTime__c        = System.now(),
                    TotalRecords__c     = 0,
                    ProcessedRecords__c = 0,
                    FailedRecords__c    = 0
                );
                executionsToInsert.add(exec);
            }

            // 4. Insertion en masse (en respectant les droits)
            if (!SecurityUtils.isCreateable(ImportExecution__c.SObjectType)) {
                result.errorMessages.add('Permissions insuffisantes pour crÃ©er des exÃ©cutions.');
                result.errorCount++;
                return result;
            }

            insert executionsToInsert;

            // 5. Pour chaque exÃ©cution crÃ©Ã©e, planifier le ScheduleJob
            //    Les exÃ©cutions sont dans le mÃªme ordre que les schedules
            for (Integer i = 0; i < executionsToInsert.size() && i < schedules.size(); i++) {
                ImportExecution__c exec = executionsToInsert[i];
                Schedule__c sched = schedules[i];

                try {
                    // Planifier le job CRON pour le schedule
                    if (sched.NextRun__c != null && sched.NextRun__c > System.now()) {
                        String cron    = buildCron(sched.NextRun__c);
                        String jobName = 'Schedule_' + sched.Id + '_' + System.now().getTime();
                        System.schedule(jobName, cron, new ScheduleJob(sched.Id));

                        result.successMessages.add(
                            'ExÃ©cution crÃ©Ã©e pour le schedule ' + sched.Name +
                            ' (exÃ©cution: ' + exec.Id + ', prochaine exÃ©cution: ' + sched.NextRun__c + ')'
                        );
                        result.successCount++;
                    } else {
                        // NextRun dans le passÃ© â†’ on crÃ©e l'exÃ©cution mais on ne programme pas de CronTrigger
                        result.successMessages.add(
                            'ExÃ©cution crÃ©Ã©e pour le schedule ' + sched.Name +
                            ' (exÃ©cution: ' + exec.Id + '). La date de prochaine exÃ©cution est passÃ©e, ' +
                            'le job CRON n\'a pas Ã©tÃ© programmÃ©.'
                        );
                        result.successCount++;
                    }
                } catch (Exception e) {
                    result.errorMessages.add(
                        'Erreur lors de la planification du job pour le schedule ' + sched.Name +
                        ' : ' + e.getMessage()
                    );
                    result.errorCount++;
                }
            }

        } catch (Exception e) {
            ErrorLogService.logException(e);
            result.errorMessages.add('Erreur inattendue: ' + e.getMessage());
            result.errorCount++;
        }

        return result;
    }

    /**
     * Reprogrammer OU Reporter une exÃ©cution planifiÃ©e (schedule) existante
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
     * Toggle  suspension/reprise  d'une exÃ©cution planifiÃ©e  via l'identifiant (schedule)
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

    // Suspendre une exÃ©cution planifiÃ©e
    private static Map<String, Object> pauseSchedule(Schedule__c schedule) {
        cancelExistingJob(schedule.Id);

        // Marquer le schedule comme suspendu (champ de verite)
        schedule.IsActive__c = false;
        try {
            update schedule;
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
        // 1 seul schedule par projet â†’ query via Project__c sans ambiguÃ¯tÃ©
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

        // Marquer le schedule comme actif (champ de verite)
        schedule.IsActive__c = true;
        update schedule;

        String newCron    = buildCron(schedule.NextRun__c);
        String newJobName = 'Schedule_' + schedule.Id + '_' + Datetime.now().getTime();
        System.schedule(newJobName, newCron, new ScheduleJob(schedule.Id));

        return new Map<String, Object>{
            'success'     => true,
            'action'      => 'resumed',
            'executionId' => executionId
        };
    }

    
    // *** EXÃ‰CUTION ***

    /**
     * ExÃ©cuter un schedule (appelÃ© par ScheduleJob)
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

            // 5. CrÃ©er les lignes de staging
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

    // rÃ©gle de validations 
    private static ScheduleJobResult validateExecution(Schedule__c schedule,Id projectId,List<ContentDocumentService.ContentFileWrapper> files){
        if (schedule == null) {
            return ScheduleJobResult.error('Schedule not found: ' + schedule.Id);
        }
            // 1. VÃ©rifier si une exÃ©cution est en cours de suspension
        if (isExecutionSuspended(projectId)) {
            return ScheduleJobResult.error('Execution is suspended. Resume before running.');
        }
        
        if (files == null || files.isEmpty()) {
            return ScheduleJobResult.error('No data found for scheduled import');
        }
        return  ScheduleJobResult.ok();
    }

    //  mise Ã  jour des donnÃ©es de l'exÃ©cution
    private  static ImportExecution__c updateExecution(Id projectId,Id scheduleId,List<ContentDocumentService.ContentFileWrapper> file){
       // 1. RÃ©cupÃ©rer ou crÃ©er l'exÃ©cution en cours (Pending) 
        ImportExecution__c execution = getOrderedExecutionSchedule(projectId, scheduleId,file.size());

        // 2. Mise Ã  jour de l'exÃ©cution avant traitement
        execution.Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS;
        execution.Phase__c  = Constants.EXECUTION_PHASE_IMPORTING;
        execution.TotalRecords__c = file.size();   // important pour le suivi

        ExecutionRepository.updateImportExecution(execution);
        return execution;
    }

    //lancer l'importation  via une exÃ©cution batch
    private static void launchImport(Id executionId,Schedule__c schedule){
          // 6. Lancer le batch de prÃ©traitement
            Id batchJobId = Database.executeBatch(
                new PreProcessBatch(executionId, false),
                Constants.PREPROCESS_BATCH_SIZE
            );

            // 7. Mise Ã  jour du prochain run + sauvegarde
            recalculateNextRun(schedule);
            update schedule;
    }
   
    /**
     * RÃ©cupÃ¨re l'exÃ©cution la plus adaptÃ©e pour ce Schedule
     * PrioritÃ© : Pending  la plus rÃ©cente de type Scheduled
     */
    private static ImportExecution__c getOrderedExecutionSchedule(Id projectId, Id scheduleId,Integer totalRecords) {
        // On cherche d'abord une exÃ©cution Pending liÃ©e Ã  ce projet et de type Scheduled
        List<ImportExecution__c> executions = ExecutionRepository.getExecutionHistory(
            String.valueOf(projectId), 
            Constants.EXECUTION_STATUS_PENDING, 
            Constants.EXECUTION_TYPE_SCHEDULED
        );

        if (!executions.isEmpty()) {
            return executions[0];   // la plus rÃ©cente grÃ¢ce au ORDER BY CreatedDate DESC
        }

        //  crÃ©er une nouvelle exÃ©cution s'il n'existe pas 
        return ExecutionRepository.createImportExecution(
            projectId,
            Constants.EXECUTION_STATUS_PENDING,
            Constants.EXECUTION_TYPE_SCHEDULED,
            Constants.EXECUTION_PHASE_STAGING,
            totalRecords != null ? totalRecords : 0
        );
    }
    // vÃ©rifier si l'ImportExecution a statut Suspendue
    private static Boolean isExecutionSuspended(Id projectId) {
        List<ImportExecution__c> suspended = ExecutionRepository.getExecutionHistory(
            String.valueOf(projectId), 'Suspended', null
        );
        return !suspended.isEmpty();
    }

    // annuler les tÃ¢ches CRON Job
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

    // recalculer la prochaine exÃ©cution
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