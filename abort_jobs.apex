// Abort the blocking CronTrigger scheduled job
try {
    System.abortJob('08eg50000092T2j');
    System.debug('CronTrigger 08eg50000092T2j aborted successfully.');
} catch (Exception e) {
    System.debug('CronTrigger abort error: ' + e.getMessage());
}

// Also abort the AsyncApexJob if still running
try {
    System.abortJob('707g500000M9abN');
    System.debug('AsyncApexJob 707g500000M9abN aborted successfully.');
} catch (Exception e) {
    System.debug('AsyncApexJob abort error: ' + e.getMessage());
}

// Verify: list any remaining scheduled jobs blocking deployment
List<CronTrigger> remainingJobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger
    WHERE State IN ('WAITING', 'ACQUIRED', 'EXECUTING')
    LIMIT 10
];
System.debug('Remaining active CronTriggers: ' + remainingJobs.size());
for (CronTrigger ct : remainingJobs) {
    System.debug('  -> ' + ct.Id + ' | ' + ct.CronJobDetail.Name + ' | ' + ct.State);
}
