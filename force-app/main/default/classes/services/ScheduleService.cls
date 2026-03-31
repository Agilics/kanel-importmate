/**
 * @description       : Service pour la gestion des planifications
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-31-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Corrections :
 *  - Opérateur === remplacé par == dans runDueSchedules() (Apex ne supporte pas ===)
 *  - FLS checks via SecurityUtils (point 5)
 *  - initCause(e) ajouté sur tous les re-throw pour préserver les stack traces
 **/
public with sharing class ScheduleService {

    public class ScheduleWrapper {
        @AuraEnabled public ImportProject__c         project;
        @AuraEnabled public List<Schedule__c>        schedules        { get; set; }
        @AuraEnabled public List<ImportExecution__c> importExecutions { get; set; }

        public ScheduleWrapper() {}
    }

    public static Id schedule(String frequence, Datetime nextRun, String projectId) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        SecurityUtils.checkAccessible(ImportProject__c.SObjectType);
        SecurityUtils.checkCreateable(Schedule__c.SObjectType);

        try {
            Schedule__c sch = new Schedule__c(
                Frequency__c = frequence,
                Project__c   = projectId,
                NextRun__c   = nextRun
            );
            ScheduleRepository.addSchedule(sch);

            if (sch.Id == null) {
                throw new ApplicationException('Failed to create schedule record');
            }

            String cron    = buildCron(sch.NextRun__c);
            String jobName = 'Schedule_' + sch.Id + '_' + Datetime.now().getTime();
            System.schedule(jobName, cron, new ScheduleJob());
            return sch.Id;

        } catch (DmlException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    public static void deleteScheduleById(String scheduleId) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        SecurityUtils.checkDeletable(Schedule__c.SObjectType);
        try {
            ScheduleRepository.deleteScheduleById(scheduleId);
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    public static List<Schedule__c> getPastSchedules() {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        try {
            return ScheduleRepository.getPastSchedules();
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    public static List<ScheduleWrapper> getSchedulesWithExecutionsByIdProject(Id idProject) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        try {
            return ScheduleRepository.getSchedulesWithExecutionsByIdProject(idProject);
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    public static List<ScheduleWrapper> getSchedulesByExecutionStatusAndIdProject(
        String status,
        String idProject
    ) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        try {
            return ScheduleRepository.getSchedulesByExecutionStatusAndIdProject(status, idProject);
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    public static List<Schedule__c> getSchedulesByFrequencyAndProjectId(
        ImportMateEnum.FrequencyEnum frequence,
        String idProject
    ) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        try {
            return ScheduleRepository.getSchedulesByFrequencyAndProjectId(frequence, idProject);
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    public static Schedule__c getScheduleById(Id id) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        try {
            return ScheduleRepository.getScheduleById(id);
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    public static List<ScheduleWrapper> getSchedulesByProjectName(String name) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        try {
            if (String.isBlank(name)) return new List<ScheduleWrapper>();
            return ScheduleRepository.getSchedulesByProjectName(name);
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    public static void runDueSchedules() {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        SecurityUtils.checkUpdateable(Schedule__c.SObjectType);

        List<Schedule__c> schedules = ScheduleRepository.getPastSchedules();
        for (Schedule__c sch : schedules) {
            try {
                ImportMateEnum.FrequencyEnum freq =
                    ImportMateEnum.FrequencyEnum.valueOf(sch.Frequency__c);

                if (freq == ImportMateEnum.FrequencyEnum.DAILY) {
                    sch.NextRun__c = sch.NextRun__c.addDays(1);
                } else if (freq == ImportMateEnum.FrequencyEnum.WEEKLY) {
                    sch.NextRun__c = sch.NextRun__c.addDays(7);
                } else if (freq == ImportMateEnum.FrequencyEnum.MONTHLY) {
                    sch.NextRun__c = sch.NextRun__c.addMonths(1);
                }
            } catch (Exception e) {
                ErrorLogService.logException(e);
                // ── CORRECTION : initCause préserve la stack trace d'origine ──
                ApplicationException ae = new ApplicationException(
                    'Erreur planification : ' + e.getMessage()
                );
                ae.initCause(e);
                throw ae;
            }
        }
        update schedules;
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
}