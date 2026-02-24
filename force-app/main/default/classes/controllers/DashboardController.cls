public with sharing class DashboardController {
    
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(Integer limitor) {
        try {
            DashboardData data = new DashboardData();
            
            //projects with stats
            data.projects = ProjectService.getProjectsWithStats(limitor);
            
            //dashboard stats
            data.stats = ProjectService.calculateDashboardStats();
            
            return data;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading dashboard data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static DashboardData getDashboardDataLive(Integer limitor) {
        try {
            DashboardData data = new DashboardData();
            data.projects = ProjectService.getProjectsWithStats(limitor);
            data.stats = ProjectService.calculateDashboardStats();
            return data;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading dashboard data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<ImportExecution__c> getExecutionHistoryLive(Integer limitor) {
        try {
            Integer safeLimit = limitor == null || limitor <= 0 ? 2000 : limitor;
            if (safeLimit > 10000) {
                safeLimit = 10000;
            }

            return [
                SELECT Id, Name, Status__c, Type__c, Phase__c, StartTime__c, EndTime__c,
                       TotalRecords__c, ProcessedRecords__c, FailedRecords__c, CreatedDate,
                       Project__c, Project__r.Name, Project__r.TargetObject__c
                FROM ImportExecution__c
                ORDER BY CreatedDate DESC
                LIMIT :safeLimit
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error loading execution history: ' + e.getMessage());
        }
    }
    

    @AuraEnabled(cacheable=true)
    public static List<ImportProject__c> getProjectsWithStats(Integer limitor) {
        try {
            return ProjectService.getProjectsWithStats(limitor);
        } catch (Exception e) {
            throw new AuraHandledException('Error loading projects: ' + e.getMessage());
        }
    }
    

    @AuraEnabled
    public static void deleteProject(String projectId) {
        try {
            ProjectService.deleteProject(projectId);
        } catch (ApplicationException e) {
            throw new AuraHandledException('Error deleting project: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> deleteExecutionHistory(Id executionId) {
        try {
            if (executionId == null) {
                throw new AuraHandledException('Execution ID is required.');
            }

            if (!SecurityUtils.isAccessible(ImportExecution__c.SObjectType) ||
                !SecurityUtils.isDeletable(ImportExecution__c.SObjectType)) {
                throw new AuraHandledException('You do not have permission to delete executions.');
            }

            ImportExecution__c execution = [
                SELECT Id, Status__c
                FROM ImportExecution__c
                WHERE Id = :executionId
                LIMIT 1
            ];

            if (execution.Status__c == Constants.EXECUTION_STATUS_IN_PROGRESS ||
                execution.Status__c == Constants.EXECUTION_STATUS_PENDING) {
                throw new AuraHandledException('Cannot delete an execution that is running.');
            }

            if (!SecurityUtils.isAccessible(StagingRow__c.SObjectType) ||
                !SecurityUtils.isDeletable(StagingRow__c.SObjectType)) {
                Integer orphanRows = [
                    SELECT COUNT()
                    FROM StagingRow__c
                    WHERE Execution__c = :executionId
                ];
                if (orphanRows > 0) {
                    throw new AuraHandledException('Cannot delete execution because staging rows still exist.');
                }
            } else {
                Integer stagingRowCount = [
                    SELECT COUNT()
                    FROM StagingRow__c
                    WHERE Execution__c = :executionId
                ];
                if (stagingRowCount > 10000) {
                    throw new AuraHandledException(
                        'Cannot delete execution because too many staging rows remain (' + stagingRowCount + ').'
                    );
                }

                if (stagingRowCount > 0) {
                    List<StagingRow__c> stagingRows = [
                        SELECT Id
                        FROM StagingRow__c
                        WHERE Execution__c = :executionId
                    ];
                    delete stagingRows;
                }
            }

            delete execution;

            return new Map<String, Object>{
                'success' => true
            };
        } catch (AuraHandledException e) {
            throw e;
        } catch (QueryException e) {
            throw new AuraHandledException('Execution not found.');
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting execution: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> deleteExecutionHistories(List<Id> executionIds) {
        try {
            if (executionIds == null || executionIds.isEmpty()) {
                throw new AuraHandledException('Execution IDs are required.');
            }

            if (!SecurityUtils.isAccessible(ImportExecution__c.SObjectType) ||
                !SecurityUtils.isDeletable(ImportExecution__c.SObjectType)) {
                throw new AuraHandledException('You do not have permission to delete executions.');
            }

            Set<Id> requestedIds = new Set<Id>(executionIds);
            Map<Id, ImportExecution__c> executionById = new Map<Id, ImportExecution__c>([
                SELECT Id, Status__c
                FROM ImportExecution__c
                WHERE Id IN :requestedIds
            ]);

            Integer skippedNotFoundCount = requestedIds.size() - executionById.size();
            Integer skippedRunningCount = 0;
            Integer skippedStagingCount = 0;
            Integer failedCount = 0;
            Integer deletedCount = 0;
            List<String> errors = new List<String>();

            Set<Id> canDeleteExecutionIds = new Set<Id>();
            for (ImportExecution__c execution : executionById.values()) {
                if (execution.Status__c == Constants.EXECUTION_STATUS_IN_PROGRESS ||
                    execution.Status__c == Constants.EXECUTION_STATUS_PENDING) {
                    skippedRunningCount++;
                } else {
                    canDeleteExecutionIds.add(execution.Id);
                }
            }

            if (!canDeleteExecutionIds.isEmpty()) {
                Boolean canDeleteStaging = SecurityUtils.isAccessible(StagingRow__c.SObjectType) &&
                    SecurityUtils.isDeletable(StagingRow__c.SObjectType);

                Map<Id, Integer> stagingCountByExecutionId = new Map<Id, Integer>();
                for (AggregateResult ar : [
                    SELECT Execution__c executionId, COUNT(Id) rowCount
                    FROM StagingRow__c
                    WHERE Execution__c IN :canDeleteExecutionIds
                    GROUP BY Execution__c
                ]) {
                    Id executionId = (Id) ar.get('executionId');
                    Integer rowCount = Integer.valueOf(String.valueOf(ar.get('rowCount')));
                    stagingCountByExecutionId.put(executionId, rowCount);
                }

                Set<Id> stagingDeleteExecutionIds = new Set<Id>();
                Set<Id> safeExecutionIds = new Set<Id>();

                for (Id executionId : canDeleteExecutionIds) {
                    Integer stagingCount = stagingCountByExecutionId.containsKey(executionId)
                        ? stagingCountByExecutionId.get(executionId)
                        : 0;

                    if (stagingCount == 0) {
                        safeExecutionIds.add(executionId);
                        continue;
                    }

                    if (!canDeleteStaging) {
                        skippedStagingCount++;
                        errors.add('Cannot delete staging rows for execution ' + executionId + '.');
                        continue;
                    }

                    if (stagingCount > 10000) {
                        skippedStagingCount++;
                        errors.add(
                            'Too many staging rows for execution ' + executionId + ' (' + stagingCount + ').'
                        );
                        continue;
                    }

                    stagingDeleteExecutionIds.add(executionId);
                    safeExecutionIds.add(executionId);
                }

                if (!stagingDeleteExecutionIds.isEmpty()) {
                    List<StagingRow__c> stagingRows = [
                        SELECT Id
                        FROM StagingRow__c
                        WHERE Execution__c IN :stagingDeleteExecutionIds
                    ];
                    if (!stagingRows.isEmpty()) {
                        delete stagingRows;
                    }
                }

                if (!safeExecutionIds.isEmpty()) {
                    List<ImportExecution__c> executionsToDelete = new List<ImportExecution__c>();
                    for (Id executionId : safeExecutionIds) {
                        executionsToDelete.add(new ImportExecution__c(Id = executionId));
                    }

                    Database.DeleteResult[] deleteResults = Database.delete(executionsToDelete, false);
                    for (Integer i = 0; i < deleteResults.size(); i++) {
                        if (deleteResults[i].isSuccess()) {
                            deletedCount++;
                        } else {
                            failedCount++;
                            if (!deleteResults[i].getErrors().isEmpty()) {
                                errors.add(deleteResults[i].getErrors()[0].getMessage());
                            }
                        }
                    }
                }
            }

            return new Map<String, Object>{
                'success' => true,
                'requestedCount' => requestedIds.size(),
                'deletedCount' => deletedCount,
                'skippedRunningCount' => skippedRunningCount,
                'skippedNotFoundCount' => skippedNotFoundCount,
                'skippedStagingCount' => skippedStagingCount,
                'failedCount' => failedCount,
                'errors' => errors
            };
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting execution histories: ' + e.getMessage());
        }
    }

    public class DashboardData {
        @AuraEnabled public List<ImportProject__c> projects;
        @AuraEnabled public DashboardStats stats;
        
        public DashboardData() {
            this.projects = new List<ImportProject__c>();
            this.stats = new DashboardStats();
        }
    }
}
