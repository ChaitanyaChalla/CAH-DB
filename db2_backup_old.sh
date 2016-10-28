#!/usr/bin/ksh

umask u=rw,g=rw,o=r    # set umask so any group ID can manage the log files created

date_today="$(date +"%m_%d")"

JobLog=/home/dbadmin/logs/backups/job_summary_${date_today}.log

  typeset -l BackupType=$1
  typeset -u database=$2
  typeset -l Instance=$3

 mkdir /backups/${database}
 chmod -R 775 /backups/${database}

. /db2/${Instance}/sqllib/db2profile

##      Add support for nonstandard database names or multiple databases in one instance
##
   if [[ -n ${DB2INSTANCE} ]]
   then
        Instance=${DB2INSTANCE}
   else
        Instance="db2${2}"
   fi

   ihome=`lsuser -a home ${Instance} 2>/dev/null`
   if [[ $? -ne 0 ]]                    # Is this a valid user?
   then                                 # No,
        Instance=`id -un`               #       default to user name
   fi
##

  typeset -i backup_return=0
  typeset -i backup_retry=1             # Number of backup retries


  LOG=/home/dbadmin/logs/backups/${database}_${BackupType}_bkup_${$}.log

  echo "`date '+%Y/%m/%d %T'` $0: START ${BackupType} Backup for ${database}" >> ${JobLog}
  echo "INFO: `date '+%Y/%m/%d %T'`: START ${BackupType} Backup for ${database}" >> ${LOG}
  echo "--------------" >> ${LOG}

  if  [[ $BackupType = "online" ]]
  then
    # If its time to do an online backup and the database is down.. send an alert
    # If this is tek it will just go through email
    if [[ $Database_Status = "DOWN" ]]
    then
        echo "`date '+%Y/%m/%d %T'`: FAILED Online backup. Instance was down.">> $LOG
    else
        db2 "backup db ${database} ${BackupType} to /backups/${database}/ compress INCLUDE LOGS WITHOUT PROMPTING" >> $LOG
     fi

backup_return=$?
backup_retry=${backup_retry}-1
        sleep 5

    db2 "archive log for db ${database}" >> $LOG

  fi

  echo "--------------" >> ${LOG}

  if (( backup_return == 0 ))
  then
        echo "INFO: `date '+%Y/%m/%d %T'`: SUCCESSFUL ${BackupType} Backup for ${database}" >> ${LOG}
        echo    "`date '+%Y/%m/%d %T'` $0: SUCCESSFUL ${BackupType} Backup for ${database}" >> $JobLog
    #    mail_subject="${database}: ${BackupType} backup Succeeded"
  else
        echo "INFO: `date '+%Y/%m/%d %T'`: FAILED ${BackupType} Backup for ${database}" >> ${LOG}
        echo    "`date '+%Y/%m/%d %T'` $0: FAILED ${BackupType} Backup for ${database} see ${LOG}" >> $JobLog
     #   mail_subject="${database}: ${BackupType} backup Failed"
     exit 1
  fi

  /home/dbadmin/scripts/list_backups ${database} >> ${LOG}


