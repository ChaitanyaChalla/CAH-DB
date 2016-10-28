#!/usr/bin/ksh

umask u=rw,g=rw,o=r    # set umask so any group ID can manage the log files created

date_today="$(date +"%m_%d")"

JobLog=/home/dbadmin/logs/backups/job_summary_${date_today}.log

  typeset -l BackupType=$1
  typeset -u database=$2
  typeset -l Instance=$3

backup_dir=/backups/${database}
#backup_dir=/tmp/raj/${database}

if [[ ! -e $backup_dir} ]]; then
    mkdir $backup_dir
    chmod -R 775 $backup_dir
fi


. /db2/${Instance}/sqllib/db2profile

##      Add support for nonstandard database names or multiple databases in one instance
##
   if [[ -n ${DB2INSTANCE} ]]
   then
        Instance=${DB2INSTANCE}
   else
        Instance="db2${2}"
   fi

  typeset -i backup_return=0
  typeset -i backup_retry=1             # Number of backup retries


  LOG=/home/dbadmin/logs/backups/${database}_${BackupType}_bkup_${$}.log

  echo "`date '+%Y/%m/%d %T'` $0: START ${BackupType} Backup for ${database}" >> ${JobLog}
  echo "INFO: `date '+%Y/%m/%d %T'`: START ${BackupType} Backup for ${database}" >> ${LOG}
  echo "--------------" >> ${LOG}

  # Find first active log
  ACTIVELOG=`db2 get db cfg for $database | grep 'First active log file' | awk '{ print $6 }'`


  if  [[ $BackupType == "online" ]]
  then

    # If its time to do an online backup and the database is down.. send an alert
    # If this is tek it will just go through email
    if [[ $Database_Status == "DOWN" ]]
    then
        echo "`date '+%Y/%m/%d %T'`: FAILED Online backup. Instance was down.">> $LOG

    else
        echo "Begining backup - Active log file is : " $ACTIVELOG >> $LOG
        db2 "backup db ${database} ${BackupType} to $backup_dir compress INCLUDE LOGS WITHOUT PROMPTING" >> $LOG

         backup_return=$?

         if (( backup_return == 0 ))
         then
             # Find first active log immediately after the backup
             ACTIVELOG=`db2 get db cfg for $database | grep 'First active log file' | awk '{ print $6 }'`
             echo "End-of-backup backup - Active log file is : " $ACTIVELOG   >> $LOG
             backup_image=`ls -ltr $backup_dir | awk '{print $9}' | awk '{ rec=$0 } END{ print rec }'`

             echo " Backup image date : $backup_image" \n >> $LOG
             aws s3 cp $backup_dir/$backup_image s3://cah-ecomm-dbbackups/dev01/${database}/backups/ --sse AES256
             #aws s3 cp $backup_dir/$backup_image s3://cah-ecomm-dbbackups/dev01/D23X/backups/ --sse AES256
             S3_backup_return=$?

             if (( S3_backup_return == 0 ))
             then
                echo " Call the archive log scripte to send the logfiles to S3 "  >> $LOG
                /home/dbadmin/scripts/db2_archive_s3.sh $database
             fi

             if (( S3_backup_return == 0 ))
             then
               echo "INFO: `date '+%Y/%m/%d %T'`: SUCCESSFUL ${BackupType} Backup for ${database}" >> ${LOG}
               echo    "`date '+%Y/%m/%d %T'` $0: SUCCESSFUL ${BackupType} Backup for ${database}" >> $JobLog
               echo    "`date '+%Y/%m/%d %T'` $0: SUCCESSFUL ${BackupType} Backup for ${database}"
             else
               echo "INFO: `date '+%Y/%m/%d %T'`: FAILED ${BackupType} Backup for ${database}" >> ${LOG}
               echo "INFO: `date '+%Y/%m/%d %T'`: FAILED ${BackupType} Backup for ${database}" >> $JobLog
               echo "INFO: `date '+%Y/%m/%d %T'`: FAILED ${BackupType} Backup for ${database}"
             fi
            if (( S3_backup_return == 0 ))
             then
                prev_bkp_img=`find $backup_dir/*.001 | head -1`
              echo "Removing Previous Backup Image: ${prev_bkp_img}"  >> $LOG
            rm `find $backup_dir/*.001 | head -1`
            else
             exit
            fi
         else
           exit
         fi

   fi


  fi

  echo "--------------" >> ${LOG}

  /home/dbadmin/scripts/list_backups ${database} >> ${LOG}

##################################################################################################################
## Send the backup image to S3 bucket`
##################################################################################################################

exit

