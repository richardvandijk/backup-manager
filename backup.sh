#!/bin/bash

# Check the command dependency
cmds="date rsync find gpg tar"
for i in $cmds
do
  command -v $i >/dev/null && continue || { echo "$i command not found."; exit 1; }
done

################################################################################
# Step #0: Data repository models
################################################################################

# Variable to configure
user="richard"
email="richard@richardvd.nl"
backupHome="/Users/$user/backups"
backupSourceDirectory="/Users/$user/Documents"

# Dates
now=$(date +%Y%m%d%H%M)               #YYYYMMDDHHMM
yesterday=$(date -v -1d +%Y%m%d)      #YYYYMMDD
previousMonth=$(date -v -1m +%Y%m)    #YYYYMM
today=${now:0:8}                      #YYYYMMDD
thisMonth=${today:0:6}                #YYYYMM
thisYear=${today:0:4}                 #YYYY

# Backup Configuration
logfile="$backupHome/backups.log"
currentLink="$backupHome/current"
snapshotDirectory="$backupHome/snapshots"
archivesDirectory="$backupHome/archives"
dailyArchivesDirectory="$archivesDirectory/daily"
weeklyArchivesDirectory="$archivesDirectory/weekly"
monthlyArchivesDirectory="$archivesDirectory/monthly"

start_time=`date +%s`

# Init the folder structure
mkdir -p $snapshotDirectory $dailyArchivesDirectory $weeklyArchivesDirectory $monthlyArchivesDirectory &> /dev/null
touch $logfile
printf "[%12d] Backup started\n" $now >> $logfile
printf "[%12d] Backup started\n" $now

################################################################################
# Step #1: Retreive files to create snapshots with RSYNC.
################################################################################

rsync -auzH --hard-links --link-dest=$currentLink $backupSourceDirectory $snapshotDirectory/$now \
  && ln -snf $(ls -1d $snapshotDirectory/* | tail -n1) $currentLink \
  && printf "\t- Copy from %s to %s successfull \n" $backupSourceDirectory $snapshotDirectory/$now >> $logfile

################################################################################
# Step #2: Group and Compress the previous snaphots per days
################################################################################

# Go Through all the snapshots to find those eligible for backup
find $snapshotDirectory -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | \
  while read fileName
  do
    snapshotGroup=${fileName:0:8}   # YYYYMMDD
    # Archive and delete only if the snapshots are older than yesterday
    if [[ $snapshotGroup -le $yesterday ]]
    then
      tar -czf $dailyArchivesDirectory/$snapshotGroup.tar.gz -C $snapshotDirectory $(cd $snapshotDirectory && ls -dl1 $snapshotGroup*) \
        && rm -rf $snapshotDirectory/$snapshotGroup* \
        && printf "\t- Created archive %s and removed the folders starting with %s\n" $dailyArchivesDirectory/$snapshotGroup.tar.gz $snapshotDirectory/$snapshotGroup >> $logfile
    fi
  done

################################################################################
# Step #3: Encrypt the archives with PGP
################################################################################

# Step 3.1: If there are archives not encrypted, encrypt them and delete the archive
if [ $(ls -d $dailyArchivesDirectory/*.tar.gz 2> /dev/null | wc -l) != "0" ]
then
  gpg -r $email --encrypt-files $dailyArchivesDirectory/*.tar.gz \
    && rm -rf $dailyArchivesDirectory/*.tar.gz \
    && printf "\t- Encrypted archive in %s and removed the unencrypted version\n" $dailyArchivesDirectory >> $logfile 
fi

################################################################################
# Step #4: rotate the backups 
################################################################################

find -E $dailyArchivesDirectory -type f -mindepth 1 -maxdepth 1 -regex '.*/[0-9]{8}\.tar\.gz\.gpg$' -exec basename {} \; | \
while read encryptedArchive
do
  archiveMonth=${encryptedArchive:0:6}

  # Step #4.1: Keep weekly backups for previous month
  if [[ $encryptedArchive =~ ^$previousMonth ]]; then
    archiveDay=${encryptedArchive:6:2}
    weekNum=$(((10#$archiveDay)/7))
    mv $dailyArchivesDirectory/$encryptedArchive $weeklyArchivesDirectory/$previousMonth.WK_$weekNum.tar.gz.gpg \
      && printf "\t- Moved %s to %s\n" $dailyArchivesDirectory/$encryptedArchive $weeklyArchivesDirectory/$previousMonth.WK_$weekNum.tar.gz.gpg >> $logfile
  fi

  # Step #4.2: if the daily archive is older than the previous month we move it to monthly
  if [[ $archiveMonth -lt $previousMonth ]]; then
    mv -n $dailyArchivesDirectory/$encryptedArchive $monthlyArchivesDirectory/$archiveMonth.tar.gz.gpg \
      && printf "\t- Moved %s to %s\n" $dailyArchivesDirectory/$encryptedArchive $monthlyArchivesDirectory/$archiveMonth.tar.gz.gpg >> $logfile
  fi
done 

# Step #4.3: Keep monthly backups for older backups
find -E $weeklyArchivesDirectory -mindepth 1 -maxdepth 1 -type f -regex '.*/[0-9]{6}\.WK_[1-4]\.tar\.gz\.gpg$' -exec basename {} \; | \
while read encryptedArchive
do
  archiveMonth=${encryptedArchive:0:6}
  if [[ $archiveMonth -lt $previousMonth ]]; then
    mv $weeklyArchivesDirectory/$encryptedArchive $monthlyArchivesDirectory/$archiveMonth.tar.gz.gpg \
      && printf "\t- Moved %s to %s\n" $weeklyArchivesDirectory/$encryptedArchive $monthlyArchivesDirectory/$archiveMonth.tar.gz.gpg >> $logfile
  fi
done

end_time=`date +%s`
printf "\t===== Backup execute successfully in %6d s. =====\n" $(($end_time - $start_time)) >> $logfile
printf "\t===== Backup execute successfully in %6d s. =====\n" $(($end_time - $start_time))
