#!/usr/bin/ksh
#
# Simple script to List the last 10 backups
#
#
#

database=${1:-$DB2DBDFT}

db2 +o connect to ${database}
db2 -t -f /home/dbadmin/scripts/list_backups.sql
db2 +o terminate
$ cat db2_archive_s3.sh
#!/usr/bin/ksh
  typeset -u database=$1

. /db2/${DB2INSTANCE}/sqllib/db2profile

umask u=rw,g=rw,o=r    # set umask so any group ID can manage the log files created

date_today="$(date +"%m_%d")"
date_time="$(date +"%m%d%H""%M""%S")"

DELETED_FILES=/home/dbadmin/logs/removedlogs_${DB2INSTANCE}_${database}_$date_time.log
SELECTED_FILES=/home/dbadmin/logs/selected_logs_for_archival_${DB2INSTANCE}_${database}_$date_time.log
BACKEDUP_FILES=/home/dbadmin/logs/backedup_logs_from_archive_log_${DB2INSTANCE}_${database}_$date_time.log
LOG_ARCHIVE_DIR=/db2/$database/log_archive
#LOG_ARCHIVE_DIR=/tmp/raj
Joblog=/home/dbadmin/logs/archive_logs_to_s3.log

if [ ! -e "$SELECTED_FILES" ] ; then
    touch "$SELECTED_FILES"
    chmod 775 $SELECTED_FILES
fi

if [ ! -e "$BACKEDUP_FILES" ] ; then
    touch "$BACKEDUP_FILES"
    chmod 775 $BACKEDUP_FILES
fi

if [ ! -e "$DELETED_FILES" ] ; then
    touch "$DELETED_FILES"
    chmod 775 $DELETED_FILES
fi
###########################################################################################################
#### Set the Archive LOG Path
###########################################################################################################
echo "Setting the archive log directory" >> $Joblog
DB2RELEASE=`db2level | grep "DB2 code release" | sed -e "s=.*SQL\([0-9][0-9][0-9][0-9]\).*=\1=g"`

        if [[ $DB2RELEASE -gt 0907 ]]
        then
            log_archive="$LOG_ARCHIVE_DIR/${DB2INSTANCE}/${database}/NODE0000/LOGSTREAM0000"
        else
            log_archive="$LOG_ARCHIVE_DIR/${DB2INSTANCE}/${database}/NODE0000"
        fi


###########################################################################################################
#### Listing or seleting the tables for deletion
###########################################################################################################
echo "List the files that to be archived to S3 check in $SELECTED_FILES" >> $Joblog
cd $log_archive
for log_chain in `ls -d C[0-9][0-9][0-9][0-9][0-9][0-9][0-9]`
do
   find $log_chain -name "S*.LOG" | grep -c LOG$ | read nbr_of_logs
   if [[ $nbr_of_logs -ne 0 ]]
   then
   find $log_archive/$log_chain/S*.LOG >> $SELECTED_FILES
   find $log_archive/$log_chain/S*.LOG >> $BACKEDUP_FILES
   fi
done


###########################################################################################################
#### start the copying the files to S3 bucket and then delete them
###########################################################################################################
echo "Starting the selected files that to be archived to S3 bucket check in $SELECTED_FILES" >> $Joblog
for i in `cat $SELECTED_FILES`
do
   echo "Sending the files to S3 bucket - Check in $DELETED_FILES" >> $Joblog
   aws s3 cp $i s3://cah-ecomm-dbbackups/dev01/$database/archives/

   if [[ $? = 0 ]]
   then
          echo $i >>  $Joblog
          rm -f $i >> $DELETED_FILES
   fi
done

exit

