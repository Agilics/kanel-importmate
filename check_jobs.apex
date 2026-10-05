// Find the CronTrigger for the AsyncApexJob 707g500000M9abN
List<AsyncApexJob> asyncJobs = [
    SELECT Id, ApexClass.Name, Status, CronTriggerId
    FROM AsyncApexJob
    WHERE Id = '707g500000M9abN'
    LIMIT 1
];
if (!asyncJobs.isEmpty()) {
    AsyncApexJob j = asyncJobs[0];
    System.debug('AsyncApexJob: ' + j.ApexClass.Name + ' | Status: ' + j.Status + ' | CronTriggerId: ' + j.CronTriggerId);
    if (j.CronTriggerId != null) {
        try {
            System.abortJob(j.CronTriggerId);
            System.debug('Parent CronTrigger ' + j.CronTriggerId + ' aborted.');
        } catch (Exception e) {
            System.debug('Abort error: ' + e.getMessage());
        }
    }
} else {
    System.debug('AsyncApexJob 707g500000M9abN not found (may have already completed).');
}

// List remaining active CronTriggers
List<CronTrigger> remaining = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger
    WHERE State IN ('WAITING', 'ACQUIRED', 'EXECUTING')
    LIMIT 20
];
System.debug('Remaining CronTriggers: ' + remaining.size());
for (CronTrigger ct : remaining) {
    System.debug('  ' + ct.Id + ' | ' + ct.CronJobDetail.Name + ' | ' + ct.State + ' | ' + ct.NextFireTime);
}
