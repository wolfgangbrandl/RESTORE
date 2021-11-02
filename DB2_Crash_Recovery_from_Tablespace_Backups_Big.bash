#!/usr/bin/bash
CONTAINERPATH=/node1/data0/db2/S2T01/IT99
REPLACEPATH=/node1/data0/db2/S2T01/OPTIM
BACKUPPATH=/node1/data0/db2/S2T01/IT99/backup
QUAL=QTEST
LOCALINSTANCE=db2it99
RESTOREINSTANCE=db2opt
source util.bash
#-------------------------------------------------------
# HELP Message
# ------------------------------------------------------
print_help ()
{
  printf "Usage: test_tablespace_restore.bash -m <MODE> -c <CASE> -s <Databasename Source> \n"
  printf " -m <MODE>\n"
  printf "   MODE can be:\n"
  printf "       BACKUP: Backup der Datenbank\n"
  printf "       RESTORE: RESTORE: Backup der Datenbank\n"
  printf "       WORK: Make additional work after restore for testing log sequence\n"
  printf "       RESTOREWORK: Restore after work to check if log sequence matters\n"
  printf "       RESTOREREBUILD: Restore in other Instabnce same Database\n"
  printf " -c <CASE>\n"
  printf "   CASE can be:\n"
  printf "       1:   restore with offline tablespace backups\n"
  printf "       2:   restore with online tablespace backups without logs\n"
  printf "       3:   restore with online tablespace backups with logs\n"
  printf "       4:   restore with online incremental tablespace backups with logs\n"
  printf " -s    Database name\n"
  printf "Please add the name of the Databases\n"
}
#-------------------------------------------------------
# MAIN
# ------------------------------------------------------
while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -m|--mode)
    MODE="$2"
    shift # past argument
    ;;
    -c|--case)
    CASE="$2"
    shift # past argument
    ;;
    -s|--sourcedb)
    DB="$2"
    shift # past argument
    ;;
    -h|--help)
    print_help
    exit 4
    ;;
    *)
      print_help
      exit 4 
    ;;
esac
countbig=30000
count=1000
shift # past argument or value
done
if [ "$DB" == "" ]
then
  print_help
  exit 8
fi
case $MODE in
  BACKUP)
    rm -f $BACKUPPATH/$DB.*.001
    rm -f $BACKUPPATH/ONLINE*.out
    rm -f $BACKUPPATH/OFFLINE*.out
    smooth_drop $DB $CONTAINERPATH 
    create_db $DB $CONTAINERPATH
    case $CASE in
      1 | 2 | 3 )
        printf "Aufsetzen der Datenbabnk $DB für online Backups\n"
        db2 -v  "update db cfg for $DB using logarchmeth1 disk:$CONTAINERPATH/log/archlog/$DB"
        db2 -v  "connect to $DB"
        db2 -v  "connect reset"
        db2 -v  "backup database $DB to /dev/null"
        db2 -v  "backup database $DB online to /dev/null"
      ;;
      4)
        printf "Aufsetzen der Datenbabnk $DB für incremental online Backups\n"
        db2 -v  "update db cfg for $DB using logarchmeth1 disk:$CONTAINERPATH/log/archlog/$DB"
        db2 -v  "update db cfg for $DB using TRACKMOD YES"
        db2 -v  "connect to $DB"
        db2 connect reset
        db2 backup database $DB to /dev/null
        db2 backup database $DB to /dev/null
        db2 backup database $DB online to /dev/null
        db2 backup database $DB online incremental to /dev/null
      ;;
      *)
        echo Case is not valid
        exit 8
      ;;
    esac
    
    db2 -v  "connect to $DB"
    db2 -v  "CREATE STOGROUP "TS_U" ON '$CONTAINERPATH/TS_U_SPACE/$DB' "
    db2 -v  "CREATE STOGROUP "TS_M" ON '$CONTAINERPATH/TS_M_SPACE/$DB' "
    db2 -v  "CREATE STOGROUP "TS_B" ON '$CONTAINERPATH/TS_B_SPACE/$DB' "
    db2 -v  "CREATE STOGROUP "TS_N" ON '$CONTAINERPATH/TS_N_SPACE/$DB' "
    db2 -v  create tablespace NSPACE USING STOGROUP "TS_N"
    db2 -v  create tablespace BSPACE USING STOGROUP "TS_B"
    db2 -v  create tablespace URSPACE USING STOGROUP "TS_U"
    db2 -v  create tablespace MYSPACE USING STOGROUP "TS_M"
    db2 -v  "create table $QUAL.TABLEN (ind integer not null generated always as identity (start with 1 increment by 1),
                                  pid integer not null default 1, 
                                  date date not null default current date, 
                                  time time not null default current time, 
                                  object varchar(255) , 
                                  primary key (ind)
                                 ) in NSPACE"
    db2 -v  "create table $QUAL.TABLEB (ind integer not null generated always as identity (start with 1 increment by 1),
                                  pid integer not null default 1, 
                                  date date not null default current date, 
                                  time time not null default current time, 
                                  object varchar(255) , 
                                  primary key (ind)
                                 ) in BSPACE"
    db2 -v "connect reset"
    insert_into_table $DB $QUAL.TABLEB $countbig
    insert_into_table $DB $QUAL.TABLEN $countbig
    case $CASE in
      1)
        db2 -v  "backup database $DB tablespace (NSPACE) to $BACKUPPATH" | tee   $BACKUPPATH/OFFLINEBACKUPTIMEBIG2.out
        RC=$?
        OFFLINEBACKUPTIMEBIG2=$(check_backup $RC $BACKUPPATH/OFFLINEBACKUPTIMEBIG2.out)
        db2 -v  "backup database $DB tablespace (BSPACE) to $BACKUPPATH" | tee   $BACKUPPATH/OFFLINEBACKUPTIMEBIG.out
        RC=$?
        OFFLINEBACKUPTIMEBIG=$(check_backup $RC $BACKUPPATH/OFFLINEBACKUPTIMEBIG.out)
      ;;
      2)
        db2 -v  "backup database $DB tablespace (NSPACE) online to $BACKUPPATH" | tee   $BACKUPPATH/ONLINEBACKUPTIMEBIG2.out
        RC=$?
        ONLINEBACKUPTIMEBIG2=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMEBIG2.out)
        db2 -v  "backup database $DB tablespace (BSPACE) online to $BACKUPPATH" | tee   $BACKUPPATH/ONLINEBACKUPTIMEBIG.out
        RC=$?
        OFFLINEBACKUPTIMEBIG=$(check_backup $RC $BACKUPPATH/OFFLINEBACKUPTIMEBIG.out)
      ;;
      3 | 4 )
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,NSPACE) online  to $BACKUPPATH include logs" | tee   $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS2.out
        RC=$?
        ONLINEBACKUPTIMEBIGWTIHLOGS2=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS2.out)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,BSPACE) online to $BACKUPPATH  include logs" | tee   $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS.out
        RC=$?
        ONLINEBACKUPTIMEBIGWTIHLOGS=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS.out)
      ;;
    
      *)
        echo Case is not valid
        exit 8
      ;;
    esac
    
    ls -l $CONTAINERPATH/log/archlog/$DB/*
    db2 get db cfg for $DB|grep "First active log file"
    
    db2 -v  "connect to $DB"
    db2 -v  "create table $QUAL.TABLEA (ind integer not null generated always as identity (start with 1 increment by 1),
                                  pid integer not null default 1, 
                                  date date not null default current date, 
                                  time time not null default current time, 
                                  object varchar(255) , 
                                  primary key (ind)
                                 ) in USERSPACE1"
    db2 -v "connect reset"
    insert_into_table $DB $QUAL.TABLEA $count
    case $CASE in
      1 | 2)
      ;;
      3 | 4)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online to $BACKUPPATH include logs" | tee   $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSFULL.out
        RC=$?
        ONLINEBACKUPTIMENORMALWTIHLOGSFULL=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSFULL.out)
      ;;
      *)
        echo Case is not valid
        exit 8
      ;;
    esac
    db2 -v "connect to $DB"
    db2 -v  "create table $QUAL.TABLEC (ind integer not null generated always as identity (start with 1 increment by 1),
                                  pid integer not null default 1, 
                                  date date not null default current date, 
                                  time time not null default current time, 
                                  object varchar(255) , 
                                  primary key (ind)
                                 ) in URSPACE"
    db2 connect reset
    insert_into_table $DB $QUAL.TABLEC $count
    db2 "connect to $DB"
    db2 -v  "create table $QUAL.TABLEM (ind integer not null generated always as identity (start with 1 increment by 1),
                                  pid integer not null default 1, 
                                  date date not null default current date, 
                                  time time not null default current time, 
                                  object varchar(255) , 
                                  primary key (ind)
                                 ) in MYSPACE"
    db2 connect reset
    insert_into_table $DB $QUAL.TABLEM $count
    case $CASE in
      1 | 2 | 3)
      ;;
      4)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental to $BACKUPPATH include logs" | tee   $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL1.out
        RC=$?
        ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL1=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL1.out)
      ;;
      *)
        echo Case is not valid
        exit 8
      ;;
    esac
    insert_into_table $DB $QUAL.TABLEM $count
    insert_into_table $DB $QUAL.TABLEA $count
    case $CASE in
      1 | 2 | 3)
      ;;
      4)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental to $BACKUPPATH include logs" | tee   $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out
        RC=$?
        ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out)
      ;;
      *)
        echo Case is not valid
        exit 8
      ;;
    esac
    insert_into_table $DB $QUAL.TABLEM $count
    insert_into_table $DB $QUAL.TABLEC $count
    insert_into_table $DB $QUAL.TABLEA $count
    
    ls -l $CONTAINERPATH/log/archlog/$DB/*
    db2 get db cfg for $DB|grep "First active log file"
    
    db2 -v  "connect to $DB"
    db2 -v  "select max(ind) FROM $QUAL.tablea"
    db2 -v  "select max(ind) FROM $QUAL.tableb"
    db2 -v  "select max(ind) FROM $QUAL.tablec"
    db2 -v  "select max(ind) FROM $QUAL.tablem"
    db2 -v  "SELECT DBPARTITIONNUM, char(TYPE,20), char(PATH,80) FROM TABLE(ADMIN_LIST_DB_PATHS()) AS FILES"
    db2 -v  "connect reset"
    case $CASE in
      1)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) to $BACKUPPATH " | tee   $BACKUPPATH/OFFLINEBACKUPTIMENORMAL.out
        RC=$?
        OFFLINEBACKUPTIMENORMAL=$(check_backup $RC $BACKUPPATH/OFFLINEBACKUPTIMENORMAL.out)
      ;;
      2)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE to $BACKUPPATH ) online" | tee   $BACKUPPATH/ONLINEBACKUPTIMENORMAL.out
        RC=$?
        ONLINEBACKUPTIMENORMAL=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMENORMAL.out)
      ;;
      3)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online  to $BACKUPPATH include logs" | tee   $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGS.out
        RC=$?
        ONLINEBACKUPTIMENORMALWTIHLOGS=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGS.out)
      ;;
      4)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental  to $BACKUPPATH include logs" | tee   $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out
        RC=$?
        ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out)
      ;;
      *)
        echo Case is not valid
        exit 8
      ;;
    esac
  chmod g+r $BACKUPPATH/$DB*.001
  ;;
  WORK)
    insert_into_table $DB $QUAL.TABLEM $count
    insert_into_table $DB $QUAL.TABLEC $count
    insert_into_table $DB $QUAL.TABLEA $count
    case $CASE in
      1 | 2)
      ;;
      3)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online  to $BACKUPPATH include logs" | tee   $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGS.out
        RC=$?
        ONLINEBACKUPTIMENORMALWTIHLOGS=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGS.out)
      ;;
      4)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online  to $BACKUPPATH include logs" | tee   $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK.out
        RC=$?
        ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK.out)
      ;;
      *)
        echo Case is not valid
        exit 8
      ;;
    esac
    insert_into_table $DB $QUAL.TABLEM $count
    insert_into_table $DB $QUAL.TABLEC $count
    insert_into_table $DB $QUAL.TABLEA $count
    case $CASE in
      1 | 2)
      ;;
      3)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online  to $BACKUPPATH include logs" | tee   $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSWORK.out
        RC=$?
        ONLINEBACKUPTIMENORMALWTIHLOGSWORK=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSWORK.out)
      ;;
      4)
        db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental  to $BACKUPPATH include logs" | tee   $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK.out
        RC=$?
        ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2=$(check_backup $RC $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out)
      ;;
      *)
        echo Case is not valid
        exit 8
      ;;
    esac
  chmod g+r $BACKUPPATH/$DB*.001
  ;;
  RESTOREWORK)
    case $CASE in
      1 | 2)
      ;;
      3)
        ONLINEBACKUPTIMENORMALWTIHLOGSWORK=`cat $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSWORK.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIGWTIHLOGS=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIGWTIHLOGS2=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS2.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        printf "Restore into source DB $DB\n"
        printf "Restore database just FROM tablespace backups into original DB\n"
        smooth_drop $DB $CONTAINERPATH
        db2 -v "RESTORE DATABASE $DB rebuild with all tablespaces in image FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSWORK DBPATH on '$CONTAINERPATH/metadata/$DB' LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore failed Returns"
        db2 get db cfg for $DB|grep LOG
        db2 -v "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
        RC=$?
        check_RC $RC "Rollforward failed Returns"
        rm -rf $PWD/logretain/*
        db2 -v  "RESTORE DATABASE $DB tablespace FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGS LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore BIG failed"
        db2 -v "rollforward database $DB stop tablespace(BSPACE) overflow log path ('$PWD/logretain') "
        RC=$?
        check_RC $RC "Rollforward failed Returns"
        rm -rf $PWD/logretain/*
        db2 -v  "RESTORE DATABASE $DB tablespace FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGS2 LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore BIG2 failed"
        db2 -v "rollforward database $DB stop tablespace(NSPACE) overflow log path ('$PWD/logretain') "
        RC=$?
        check_RC $RC "Rollforward failed Returns"
        db2 update db cfg for $DB using NEWLOGPATH $CONTAINERPATH/log/$DB
        db2 connect to $DB
        db2 connect reset
      ;;
      4)
        ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK=`cat $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK=`cat $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIGWTIHLOGS2=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS2.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIGWTIHLOGS=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        printf "Restore Database out of incremental tablespace backups $DB\n"
        smooth_drop $DB $CONTAINERPATH
    
        db2 -v "RESTORE DATABASE $DB REBUILD WITH all tablespaces in image INCREMENTAL FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK DBPATH ON '$CONTAINERPATH/metadata/$DB' LOGTARGET '$PWD/logretain' NEWLOGPATH $CONTAINERPATH/log/$DB REDIRECT WITHOUT PROMPTING "
        RC=$?
        check_RC $RC "Redirect Restore incremental pre Work failed Return"
        db2 -v "SET STOGROUP PATHS FOR IBMSTOGROUP ON '$CONTAINERPATH/tablespace/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_U ON '$CONTAINERPATH/TS_U_SPACE/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_M ON '$CONTAINERPATH/TS_M_SPACE/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_B ON '$CONTAINERPATH/TS_B_SPACE/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_N ON '$CONTAINERPATH/TS_N_SPACE/$DB' "
        db2 -v "RESTORE DATABASE $DB CONTINUE"
        RC=$?
        check_RC $RC "Redirect Restore incremental pre Work failed Return"
    
        db2 -v "RESTORE DATABASE $DB incremental FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore incremental full failed Returns"
        db2 -v "RESTORE DATABASE $DB incremental FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore incremental failed Returns"
        db2 -v "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
        RC=$?
        check_RC $RC "Rollforward failed Returns"
#        db2 update db cfg for $DB using NEWLOGPATH $CONTAINERPATH/log/$DB
        db2 connect to $DB
        db2 connect reset
        rm -rf $PWD/logretain/*
        db2 -v "RESTORE DATABASE $DB tablespace (BSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGS LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore failed Returns"
        db2 -v "rollforward database $DB to end of backup and stop tablespace(BSPACE) overflow log path ('$PWD/logretain') "
        RC=$?
        check_RC $RC "Rollforward failed Returns"
        rm -rf $PWD/logretain/*
        db2 -v "RESTORE DATABASE $DB tablespace (NSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGS2 LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore failed Returns"
        db2 -v "rollforward database $DB to end of backup and stop tablespace(NSPACE) overflow log path ('$PWD/logretain') "
        RC=$?
        check_RC $RC "Rollforward failed Returns"
      ;;
      *)
        echo Case is not valid
        exit 8
      ;;
    esac
    ;;

  RESTOREREBUILD)
    case $CASE in
      4)
        ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK=`cat $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK=`cat $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIGWTIHLOGS2=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS2.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIGWTIHLOGS=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        printf "Restore Database out of incremental tablespace backups $DB\n"
        smooth_drop $DB $REPLACEPATH
    
        db2 -v "RESTORE DATABASE $DB REBUILD WITH all tablespaces in image INCREMENTAL FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK ON '$REPLACEPATH/tablespace/$DB' DBPATH ON '$REPLACEPATH/metadata/$DB' LOGTARGET '$PWD/logretain' NEWLOGPATH $REPLACEPATH/log/$DB REDIRECT WITHOUT PROMPTING "
        RC=$?
        check_RC $RC "Redirect Restore incremental pre Work failed Return"
        db2 -v "SET STOGROUP PATHS FOR IBMSTOGROUP ON '$REPLACEPATH/tablespace/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_U ON '$REPLACEPATH/TS_U_SPACE/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_M ON '$REPLACEPATH/TS_M_SPACE/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_B ON '$REPLACEPATH/TS_B_SPACE/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_N ON '$REPLACEPATH/TS_N_SPACE/$DB' "
        db2 -v "RESTORE DATABASE $DB CONTINUE"
        RC=$?
        check_RC $RC "Redirect Restore incremental pre Work failed Return"
    
        db2 -v "RESTORE DATABASE $DB incremental FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore incremental full failed Returns"
        db2 -v "RESTORE DATABASE $DB incremental FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore incremental failed Returns"
        db2 -v "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
        RC=$?
        check_RC $RC "Rollforward failed Returns"

        db2 connect to $DB
        db2 connect reset
        rm -rf $PWD/logretain/*
        db2 -v "RESTORE DATABASE $DB tablespace (BSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGS LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore failed Returns"

        echo "List log Files after restore tablespace:" `ls -R $PWD/logretain`
        db2 -v "rollforward database $DB to end of backup and stop tablespace(BSPACE) overflow log path ('$PWD/logretain')"
        RC=$?
        check_RC $RC "Rollforward failed Returns"

        rm -rf $PWD/logretain/*
        db2 -v "RESTORE DATABASE $DB tablespace (NSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGS2 LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore failed Returns"

        echo "List log Files after restore tablespace:" `ls -R $PWD/logretain`
        db2 -v "rollforward database $DB to end of backup and stop tablespace(NSPACE) overflow log path ('$PWD/logretain')"
        RC=$?
        check_RC $RC "Rollforward failed Returns"
        db2 connect to $DB user db2it99
        db2 grant dbadm on database to user db2opt
        db2 connect reset
      ;;
      *)
        echo Case is not valid
        exit 8
      ;;
    esac
    ;;
  RESTORE)
    echo "RESTORE CASE"
    case $CASE in
      1)
        OFFLINEBACKUPTIMENORMAL=`cat $BACKUPPATH/OFFLINEBACKUPTIMENORMAL.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        OFFLINEBACKUPTIMEBIG=`cat $BACKUPPATH/OFFLINEBACKUPTIMEBIG.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        OFFLINEBACKUPTIMEBIG2=`cat $BACKUPPATH/OFFLINEBACKUPTIMEBIG2.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        printf "Restore into source DB $DB\n"
        printf "Restore database just FROM tablespace backups into original DB\n"
        smooth_drop $DB $CONTAINERPATH
        db2 -v "RESTORE DATABASE $DB rebuild with all tablespaces in image FROM $BACKUPPATH TAKEN AT $OFFLINEBACKUPTIMENORMAL DBPATH on '$CONTAINERPATH/metadata/$DB' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore failed Returns"
        db2 -v "rollforward database $DB to end of logs and stop "
        RC=$?
        check_RC $RC "Rollforward failed Returns"
        db2 -v "RESTORE DATABASE $DB tablespace(BSPACE) FROM $BACKUPPATH TAKEN AT $OFFLINEBACKUPTIMEBIG WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore BIG failed"
        db2 -v "rollforward database $DB to end of logs and stop"
        RC=$?
        check_RC $RC "Rollforward database with BIG failed"
        db2 -v "RESTORE DATABASE $DB tablespace(NSPACE) FROM $BACKUPPATH TAKEN AT $OFFLINEBACKUPTIMEBIG2 WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore BIG2 failed"
        db2 -v "rollforward database $DB to end of logs and stop"
        RC=$?
        check_RC $RC "Rollforward database with BIG2 failed"
      ;;
      2)
        ONLINEBACKUPTIMENORMAL=`cat $BACKUPPATH/ONLINEBACKUPTIMENORMAL.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIG=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIG.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIG2=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIG2.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        printf "Restore into source DB $DB\n"
        printf "Restore database just FROM tablespace backups into original DB\n"
        mkdir -p $CONTAINERPATH/helplog
        cp -R $CONTAINERPATH/log/archlog/$DB/* $CONTAINERPATH/helplog
        smooth_drop $DB $CONTAINERPATH
    
        db2 -v "RESTORE DATABASE $DB rebuild with all tablespaces in image FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMAL on '$CONTAINERPATH/tablespace/$DB' DBPATH on '$CONTAINERPATH/metadata/$DB' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC  "Restore failed Returns"
        db2 -v "rollforward database $DB to end of backup and stop"
        RC=$?
        check_RC $RC  "Rollforward failed Returns"
        db2 -v "RESTORE DATABASE $DB tablespace(BSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIG WITHOUT PROMPTING"
        RC=$?
        check_RC $RC  "Restore BIG failed"
        db2 -v "rollforward database $DB to end of backup and stop tablespace(BSPACE)"
        RC=$?
        check_RC $RC  "Rollforward database with BIG failed"
        db2 -v "RESTORE DATABASE $DB tablespace(NSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIG2 WITHOUT PROMPTING"
        RC=$?
        check_RC $RC  "Restore BIG2 failed"
        db2 -v "rollforward database $DB to end of backup and stop tablespace(NSPACE)"
        RC=$?
        check_RC $RC  "Rollforward database with BIG failed"
      ;;
      3)
        ONLINEBACKUPTIMENORMALWTIHLOGS=`cat $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGS.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIGWTIHLOGS=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIGWTIHLOGS2=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS2.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        printf "Restore into source DB $DB\n"
        printf "Restore database just FROM tablespace backups into original DB\n"
        smooth_drop $DB $CONTAINERPATH
        db2 -v "RESTORE DATABASE $DB rebuild with all tablespaces in database  FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGS DBPATH on '$CONTAINERPATH/metadata/$DB'  LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
#        db2 -v "RESTORE DATABASE $DB rebuild with all tablespaces in image FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGS on '$CONTAINERPATH/tablespace/$DB' DBPATH on '$CONTAINERPATH/metadata/$DB' LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore failed Returns"
        db2 get db cfg for $DB|grep LOG
        db2 -v "rollforward database $DB to end of backup and stop overflow log path ('$PWD/logretain')"
#        db2 -v "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
        RC=$?
        check_RC $RC "Rollforward failed Returns"
#        rm -rf $PWD/logretain/*
#        db2 -v  "RESTORE DATABASE $DB tablespace FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGS LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
#        RC=$?
#        check_RC $RC "Restore BIG failed"
#        db2 -v "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
#        RC=$?
#        check_RC $RC "Rollforward failed Returns"
#        rm -rf $PWD/logretain/*
#        db2 -v  "RESTORE DATABASE $DB tablespace FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGS2 LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
#        RC=$?
#        check_RC $RC "Restore BIG2 failed"
#        db2 -v "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
#        RC=$?
#        check_RC $RC "Rollforward failed Returns"
#        db2 update db cfg for $DB using NEWLOGPATH $CONTAINERPATH/log/$DB
#        db2 connect to $DB
#        db2 connect reset
      ;;
      4)
        echo "Incremental "
        ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2=`cat $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMENORMALWTIHLOGSFULL=`cat $BACKUPPATH/ONLINEBACKUPTIMENORMALWTIHLOGSFULL.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIGWTIHLOGS=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        ONLINEBACKUPTIMEBIGWTIHLOGS2=`cat $BACKUPPATH/ONLINEBACKUPTIMEBIGWTIHLOGS2.out|grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}'`
        printf "Restore Database out of incremental tablespace backups $DB\n"
        smooth_drop $DB $CONTAINERPATH
    
        db2 -v "RESTORE DATABASE $DB REBUILD WITH all tablespaces in image INCREMENTAL FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2 DBPATH ON '$CONTAINERPATH/metadata/$DB' LOGTARGET '$PWD/logretain' NEWLOGPATH $CONTAINERPATH/log/$DB REDIRECT WITHOUT PROMPTING "
        RC=$?
        check_RC $RC "Redirect Restore incremental pre Work failed Return"
        db2 -v "SET STOGROUP PATHS FOR IBMSTOGROUP ON '$CONTAINERPATH/tablespace/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_U ON '$CONTAINERPATH/TS_U_SPACE/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_M ON '$CONTAINERPATH/TS_M_SPACE/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_B ON '$CONTAINERPATH/TS_B_SPACE/$DB' "
        db2 -v "SET STOGROUP PATHS FOR TS_N ON '$CONTAINERPATH/TS_N_SPACE/$DB' "
        db2 -v "RESTORE DATABASE $DB CONTINUE"
        RC=$?
        check_RC $RC "Redirect Restore incremental pre Work failed Return"
    
        db2 -v "RESTORE DATABASE $DB incremental FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSFULL LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore incremental full failed Returns"
        db2 -v "RESTORE DATABASE $DB incremental FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2 LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore incremental failed Returns"
        db2 -v "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
        RC=$?
        check_RC $RC "Rollforward failed Returns"
        rm -rf $PWD/logretain/*
#        db2 -v "RESTORE DATABASE $DB tablespace FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGS LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        db2 -v "RESTORE DATABASE $DB tablespace (BSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGS LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore failed Returns"

        echo "List log Files after restore tablespace:" `ls -R $PWD/logretain`
        db2 -v "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
        RC=$?
        check_RC $RC "Rollforward failed Returns"

        db2 -v "RESTORE DATABASE $DB tablespace (NSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGS2 LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
        RC=$?
        check_RC $RC "Restore failed Returns"

        echo "List log Files after restore tablespace:" `ls -R $PWD/logretain`
        db2 -v "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
        RC=$?
        check_RC $RC "Rollforward failed Returns"
#        db2 update db cfg for $DB using NEWLOGPATH $CONTAINERPATH/log/$DB
        db2 connect to $DB
        db2 connect reset
      ;;
      *)
        echo Case is not valid
        exit 8
      ;;
    esac
    ;;
    
  *)
    echo wrong mode
    exit 8
  ;;
esac
db2 -v  "connect to $DB"
db2 -v  "select max(ind) FROM $QUAL.tablea"
db2 -v  "select max(ind) FROM $QUAL.tableb"
db2 -v  "select max(ind) FROM $QUAL.tablec"
db2 -v  "select max(ind) FROM $QUAL.tablem"
db2 -v  "select max(ind) FROM $QUAL.tablen"
db2 -v  "SELECT DBPARTITIONNUM, char(TYPE,40), char(PATH,100) FROM TABLE(ADMIN_LIST_DB_PATHS()) AS FILES"
db2 -v  "connect reset"
    
db2 terminate
