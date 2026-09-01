/**
 * @description : Service for Schedule__c - logique métier complète
 * @author      : mouhamed niang
 * @modified    : 31-03-2026
 * @Modified: Remove shadowing filter
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

    // Résultat de résolution de données en mode Criteria (fichier(s) trouvé(s) par motif)
    private class ScheduleDataResult {
        List<Map<String, String>> rows              = new List<Map<String, String>>();
        String                    matchedFileName;
        Id                        matchedContentDocumentId;
        List<Id>                  resolvedFileIds    = new List<Id>();
    }

   
    // CRÉATION / MODIFICATION / SUPPRESSION
   

    /**
     * Créer et planifier un Schedule__c (mode Inherit par défaut, rétrocompatible)
     */
    public static Id schedule(String frequence, Datetime nextRun, String projectId) {
        return schedule(frequence, nextRun, projectId, Constants.DATA_SOURCE_MODE_INHERIT, null, null);
    }

    /**
     * Créer et planifier un Schedule__c, avec configuration optionnelle du mode Criteria
     * (sélection de fichier par motif de nom)
     */
    public static Id schedule(
        String frequence,
        Datetime nextRun,
        String projectId,
        String dataSourceMode,
        String fileSelectionMode,
        String fileNamePattern
    ) {
        try {
            if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
                !SecurityUtils.isAccessible(Schema.ImportProject__c.SObjectType)) {
                throw new SchedulingException(Label.SCH_Err_InsufficientPermissions);
            }
            if (String.isBlank(frequence) || nextRun == null || String.isBlank(projectId)) {
                throw new SchedulingException(Label.SCH_Err_RequiredFields);
            }
            if (nextRun <= System.now()) {
                throw new SchedulingException(Label.SCH_Err_NextRunInFuture);
            }

            // Une seule planification active par PROJET (pas par fichier) : l'écran de
            // planification définit des critères (motif de nom) que l'exécution applique en
            // parcourant l'ensemble des fichiers du projet pour trouver celui qui correspond.
            // Reprogrammer met donc à jour l'unique planification active existante, quels que
            // soient son mode ou son motif précédents. Un schedule terminé (Completed/Failed/
            // Cancelled) ne compte plus comme actif : la demande suivante en crée un nouveau.
            List<Schedule__c> projectSchedules = [
                SELECT Id, Frequency__c, NextRun__c, DataSourceMode__c, FileNamePattern__c
                FROM Schedule__c
                WHERE Project__c = :projectId
                ORDER BY CreatedDate DESC
            ];

            Schedule__c existingActiveSchedule = null;
            for (Schedule__c s : projectSchedules) {
                List<ImportExecution__c> lastExec = [
                    SELECT Status__c FROM ImportExecution__c
                    WHERE Schedule__c = :s.Id
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                String lastStatus = lastExec.isEmpty() ? '' : (lastExec[0].Status__c != null ? lastExec[0].Status__c : '');
                Set<String> terminalStatuses = new Set<String>{
                    Constants.EXECUTION_STATUS_COMPLETED, Constants.EXECUTION_STATUS_COMPLETED_WITH_ERRORS,
                    Constants.EXECUTION_STATUS_FAILED, Constants.EXECUTION_STATUS_CANCELLED
                };
                if (!terminalStatuses.contains(lastStatus)) {
                    existingActiveSchedule = s;
                    break;
                }
            }

            if (existingActiveSchedule != null) {
                Map<String, Object> result = reSchedule(
                    existingActiveSchedule.Id, frequence, nextRun, dataSourceMode, fileSelectionMode, fileNamePattern
                );
                if (result.get('success') == true) {
                    return existingActiveSchedule.Id;
                }
                throw new SchedulingException(String.valueOf(result.get('error')));
            }

            Schedule__c newSchedule = new Schedule__c(
                Frequency__c         = frequence,
                Project__c           = projectId,
                NextRun__c           = nextRun,
                DataSourceMode__c    = String.isNotBlank(dataSourceMode) ? dataSourceMode : Constants.DATA_SOURCE_MODE_INHERIT,
                FileSelectionMode__c = fileSelectionMode,
                FileNamePattern__c   = fileNamePattern
            );
            Schedule__c savedSchedule = ScheduleRepository.addSchedule(newSchedule);
            if (savedSchedule == null || savedSchedule.Id == null) {
                throw new ApplicationException(Label.SCH_Err_CreateFailed);
            }

            ExecutionRepository.createLinkedExecution(
                Id.valueOf(savedSchedule.Project__c),
                String.valueOf(savedSchedule.Id),
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
     * Reprogrammer OU Reporter une exécution planifiée (schedule) existante (fréquence/date uniquement ;
     * la configuration Criteria existante, si elle existe, n'est pas modifiée)
     */
    public static Map<String, Object> reSchedule(String scheduleId, String frequency, Datetime nextRun) {
        return reSchedule(scheduleId, frequency, nextRun, null, null, null);
    }

    /**
     * Reprogrammer OU Reporter une exécution planifiée (schedule) existante, avec mise à jour
     * optionnelle de la configuration Criteria. Un paramètre Criteria laissé à null conserve
     * la valeur déjà enregistrée (ne réinitialise pas vers Inherit).
     */
    public static Map<String, Object> reSchedule(
        String scheduleId,
        String frequency,
        Datetime nextRun,
        String dataSourceMode,
        String fileSelectionMode,
        String fileNamePattern
    ) {
        try {
            if (String.isBlank(scheduleId)) {
                return new Map<String, Object>{ 'success' => false, 'error' => Label.SCH_Err_IdRequired };
            }
            if (String.isBlank(frequency) || nextRun == null) {
                return new Map<String, Object>{ 'success' => false, 'error' => Label.SCH_Err_FreqAndDateRequired };
            }
            if (nextRun <= System.now()) {
                return new Map<String, Object>{ 'success' => false, 'error' => Label.SCH_Err_NextRunInFuture };
            }

            Schedule__c existingSchedule = ScheduleRepository.getScheduleById(scheduleId);
            if (existingSchedule == null) {
                return new Map<String, Object>{ 'success' => false, 'error' => Label.SCH_Err_NotFound };
            }

            cancelExistingJob(existingSchedule.Id);

            existingSchedule.Frequency__c = frequency;
            existingSchedule.NextRun__c   = nextRun;
            if (dataSourceMode != null)    existingSchedule.DataSourceMode__c    = dataSourceMode;
            if (fileSelectionMode != null) existingSchedule.FileSelectionMode__c = fileSelectionMode;
            if (fileNamePattern != null)   existingSchedule.FileNamePattern__c   = fileNamePattern;
            update existingSchedule;

            // reSchedule() peut être appelé sur un schedule dont la dernière exécution est déjà
            // terminale (Completed/Failed) — ex. reprogrammer après un premier run. Sans exécution
            // Pending/InProgress en attente, le job créé ci-dessous se déclencherait à vide au
            // prochain NextRun__c (executeSchedule() ne trouverait rien à traiter) et ne
            // n'importerait jamais rien.
            List<ImportExecution__c> openExecutions = ScheduleRepository.findExecutionsBySchedule(
                existingSchedule.Id,
                new List<String>{ Constants.EXECUTION_STATUS_PENDING, Constants.EXECUTION_STATUS_IN_PROGRESS }
            );
            if (openExecutions.isEmpty()) {
                ExecutionRepository.createLinkedExecution(
                    Id.valueOf(existingSchedule.Project__c),
                    String.valueOf(existingSchedule.Id),
                    Constants.EXECUTION_STATUS_PENDING,
                    Constants.EXECUTION_TYPE_SCHEDULED,
                    '',
                    0
                );
            }

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
                return new Map<String, Object>{ 'success' => false, 'error' => Label.SCH_Err_IdRequired };
            }
            Schedule__c existing = ScheduleRepository.getScheduleById(scheduleId);
            if (existing == null) {
                return new Map<String, Object>{ 'success' => false, 'error' => Label.SCH_Err_NotFound };
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

        // Plusieurs schedules (un par fichier) peuvent coexister sur le même projet →
        // ne toucher qu'à l'exécution liée à CE schedule précis (Schedule__c, lookup dédié).
        List<ImportExecution__c> executions = [
            SELECT Id, Status__c, EndTime__c
            FROM ImportExecution__c
            WHERE Schedule__c = :schedule.Id
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
                'error'   => Label.SCH_Err_NextRunPast
            };
        }

        List<ImportExecution__c> executions = [
            SELECT Id, Status__c, EndTime__c
            FROM ImportExecution__c
            WHERE Schedule__c = :schedule.Id
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
        } else {
            // Cas anormal (ex. l'exécution Suspended a été supprimée entre-temps) : sans exécution
            // Pending en attente, la reprise créerait un job qui se déclencherait à vide.
            ImportExecution__c fresh = ExecutionRepository.createLinkedExecution(
                Id.valueOf(schedule.Project__c),
                String.valueOf(schedule.Id),
                Constants.EXECUTION_STATUS_PENDING,
                Constants.EXECUTION_TYPE_SCHEDULED,
                '',
                0
            );
            executionId = fresh.Id;
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
        ImportExecution__c execution;
        Schedule__c existingSchedule;
        try {
            existingSchedule = ScheduleRepository.getScheduleById(scheduleId);
            if (existingSchedule == null) {
                return ScheduleJobResult.error(String.format(Label.SCH_Err_NotFoundWithId, new List<Object>{ scheduleId }));
            }

            // Bloquer si CETTE planification (pas une autre du même projet) est Suspended
            List<ImportExecution__c> suspendedExecution = [
                SELECT Id FROM ImportExecution__c
                WHERE Schedule__c = :scheduleId
                AND   Status__c  = 'Suspended'
                LIMIT 1
            ];
            if (!suspendedExecution.isEmpty()) {
                return ScheduleJobResult.error(Label.SCH_Err_Suspended);
            }

            // Récupérer l'exécution Pending liée à ce schedule dès maintenant : elle sert de
            // support de log, que l'exécution démarre normalement ou échoue plus bas.
            List<ImportExecution__c> pendingExecutions = ScheduleRepository.findExecutionsBySchedule(
                scheduleId, new List<String>{ Constants.EXECUTION_STATUS_PENDING }
            );
            execution = pendingExecutions.isEmpty() ? null : pendingExecutions[0];

            Boolean isCriteriaMode = Constants.DATA_SOURCE_MODE_CRITERIA.equals(existingSchedule.DataSourceMode__c)
                && String.isNotBlank(existingSchedule.FileNamePattern__c);

            List<Map<String, String>> importData;
            ScheduleDataResult criteriaResult;
            if (isCriteriaMode) {
                criteriaResult = retrieveScheduleDataByCriteria(existingSchedule);
                importData = criteriaResult.rows;
            } else {
                importData = retrieveScheduleData(existingSchedule);
            }

            if (importData == null || importData.isEmpty()) {
                String reason = isCriteriaMode
                    ? String.format(Label.SCH_Err_NoFileMatch, new List<Object>{ existingSchedule.FileNamePattern__c })
                    : Label.SCH_Err_NoDataAvailable;
                markExecutionFailed(execution, reason);
                // Une planification récurrente (Daily/Weekly/Monthly) doit continuer à réessayer
                // aux prochaines occurrences même si aucun fichier ne correspond aujourd'hui.
                rescheduleNext(existingSchedule);
                update existingSchedule;
                return ScheduleJobResult.error(Label.SCH_Err_NoDataFound);
            }

            if (execution == null) {
                String reason = Label.SCH_Err_NoPendingExecution;
                ErrorLogService.logError(0, Constants.ERROR_TYPE_SCHEDULING, reason);
                // Cas anormal mais pas définitif : la planification récurrente doit quand même
                // retenter à la prochaine occurrence plutôt que de rester bloquée pour toujours.
                rescheduleNext(existingSchedule);
                update existingSchedule;
                return ScheduleJobResult.error(reason);
            }

            Integer totalRecords = Integer.valueOf(importData.size());

            // inject phase
            execution.Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS;
            execution.Phase__c = Constants.EXECUTION_PHASE_IMPORTING;
            execution.TotalRecords__c = totalRecords;
            if (isCriteriaMode) {
                execution.MatchedFileName__c = criteriaResult.matchedFileName;
                execution.MatchedContentDocumentId__c = criteriaResult.matchedContentDocumentId != null
                    ? String.valueOf(criteriaResult.matchedContentDocumentId)
                    : null;
            }

            // Update Status & Phase of ImportExecution
            ExecutionRepository.updateImportExecution(execution);

            createStagingRows(execution.Id, importData);

            Id jobId = Database.executeBatch(
                new PreProcessBatch(execution.Id, false),
                Constants.PREPROCESS_BATCH_SIZE
            );

            rescheduleNext(existingSchedule);

            if (isCriteriaMode && Constants.FILE_SELECTION_ONE_PER_RUN.equals(existingSchedule.FileSelectionMode__c)
                && !criteriaResult.resolvedFileIds.isEmpty()) {
                FileMatchService.markFilesProcessed(existingSchedule, criteriaResult.resolvedFileIds);
            }

            update existingSchedule;

            PublisherService.publishExecutionStarted(String.valueOf(execution.Id));

            return ScheduleJobResult.ok(Label.SCH_Msg_ImportStarted)
                .withExecutionId(execution.Id)
                .withPhase('Staging');

        } catch (Exception e) {
            System.debug(LOG_PREFIX + ' ERROR: ' + e.getMessage());
            ErrorLogService.logException(e);
            markExecutionFailed(execution, String.format(Label.SCH_Err_UnexpectedExecution, new List<Object>{ e.getMessage() }));

            // Une erreur inattendue sur CETTE occurrence ne doit pas tuer la planification
            // récurrente pour toujours : on retente à la prochaine échéance. Isolé dans son
            // propre try/catch pour ne jamais masquer l'erreur d'origine ci-dessus si la
            // replanification elle-même échoue (ex. Frequency__c invalide).
            if (existingSchedule != null) {
                try {
                    rescheduleNext(existingSchedule);
                    update existingSchedule;
                } catch (Exception rescheduleError) {
                    ErrorLogService.logException(rescheduleError);
                }
            }

            return ScheduleJobResult.error(String.format(Label.SCH_Err_ScheduledImportFailed, new List<Object>{ e.getMessage() }));
        }
    }

    /**
     * Marque l'exécution planifiée comme Failed et consigne la raison dans ImportLog__c,
     * afin que l'échec soit visible dans l'historique (et pas seulement dans les debug logs).
     */
    private static void markExecutionFailed(ImportExecution__c execution, String reason) {
        if (execution == null) return;
        try {
            execution.Status__c = Constants.EXECUTION_STATUS_FAILED;
            execution.EndTime__c = Datetime.now();
            ExecutionRepository.updateImportExecution(execution);
            ImportLogService.logImportLog(String.valueOf(execution.Id), Constants.EXECUTION_STATUS_FAILED, reason);
            PublisherService.publishImportStatus(String.valueOf(execution.Id), Constants.EXECUTION_STATUS_FAILED, 100, reason);
        } catch (Exception e) {
            ErrorLogService.logException(e);
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

    /**
     * Toutes les planifications d'un projet — plusieurs peuvent coexister (une par fichier
     * en mode Criteria). Utilisé depuis l'écran des fichiers pour savoir, PAR FICHIER,
     * s'il est déjà programmé (comparaison sur FileNamePattern__c), sans mélanger les
     * planifications des autres fichiers du même projet.
     */
    public static List<Schedule__c> getSchedulesForProject(Id projectId) {
        try {
            if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) || projectId == null) {
                return new List<Schedule__c>();
            }
            return ScheduleRepository.getSchedulesByprojectId(String.valueOf(projectId));
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

    // Planifie le prochain déclenchement récurrent (Daily/Weekly/Monthly) de ce schedule.
    // Le CronTrigger ponctuel (one-off) qui vient de se déclencher est automatiquement
    // supprimé par Salesforce une fois exécuté : sans ce nouvel appel à System.schedule(),
    // NextRun__c avancerait bien en base mais plus aucun job ne se déclencherait jamais —
    // la planification "mourrait" silencieusement après sa toute première exécution.
    private static void rescheduleNext(Schedule__c schedule) {
        recalculateNextRun(schedule);
        String nextCron    = buildCron(schedule.NextRun__c);
        String nextJobName = 'Schedule_' + schedule.Id + '_' + Datetime.now().getTime();
        System.schedule(nextJobName, nextCron, new ScheduleJob(schedule.Id));
    }

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
    private static void createStagingRows(Id executionId, List<Map<String, String>> data) {
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

    private static List<Map<String, String>> retrieveScheduleData(Schedule__c schedule) {
        // 1. Fichier fixe attaché directement à ce schedule (mode "fichier fixe")
        List<Map<String, String>> data = getDataFromContentDocument(schedule.Id);
        if (data != null && !data.isEmpty()) return data;
        // 2. Fichier uploadé à l'étape 2 et lié au projet
        data = getDataFromContentDocument(schedule.Project__c);
        if (data != null && !data.isEmpty()) return data;
        // 3. Repli sur la requête SOQL de l'objet cible
        return getDataFromQuery(schedule.Project__c);
    }

    /**
     * Mode Criteria : résout le motif de nom de fichier pour aujourd'hui, retrouve le(s) fichier(s)
     * correspondant(s) du projet selon FileSelectionMode__c, et en extrait les lignes CSV.
     * Ne retombe volontairement PAS sur le repli SOQL du mode Inherit en cas d'absence de match :
     * l'utilisateur a explicitement choisi un critère de fichier, importer tout l'objet cible serait surprenant.
     */
    private static ScheduleDataResult retrieveScheduleDataByCriteria(Schedule__c schedule) {
        ScheduleDataResult result = new ScheduleDataResult();

        String resolvedPattern = FileMatchService.resolvePattern(schedule.FileNamePattern__c, Date.today());
        List<FileMatchService.MatchedFile> candidates =
            FileMatchService.findMatchingFiles(schedule.Project__c, resolvedPattern);
        if (candidates.isEmpty()) return result;

        Set<Id> processedIds = Constants.FILE_SELECTION_ONE_PER_RUN.equals(schedule.FileSelectionMode__c)
            ? FileMatchService.getProcessedFileIds(schedule)
            : new Set<Id>();

        List<FileMatchService.MatchedFile> selected =
            FileMatchService.applySelectionMode(candidates, schedule.FileSelectionMode__c, processedIds);
        if (selected.isEmpty()) return result;

        List<String> matchedNames = new List<String>();
        for (FileMatchService.MatchedFile file : selected) {
            List<Map<String, String>> rows = getDataFromContentDocumentId(file.contentDocumentId);
            if (rows != null) result.rows.addAll(rows);
            result.resolvedFileIds.add(file.contentDocumentId);
            matchedNames.add(file.fileName);
        }
        result.matchedFileName = String.join(matchedNames, ', ');
        result.matchedContentDocumentId = selected[0].contentDocumentId;
        return result;
    }

    private static List<Map<String, String>> getDataFromContentDocumentId(Id contentDocumentId) {
        try {
            List<ContentVersion> versions = [
                SELECT VersionData FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                AND IsLatest = true LIMIT 1
            ];
            if (versions.isEmpty()) return null;

            return parseCsvContent(versions[0].VersionData.toString());
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new SchedulingException(e.getMessage());
        }
    }

    private static List<Map<String, String>> getDataFromContentDocument(Id scheduleId) {
        try {
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId FROM ContentDocumentLink
                WHERE LinkedEntityId = :scheduleId LIMIT 1
            ];
            if (links.isEmpty()) return null;

            List<ContentVersion> versions = [
                SELECT VersionData FROM ContentVersion
                WHERE ContentDocumentId = :links[0].ContentDocumentId
                AND IsLatest = true LIMIT 1
            ];
            if (versions.isEmpty()) return null;

            return parseCsvContent(versions[0].VersionData.toString());
        } catch (Exception e) {
           ErrorLogService.logException(e);
            throw new SchedulingException(e.getMessage());
        }
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