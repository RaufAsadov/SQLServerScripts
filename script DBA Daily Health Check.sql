CREATE PROC [dbo].[DBAChecks](
	/* Agent Jobs related Params */
	@AgentJobsNumDays int=3, --Num of days to report failed jobs over
	/* Database Files related Params */
	@FileStatsIncludedDatabases varchar(max)=NULL, -- Comma sep list of databases to report filestats for. NULL=All, '' = None
	@FileStatsExcludedDatabases varchar(max)=NULL, -- Comma sep list of databases to report filestats for. NULL=No Exclusions
	@FileStatsPctUsedWarning int=90, -- Warn (Yellow) if free space in a database file is less than this threshold (Just for database specified in @FileStatsDatabases)
	@FileStatsPctUsedCritical int=95, -- Warn (Red) if free space in a database file is less than this threshold (Just for database specified in @FileStatsDatabases)
	/* Backup related Params */
	@DiffWarningThresholdDays int=3, -- Backup warning if no diff backup for "x" days
	@FullWarningThresholdDays int=1, -- Backup warning if no full backup for "x" days
	@TranWarningThresholdHours int=3, -- Backup warning if no tran backup for "x" hours
	/* Disc Drive related params*/
	@FreeDiskSpacePercentWarningThreshold int=30, -- Warn (Yellow) if free space is less than this threshold
	@FreeDiskSpacePercentCriticalThreshold int=20, -- Warn (Red) if free space is less than this threshold
	/*DBCC CHECKDB*/
	@DBCCCriticalDays int=7,
	/* General related params */
	@UptimeCritical int = 1440, -- Critical/Red if system uptime (in minutes) is less than this value
	@UptimeWarning int = 2880, -- Warn/Yellow if system uptime (in minutes) is less than this value,
	/* Error Log Params */
	@ErrorLogDays int = 1,
	/* Email/Profile params */
	@Recipients nvarchar(max), -- Email list
	@MailProfile sysname=null --take default email
)
AS
/*
	Generates a DBA Checks HTML email report
*/
SET NOCOUNT ON
DECLARE @AgentJobsHTML varchar(max)
DECLARE @AgentJobStatsHTML varchar(max)
DECLARE @FileStatsHTML varchar(max)
DECLARE @DisksHTML varchar(max)
DECLARE @DBCCInfo varchar(max)
DECLARE @BackupsHTML varchar(max)
DECLARE @HTML varchar(max)
DECLARE @Uptime varchar(max)
SELECT @Uptime = 
	CASE WHEN DATEDIFF(mi,create_date,GetDate()) < @UptimeCritical THEN '<span class="Critical">'
	WHEN DATEDIFF(mi,create_date,GetDate()) < @Uptimewarning THEN '<span class="Warning">'
	ELSE '<span class="Healthy">' END + 
	-- get system uptime
	COALESCE(NULLIF(CAST((DATEDIFF(mi,create_date,GetDate())/1440 ) as varchar),'0') + ' day(s), ','')
	+ COALESCE(NULLIF(CAST(((DATEDIFF(mi,create_date,GetDate())%1440)/60) as varchar),'0') + ' hour(s), ','')
	+ CAST((DATEDIFF(mi,create_date,GetDate())%60) as varchar) + 'min'
	--
	+ '</span>'
FROM sys.databases 
WHERE NAME='tempdb'
exec dbo.DBAChecks_FailedAgentJobs @HTML=@AgentJobsHTML out,@NumDays=@AgentJobsNumDays
exec dbo.DBAChecks_CHECKDB @HTML = @DBCCInfo OUT, @NumDays=@DBCCCriticalDays, @IncludeDBs = @FileStatsIncludedDatabases , @ExcludeDBs = @FileStatsExcludedDatabases
exec dbo.DBAChecks_JobStats @HTML=@AgentJobStatsHTML out,@NumDays=@AgentJobsNumDays
exec dbo.DBAChecks_DBFiles 
	@IncludeDBs=@FileStatsIncludedDatabases,
	@ExcludeDBs=@FileStatsExcludedDatabases,
	@WarningThresholdPCT=@FileStatsPctUsedWarning,
	@CriticalThresholdPCT=@FileStatsPctUsedCritical,
	@HTML=@FileStatsHTML out
exec dbo.DBAChecks_DiskDrives @HTML=@DisksHTML out,@PCTFreeWarningThreshold=@FreeDiskSpacePercentWarningThreshold,@PCTFreeCriticalThreshold=@FreeDiskSpacePercentCriticalThreshold 
exec dbo.DBAChecks_Backups @HTML=@BackupsHTML OUT,@FullWarningThresholdDays=@FullWarningThresholdDays,@DiffWarningThresholdDays = @DiffWarningThresholdDays,@TranWarningThresholdHours = @TranWarningThresholdHours,@IncludeDBs = @FileStatsIncludedDatabases , @ExcludeDBs = @FileStatsExcludedDatabases
SET @HTML = 
'<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
<style type="text/css">
table {
font:8pt tahoma,arial,sans-serif;
}
th {
color:#FFFFFF;
font:bold 8pt tahoma,arial,sans-serif;
background-color:#204c7d;
padding-left:5px;
padding-right:5px;
}
td {
color:#000000;
font:8pt tahoma,arial,sans-serif;
border:1px solid #DCDCDC;
border-collapse:collapse;
padding-left:3px;
padding-right:3px;
}
.Warning {
background-color:#FFFF00; 
color:#2E2E2E;
}
.Critical {
background-color:#FF0000;
color:#FFFFFF;
}
.Healthy {
background-color:#458B00;
color:#FFFFFF;
}
h1 {
color:#FFFFFF;
font:bold 16pt arial,sans-serif;
background-color:#204c7d;
text-align:center;
}
h2 {
color:#204c7d;
font:bold 14pt arial,sans-serif;
}
h3 {
color:#204c7d;
font:bold 12pt arial,sans-serif;
}
body {
color:#000000;
font:8pt tahoma,arial,sans-serif;
margin:0px;
padding:0px;
}
</style>
</head>
<body>
<h1>DBA Checks Report for ' + @@SERVERNAME + '</h1>
<h2>General Health</h2>
<b>System Uptime (SQL Server): ' + @Uptime + '</b><br/>
<b>Version: </b>' + CAST(SERVERPROPERTY('productversion') as nvarchar(max)) + ' ' 
	+ CAST(SERVERPROPERTY ('productlevel') as nvarchar(max))
    + ' ' + CAST(SERVERPROPERTY ('edition') as nvarchar(max)) 
+ COALESCE(@DisksHTML,'<div class="Critical">Error collecting Disk Info</div>')
+ COALESCE(@DBCCInfo, '<div class="Critical">Error collecting DBCC Info</div>')
+ COALESCE(@BackupsHTML,'<div class="Critical">Error collecting Backup Info</div>')
+ COALESCE(@AgentJobStatsHTML,'<div class="Critical">Error collecting Agent Jobs Stats</div>')
+ COALESCE(@AgentJobsHTML,'<div class="Critical">Error collecting Agent Jobs Info</div>')
+ COALESCE(@FileStatsHTML,'<div class="Critical">Error collecting File Stats Info</div>')
+ '</body></html>'
declare @subject varchar(50)
set @subject = 'DBA Checks (' + @@SERVERNAME + ')'
DECLARE @ErrorLogSQL nvarchar(max)
DECLARE @ExecuteQueryDB sysname
SET @ErrorLogSQL = 'exec DBAChecks_ErrorLog @NumDays=' + CAST(@ErrorLogDays as varchar)
SET @ExecuteQueryDB = DB_NAME()
EXEC msdb.dbo.sp_send_dbmail
	@query=@ErrorLogSQL,
	@attach_query_result_as_file = 1,
	@query_attachment_filename = 'ErrorLog.htm',
	@query_result_header = 1,
	@query_no_truncate = 1,
	@query_result_width=32767,
	@recipients =@Recipients,
	@body = @HTML,
	@body_format ='HTML',
	@subject = @subject,
	@execute_query_database=@ExecuteQueryDB,
	@profile_name = @MailProfile
GO
CREATE PROC [dbo].[DBAChecks_DiskDrives](@PCTFreeWarningThreshold int,@PCTFreeCriticalThreshold int,@HTML varchar(max) out)
AS
/* 
	Returns HTML for "Disk Drives" section of DBA Checks Report
*/ 

CREATE TABLE #TEMP (
     [DriveLetter] VARCHAR(3)
    ,[LogicalName] VARCHAR(20)
    ,[TotalDriveSpace] DECIMAL(18,2)
    ,[FreeSpaceOnDrive] DECIMAL(18,2)
    ,[%FreeSpace] DECIMAL(18,2)
    )

INSERT INTO #TEMP
SELECT DISTINCT 
    volume_mount_point, 
    CASE logical_volume_name WHEN '' then 'Logical Disk' ELSE logical_volume_name END,
    total_bytes/1073741824.0,
    available_bytes/1073741824.0,
    CAST(available_bytes AS FLOAT)/ CAST(total_bytes AS FLOAT)*100 
FROM sys.master_files 
CROSS APPLY sys.dm_os_volume_stats(database_id, file_id)
 

SELECT @HTML = 
	'<h2>Disk Drives</h2>
	<table>' +
	(SELECT 'Drive' th,
			'Name' th,
			'SizeGB' th,
			'FreeGB' th,
			'Free %' th
	FOR XML RAW('tr'),ELEMENTS) 
	+
	(SELECT [DriveLetter] td,
			[LogicalName] td,
			[TotalDriveSpace] td,
			[FreeSpaceOnDrive] td,
			CAST(CASE WHEN [%FreeSpace] < @PCTFreeCriticalThreshold THEN '<div class="Critical">' + CAST([%FreeSpace] as varchar) + '</div>'
			WHEN [%FreeSpace] < @PCTFreeWarningThreshold THEN '<div class="Warning">' + CAST([%FreeSpace] as varchar) + '</div>'
			ELSE '<div class="Healthy">' + CAST([%FreeSpace] as varchar) + '</div>' END as XML) td
	FROM #TEMP 
	FOR XML RAW('tr'),ELEMENTS XSINIL)
	+ '</table>'
DROP TABLE #TEMP
GO
CREATE PROCEDURE [dbo].[DBAChecks_CHECKDB] (@NumDays int, @IncludeDBs varchar(max), @ExcludeDBs varchar(max),@HTML nvarchar(max) output)
AS
/* 
	Returns HTML for "recent date of dbcc checkdb" section of DBA Checks Report
*/ 
SET NOCOUNT ON
DECLARE
	@DBName SYSNAME,
	@SQL    nvarchar(512),
	@IncludeXML XML,
    @ExcludeXML XML;
IF @IncludeDBs = ''
BEGIN
	SET @HTML = ''
	RETURN
END
CREATE TABLE #temp (
       Id INT IDENTITY(1,1), 
       ParentObject VARCHAR(255),
       [Object] VARCHAR(255),
       Field VARCHAR(255),
       [Value] VARCHAR(255)
)
CREATE TABLE #DBCCRes (
       Id INT IDENTITY(1,1)PRIMARY KEY CLUSTERED, 
       DBName sysname ,
       dbccLastKnownGood VARCHAR(255),
       RowNum	INT
)
SELECT @IncludeXML = '<a>' + REPLACE(@IncludeDBs,',','</a><a>') + '</a>'
SELECT @ExcludeXML = '<a>' + REPLACE(@ExcludeDBs,',','</a><a>') + '</a>'
DECLARE dbccpage CURSOR
	LOCAL STATIC FORWARD_ONLY READ_ONLY
	FOR SELECT name FROM sys.databases
			WHERE (name IN(SELECT n.value('.','sysname')
						FROM @IncludeXML.nodes('/a') T(n))
						OR @IncludeXML IS NULL)
				AND (name NOT IN(SELECT n.value('.','sysname')
						FROM @ExcludeXML.nodes('/a') T(n))
						OR @ExcludeXML IS NULL)
			AND source_database_id IS NULL
			AND state = 0 --ONLINE
			AND name <> 'tempdb'
			ORDER BY name
Open dbccpage;
Fetch Next From dbccpage into @DBName;
While @@Fetch_Status = 0
Begin
Set @SQL = 'Use [' + @DBName +'];' +char(10)+char(13)
Set @SQL = @SQL + 'DBCC Page ( ['+ @DBName +'],1,9,3) WITH TABLERESULTS, NO_INFOMSGS;' +char(10)+char(13)
INSERT INTO #temp
	exec sp_executesql @SQL
Set @SQL = ''
INSERT INTO #DBCCRes
        ( DBName, dbccLastKnownGood,RowNum )
	SELECT @DBName, VALUE
			, ROW_NUMBER() OVER (PARTITION BY Field ORDER BY Value) AS Rownum
		FROM #temp
		WHERE field = 'dbi_dbccLastKnownGood';
TRUNCATE TABLE #temp;
Fetch Next From dbccpage into @DBName;
End
Close dbccpage;
Deallocate dbccpage;
SET @HTML = '<h2>Recent DBCC CHECKDB Date</h2>
			<table>
			<tr>
			<th>DB Name</th>
			<th>Recent Date</th>
			</tr>' 
			+(SELECT 
					DBName td,
					CAST(CASE WHEN dbccLastKnownGood >= CONVERT(VARCHAR, DATEADD(DAY, -@NumDays, (getdate())), 121) THEN '<div class="Healthy">' + dbccLastKnownGood + '</div>'
					          ELSE '<div class="Critical">' + dbccLastKnownGood + '</div>' END as XML) td
			FROM #DBCCRes
			WHERE RowNum = 1
			order by dbccLastKnownGood asc
			FOR XML RAW('tr'),ELEMENTS XSINIL
			)
			+ '</table>'
DROP TABLE #temp
DROP TABLE #DBCCRes
GO
CREATE PROC [dbo].[DBAChecks_Backups](
	@HTML varchar(max) OUT,
	@FullWarningThresholdDays int,
	@DiffWarningThresholdDays int,
	@TranWarningThresHoldHours int,
	@IncludeDBs varchar(max),
	@ExcludeDBs varchar(max)
)
AS
SET NOCOUNT ON
/* 
	Returns HTML for "Backups" section of DBA Checks Report
*/ 
declare @Server varchar(40),
		@IncludeXML XML,
		@ExcludeXML XML
IF @IncludeDBs = ''
BEGIN
	SET @HTML = ''
	RETURN
END
CREATE TABLE #backuplog (
	DBName sysname,
	DBState varchar(15),
	DBRecoveryModel varchar(6),
	LastFullBackup datetime,
	FullDays int,
	FullBackupSize numeric(20,0),
	LastDiffBackup datetime,
        DiffDays int,
	DiffBackupSize numeric(20,0),
	LastTranBackup datetime,
	TranMinutes int,
	TranBackupSize numeric(10,0)
)
SELECT @IncludeXML = '<a>' + REPLACE(@IncludeDBs,',','</a><a>') + '</a>'
SELECT @ExcludeXML = '<a>' + REPLACE(@ExcludeDBs,',','</a><a>') + '</a>'
;WITH MostRecentBackups
   AS(
      SELECT 
         database_name AS [Database],
         MAX(bus.backup_finish_date) AS LastBackupTime,
         CASE bus.type
            WHEN 'D' THEN 'Full'
            WHEN 'I' THEN 'Differential'
            WHEN 'L' THEN 'Transaction Log'
         END AS Type
      FROM msdb.dbo.backupset bus
      WHERE bus.type <> 'F' AND bus.is_copy_only = 0  -- show only backups taken by dba
      GROUP BY bus.database_name,bus.type
   ),
   BackupsWithSize
   AS(
      SELECT mrb.*, (SELECT TOP 1 CASE bms.is_compressed WHEN 1 THEN ceiling(b.compressed_backup_size /1048576) ELSE ceiling(b.backup_size /1048576) END AS backup_size FROM msdb.dbo.backupset b LEFT OUTER JOIN msdb.dbo.backupmediaset bms ON b.media_set_id = bms.media_set_id WHERE [Database] = b.database_name AND LastBackupTime = b.backup_finish_date) AS [Backup Size]
      FROM MostRecentBackups mrb
   )
   INSERT INTO #backuplog
   SELECT 
      d.name AS [Database],
      d.state_desc AS State,
      d.recovery_model_desc AS [Recovery Model],
      bf.LastBackupTime AS [Last Full],
      DATEDIFF(DAY,bf.LastBackupTime,GETDATE()) AS [Time Since Last Full (in Days)],
      bf.[Backup Size] AS [Full Backup Size in MB],
      bd.LastBackupTime AS [Last Differential],
      DATEDIFF(DAY,bd.LastBackupTime,GETDATE()) AS [Time Since Last Differential (in Days)],
      bd.[Backup Size] AS [Differential Backup Size in MB],
      bt.LastBackupTime AS [Last Transaction Log],
      DATEDIFF(MINUTE,bt.LastBackupTime,GETDATE()) AS [Time Since Last Transaction Log (in Minutes)],
      bt.[Backup Size] AS [Transaction Log Backup Size in MB]
   FROM sys.databases d
   LEFT JOIN BackupsWithSize bf ON (d.name = bf.[Database] AND (bf.Type = 'Full' OR bf.Type IS NULL))
   LEFT JOIN BackupsWithSize bd ON (d.name = bd.[Database] AND (bd.Type = 'Differential' OR bd.Type IS NULL))
   LEFT JOIN BackupsWithSize bt ON (d.name = bt.[Database] AND (bt.Type = 'Transaction Log' OR bt.Type IS NULL))
     WHERE (d.name IN(SELECT n.value('.','sysname')
						FROM @IncludeXML.nodes('/a') T(n))
						OR @IncludeXML IS NULL)
				AND (d.name NOT IN(SELECT n.value('.','sysname')
						FROM @ExcludeXML.nodes('/a') T(n))
						OR @ExcludeXML IS NULL)
			AND source_database_id IS NULL
			AND d.name <> 'tempdb'
			--AND state = 0 --ONLINE  -- eger emailde state_desc getiriremse onda state=0 yazmaga ehtiyyac yoxdur cunki zaten butun row-larda ONLINE gorsedilecek. Bunu aktiv etmediyimiz halda hem online hemde offline gorsedecek.
SET @HTML = '<h2>Backups</h2>
			<table>
			<tr>
			<th>DB Name</th>
			<th>DB State</th>
			<th>Recovery Model</th>
			<th>Last Full Backup</th>
			<th>Time Since Last Full (In Days)</th>
			<th>Last Full Size In MB</th>
			<th>Last Diff Backup</th>
			<th>Time Since Last Diff (In Days)</th>
			<th>Last Diff Size In MB</th>
			<th>Last Tran Backup</th>
			<th>Time Since Last Tran (In Minutes)</th>
			<th>Last Tran Size In MB</th>
			</tr>' 
			+(SELECT 
					DBName td,
					DBState td,
					DBRecoveryModel td,
					CAST(CASE WHEN FullDays IS NULL THEN '<div class="Critical">None/Unknown</div>'
						WHEN FullDays >= @FullWarningThresholdDays THEN '<div class="Warning">' + CONVERT(varchar,LastFullBackup,121) + '</div>' --added 'equal' sign. Because when you take a full backup in 14.01.2020 05:00 and then you do not take backup in 15.01.2020 05:00, then in 15.01.2020 08:00 you will receive an email (FullDays at this moment calculated like getdate[15.01.2020 08:00] - lastbackuptime[14.01.2020 05:00] = 1 day) and when we replace FullDays with 1 and threshold also with 1 then it turns out that 1 is not bigger than one. That is why I added the 'equal' sign
						ELSE '<div class="Healthy">' + CONVERT(varchar,LastFullBackup,121) + '</div>' END as XML) td,
					FullDays td,
					FullBackupSize td,
					CAST(CASE WHEN DiffDays IS NULL THEN '<div class="Critical">None/Unknown</div>'
						WHEN DiffDays > @DiffWarningThresholdDays THEN '<div class="Warning">' + CONVERT(varchar,LastDiffBackup,121) + '</div>'
						ELSE  '<div class="Healthy">' + CONVERT(varchar,LastDiffBackup,121) + '</div>' END as XML) td,
					--CASE WHEN DiffDays IS NULL THEN 'N/A'								--rengi yigisdirmaq isteyirsense
					--	 ELSE CONVERT(varchar,LastDiffBackup,121) END td,
					DiffDays td,
					DiffBackupSize td,
					CAST(CASE WHEN TranMinutes IS NULL THEN  COALESCE(LEFT(NULLIF(DBRecoveryModel,'SIMPLE'),0) + '<div class="Critical">None/Unknown</div>','N/A')
						WHEN TranMinutes > @TranWarningThresholdHours THEN '<div class="Warning">' + CONVERT(varchar,LastTranBackup,121) + '</div>'
						ELSE  '<div class="Healthy">' + CONVERT(varchar,LastTranBackup,121) + '</div>' END as XML) td,
					--CASE WHEN TranMinutes IS NULL THEN  COALESCE(LEFT(NULLIF(DBRecoveryModel,'SIMPLE'),0) ,'N/A')    --rengi yigisdirmaq isteyirsense
					--	 ELSE CONVERT(varchar,LastTranBackup,121) END td, 
					TranMinutes td,
					TranBackupSize td
			FROM #backuplog bl
			ORDER BY LastFullBackup,LastDiffBackup,LastTranBackup,DBName
			FOR XML RAW('tr'),ELEMENTS XSINIL
			)
			+ '</table>'
drop table #backuplog
CREATE PROC [dbo].[DBAChecks_JobStats](@NumDays int,@HTML varchar(max) out)
AS
/* 
	Returns HTML for "Agent Jobs Stats in the last 'X' days" section of DBA Checks Report
*/ 
SET ANSI_WARNINGS OFF
DECLARE @FromDate char(8)
SET @FromDate = CONVERT(char(8), (select dateadd (day,(-1*@NumDays), getdate())), 112);

WITH nextRun as (
	SELECT js.job_id, js.session_id,
	js.next_scheduled_run_date as next_run_time
	FROM msdb..sysjobactivity js
	where js.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
),
AllRuns as (
	SELECT jh.job_id,CONVERT(datetime,CONVERT(CHAR(8), run_date, 112) 
		+ ' ' 
		+ STUFF(STUFF(RIGHT('000000' 
		+ CONVERT(VARCHAR(8), run_time), 6), 5, 0, ':'), 3, 0, ':') ) as run_datetime,
		run_status,
		step_id,
		CAST(message as varchar(max)) as result
	--	ROW_NUMBER() OVER(PARTITION BY job_id ORDER BY run_date DESC,run_time DESC) rnum
	FROM msdb..sysjobhistory jh
	WHERE run_status IN(0,1,3) --Succeeded/Failed/Cancelled
	AND jh.step_id = 0 AND jh.run_date >= @FromDate
),
JobStats AS (
	select name,
			MAX(enabled) enabled,
			SUM(CASE WHEN run_status = 1 THEN 1 ELSE 0 END) as SucceededCount,
			SUM(CASE WHEN run_status = 0 THEN 1 ELSE 0 END) as FailedCount,
			SUM(CASE WHEN run_status = 3 THEN 1 ELSE 0 END) as CancelledCount,
			MAX(run_datetime) last_run_datetime,
			MAX(next_run_time) next_run_datetime,
			MAX(run_status) last_run_status,
			COALESCE(MAX(result),'Unknown') last_result
	from msdb..sysjobs j
	LEFT JOIN nextrun ON j.job_id = nextrun.job_id
	LEFT JOIN AllRuns ON j.job_id = AllRuns.job_id
	GROUP BY name
)
SELECT @HTML =N'<h2>Agent Job Stats in the last ' + CAST(@NumDays as varchar) + N' day(s)</h2>
	<table>' +
	(SELECT 'Name' th,
	'Enabled' th,
	'Succeeded' th,
	'Failed' th,
	'Cancelled' th,
	'Last Run Time' th,
	'Next Run Time' th,
	'Last Result' th
	FOR XML RAW('tr'),ELEMENTS) 
	+ (SELECT name td,
			CAST(CASE WHEN enabled = 1 THEN N'<div class="Healthy">Yes</div>'
					ELSE N'<div class="Warning">No</div>' END as XML) td,
			CAST(CASE WHEN SucceededCount = 0 THEN  N'<div class="Warning">'
					ELSE N'<div>' END
					+ CAST(SucceededCount as varchar) + '</div>' as XML) td,
			CAST(CASE WHEN FailedCount >0 THEN  N'<div class="Critical">'
					ELSE N'<div class="Healthy">' END
					+ CAST(FailedCount as varchar) + N'</div>' as XML) td,
			CAST(CASE WHEN CancelledCount >0 THEN  N'<div class="Critical">'
					ELSE N'<div class="Healthy">' END
					+ CAST(CancelledCount as varchar) + N'</div>' as XML) td,
			CONVERT(nvarchar,last_run_datetime,121) td,
			CONVERT(nvarchar,next_run_datetime,121) td,
			CAST(CASE WHEN last_run_status = 1 THEN N'<span class="Healthy"><![CDATA[' + last_result + N']]></span>' 
					ELSE N'<span class="Critical"><![CDATA[' + last_result + N']]></span>' END  AS XML)  td 
		FROM JobStats
		ORDER BY last_run_datetime DESC
		FOR XML RAW('tr'),ELEMENTS XSINIL
	) + N'</table>'
GO
CREATE PROC [dbo].[DBAChecks_FailedAgentJobs](@HTML varchar(max) out,@NumDays int)
AS
/* 
	Returns HTML for "Failed jobs in the last 'X' days" section of DBA Checks Report
*/ 
DECLARE @FromDate char(8)
DECLARE @SucceededCount int
SET @FromDate = CONVERT(char(8),dateadd (day,-@NumDays, getdate()), 112)
IF EXISTS(	
	SELECT *
	FROM msdb..sysjobhistory jh
	JOIN msdb..sysjobs j ON jh.job_id = j.job_id
	WHERE jh.run_status IN(0,3) -- Failed/Cancelled
		AND jh.step_id <> 0
		AND	run_date >= @FromDate)
BEGIN
SET @HTML = '<h2>Failed Jobs in the last ' + CAST(@NumDays as varchar) + ' day(s)</h2>
	<table>
	<tr>
	<th>Date</th>
	<th>Job Name</th>
	<th>Job Status</th>
	<th>Step ID</th>
	<th>Step Name</th>
	<th>Message</th>
	<th>Run Duration</th>
	</tr>'
	+
	(SELECT CONVERT(datetime,CAST(jh.run_date AS char(8)) + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR,jh.run_time),6),5,0,':'),3,0,':'),101) AS td,
		j.name AS td,
		CAST(CASE jh.run_status WHEN 0 THEN '<div class="Critical">Failed</div>'
			WHEN 3 THEN '<div class="Warning">Cancelled</div>'
			ELSE NULL END as XML) as td,
		jh.step_id as td,
		jh.step_name as td,
		jh.message as td,
				RIGHT('00' +CAST(run_duration/10000 as varchar),2) + ':' +
				RIGHT('00' + CAST(run_duration/100%100 as varchar),2) + ':' +
				RIGHT('00' + CAST(run_duration%100 as varchar),2) as td
	FROM	msdb..sysjobhistory jh
	JOIN	msdb..sysjobs j
		ON jh.job_id = j.job_id
	WHERE	jh.run_status IN(0,3) -- Failed/Cancelled
		AND jh.step_id <> 0
		AND	run_date >= @FromDate
	ORDER BY CONVERT(datetime,CAST(jh.run_date AS char(8)) + ' ' + STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR,jh.run_time),6),5,0,':'),3,0,':'),101) DESC
	FOR XML RAW('tr'),ELEMENTS XSINIL
	)
	+ '</table><br/>'
END
ELSE
BEGIN
	SET @HTML = '<h2>Failed Jobs in the last ' + CAST(@NumDays as varchar) + ' day(s)</h2>
				<span class="Healthy">No failed jobs</span><br/>'	
END
GO
CREATE PROC [dbo].[DBAChecks_DBFiles](
	@IncludeDBs varchar(max),
	@ExcludeDBs varchar(max),
	@WarningThresholdPCT int,
	@CriticalThresholdPCT int,
	@HTML varchar(max) output
)
AS
/* 
	Returns HTML for "Database Files" section of DBA Checks Report
*/ 
DECLARE @IncludeXML XML
DECLARE @ExcludeXML XML
DECLARE @DB sysname

IF @IncludeDBs = ''
BEGIN
	SET @HTML = ''
	RETURN
END
CREATE TABLE #FileStats(
	[db] sysname not null,
	[name] [sysname] not null,
	[file_group] [sysname] null,
	[physical_name] [nvarchar](260) NOT NULL,
	[type_desc] [nvarchar](60) NOT NULL,
	[size] [varchar](33) NOT NULL,
	[space_used] [varchar](33)  NULL,
	[free_space] [varchar](33)  NULL,
	[pct_used] [float]  NULL,
	[max_size] [varchar](33) NOT NULL,
	[growth] [varchar](33) NOT NULL
) 

SELECT @IncludeXML = '<a>' + REPLACE(@IncludeDBs,',','</a><a>') + '</a>'
SELECT @ExcludeXML = '<a>' + REPLACE(@ExcludeDBs,',','</a><a>') + '</a>'

DECLARE cDBs CURSOR LOCAL STATIC FORWARD_ONLY READ_ONLY FOR 
			SELECT name FROM sys.databases
			WHERE (name IN(SELECT n.value('.','sysname')
						FROM @IncludeXML.nodes('/a') T(n))
						OR @IncludeXML IS NULL)
				AND (name NOT IN(SELECT n.value('.','sysname')
						FROM @ExcludeXML.nodes('/a') T(n))
						OR @ExcludeXML IS NULL)
			AND source_database_id IS NULL
			AND state = 0 --ONLINE
			ORDER BY name
			
OPEN cDBs
FETCH NEXT FROM cDBs INTO @DB
WHILE @@FETCH_STATUS = 0
BEGIN
	DECLARE @SQL nvarchar(max)
	SET @SQL =		 N'USE ' + QUOTENAME(@DB) + ';
					INSERT INTO #FileStats(db,name,file_group,physical_name,type_desc,size,space_used,free_space,[pct_used],max_size,growth)
					select DB_NAME() db,
					f.name,
					fg.name as file_group,
					f.physical_name,
					f.type_desc,
					CASE WHEN (f.size/128) < 1024 THEN CAST(f.size/128 as varchar) + '' MB'' 
						ELSE CAST(CAST(ROUND(f.size/(128*1024.0),1) as float) as varchar) + '' GB'' 
						END as size,
					CASE WHEN FILEPROPERTY(f.name,''spaceused'')/128 < 1024 THEN CAST(FILEPROPERTY(f.name,''spaceused'')/128 as varchar) + '' MB''
						ELSE CAST(CAST(ROUND(FILEPROPERTY(f.name,''spaceused'')/(128*1024.0),1) as float) as varchar) + '' GB'' 
						END space_used,
					CASE WHEN (f.size - FILEPROPERTY(f.name,''spaceused''))/128 < 1024 THEN CAST((f.size - FILEPROPERTY(f.name,''spaceused''))/128 as varchar) + '' MB''
						ELSE CAST(CAST(ROUND((f.size - FILEPROPERTY(f.name,''spaceused''))/(128*1024.0),1) as float) as varchar) + '' GB''
						END free_space,
					ROUND((FILEPROPERTY(f.name,''spaceused''))/CAST(size as float)*100,2) as [pct_used],
					CASE WHEN f.max_size =-1 THEN ''unlimited'' 
						WHEN f.max_size/128 < 1024 THEN CAST(f.max_size/128 as varchar) + '' MB'' 
						ELSE CAST(f.max_size/(128*1024) as varchar) + '' GB''
						END as max_size,
					CASE WHEN f.is_percent_growth=1 THEN CAST(f.growth as varchar) + ''%''
						WHEN f.growth = 0 THEN ''none''
						WHEN f.growth/128 < 1024 THEN CAST(f.growth/128 as varchar) + '' MB'' 
						ELSE CAST(CAST(ROUND(f.growth/(128*1024.0),1) as float) as varchar) + '' GB''
						END growth
					from sys.database_files f
					LEFT JOIN sys.filegroups fg on f.data_space_id = fg.data_space_id
					where f.type_desc <> ''FULLTEXT'''
	exec sp_executesql @SQL					
	FETCH NEXT FROM cDBs INTO @DB
END
CLOSE cDBs
DEALLOCATE cDBs
SELECT @HTML = '<h2>Database Files</h2><table>' + 
		(SELECT 'Database' th,
		'Name' th,
		'File Group' th,
		'File Path' th,
		'Type' th,
		'Size' th,
		'Used' th,
		'Free' th,
		'Used %' th,
		'Max Size' th,
		'Growth' th
		FOR XML RAW('tr'),ELEMENTS ) +		
		(SELECT db td,
					name td,
					file_group td,
					physical_name td,
					type_desc td,
					size td,
					space_used td,
					free_space td,
					CAST(CASE WHEN pct_used > @CriticalThresholdPCT 
						THEN '<div class="Critical">' + CAST(pct_used as varchar) + '</div>'
						WHEN pct_used > @WarningThresholdPCT  
						THEN '<div class="Warning">' + CAST(pct_used as varchar) + '</div>'
						ELSE '<div class="Healthy">' + CAST(pct_used as varchar) + '</div>'
						END as XML) td,
					max_size td,
					CAST(CASE WHEN growth='none' THEN '<div class="Warning">' + growth + '</div>'
					ELSE growth END as XML) td
				FROM #FileStats
				ORDER BY db,type_desc DESC,file_group,name
				FOR XML RAW('tr'),ELEMENTS XSINIL) + '</table>'			
DROP TABLE #FileStats;
GO
CREATE PROC [dbo].[DBAChecks_ErrorLog](@NumDays int)
AS
/* 
	Returns HTML for "ErrorLog.htm" attachment of DBA Checks Report
*/ 
SET NOCOUNT ON
declare @sql varchar(max)
---------------------------------------------------------------------------------
--set @hours back to a negative number, so we can go back in time
---------------------------------------------------------------------------------
if @NumDays is null set @NumDays = 1
set @NumDays = (@NumDays * -1)
declare @startDate datetime = dateadd(d, @NumDays, getdate())
---------------------------------------------------------------------------------
--tables to hold error log results
---------------------------------------------------------------------------------
create table #errorLog(LogDate datetime2
					  ,ProcessInfo varchar(64)
					  ,LogText varchar(max))
---------------------------------------------------------------------------------
--get errors from error log going back to @startDate
--we cycle through the error logs in case there were multiple restarts
---------------------------------------------------------------------------------
DECLARE @FileList AS TABLE (
  subdirectory VARCHAR(4000) NOT NULL 
  ,DEPTH BIGINT NOT NULL
  ,[FILE] BIGINT NOT NULL
 );
DECLARE @ErrorLog VARCHAR(4000), @ErrorLogPath VARCHAR(4000);
SELECT @ErrorLog = CAST(SERVERPROPERTY(N'errorlogfilename') AS VARCHAR(4000));
SELECT @ErrorLogPath = SUBSTRING(@ErrorLog, 1, LEN(@ErrorLog) - CHARINDEX(N'\', REVERSE(@ErrorLog))) + N'\';
INSERT INTO @FileList
EXEC xp_dirtree @ErrorLogPath, 0, 1;
DECLARE @NumberOfLogfiles INT;
SET @NumberOfLogfiles = (SELECT COUNT(*) FROM @FileList WHERE [@FileList].subdirectory LIKE N'ERRORLOG%');
declare @i int = 0
declare @maxDate datetime = (select max(isnull(LogDate,'19010101')) from #errorLog)
while (@i < @NumberOfLogfiles or @maxDate < @startDate)
begin
set @sql = '
insert into #errorLog
exec master.dbo.xp_readerrorlog
	' + cast(@i as char(1)) + '
	,1
	," "
	," "
	,''' + convert(varchar(8),@startDate,112) + '''
	,null
	,"desc"
	'
	exec (@sql)
	set @i = @i + 1
	set @maxDate = (select max(isnull(LogDate,'19010101')) from #errorLog)
end
---------------------------------------------------------------------------------
--return the error log results, while removing some noise
---------------------------------------------------------------------------------
SELECT '<HTML>
<HEAD>
<style type="text/css">
table {
/*width:100%;*/
font:8pt tahoma,arial,sans-serif;
border-collapse:collapse;
}
th {
color:#FFFFFF;
font:bold 8pt tahoma,arial,sans-serif;
background-color:#204c7d;
padding-left:5px;
padding-right:5px;
}
td {
color:#000000;
font:8pt tahoma,arial,sans-serif;
border:1px solid #DCDCDC;
border-collapse:collapse;
}
.Warning {
background-color:#FFFF00; 
color:#2E2E2E;
}
.Critical {
background-color:#FF0000;
color:#FFFFFF;
}
.Healthy {
background-color:#458B00;
color:#FFFFFF;
}
</style>
</HEAD>
<BODY>
<table><tr><th>Log Date</th><th>Source</th><th>Message</th></tr>' + 
(SELECT CONVERT(varchar,el.LogDate,120) td,
	CAST('<div><![CDATA[' + el.ProcessInfo + N']]></div>' as XML) td,
	CAST('<div' + 
		CASE WHEN (el.LogText LIKE '%error%' OR el.LogText LIKE '%exception%' 
					OR el.LogText LIKE '%stack dump%' OR el.LogText LIKE '%fail%') 
				OR el.LogText LIKE '%DBCC%' THEN ' Class="Critical"' 
		WHEN el.LogText LIKE '%warning%' THEN ' Class="Warning"'
		ELSE '' END 
		+ '><![CDATA[' + el.LogText + N']]></div>' as XML) td
FROM #errorLog el
WHERE
LogDate >= @startDate
		AND el.LogText NOT LIKE '%This is an informational message%'
		AND el.LogText NOT LIKE 'Authentication mode is%'
		AND el.LogText NOT LIKE 'System Manufacturer%'
		AND el.LogText NOT LIKE 'All rights reserved.'
		AND el.LogText NOT LIKE 'Server Process ID is%'
		AND el.LogText NOT LIKE 'Starting up database%'
		AND el.LogText NOT LIKE 'Registry startup parameters%'
		AND el.LogText NOT LIKE '(c) 2019 Microsoft%'
		AND el.LogText NOT LIKE 'Server is listening on%'
		AND el.LogText NOT LIKE 'Server local connection provider is ready to accept connection on%'
		AND el.LogText NOT LIKE 'Logging SQL Server messages in file%'
		AND el.LogText <> 'Clearing tempdb database.'
		AND el.LogText <> 'Using locked pages for buffer pool.'
		AND el.LogText <> 'Service Broker manager has started.'
	order by
		el.LogDate desc
		,case when el.LogText like 'Error:%' then 1 else 2 end
FOR XML RAW('tr'),ELEMENTS XSINIL)
+ '</table></HEAD></BODY>' as HTML
drop table #errorLog
GO
