#!/bin/bash
TIME=`date +%d-%b-%y`

#Argument (fill all of these)
#Path
BACKUP=/backup
MASTODON=/home/mastodon
LOG=/var/log
MUNIN=/var/www/munin
LETSENCRYPT=/etc/letsencrypt/live
NGINX=/etc/nginx/conf.d
NETDATA=~/netdata
#FTP Settings
FTPHOST=
FTPLOGIN=
FTPPASSWORD=
FTPPORT=
#SFTP Settings
SFTPHOST=
SFTPLOGIN=
SFTPPASSWORD=
SFTPPORT=
#FTP Use or SFTP Use (default is no, set yes for each service you use)
FTP=no
SFTP=yes
#I'll implement it later
#RSYNC=no

#ASCII Art :)
echo -e '\e[94m'
echo -e "┌┬┐┌─┐┌─┐┌┬┐┌─┐┌┬┐┌─┐┌┐┌    ┌┐ ┌─┐┌─┐┬┌─┬ ┬┌─┐"
echo -e "│││├─┤└─┐ │ │ │ │││ ││││    ├┴┐├─┤│  ├┴┐│ │├─┘"
echo -e "┴ ┴┴ ┴└─┘ ┴ └─┘─┴┘└─┘┘└┘────└─┘┴ ┴└─┘┴ ┴└─┘┴"
echo -e "                                made by w4rell"

#Create folders if they don't exist
echo -e '\e[93m'
echo -e 'Creating folders...'
if [ ! -d "$BACKUP/tmp" ]; then
	mkdir -p $BACKUP/{tmp/{db,mastodon,log,munin,letsencrypt,nginx,netdata},archives}
fi

#Dump all about PostgreSQL
echo -e '\e[95m'
echo -e 'Dumping database...'
chown postgres $BACKUP/tmp/db 
su - postgres -c "pg_dumpall > $BACKUP/tmp/db/db_mstdn_$TIME"

#Copy all file to a tmp location
[ `which rsync` ] $$ echo "rsync : installed" || sudo apt-get install -y rsync
echo -e '\e91m'
echo -e 'Copying files...'
rsync -arqlpogt --stats --progress $MASTODON/* $BACKUP/tmp/mastodon
rsync -arqlpogt --stats --progress $LOG/* $BACKUP/tmp/log
rsync -arqlpogt --stats --progress $MUNIN/* $BACKUP/tmp/munin
rsync -arqlpogt --stats --progress $LETSENCRYPT/* $BACKUP/tmp/letsencrypt
rsync -arqlpogt --stats --progress $NGINX/* $BACKUP/tmp/nginx
rsync -arqlpogt --stats --progress $NETDATA/* $BACKUP/tmp/netdata

#Create an archive of all these files
echo -e '\e[91m'
echo -e 'Creating tar.gz archive...'
tar -czf $BACKUP/archives/backup_mstdn_$TIME.tar.gz $BACKUP/tmp/*

#Sent archive to the safe location (FTP/SFTP)
if [ $FTP = "yes" ]; then
	echo -e '\e[92m'
	echo -e 'Sending archive through FTP...'
	cd $BACKUP/archives
	ftp -i -n $FTPHOST $FTPPORT << END_SCRIPT
	quote USER $FTPLOGIN
	quote PASS $FTPPASSWORD
	pwd
	bin
	put backup_mstdn_$TIME.tar.gz
	quit
END_SCRIPT
fi

if [ $SFTP = "yes" ]; then
	echo -e '\e[92m'
	echo -e 'Sending archive through SFTP...'
	cd $BACKUP/archives
	#Check if the expect package is installed
	[ `which expect` ] $$ echo "expect : installed" || sudo apt-get install -y expect
	expect -c "
	spawn sftp -oPort=$SFTPPORT ${SFTPLOGIN}@${SFTPHOST}
	expect \"password: \"
	send \"${SFTPPASSWORD}\r\"
	expect \"sftp>\"
	send \"put backup_mstdn_$TIME.tar.gz\r\"
	#Timeout needed to avoid any interruption during transfer
	set timeout 1000
	expect \"sftp>\"
	send \"bye\r\"
	expect \"#\"
	"
fi

#Delete all tmp files
echo -e '\e[39m'
echo -e 'Deleting tmp files and archive...'
rm -rf $BACKUP/*
