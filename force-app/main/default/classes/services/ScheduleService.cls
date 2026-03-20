/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 
 * @last modified on  : 01-12-2026
 * @last modified by  mouhamed niang
**/
public with sharing class ScheduleService{
    // Classe wrapper pour contenir le schedule et ses importations d'executions
    public class ScheduleWrapper {
        @AuraEnabled public ImportProject__c project;
        @AuraEnabled
        public List<Schedule__c> schedules { get; set; } //attribut avec getters & setters
        @AuraEnabled
        public List<ImportExecution__c> importExecutions { get; set; }
        
        //constructeur par défaut
        public ScheduleWrapper(){

        }
    }

     /**
     * Mettre à jour et enregistrement  d'une planification  Schedule__c
     */
    public static Id schedule(String frequence,Datetime nextRun,String projectId) {
        try {
            if (
                SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) &&
                SecurityUtils.isAccessible(Schema.ImportProject__c.SObjectType) 
            ) {

            //Intialisation de la planification
            Schedule__c schedule = new Schedule__c(
                Frequency__c = frequence,
                Project__c = projectId,
                NextRun__c = nextRun
            );

                Schedule__c savedSchedule = ScheduleRepository.addSchedule(schedule);
                
                if (schedule.Id == null) {
                    throw new ApplicationException('Failed to create schedule record');
                }

                String cron = buildCron(schedule.NextRun__c);
                ScheduleJob scheduler = new ScheduleJob(savedSchedule.Id);
                String jobName = 'Schedule_' + schedule.Id + '_' + Datetime.now().getTime();
                System.schedule(jobName, cron, scheduler);
            
                return schedule.Id;
            }
                return null;
          } catch (DmlException e) {
              ErrorLogService.logException(e);
              throw new DmlException(e.getMessage());
        }
    }
   
   

    /*
    *suppression d'une planification via l'id du schedule
    */ 
     public static void deleteScheduleById(String scheduleId) {
        try {
            if(
                SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) &&
                SecurityUtils.isDeletable(Schema.Schedule__c.SObjectType)
            ) {
                ScheduleRepository.deleteScheduleById(scheduleId);   
            } 
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new DmlException(e.getMessage());
        }
    
    }

      /**
    *Récupérer toutes les planifications avec une date d'éxécution passée
    */
    public static List<Schedule__c> getPastSchedules() {
       
        try {  
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                return   ScheduleRepository.getPastSchedules();
            }
            return new List<Schedule__c>();
        } catch (ApplicationException e) {
                ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());
            }
        }

    /**
    *Récupérer toutes les planifications avec les éxécutions importés
    */
    public static List<ScheduleService.ScheduleWrapper>  getSchedulesWithExecutionsByIdProject(Id idProject) {
       
        try {  
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                return   ScheduleRepository.getSchedulesWithExecutionsByIdProject(idProject);    
            }
            return new List<ScheduleService.ScheduleWrapper>();
        } catch (ApplicationException e) {
                ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());
            }
    }
    /**
     * Filter planifications par le statut d'éxécution d'importé et par l'id du projet
     */
      public static List<ScheduleService.ScheduleWrapper> getSchedulesByExecutionStatusAndIdProject(String status,String idProject) {
        try {  
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                return   ScheduleRepository.getSchedulesByExecutionStatusAndIdProject(status,idProject);    
            }
            return new List<ScheduleService.ScheduleWrapper>();
        } catch (ApplicationException e) {
                ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());
            }
    }

    /**
     *Filtrer par fréquence (DAILY | WEEKLY | MONTHLY)
    */
     public static List<Schedule__c> getSchedulesByFrequencyAndProjectId(ImportMateEnum.FrequencyEnum frequence,String idProject) {
       try {
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                return  ScheduleRepository.getSchedulesByFrequencyAndProjectId(frequence,idProject);   
            }
            return new List<Schedule__c>();
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    /**
     * Recherche les planifications par l'id
    */
     public static Schedule__c getScheduleById(Id id) {
       try {
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                return  ScheduleRepository.getScheduleById(id);   
            }
            return null;
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }


    /**
     * Recherche les planifications par le nom du projet
    */
     public static List<ScheduleWrapper> getSchedulesByProjectName(String name) {
       try {
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                if(String.isNotBlank(name)) {
                    return  ScheduleRepository.getSchedulesByProjectName(name);     
                } else {
                    return new List<ScheduleWrapper>();
                }
            }
            return new List<ScheduleWrapper>();
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }  
    } 

   
    
    //Execution automatique
 public static void runDueSchedules() {
        List<Schedule__c> schedules = ScheduleRepository.getPastSchedules();

        for (Schedule__c sch : schedules) {
            try {
                // Lancer l’import
                
                // Replanifier selon la fréquence
                ImportMateEnum.FrequencyEnum  frequence = ImportMateEnum.FrequencyEnum.valueOf(sch.Frequency__c);
                 
                if(ImportMateEnum.FrequencyEnum.DAILY.equals(frequence)) {
                    sch.NextRun__c = sch.NextRun__c.addDays(1);
                } else if(ImportMateEnum.FrequencyEnum.WEEKLY === frequence) {
                    sch.NextRun__c = sch.NextRun__c.addDays(7);
                } else if(ImportMateEnum.FrequencyEnum.MONTHLY === frequence) {
                    sch.NextRun__c = sch.NextRun__c.addMonths(1);
                }
            } catch (Exception e) {
                // Gestion d’erreurs 
                ErrorLogService.logException(e);
                throw new ApplicationException('Erreur planification : ' + e.getMessage());
            }
        }
        update schedules;
    }

    /**
     * Construit l’expression CRON Salesforce
    */
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




        
    private static final String LOG_PREFIX = '[ScheduleJobService]';
    
    /**
     * Exécuter un schedule programmé
     * 
     * FLUX:
     * 1. Valider le schedule
     * 2. Récupérer les données (CSV stocké, API, etc.)
     * 3. Créer ImportExecution__c
     * 4. Créer StagingRow__c avec les données
     * 5. Lancer PreProcessBatch
     * 6. Recalculer NextRun
     * 7. Mettre à jour Schedule__c
     * 
     * @param scheduleId ID du Schedule__c
     * @return ScheduleJobResult
     */
    public static ScheduleJobResult executeSchedule(Id scheduleId) {
        System.debug(LOG_PREFIX + ' Starting scheduled execution for: ' + scheduleId);
        
        try {
            // ÉTAPE 1: VALIDATION
            Schedule__c schedule = ScheduleRepository.getScheduleById(scheduleId);
            
            if (schedule == null) {
                return ScheduleJobResult.error('Schedule not found: ' + scheduleId);
            }
            
            // ÉTAPE 2: RÉCUPÉRER LES DONNÉES
            // Option 1: ContentDocument (CSV uploadé)
            List<Map<String, String>> importData = retrieveScheduleData(schedule);
            
            if (importData == null || importData.isEmpty()) {
                System.debug(LOG_PREFIX + ' WARNING: No data found for schedule');
                return ScheduleJobResult.error('No data found for scheduled import');
            }
            
            System.debug(LOG_PREFIX + ' Retrieved ' + importData.size() + ' rows');
            
            // ÉTAPE 3: CRÉER IMPORTEXECUTION__C
            ImportExecution__c execution = new ImportExecution__c(
                Project__c = schedule.Project__c,
                Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS,
                Type__c = Constants.EXECUTION_TYPE_IMPORT,
                Phase__c = Constants.EXECUTION_PHASE_STAGING,
                StartTime__c = System.now(),
                TotalRecords__c = importData.size(),
                ProcessedRecords__c = 0,
                FailedRecords__c = 0,
                RetryCount__c = 0,
                MaxRetries__c = 3
            );
            
            insert execution;
            System.debug(LOG_PREFIX + ' Execution created: ' + execution.Id);
            
            // ÉTAPE 4: CRÉER STAGINGROW__C
            createStagingRows(execution.Id, importData);
            
            System.debug(LOG_PREFIX + ' StagingRows created');
            
            // ÉTAPE 5: LANCER PREPROCESS BATCH
            Boolean dryRun = false;  // Scheduled imports are always live
            Id jobId = Database.executeBatch(
                new PreProcessBatch(execution.Id, dryRun),
                Constants.PREPROCESS_BATCH_SIZE
            );
            
            execution.ApexJobId__c = String.valueOf(jobId);
            update execution;
            
            System.debug(LOG_PREFIX + ' PreProcessBatch launched: ' + jobId);
            
            // ÉTAPE 6: RECALCULER NEXTRUN
            recalculateNextRun(schedule);
            
            System.debug(LOG_PREFIX + ' NextRun recalculated: ' + schedule.NextRun__c);
            
            // ÉTAPE 7: METTRE À JOUR SCHEDULE
            update schedule;
            
            // PUBLIER ÉVÉNEMENT
            PublisherService.publishExecutionStarted(String.valueOf(execution.Id));
            
            System.debug(LOG_PREFIX + ' SUCCESS - Execution started: ' + execution.Id);
            
            return ScheduleJobResult.ok('Scheduled import started')
                .withExecutionId(execution.Id)
                .withPhase('Staging');
            
        } catch (Exception e) {
            System.debug(LOG_PREFIX + ' ERROR: ' + e.getMessage());
            System.debug(LOG_PREFIX + ' Stack: ' + e.getStackTraceString());
            
            return ScheduleJobResult.error('Scheduled import failed: ' + e.getMessage());
        }
    }
    
    /**
     * Récupérer les données pour un schedule programmé
     * 
     * SOURCES POSSIBLES:
     * 1. ContentDocument (CSV uploadé)
     * 2. ScheduleImportData__c (JSON stocké)
     * 3. API externe
     * 4. Query d'un autre object
     * 
     * @param schedule Schedule__c
     * @return List<Map<String, String>> (données parsées)
     */
    private static List<Map<String, String>> retrieveScheduleData(Schedule__c schedule) {
        System.debug(LOG_PREFIX + ' retrieveScheduleData START');
        
        try {
            // Option 1: Récupérer depuis ContentDocument (CSV uploadé)
            List<Map<String, String>> dataFromDocument = getDataFromContentDocument(schedule.Id);
            if (dataFromDocument != null && !dataFromDocument.isEmpty()) {
                System.debug(LOG_PREFIX + ' Data retrieved from ContentDocument');
                return dataFromDocument;
            }
            
            // Option 2: Récupérer depuis ScheduleImportData__c (JSON stocké)
            List<Map<String, String>> dataFromCustom = getDataFromCustomObject(schedule.Id);
            if (dataFromCustom != null && !dataFromCustom.isEmpty()) {
                System.debug(LOG_PREFIX + ' Data retrieved from ScheduleImportData');
                return dataFromCustom;
            }
            
            // Option 3: Query par défaut (requête prédéfinie)
            List<Map<String, String>> dataFromQuery = getDataFromQuery(schedule.Project__c);
            if (dataFromQuery != null && !dataFromQuery.isEmpty()) {
                System.debug(LOG_PREFIX + ' Data retrieved from Query');
                return dataFromQuery;
            }
            
            System.debug(LOG_PREFIX + ' WARNING: No data source found');
            return null;
            
        } catch (Exception e) {
            System.debug(LOG_PREFIX + ' ERROR retrieving data: ' + e.getMessage());
            throw new ApplicationException('Failed to retrieve scheduled import data: ' + e.getMessage());
        }
    }
    
    /**
     * Option 1: Récupérer CSV depuis ContentDocument (uploadé par l'utilisateur)
     * 
     * PROCESSUS:
     * 1. Chercher ContentDocumentLink avec LinkedEntityId = scheduleId
     * 2. Récupérer le ContentVersion (le fichier)
     * 3. Parser le CSV
     * 4. Retourner les données
     */
    private static List<Map<String, String>> getDataFromContentDocument(Id scheduleId) {
        try {
            // Chercher les documents liés au schedule
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :scheduleId
                LIMIT 1
            ];
            
            if (links.isEmpty()) {
                System.debug(LOG_PREFIX + ' No ContentDocument found for schedule');
                return null;
            }
            
            // Récupérer le fichier
            Id contentDocId = links[0].ContentDocumentId;
            List<ContentVersion> versions = [
                SELECT VersionData
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocId
                AND IsLatest = true
                LIMIT 1
            ];
            
            if (versions.isEmpty()) {
                System.debug(LOG_PREFIX + ' No ContentVersion found');
                return null;
            }
            
            // Parser le CSV
            String csvContent = versions[0].VersionData.toString();
            return parseCsvContent(csvContent);
            
        } catch (Exception e) {
            System.debug(LOG_PREFIX + ' ERROR getDataFromContentDocument: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Option 2: Récupérer JSON depuis ScheduleImportData__c
     * 
     * PROCESSUS:
     * 1. Chercher ScheduleImportData__c pour ce schedule
     * 2. Parser le JSON stocké
     * 3. Retourner les données
     */
    private static List<Map<String, String>> getDataFromCustomObject(Id scheduleId) {
        try {
            // Cette table n'existe que si vous la créez!
            // SELECT Id, Data__c FROM ScheduleImportData__c WHERE Schedule__c = :scheduleId
            
            // Pour maintenant, retourner null
            System.debug(LOG_PREFIX + ' ScheduleImportData not implemented yet');
            return null;
            
        } catch (Exception e) {
            System.debug(LOG_PREFIX + ' ERROR getDataFromCustomObject: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Option 3: Query prédéfinie (ex: tous les Accounts)
     * 
     * PROCESSUS:
     * 1. Query les records liés au project
     * 2. Convertir en format CSV Map
     * 3. Retourner les données
     */
    private static List<Map<String, String>> getDataFromQuery(Id projectId) {
        try {
            // Récupérer le projet pour connaître l'object cible
            ImportProject__c project = [
                SELECT TargetObject__c
                FROM ImportProject__c
                WHERE Id = :projectId
                LIMIT 1
            ];
            
            // Example: Si TargetObject = "Account", query les Accounts
            if (project.TargetObject__c == 'Account') {
                List<Account> accounts = [
                    SELECT Name, Type, Industry, AnnualRevenue, NumberOfEmployees, Phone
                    FROM Account
                    LIMIT 10000
                ];
                
                return convertAccountsToMapList(accounts);
            }
            
            System.debug(LOG_PREFIX + ' Unsupported target object: ' + project.TargetObject__c);
            return null;
            
        } catch (Exception e) {
            System.debug(LOG_PREFIX + ' ERROR getDataFromQuery: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Parser CSV content et retourner List<Map<String, String>>
     */
    private static List<Map<String, String>> parseCsvContent(String csvContent) {
        try {
            List<Map<String, String>> result = new List<Map<String, String>>();
            
            List<String> lines = csvContent.split('\n');
            if (lines.isEmpty()) {
                return result;
            }
            
            // Première ligne = headers
            List<String> headers = lines[0].split(',');
            
            // Autres lignes = données
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
            System.debug(LOG_PREFIX + ' ERROR parseCsvContent: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Convertir List<Account> en List<Map<String, String>>
     */
    private static List<Map<String, String>> convertAccountsToMapList(List<Account> accounts) {
        List<Map<String, String>> result = new List<Map<String, String>>();
        
        for (Account acc : accounts) {
            Map<String, String> row = new Map<String, String>{
                'Name' => acc.Name,
                'Type' => acc.Type,
                'Industry' => acc.Industry,
                'AnnualRevenue' => String.valueOf(acc.AnnualRevenue),
                'NumberOfEmployees' => String.valueOf(acc.NumberOfEmployees),
                'Phone' => acc.Phone
            };
            result.add(row);
        }
        
        return result;
    }
    
    /**
     * Créer StagingRow__c pour chaque ligne de données
     */
    private static void createStagingRows(Id executionId, List<Map<String, String>> data) {
        List<StagingRow__c> rows = new List<StagingRow__c>();
        
        for (Integer i = 0; i < data.size(); i++) {
            rows.add(new StagingRow__c(
                Execution__c = executionId,
                LineNumber__c = i + 2,  // +2 car header = ligne 1
                RawData__c = JSON.serialize(data[i]),
                Processed__c = false
            ));
        }
        
        insert rows;
    }
    
    /**
     * Recalculer la prochaine date d'exécution selon la fréquence
     */
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
            System.debug(LOG_PREFIX + ' ERROR recalculateNextRun: ' + e.getMessage());
        }
    }
}