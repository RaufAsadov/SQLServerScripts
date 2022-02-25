Running the report
The DBA Checks report is run by executing the dbo.DBAChecks stored procedure.  This stored procedure takes a number of parameters, but only one is required:

exec dbo.DBAChecks @recipients='rauf.asadov@outlook.com'

The code below shows a call to the DBAChecks stored procedure with all parameters specified:

EXEC dbo.DBAChecks 
@AgentJobsNumDays=3,
@FileStatsIncludedDatabases=NULL,
@FileStatsExcludedDatabases=NULL,
@FileStatsPctUsedWarning=90,
@FileStatsPctUsedCritical=95,
@DiffWarningThresholdDays=3,
@FullWarningThresholdDays=7,
@TranWarningThresholdHours=4,
@FreeDiskSpacePercentWarningThreshold=15,
@FreeDiskSpacePercentCriticalThreshold=10,
@DBCCCriticalDays = 1,
@UptimeCritical=1440 ,
@UptimeWarning=2880,
@ErrorLogDays=3,
@Recipients='rauf.asadov@outlook.com',
@MailProfile=NULL

A full explanation of these parameters is available here:

 @AgentJobsNumDays

The number of days SQL Server jobs are reported over.

 @FileStatsIncludedDatabases

A list of databases (comma-separated) to display file stats for.  Default value is NULL (All databases).

 @FileStatsExcludedDatabases

A list of databases (comma-separated) that are excluded from database file stats.  Default values is NULL (No excluded databases)

 @FileStatsPctUsedWarning

If the percent used space in the database file is larger than this value (but less than critical threshold) it will be highlighted in yellow.

 @FileStatsPctUsedCritical

If the percent used space in the database file is larger than this value it will be highlighted in red.

 @DiffWarningThresholdDays

Highlights differential backups that have not been completed for over "X" number of days

 @FullWarningThresholdDays

Highlights full backups that have not been completed for over "X" number of days

 @TranWarningThresholdHours

Highlights transaction log backups that have not been completed for over "X" number of hours.

 @FreeDiskSpacePercentWarningThreshold

Used to highlight disk drives with low disk space in yellow, where the free disk space percent is less than the value specified.

 @FreeDiskSpacePercentCriticalThreshold

Used to highlight disk drives with low disk space in red, where the free disk space percent is less than the value specified.

 @UptimeCritical

The uptime in minutes threshold that causes the uptime to be highlighted in red.

 @UptimeWarning

The uptime in minutes threshold that causes the uptime to be highlighted in yellow.

 @ErrorLogDays

The number of days worth of events included in the attached error log html file.

 @Recipients

The email addresses where the report will be sent.

 @MailProfile

The mail profile used to send the email.  NULL = default profile.

@DBCCCriticalDays

The number of days




Database Code

dbo.DBAChecks

This is the stored procedure you run to generate the email report. The stored procedure collates the information from the other stored procedures into a single email report.   The parameters are described in the previous section. 

dbo.DBAChecks_Backups

Produces HTML for the "Backups" section of the report.

dbo.DBAChecks_DBFiles

Produces HTML for the "Database Files" section of the report. 

dbo.DBAChecks_DiskDrives

Produces HTML for the "Disk Drives" section of the report.

dbo.DBAChecks_ErrorLog

Produces HTML for the "ErrorLog.htm" report attachment.  Review and ammend the filter applied to the error log as appropriate.

dbo.DBAChecks_FailedAgentJobs

Produces HTML for the "Failed Jobs" section of the report.

dbo.DBAChecks_JobStats

Produces HTML for the "Agent Job Stats" section of the report

dbo.DBAChecks_CHECKDB

Produces HTML for the “DBCC CHECKDB” section of the report


