#!/usr/bin/bash
#############################################################################
## Licensed Materials - Property of BRZ
##
## Governed under the terms of the International
## License Agreement for Non-Warranted Sample Code.
##
## (C) COPYRIGHT Bundesrechenzentrum 
## All Rights Reserved.
## Author : Wolfgang Brandl
#############################################################################

# This Script should test a specific backup / restore scenario
# There a several steps which could be executed


#Die folgenden Szenarien sollen mit diesem Skript nachgestellt werden können.
#Es gibt eine Datenbank in der zwei Tablespaces alte Daten enthalten. Diese Archived - Data sind sehr grosz und werden nicht mehr verändert und stehen für die laufenden Transaktionen nur mehr lesend zur Verfügung.
#1.	In der Datenbank wird eine Tabelle zerstört
#  a.	Restore des Tablespaces welcher die Tabelle enthält in die active Datenbank to point in time RESTOREINTOEXIST
#  b.	Restore des Tablespaces welcher die zerstörte Tabelle enthält in eine neue Datenbank (REDIRECT)
#2.	Datenbank ist zerstört
#  a.	Archive Logs sind noch vorhanden RESTOREWITHARCHLOGS
#  b.	Archive logs sind nicht vorhanden. Dadurch kann nicht vollständig recovered werden. RESTOREWITHOUTARCHLOGS




CONTAINERPATH=/node1/data0/db2/S2T01/IT99
LOGCONTAINERPATH=/node1/logs/db2/S2T01/IT99
REPLACEPATH=/node1/data0/db2/S2T01/OPTIM
REPLACELOGPATH=/node1/logs/db2/S2T01/OPTIM
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
  printf "Usage: test_tablespace_restore.bash -m <MODE> -s <Databasename Source> \n"
  printf " -m <MODE>\n"
  printf "   MODE can be:\n"
  printf "       INITDB:                               Initialisieren, bef�uellen und Backup der Datenbank\n"
  printf "       DROPDB:                               Loeschen der Datenbank\n"
  printf "       WORK:                                 Make additional work  and backup\n"
  printf "       WORKWITHREORGRUNSTATBIG:              Make additional work and run reorg and runstat on the big tables to generate additional log entries for BIG tablespaces\n"
  printf "       WORKTIME:                             Make additional work make a timestamp and delete a table TABLEM\n"
  printf "       BACKUPBIG:                            If Backup is needed for the big tablespaces\n"
  printf "       CHECK:                                Check records of Database and tablespace State\n"
  printf "  DROPED TABLE recover Test\n"
  printf "       WORKDROP:                             Drop Table TABLEM \n"
  printf "       CREATEDROPEDTABLE:                    Create TABLEM \n"
  printf "       IMPORTTABLEM:                         Import droped table \n"
  printf "       RESTOREDROPEDTABLE:                   Restore one tablespace into other instance and generate import File\n"
  printf "  Load Test\n"
  printf "       EXPORTTABLEA:                         Export content of TABLEA\n"
  printf "       FILLTABLEA:                           Fill table TABLEA with data\n"
  printf "       CHGTABLEANOGENERATEDCOLUMN:           Export/Drop/Create witout generated column/import TABLEA\n"
  printf "       BACKUPFULLONLINE:                     Backup Database Full Online\n"
  printf "       BACKUPINCONLINE:                      Backup Database incremental Online\n"
  printf "       EMPTYTABLEA      :                    Empty Table TABLEA without Transaction Logs\n"
  printf "       LOADTABLEANONRECOVERABLE:             Load data of TABLEA nonrecoverable\n"
  printf "       LOADTABLEACOPYYES:                    Load data of TABLEA with copy yes into BACKUP Directory\n"
  printf "       RECOVERDATABASEFROMFULL:              Recover Database: Restore/Rollforward from Full Backup to end of logs\n"
  printf "       RECOVERDATABASEFROMINC:               Recover Database: Restore/Rollforward from Incremental Backup to end of logs\n"
  printf "  Crash Recovery Datenbank ist zerstoert\n"
  printf "       RESTOREWITHARCHLOGSREDIRECT:          Restore Database to end of archlogs in other Instance\n"
  printf "       RESTOREWITHARCHLOGS:                  Restore Database to end of archlogs\n"
  printf "       RESTOREWITHOUTARCHLOGS:               Restore Crash recovery\n"
  printf "  Human errort\n"
  printf "       RESTOREONETABLESPACE:                 Restore one tablespace into other instance and rollforward to timestamp . You have to run WORKTIME before \n"
  printf "       RESTOREINTOEXIST:                     Restore one tablespace into existing DB with rollforward to timestamp You have to run WORKTIME before \n"
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
  INITDB)
    rm -f $BACKUPPATH/"$DB".*.001
    rm -f $BACKUPPATH/"$DB"ONLINE*.out
    rm -f $BACKUPPATH/"$DB"LOAD*.out
    smooth_drop "$DB" $CONTAINERPATH $LOGCONTAINERPATH
    create_db "$DB" $CONTAINERPATH $LOGCONTAINERPATH
    printf "Aufsetzen der Datenbanknk %s incremental online Backups\n" "$DB"
    db2 -v "update db cfg for $DB using logarchmeth1 disk:$LOGCONTAINERPATH/log/archlog/$DB"
    db2 -v "update db cfg for $DB using TRACKMOD YES"
    db2 +o connect to "$DB"
    db2 +o connect reset
    db2 +o backup database "$DB" to /dev/null
    db2 +o backup database "$DB" to /dev/null
    db2 +o backup database "$DB" online to /dev/null
    db2 +o backup database "$DB" online incremental to /dev/null
#   CREATE SYSTOOLSPACE by calling procedure get_dbsize_info
    db2 +o  connect to "$DB"
    db2 -v "call get_dbsize_info(?,?,?,-1)"
    db2 +o connect reset
#
    db2 +o  connect to "$DB"
    db2 -v  "CREATE STOGROUP TS_U ON '$CONTAINERPATH/TS_U_SPACE/$DB' "
    db2 -v  "CREATE STOGROUP TS_M ON '$CONTAINERPATH/TS_M_SPACE/$DB' "
    db2 -v  "CREATE STOGROUP TS_B ON '$CONTAINERPATH/TS_B_SPACE/$DB' "
    db2 -v  "CREATE STOGROUP TS_N ON '$CONTAINERPATH/TS_N_SPACE/$DB' "
    db2 -v  create tablespace NSPACE USING STOGROUP TS_N
    db2 -v  create tablespace BSPACE USING STOGROUP TS_B
    db2 -v  create tablespace URSPACE USING STOGROUP TS_U
    db2 -v  create tablespace MYSPACE USING STOGROUP TS_M
    db2 +o connect reset
    create_table "$DB" TABLEN NSPACE
    create_table "$DB" TABLEB BSPACE
    insert_into_table "$DB" $QUAL.TABLEB $countbig &
    insert_into_table "$DB" $QUAL.TABLEN $countbig &
    wait
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,NSPACE) online  to $BACKUPPATH include logs" | tee   $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE.out
    RC=$?
    ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE.out)
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,BSPACE) online to $BACKUPPATH  include logs" | tee   $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE.out
    RC=$?
    ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE.out)
    rm -rf $LOGCONTAINERPATH/log/archlog/"$DB"/*
    
    ls -l $LOGCONTAINERPATH/log/archlog/"$DB"/*
    db2 get db cfg for "$DB"|grep "First active log file"
    create_table "$DB" TABLEA USERSPACE1
    create_table "$DB" TABLEC URSPACE
    create_table "$DB" TABLEM MYSPACE
    create_table "$DB" TABLEG USERSPACE1
    
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,SYSTOOLSPACE,USERSPACE1,URSPACE,MYSPACE) online to $BACKUPPATH include logs" | tee   $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSFULL.out
    RC=$?
    ONLINEBACKUPTIMENORMALWTIHLOGSFULL=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSFULL.out)
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    wait
    db2 -v "backup database $DB tablespace (SYSCATSPACE,SYSTOOLSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental to $BACKUPPATH include logs" | tee $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out
    RC=$?
    ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out)
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    wait
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    
    db2 get db cfg for "$DB"|grep "First active log file"
    
    db2 -v "backup database $DB tablespace (SYSCATSPACE,SYSTOOLSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental  to $BACKUPPATH include logs" | tee $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out
    RC=$?
    ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out)
    chmod g+r $BACKUPPATH/"$DB"*.001
    wait
  ;;
  DROPDB)
    rm -f $BACKUPPATH/"$DB".*.001
    rm -f $BACKUPPATH/"$DB".ONLINE*.out
    rm -f $BACKUPPATH/"$DB".LOAD*.out
    smooth_drop "$DB" $CONTAINERPATH $LOGCONTAINERPATH
  ;;
  WORK)
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEM &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEG &
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,SYSTOOLSPACE,USERSPACE1,URSPACE,MYSPACE) online  to $BACKUPPATH include logs" | tee $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK.out
    RC=$?
    ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK.out)
    wait
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEM &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEG &
    mon_table "$DB"
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,SYSTOOLSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental  to $BACKUPPATH include logs" | tee $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK.out
    RC=$?
    ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out)
    chmod g+r $BACKUPPATH/"$DB"*.001
    wait
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEM &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEG &
    wait
  ;;
  WORKWITHREORGRUNSTATBIG)
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEM &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEG &
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,SYSTOOLSPACE,USERSPACE1,URSPACE,MYSPACE) online  to $BACKUPPATH include logs" | tee $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK.out
    RC=$?
    ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK.out)
    wait
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEM &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEG &
    db2 connect to "$DB"
    db2 -v "runstats on table $QUAL.TABLEN with distribution and sampled detailed indexes all ALLOW WRITE ACCESS"
    db2 -v "runstats on table $QUAL.TABLEB with distribution and sampled detailed indexes all ALLOW WRITE ACCESS"
    db2 -v "REORG INDEXES ALL FOR TABLE $QUAL.TABLEN "
    db2 -v "REORG INDEXES ALL FOR TABLE $QUAL.TABLEB "
    db2 terminate
    mon_table "$DB"
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,SYSTOOLSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental  to $BACKUPPATH include logs" | tee $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK.out
    RC=$?
    ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out)
    wait
    chmod g+r $BACKUPPATH/"$DB"*.001
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEM &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEG &
    wait
  ;;
  WORKTIME)
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEM &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEG &
    db2 +v  "backup database $DB tablespace (SYSCATSPACE,SYSTOOLSPACE,USERSPACE1,URSPACE,MYSPACE) online  to $BACKUPPATH include logs" | tee $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORKTIME.out
    RC=$?
    ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORKTIME=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORKTIME.out)
    chmod g+r $BACKUPPATH/"$DB"*.001
    wait
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEM &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEG &
    db2 +o  connect to "$DB"
    wait
    printf "Für den Restore brauchen wir dn UTC - Timestamp (Coordinated Universal Time, formely know as GMT) \n"
    db2 -x "select current timestamp - current timezone from sysibm.sysdummy1" | tee $BACKUPPATH/WORKTIMESTAMP.out
    db2 +o  connect reset
    sleep 5
    printf "Löschen der Inhalte von TABLEM \n"
    db2 +o  connect to "$DB"
    db2 -v  "select max(ind) FROM $QUAL.tablem"
    db2 -v "delete from $QUAL.TABLEM"
    db2 +o  connect reset
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEM &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEG &
    wait
  ;;
  BACKUPBIG)
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,NSPACE) online  to $BACKUPPATH include logs" | tee   $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE.out
    RC=$?
    ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE.out)
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,BSPACE) online to $BACKUPPATH  include logs" | tee   $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE.out
    RC=$?
    ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE.out)
  ;;
  CHECK)
    mon_table "$DB"
    exit 0
  ;;
#   End of DB Section
#   Restore a droped table
  WORKDROP)
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEM &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEG &
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,SYSTOOLSPACE,USERSPACE1,URSPACE,MYSPACE) online  to $BACKUPPATH include logs" | tee $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK.out
    RC=$?
    ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORK.out)
    wait
    insert_into_table "$DB" $QUAL.TABLEM $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEM &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEG &
    mon_table "$DB"
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,SYSTOOLSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental  to $BACKUPPATH include logs" | tee $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK.out
    RC=$?
    ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2=$(check_backup $RC $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out)
    chmod g+r $BACKUPPATH/"$DB"*.001
    wait
    db2 connect to $DB
    db2 drop table $QUAL.TABLEM
    db2 connect reset
    db2 list history dropped table since `/opt/freeware/bin/date --date "2 minutes ago" "+%Y%m%d%H%M"` for db $DB|/opt/freeware/bin/grep -A2 "Backup ID"|tail -n1| tee $BACKUPPATH/DROPBACKUPID.out
    insert_into_table "$DB" $QUAL.TABLEA $count &
    insert_into_table "$DB" $QUAL.TABLEC $count &
    insert_into_table "$DB" $QUAL.TABLEG $count &
    update_table "$DB" $QUAL.TABLEA &
    update_table "$DB" $QUAL.TABLEC &
    update_table "$DB" $QUAL.TABLEG &
    wait
  ;;
  RESTOREDROPEDTABLE)
    printf " ---------------------------------------------------------------------- \n"
    printf " Create database with just one tablespace to recover droped table       \n"
    printf " ---------------------------------------------------------------------- \n"
    ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    DROPBACKUPID=$( awk '{print $4}' $BACKUPPATH/DROPBACKUPID.out )
    smooth_drop "$DB" $REPLACEPATH $REPLACELOGPATH
    
    db2 -v "RESTORE DATABASE $DB REBUILD WITH tablespace(SYSCATSPACE,MYSPACE) incremental auto FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK 
            ON '$REPLACEPATH/tablespace/$DB' DBPATH ON '$REPLACEPATH/metadata/$DB' NEWLOGPATH $REPLACELOGPATH/log/$DB REDIRECT WITHOUT PROMPTING "
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
    db2 -v  "update db cfg for $DB using logarchmeth1 disk:$REPLACELOGPATH/log/archlog/$DB"

    rm -rf "$PWD"/logretain/*
    mkdir -p "$PWD"/dropedtable
    rm -rf "$PWD"/dropedtable/*
 
    find $LOGCONTAINERPATH/log/archlog/"$DB" -name "S*.LOG" -exec cp '{}' "$PWD"/logretain/ \;
    db2 -v "rollforward database $DB to end of logs and complete overflow log path ('$PWD/logretain') RECOVER DROPPED TABLE $DROPBACKUPID to $PWD/dropedtable"
    RC=$?
    check_RC $RC "Rollforward failed Returns"

    db2 connect to "$DB" user db2it99
    db2 grant dbadm on database to user db2opt
    db2 connect reset
  ;;
  CREATEDROPEDTABLE)
    create_tablenon_generated "$DB" TABLEM MYSPACE
  ;;

  EXPORTTABLEA)
    db2 +o connect to "$DB"
    db2 "EXPORT TO $BACKUPPATH/TABLEA.IXF OF IXF select * from $QUAL.TABLEA"
    db2 +o connect reset
  ;;
  FILLTABLEA)
    insert_into_table "$DB" $QUAL.TABLEA $count
  ;;
  CHGTABLEANOGENERATEDCOLUMN)
    db2 +o connect to "$DB"
    db2 "EXPORT TO $BACKUPPATH/TABLEA.IXF OF IXF select * from $QUAL.TABLEA"
    db2 drop table $QUAL.TABLEA
    create_tablenon_generated "$DB" TABLEA USERSPACE1
    db2 -v import FROM $BACKUPPATH/TABLEA.IXF of IXF COMMITCOUNT 2000 INSERT INTO $QUAL.TABLEA
    db2 +o connect reset
  ;;
  BACKUPFULLONLINE)
    db2 +v "backup database $DB online to $BACKUPPATH compress include logs" | tee $BACKUPPATH/"$DB"LOADTESTFULL.out
    RC=$?
    LOADTESTFULL=$(check_backup $RC $BACKUPPATH/"$DB"LOADTESTFULL.out)
  ;;
  BACKUPINCONLINE)
    db2 +v "backup database $DB online incremental to $BACKUPPATH compress include logs" | tee $BACKUPPATH/"$DB"LOADTESTINC.out
    RC=$?
    LOADTESTINC=$(check_backup $RC $BACKUPPATH/"$DB"LOADTESTINC.out)
  ;;
  EMPTYTABLEA)
    db2 +o connect to "$DB"
    db2 LOAD FROM /dev/null of DEL REPLACE INTO $QUAL.TABLEA NONRECOVERABLE
    db2 +o connect reset
  ;;
  LOADTABLEANONRECOVERABLE)
    db2 +o connect to "$DB"
    db2 LOAD FROM $BACKUPPATH/TABLEA.IXF of IXF REPLACE INTO $QUAL.TABLEA NONRECOVERABLE
    db2 +o connect reset
  ;;
  LOADTABLEACOPYYES)
    db2 +o connect to "$DB"
    db2 LOAD FROM $BACKUPPATH/TABLEA.IXF of IXF REPLACE INTO QTEST.TABLEA COPY YES TO $BACKUPPATH
    db2 +o connect reset
  ;;
  RECOVERDATABASEFROMFULL)
    LOADTESTFULL=$(< $BACKUPPATH/"$DB"LOADTESTFULL.out grep "The timestamp for this backup image is" |awk 'BEGIN{FS=":"}{print $2}')
    db2 -v "restore database $DB from $BACKUPPATH taken at $LOADTESTFULL"
    RC=$?
    check_RC $RC "Restore from Full after LOAD failed\n"
    db2 -v "rollforward db TESTS to end of logs and stop"
    RC=$?
    check_RC $RC "Rollforward failed"
  ;;
  RECOVERDATABASEFROMINC)
    LOADTESTINC=$(< $BACKUPPATH/"$DB"LOADTESTINC.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    db2 -v "restore database $DB incremental auto from $BACKUPPATH taken at $LOADTESTINC"
    RC=$?
    check_RC $RC "Restore from Full after LOAD failed\n"
    db2 -v "rollforward db TESTS to end of logs and stop"
    RC=$?
    check_RC $RC "Rollforward failed"
  ;;

# End of Load Test



  RESTOREINTOEXIST)
    printf " ---------------------------------------------------------------------- \n"
    printf " Restore just tablespace MYSPACE into existing database                 \n"
    printf " Prerequisits is that you have to run WORKTIME before                   \n"
    printf " ---------------------------------------------------------------------- \n"
    ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORKTIME=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORKTIME.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    Time=$(< $BACKUPPATH/WORKTIMESTAMP.out)
    db2 -v "RESTORE DATABASE $DB tablespace(MYSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSFULLWORKTIME"
    RC=$?
    check_RC $RC "Restore just MYSPACE tablespace into existing database \n"
    db2 -v "rollforward database $DB to $Time and complete tablespace(MYSPACE)"
    RC=$?
    check_RC $RC "Rollforward failed Returns"
  ;;
  IMPORTTABLEM)
    printf " ---------------------------------------------------------------------- \n"
    printf " Import droped table TABLEM                                             \n"
    printf " ---------------------------------------------------------------------- \n"
    db2 connect to $DB
    db2 import from "$PWD"/dropedtable/N*/data of DEL insert into $QUAL.TABLEM
    db2 connect reset
  ;;

  RESTOREONETABLESPACE)
    printf " ---------------------------------------------------------------------- \n"
    printf " Create database with just one tablespace and rollforward to timestamp  \n"
    printf " in another DB2 Instance                                                \n"
    printf " ---------------------------------------------------------------------- \n"
    ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    Time=$(< $BACKUPPATH/WORKTIMESTAMP.out)
    smooth_drop "$DB" $REPLACEPATH $REPLACELOGPATH
    
    db2 -v "RESTORE DATABASE $DB REBUILD WITH tablespace(SYSCATSPACE,MYSPACE) incremental auto FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK 
            ON '$REPLACEPATH/tablespace/$DB' DBPATH ON '$REPLACEPATH/metadata/$DB' NEWLOGPATH $REPLACELOGPATH/log/$DB REDIRECT WITHOUT PROMPTING "
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
    db2 -v  "update db cfg for $DB using logarchmeth1 disk:$REPLACELOGPATH/log/archlog/$DB"

    echo "$Time"

    rm -rf "$PWD"/logretain/*
 
    find $LOGCONTAINERPATH/log/archlog/"$DB" -name "S*.LOG" -exec cp '{}' "$PWD"/logretain/ \;
    db2 -v "rollforward database $DB to $Time and complete overflow log path ('$PWD/logretain')"
    RC=$?
    check_RC $RC "Rollforward failed Returns"

    db2 connect to "$DB" user db2it99
    db2 grant dbadm on database to user db2opt
    db2 connect reset
  ;;
  RESTOREWITHARCHLOGSREDIRECT)
    printf " ---------------------------------------------------------------------------- \n"
    printf "RESTORE original Database with still existing archival logs in other Instance \n"
    printf " ---------------------------------------------------------------------------- \n"
    smooth_drop "$DB" $REPLACEPATH $REPLACELOGPATH
    ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    db2 -v "restore db $DB rebuild with all tablespaces in image incremental auto from $BACKUPPATH taken at $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK DBPATH ON $REPLACEPATH/metadata/$DB logtarget $PWD/logretain NEWLOGPATH $REPLACELOGPATH/log/$DB REDIRECT WITHOUT PROMPTING"
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

    find $LOGCONTAINERPATH/log/archlog/"$DB" -name "S*.LOG" -exec cp '{}' "$PWD"/logretain/ \;

    db2 -v "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
    RC=$?
    check_RC $RC "Rollforward failed Returns"
    db2 connect to "$DB"
    db2 connect reset
    mon_table "$DB"
    rm -rf "$PWD"/logretain/*
    db2 -v "RESTORE DATABASE $DB tablespace (BSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE LOGTARGET $PWD/logretain WITHOUT PROMPTING"
    RC=$?
    check_RC $RC "Restore failed Returns"

    echo "List log Files after restore tablespace:" $(ls -R "$PWD"/logretain)
    db2 -v "rollforward database $DB to end of backup and stop tablespace(BSPACE) overflow log path ('$PWD/logretain')"
    RC=$?
    check_RC $RC "Rollforward failed Returns"

    rm -rf "$PWD"/logretain/*
    db2 -v "RESTORE DATABASE $DB tablespace (NSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE LOGTARGET $PWD/logretain WITHOUT PROMPTING"
    RC=$?
    check_RC $RC "Restore failed Returns"

    echo "List log Files after restore tablespace:" $(ls -R "$PWD"/logretain)
    db2 -v "rollforward database $DB to end of backup and stop tablespace(NSPACE) overflow log path ('$PWD/logretain')"
    RC=$?
    check_RC $RC "Rollforward failed Returns"
    db2 connect to "$DB" user db2it99
    db2 grant dbadm on database to user db2opt
    db2 connect reset
  ;;
  RESTOREWITHARCHLOGS)
    printf " ---------------------------------------------------------------------- \n"
    printf "RESTORE original Database with still existing archival logs             \n"
    printf " ---------------------------------------------------------------------- \n"
    smooth_drop_without_archive_logs "$DB" $CONTAINERPATH $LOGCONTAINERPATH
    db2 connect reset
    ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    db2 -v "restore db $DB rebuild with all tablespaces in image incremental auto from $BACKUPPATH taken at $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK DBPATH ON $CONTAINERPATH/metadata/$DB LOGTARGET $PWD/logretain"
    RC=$?
    check_RC $RC "Restore incremental full failed Returns"
    db2 -v "rollforward db $DB to end of logs and stop overflow log path ('$PWD/logretain')"
    RC=$?
    check_RC $RC "Rollforward db $DB failed Returns"
    db2 -v "RESTORE DATABASE $DB tablespace (BSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE LOGTARGET $PWD/logretain WITHOUT PROMPTING"
    RC=$?
    check_RC $RC "Restore failed Returns"
    db2 -v "rollforward database $DB to end of backup and stop tablespace (BSPACE) overflow log path ('$PWD/logretain')"
    RC=$?
    check_RC $RC "Rollforward failed Returns"
    db2 -v "RESTORE DATABASE $DB tablespace (NSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE LOGTARGET $PWD/logretain WITHOUT PROMPTING"
    RC=$?
    check_RC $RC "Restore failed Returns"
    db2 -v "rollforward database $DB to end of backup and stop tablespace (NSPACE) overflow log path ('$PWD/logretain')"
    RC=$?
    check_RC $RC "Rollforward failed Returns"
  ;;
  RESTOREWITHOUTARCHLOGS)
    printf " ---------------------------------------------------------------------- \n"
    printf "RESTORE original Database without Archival logs left                    \n"
    printf " ---------------------------------------------------------------------- \n"
    smooth_drop "$DB" $CONTAINERPATH $LOGCONTAINERPATH
    ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE=$(< $BACKUPPATH/"$DB"ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE.out grep "The timestamp for this backup image is"|awk 'BEGIN{FS=":"}{print $2}')
    db2 -v "restore db $DB rebuild with all tablespaces in image incremental auto from $BACKUPPATH taken at $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2WORK DBPATH ON $CONTAINERPATH/metadata/$DB LOGTARGET $PWD/logretain"
    RC=$?
    check_RC $RC "Recover from inceremental images"
    db2 -v "rollforward db $DB to end of logs and stop overflow log path ('$PWD/logretain')"
    RC=$?
    check_RC $RC "Rollforward failed Returns"
    db2 -v "RESTORE DATABASE $DB tablespace (BSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGSBSPACE LOGTARGET $PWD/logretain WITHOUT PROMPTING"
    RC=$?
    check_RC $RC "Restore failed Returns"
    db2 -v "rollforward database $DB to end of backup and stop tablespace (BSPACE) overflow log path ('$PWD/logretain')"
    RC=$?
    check_RC $RC "Rollforward failed Returns"
    db2 -v "RESTORE DATABASE $DB tablespace (NSPACE) FROM $BACKUPPATH TAKEN AT $ONLINEBACKUPTIMEBIGWTIHLOGSNSPACE LOGTARGET $PWD/logretain WITHOUT PROMPTING"
    RC=$?
    check_RC $RC "Restore failed Returns"
    db2 -v "rollforward database $DB to end of backup and stop tablespace (NSPACE) overflow log path ('$PWD/logretain')"
    RC=$?
    check_RC $RC "Rollforward failed Returns"
  ;;
  *)
    echo wrong mode
    exit 8
  ;;
esac

mon_table "$DB"
mon_tablespace "$DB"
mon_container "$DB"
    
db2 terminate
