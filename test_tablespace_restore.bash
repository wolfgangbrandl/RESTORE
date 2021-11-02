#!/usr/bin/bash
CONTAINERPATH=/products/home/db2it99
#-------------------------------------------------------
# stoppt alle Applikationen fuer die mitgegebene DB
function force ()
{
for a in `db2 list applications|grep $1|awk '{print $3}'`
do
  echo force Application $a
  db2 force application \($a\)
done
}

#-------------------------------------------------------
# Versucht die mitgegebene Datenbank zu stoppen und dann zu koeschen
function smooth_drop ()
{
  DBT=$1
  force $DBT
  db2 "connect to $DBT"
  RC=$?
  if [ $RC -ne 0 ]
    then
      echo  Database $DBT does not exist
      db2 uncatalog database $DBT
      return 8
  fi
  db2 "QUIESCE DATABASE IMMEDIATE FORCE CONNECTIONS"
  db2 "UNQUIESCE DATABASE"
  db2 "connect reset"
  db2 "drop database $DBT"
  db2 uncatalog database $DBT
}

#-------------------------------------------------------
# MAIN
# -------------------------------------------------
while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -c|--case)
    CASE="$2"
    shift # past argument
    ;;
    -s|--sourcedb)
    DB="$2"
    shift # past argument
    ;;
    -r|--restoredb)
    DBR="$2"
    shift # past argument
    ;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done
if [ "$DB" == "" -o "$DBR" == "" ]
then
  printf "Usage: test_tablespace_restore.bash -c <CASE> -s <Databasename Source> -r <Databasename rebuild>\n"
  printf "CASE: 1:restore into same database\n"
  printf "CASE: 2:restore tablespace Backup into rebuild database\n"
  printf "CASE: 3:restore full Backup image into rebuild database\n"
  printf "CASE: 4:Recover Database just from tablespace backups\n"
  printf "Please add the name of the Databases\n"
  exit 8
fi

rm -f $DB.*.001
smooth_drop $DB
smooth_drop $DBR
printf "Anlegen der Source Datenbank $DB\n"
mkdir -p $CONTAINERPATH/tablespace/$DB 
mkdir -p $CONTAINERPATH/tablespaceu/$DB 
mkdir -p $CONTAINERPATH/tablespacem/$DB 
mkdir -p $CONTAINERPATH/tablespaceb/$DB 
mkdir -p $CONTAINERPATH/metadata/$DB 
mkdir -p $CONTAINERPATH/log/archlog/$DB 
mkdir -p $CONTAINERPATH/log/$DB 
rm -rf  $CONTAINERPATH/tablespace/$DB/* 
rm -rf  $CONTAINERPATH/tablespaceu/$DB/* 
rm -rf  $CONTAINERPATH/tablespacem/$DB/* 
rm -rf  $CONTAINERPATH/tablespaceb/$DB/* 
rm -rf  $CONTAINERPATH/metadata/$DB/* 
rm -rf  $CONTAINERPATH/log/archlog/$DB/* 
rm -rf  $CONTAINERPATH/log/$DB/* 
db2 -v  "create database $DB on '$CONTAINERPATH/tablespace/$DB' DBPATH on '$CONTAINERPATH/metadata/$DB' "
db2 -v  "connect to $DB"
printf "Aufsetzen der Datenbabnk $DB für archival logging\n"
db2 -v  "update db cfg using logarchmeth1 disk:$CONTAINERPATH/log/archlog/$DB"
db2 -v  "update db cfg using newlogpath $CONTAINERPATH/log/$DB"
db2 -v  "connect reset"

printf "First full offline backup\n" 

db2 -v  "backup database $DB" > T1.out
RC=$?
if [ $RC -ne 0 ]
  then
    echo BACKUP T1 failed
    exit 8
  else
    T1=`cat T1.out|awk '{print $11}'`
    cat T1.out
    # rm -f T1.out
fi
printf "Erzeugen zwei Storage Groups\n"
db2 -v  "connect to $DB"
db2 -v  "CREATE STOGROUP "TS_U" ON '$CONTAINERPATH/tablespaceu/$DB' "
db2 -v  "CREATE STOGROUP "TS_M" ON '$CONTAINERPATH/tablespacem/$DB' "
db2 -v  "CREATE STOGROUP "TS_B" ON '$CONTAINERPATH/tablespaceb/$DB' "
db2 -v  "create table tablea(id int,name varchar(16)) in USERSPACE1"
db2 -v  "insert into tablea values(100,'AAA')"
db2 -v  "insert into tablea values(200,'BBB')"
db2 -v  "insert into tablea values(300,'CCC')"
printf "Erzeuge Tablespace URSPACE in Storage Group TS_U\n"
db2 -v  create tablespace URSPACE USING STOGROUP "TS_U"
db2 -v  "create table tablec(id int,name varchar(16)) in URSPACE"
db2 -v  "insert into tablec values(100,'AAA')"
db2 -v  "insert into tablec values(200,'BBB')"
db2 -v  "insert into tablec values(300,'CCC')"
db2 -v  "commit"
db2 -v  "connect reset"

printf "First full ONLINE backup\n" 
db2 -v  "backup database $DB online to . compress include logs" > T2.out
RC=$?
if [ $RC -ne 0 ]
  then
    echo BACKUP T2 failed
    exit 8
  else
    T2=`cat T2.out|awk '{print $11}'`
    cat T2.out
    # rm -f T2.out
fi

db2 -v  "connect to $DB"
printf "Erzeuge Tablespace MYSPACE in Storage Group TS_M\n"
db2 -v  create tablespace MYSPACE USING STOGROUP "TS_M"
db2 -v  "create table tablem(id int,name varchar(16)) in MYSPACE"
db2 -v  "insert into tablem values(100,'AAA')"
db2 -v  "insert into tablem values(200,'BBB')"
db2 -v  "insert into tablem values(300,'CCC')"
printf "Erzeuge Tablespace BSPACE in Storage Group TS_B\n"
db2 -v  create tablespace BSPACE USING STOGROUP "TS_B"
db2 -v  "create table tableb(id int,name varchar(16)) in BSPACE"
db2 -v  "insert into tableb values(100,'AAA')"
db2 -v  "insert into tableb values(200,'BBB')"
db2 -v  "insert into tableb values(300,'CCC')"
db2 -v  "commit"
db2 -v  "connect reset"


printf "Second full online backup \n"
db2 -v  "backup database $DB online to . compress include logs" > T3.out
RC=$?
if [ $RC -ne 0 ]
  then
    echo BACKUP T3 failed
    exit 8
  else
    T3=`cat T3.out|awk '{print $11}'`
    cat T3.out
    # rm -f T3.out
fi


db2 -v  "connect to $DB"
db2 -v  "insert into tablem values(400,'DDD')"
db2 -v  "insert into tablem values(500,'EEE')"
db2 -v  "insert into tablem values(600,'FFF')"
db2 -v  "commit"
db2 -v  "select count(*) from tablem"
db2 -v  "connect reset"

printf "tablespace backup for MYSPACE online \n"
db2 -v  "backup database $DB tablespace (MYSPACE) online" > T4.out
RC=$?
if [ $RC -ne 0 ]
  then
    echo BACKUP T4 failed
    exit 8
  else
    T4=`cat T4.out|awk '{print $11}'`
    cat T4.out
    # rm -f T4.out
fi

db2 -v  "connect to $DB"
db2 -v  "insert into tablea values(400,'DDD')"
db2 -v  "insert into tablea values(500,'EEE')"
db2 -v  "insert into tablea values(600,'FFF')"
db2 -v  "insert into tablem values(700,'GGG')"
db2 -v  "insert into tablem values(800,'HHH')"
db2 -v  "insert into tablem values(900,'III')"
db2 -v  "insert into tablec values(400,'DDD')"
db2 -v  "insert into tablec values(500,'EEE')"
db2 -v  "insert into tablec values(600,'FFF')"
db2 -v  "commit"
db2 -v  "connect reset"

printf "tablespace backup for syscatspace,MYSPACE online \n"
db2 -v  "backup database $DB tablespace (SYSCATSPACE,MYSPACE) online" >  T5.out
RC=$?
if [ $RC -ne 0 ]
  then
    echo BACKUP T5 failed
    exit 8
  else
    T5=`cat T5.out|awk '{print $11}'`
    cat T5.out
    # rm -f T5.out
fi

db2 -v  "connect to $DB"
db2 -v  "list history all for db $DB" > history_$DB.out
db2 -v  "insert into tablea values(700,'GGG')"
db2 -v  "insert into tablea values(800,'HHH')"
db2 -v  "insert into tablea values(900,'III')"
db2 -v  "commit"
db2 -v  "select count(*) from tablem"
date
Time=`db2 -x select current timestamp-current timezone from sysibm.sysdummy1`
printf "Fuer den restore brauchen wir den UTC (Coordinated Universal Time, formerly known as GMT) timestamp: $Time \n"
sleep 5
printf "Loesche den Inhalt von tablem\n"
db2 -v  "delete from tablem"

db2 -v  "connect reset"
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online include logs" >  T6.out
    RC=$?
    if [ $RC -ne 0 ]
      then
        echo BACKUP T6 failed
        exit 8
      else
        T6=`cat T6.out|awk '{print $11}'`
        cat T6.out
    fi
    db2 -v  "backup database $DB tablespace (BSPACE) online include logs" >  T7.out
    RC=$?
    if [ $RC -ne 0 ]
      then
        echo BACKUP T7 failed
        exit 8
      else
        T7=`cat T7.out|awk '{print $11}'`
        cat T7.out
    fi
case $CASE in
  1)
    printf "Restore into source DB $DB\n"
    db2 -v  "connect reset"
    printf "restore tables space for deleted table tablem\n"
    db2 -v  "restore database $DB tablespace(MYSPACE) taken at $T4"
    db2 -v  "rollforward database $DB to $Time and complete tablespace (MYSPACE)"
    db2 -v  "connect to $DB"
    db2 -v  "select count(*) from tablem"
    db2 -v  "insert into tablea values(1000,'JJJ')"
    db2 -v  "insert into tablea values(1100,'KKK')"
    db2 -v  "insert into tablea values(1200,'LLL')"
    db2 -v  "commit"
    db2 -v  "connect reset"
  ;;
  2)
    printf "Restore tablespaces into rebuild DB\n"
    mkdir -p $CONTAINERPATH/tablespace/$DBR
    mkdir -p $CONTAINERPATH/tablespaceu/$DBR
    mkdir -p $CONTAINERPATH/tablespacem/$DBR
    mkdir -p $CONTAINERPATH/metadata/$DBR
    mkdir -p $CONTAINERPATH/log/archlog/$DBR
    mkdir -p $CONTAINERPATH/log/$DBR
    mkdir -p $PWD/logretain
    rm -rf  $CONTAINERPATH/tablespace/$DBR/*
    rm -rf  $CONTAINERPATH/tablespaceu/$DBR/*
    rm -rf  $CONTAINERPATH/tablespacem/$DBR/*
    rm -rf  $CONTAINERPATH/metadata/$DBR/*
    rm -rf  $CONTAINERPATH/log/archlog/$DBR/*
    rm -rf  $CONTAINERPATH/log/$DBR/*
    rm -rf $PWD/logretain/*
    db2 -v  "create database $DBR on '$CONTAINERPATH/tablespace/$DBR' DBPATH on '$CONTAINERPATH/metadata/$DBR' "
    db2 -v  "connect to $DBR"
    db2 -v  "update db cfg using logarchmeth1 disk:$CONTAINERPATH/log/archlog/$DBR"
    db2 -v  "connect reset"
    db2 -v  "connect to $DBR"
    db2 -v  "restore db $DB rebuild with tablespace (syscatspace,MYSPACE) taken at $T5 into $DBR LOGTARGET '$PWD/logretain' NEWLOGPATH '$CONTAINERPATH/log/$DBR' WITH 50 BUFFERS BUFFER 8193 REDIRECT PARALLELISM 25 WITHOUT PROMPTING"
    db2 -v  "SET STOGROUP PATHS FOR TS_U ON '$CONTAINERPATH/tablespaceu/$DBR' "
    db2 -v  "SET STOGROUP PATHS FOR TS_M ON '$CONTAINERPATH/tablespacem/$DBR' "
    db2 -v  "RESTORE DATABASE $DB CONTINUE"
    rm -rf $PWD/logretain/*
    printf "Kopieren der archive Logs und Logs into overflow log path\n"
    find $CONTAINERPATH/log/archlog/$DB -name "S*.LOG" -exec cp '{}' $PWD/logretain/ \;
    find $CONTAINERPATH/log/$DB -name "S*.LOG" -exec cp '{}' $PWD/logretain/ \;
    db2 -v  "rollforward database $DBR to $Time and complete overflow log path('$PWD/logretain')"
    db2 -v  "connect to $DBR"
    db2 -v  "select count(*) from tablem"
    db2 -v  "commit"
    db2 -v  "connect reset"
  ;;
  3)
    printf "Restore full database image of $DB into rebuild DB $DBR\n"
    mkdir -p $CONTAINERPATH/tablespace/$DBR
    mkdir -p $CONTAINERPATH/tablespaceu/$DBR
    mkdir -p $CONTAINERPATH/tablespacem/$DBR
    mkdir -p $CONTAINERPATH/tablespaceb/$DBR
    mkdir -p $CONTAINERPATH/metadata/$DBR
    mkdir -p $CONTAINERPATH/log/archlog/$DBR
    mkdir -p $CONTAINERPATH/log/$DBR
    mkdir -p $PWD/logretain
    rm -rf  $CONTAINERPATH/tablespace/$DBR/*
    rm -rf  $CONTAINERPATH/tablespaceu/$DBR/*
    rm -rf  $CONTAINERPATH/tablespacem/$DBR/*
    rm -rf  $CONTAINERPATH/tablespaceb/$DBR/*
    rm -rf  $CONTAINERPATH/metadata/$DBR/*
    rm -rf  $CONTAINERPATH/log/archlog/$DBR/*
    rm -rf  $CONTAINERPATH/log/$DBR/*
    rm -rf $PWD/logretain/*
    db2 -v "create database $DBR on '$CONTAINERPATH/tablespace/$DBR' DBPATH on '$CONTAINERPATH/metadata/$DBR' "
    db2 "connect to $DBR"
    db2 -v "update db cfg using logarchmeth1 disk:$CONTAINERPATH/log/archlog/$DBR"
    db2 -v "connect reset"
    printf "Start eines Redirect Restores\n"
    db2 -v "restore db $DB from . taken at $T3 into $DBR LOGTARGET '$PWD/logretain' NEWLOGPATH '$CONTAINERPATH/log/$DBR' WITH 50 BUFFERS BUFFER 8193 REDIRECT PARALLELISM 25 WITHOUT PROMPTING"
    db2 -v "SET STOGROUP PATHS FOR TS_U ON '$CONTAINERPATH/tablespaceu/$DBR' "
    db2 -v "SET STOGROUP PATHS FOR TS_M ON '$CONTAINERPATH/tablespacem/$DBR' "
    db2 -v "RESTORE DATABASE $DB CONTINUE"
    rm -rf $PWD/logretain/*
    printf "Kopieren der archive Logs und Logs into overflow log path\n"
    find $CONTAINERPATH/log/archlog/$DB -name "S*.LOG" -exec cp '{}' $PWD/logretain/ \;
    find $CONTAINERPATH/log/$DB -name "S*.LOG" -exec cp '{}' $PWD/logretain/ \;
    db2 -v "rollforward database $DBR to $Time and complete overflow log path('$PWD/logretain')"
    db2 -v "connect to $DBR"
    db2 -v "select count(*) from tablem"
    db2 -v "commit"
    db2 -v "connect reset"
  ;;
  4)
    printf "Restore database just from tablespace backups\n"
    mkdir -p $CONTAINERPATH/tablespace/$DBR
    mkdir -p $CONTAINERPATH/tablespaceu/$DBR
    mkdir -p $CONTAINERPATH/tablespacem/$DBR
    mkdir -p $CONTAINERPATH/tablespaceb/$DBR
    mkdir -p $CONTAINERPATH/metadata/$DBR
    mkdir -p $CONTAINERPATH/log/archlog/$DBR
    mkdir -p $CONTAINERPATH/log/$DBR
    mkdir -p $PWD/logretain
    rm -rf  $CONTAINERPATH/tablespace/$DBR/*
    rm -rf  $CONTAINERPATH/tablespaceu/$DBR/*
    rm -rf  $CONTAINERPATH/tablespacem/$DBR/*
    rm -rf  $CONTAINERPATH/tablespaceb/$DBR/*
    rm -rf  $CONTAINERPATH/metadata/$DBR/*
    rm -rf  $CONTAINERPATH/log/archlog/$DBR/*
    rm -rf  $CONTAINERPATH/log/$DBR/*
    rm -rf $PWD/logretain/*
    db2 -v  "create database $DBR on '$CONTAINERPATH/tablespace/$DBR' DBPATH on '$CONTAINERPATH/metadata/$DBR' "
    db2 -v  "restore db $DB rebuild with tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) taken at $T6 into $DBR LOGTARGET '$PWD/logretain' NEWLOGPATH '$CONTAINERPATH/log/$DBR' WITH 50 BUFFERS BUFFER 8193 REDIRECT PARALLELISM 25 WITHOUT PROMPTING"
    db2 -v  "SET STOGROUP PATHS FOR TS_U ON '$CONTAINERPATH/tablespaceu/$DBR' "
    db2 -v  "SET STOGROUP PATHS FOR TS_M ON '$CONTAINERPATH/tablespacem/$DBR' "
    db2 -v  "RESTORE DATABASE $DB CONTINUE"
    db2 -v  "rollforward database $DBR to end of logs overflow log path('$PWD/logretain')"

    db2 -v  "restore db $DB tablespace (bspace) taken at $T7 into $DBR LOGTARGET '$PWD/logretain' NEWLOGPATH '$CONTAINERPATH/log/$DBR' WITH 50 BUFFERS BUFFER 8193 redirect PARALLELISM 25 WITHOUT PROMPTING"
    db2 -v  "SET STOGROUP PATHS FOR TS_B ON '$CONTAINERPATH/tablespaceb/$DBR' "
    db2 -v  "RESTORE DATABASE $DB CONTINUE"
    db2 -v  "rollforward database $DBR to end of logs overflow log path('$PWD/logretain')"
    db2 -v  "rollforward database $DBR complete overflow log path('$PWD/logretain')"

#    db2 -v  "connect to $DBR"
#    db2 -v  "select count(*) from tablea"
#    db2 -v  "select count(*) from tableb"
#    db2 -v  "select count(*) from tablem"
    db2 -v  "commit"
    db2 -v  "connect reset"
  ;;
  5)
    printf "Restore into source DB $DB\n"
    printf "Restore database just from tablespace backups into original DB\n"
    smooth_drop $DB
    mkdir -p $CONTAINERPATH/tablespace/$DB
    mkdir -p $CONTAINERPATH/tablespaceu/$DB
    mkdir -p $CONTAINERPATH/tablespacem/$DB
    mkdir -p $CONTAINERPATH/tablespaceb/$DB
    mkdir -p $CONTAINERPATH/metadata/$DB
    mkdir -p $CONTAINERPATH/log/archlog/$DB
    mkdir -p $CONTAINERPATH/log/$DB
    mkdir -p $PWD/logretain
    rm -rf  $CONTAINERPATH/tablespace/$DB/*
    rm -rf  $CONTAINERPATH/tablespaceu/$DB/*
    rm -rf  $CONTAINERPATH/tablespacem/$DB/*
    rm -rf  $CONTAINERPATH/tablespaceb/$DB/*
    rm -rf  $CONTAINERPATH/metadata/$DB/*
    rm -rf  $CONTAINERPATH/log/archlog/$DB/*
    rm -rf  $CONTAINERPATH/log/$DB/*
    rm -rf $PWD/logretain/*
    db2 -v  "create database $DB on '$CONTAINERPATH/tablespace/$DB' DBPATH on '$CONTAINERPATH/metadata/$DB' "
    db2 -v  "restore db $DB rebuild with all tablespaces in image taken at $T6 LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
    db2 -v  "rollforward database $DB to end of logs overflow log path('$PWD/logretain')"
    db2 -v  "rollforward database $DB complete"

    db2 -v  "restore db $DB tablespace taken at $T7 LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
    db2 -v  "rollforward database $DB to end of backup tablespace (BSPACE) overflow log path('$PWD/logretain')"
    db2 -v  "rollforward database $DB stop"

    db2 -v  "connect to $DBR"
    db2 -v  "select count(*) from tablea"
    db2 -v  "select count(*) from tableb"
    db2 -v  "select count(*) from tablem"
    db2 -v  "commit"
    db2 -v  "connect reset"
  ;;

  *)
    echo Case is not valid
    exit 8
  ;;
esac
db2 terminate
