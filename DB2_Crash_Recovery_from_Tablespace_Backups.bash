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
      rm -rf  $CONTAINERPATH/tablespace/$DB/* 
      rm -rf  $CONTAINERPATH/tablespaceu/$DB/* 
      rm -rf  $CONTAINERPATH/tablespacem/$DB/* 
      rm -rf  $CONTAINERPATH/tablespaceb/$DB/* 
      rm -rf  $CONTAINERPATH/metadata/$DB/* 
      rm -rf  $CONTAINERPATH/log/archlog/$DB/* 
      rm -rf  $CONTAINERPATH/log/$DB/* 
      rm -rf  $PWD/logretain/*
      return 8
  fi
  db2 "QUIESCE DATABASE IMMEDIATE FORCE CONNECTIONS"
  db2 "UNQUIESCE DATABASE"
  db2 "connect reset"
  db2 "drop database $DBT"
  db2 uncatalog database $DBT
  rm -rf  $CONTAINERPATH/tablespace/$DB/* 
  rm -rf  $CONTAINERPATH/tablespaceu/$DB/* 
  rm -rf  $CONTAINERPATH/tablespacem/$DB/* 
  rm -rf  $CONTAINERPATH/tablespaceb/$DB/* 
  rm -rf  $CONTAINERPATH/metadata/$DB/* 
  rm -rf  $CONTAINERPATH/log/archlog/$DB/* 
  rm -rf  $CONTAINERPATH/log/$DB/* 
  rm -rf  $PWD/logretain/*
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
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done
if [ "$DB" == "" ]
then
  printf "Usage: test_tablespace_restore.bash -c <CASE> -s <Databasename Source> -r <Databasename rebuild>\n"
  printf "CASE: 1:restore with offline tablespace backups\n"
  printf "CASE: 2:restore with online tablespace backups\n"
  printf "CASE: 3:restore with online tablespace backups with logs\n"
  printf "CASE: 4:restore with online incremental tablespace backups with logs\n"
  printf "Please add the name of the Databases\n"
  exit 8
fi

rm -f $DB.*.001
smooth_drop $DB
printf "Anlegen der Source Datenbank $DB\n"
mkdir -p $CONTAINERPATH/tablespace/$DB 
mkdir -p $CONTAINERPATH/tablespaceu/$DB 
mkdir -p $CONTAINERPATH/tablespacem/$DB 
mkdir -p $CONTAINERPATH/tablespaceb/$DB 
mkdir -p $CONTAINERPATH/metadata/$DB 
mkdir -p $CONTAINERPATH/log/archlog/$DB 
mkdir -p $CONTAINERPATH/log/$DB 
db2 -v  "create database $DB on '$CONTAINERPATH/tablespace/$DB' DBPATH on '$CONTAINERPATH/metadata/$DB' "
db2 -v  "connect to $DB"
printf "Aufsetzen der Datenbabnk $DB für archival logging\n"
db2 -v  "update db cfg using logarchmeth1 disk:$CONTAINERPATH/log/archlog/$DB"
db2 -v  "update db cfg using newlogpath $CONTAINERPATH/log/$DB"
case $CASE in
  1 | 2 | 3)
  ;;
  4)
    db2 -v  "update db cfg using TRACKMOD YES"
    db2 connect reset
    db2 backup database $DB to /dev/null
    db2 backup database $DB online to /dev/null
    db2 backup database $DB online incremental to /dev/null
  ;;
  *)
    echo Case is not valid
    exit 8
  ;;
esac

db2 -v  "connect reset"
db2 -v  "backup database $DB to /dev/null"
db2 -v  "backup database $DB online to /dev/null"
db2 -v  "connect to $DB"
db2 -v  "CREATE STOGROUP "TS_U" ON '$CONTAINERPATH/tablespaceu/$DB' "
db2 -v  "CREATE STOGROUP "TS_M" ON '$CONTAINERPATH/tablespacem/$DB' "
db2 -v  "CREATE STOGROUP "TS_B" ON '$CONTAINERPATH/tablespaceb/$DB' "
db2 -v  create tablespace BSPACE USING STOGROUP "TS_B"
db2 -v  "create table tableb(id int,name varchar(16)) in BSPACE"
db2 -v  "insert into tableb values(100,'AAA')"
db2 -v  "insert into tableb values(200,'BBB')"
db2 -v  "insert into tableb values(300,'CCC')"
db2 -v  "insert into tableb values(400,'CCC')"
db2 -v  "insert into tableb values(500,'CCC')"
db2 -v  "insert into tableb values(600,'CCC')"
db2 -v  "insert into tableb values(700,'CCC')"
db2 -v  "insert into tableb values(800,'CCC')"
db2 -v  "insert into tableb values(900,'CCC')"
db2 -v  "insert into tableb values(1000,'CCC')"
db2 -v  "insert into tableb values(1100,'CCC')"
db2 -v  "insert into tableb values(1200,'CCC')"
db2 -v  "insert into tableb values(1400,'CCC')"
db2 -v  "insert into tableb values(1500,'CCC')"
db2 -v  "insert into tableb values(1600,'CCC')"
db2 -v  "insert into tableb values(1700,'CCC')"
db2 -v  "insert into tableb values(1800,'CCC')"
db2 -v  "insert into tableb values(1900,'CCC')"
db2 -v  "insert into tableb values(2000,'CCC')"
db2 -v  "insert into tableb values(2100,'CCC')"
db2 -v  "insert into tableb values(2200,'CCC')"
db2 -v  "insert into tableb values(2400,'CCC')"
db2 -v  "insert into tableb values(2500,'CCC')"
db2 -v  "insert into tableb values(2600,'CCC')"
db2 -v  "insert into tableb values(2700,'CCC')"
db2 -v  "insert into tableb values(2800,'CCC')"
db2 -v  "insert into tableb values(2900,'CCC')"
db2 -v  "insert into tableb values(3000,'CCC')"
db2 -v  "commit"
db2 -v  "connect reset"
case $CASE in
  1)
    db2 -v  "backup database $DB tablespace (BSPACE)" >  OFFLINEBACKUPTIMEBIG.out
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo BACKUP OFFLINEBACKUPTIMEBIG failed
      exit 8
    else
      OFFLINEBACKUPTIMEBIG=`cat OFFLINEBACKUPTIMEBIG.out|awk '{print $11}'`
      cat OFFLINEBACKUPTIMEBIG.out
    fi
  ;;
  2)
    db2 -v  "backup database $DB tablespace (BSPACE)" online >  ONLINEBACKUPTIMEBIG.out
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo BACKUP ONLINEBACKUPTIMEBIG failed
      exit 8
    else
      ONLINEBACKUPTIMEBIG=`cat ONLINEBACKUPTIMEBIG.out|awk '{print $11}'`
      cat ONLINEBACKUPTIMEBIG.out
    fi
  ;;
  3 | 4 )
    db2 -v  "backup database $DB tablespace (BSPACE)" online include logs>  ONLINEBACKUPTIMEBIGWTIHLOGS.out
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo BACKUP ONLINEBACKUPTIMEBIGWTIHLOGS failed
      exit 8
    else
      ONLINEBACKUPTIMEBIGWTIHLOGS=`cat ONLINEBACKUPTIMEBIGWTIHLOGS.out|awk '{print $11}'`
      cat ONLINEBACKUPTIMEBIGWTIHLOGS.out
    fi
  ;;

  *)
    echo Case is not valid
    exit 8
  ;;
esac

ls -l $CONTAINERPATH/log/archlog/$DB/*
db2 get db cfg for $DB|grep "First active log file"



db2 -v  "connect to $DB"
db2 -v  "create table tablea(id int,name varchar(16)) in USERSPACE1"
db2 -v  create tablespace URSPACE USING STOGROUP "TS_U"
db2 -v  create tablespace MYSPACE USING STOGROUP "TS_M"
db2 -v  "insert into tablea values(100,'AAA')"
db2 -v  "insert into tablea values(200,'BBB')"
db2 -v  "insert into tablea values(300,'CCC')"
db2 -v connect reset
case $CASE in
  1 | 2 | 3)
  ;;
  4)
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online include logs" >  ONLINEBACKUPTIMENORMALWTIHLOGSFULL.out
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo BACKUP ONLINEBACKUPTIMENORMALWTIHLOGSFULL failed Returns $RC
      exit 8
    else
      ONLINEBACKUPTIMENORMALWTIHLOGSFULL=`cat ONLINEBACKUPTIMENORMALWTIHLOGSFULL.out|awk '{print $11}'`
      cat ONLINEBACKUPTIMENORMALWTIHLOGSFULL.out
    fi
  ;;
  *)
    echo Case is not valid
    exit 8
  ;;
esac
db2 -v  "connect to $DB"
db2 -v  "create table tablec(id int,name varchar(16)) in URSPACE"
db2 -v  "insert into tablec values(100,'AAA')"
db2 -v  "insert into tablec values(200,'BBB')"
db2 -v  "insert into tablec values(300,'CCC')"
db2 -v  "create table tablem(id int,name varchar(16)) in MYSPACE"
db2 -v  "insert into tablem values(100,'AAA')"
db2 -v  "insert into tablem values(200,'BBB')"
db2 -v  "insert into tablem values(300,'CCC')"
db2 -v  "insert into tablem values(400,'DDD')"
case $CASE in
  1 | 2 | 3)
  ;;
  4)
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental include logs" >  ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL1.out
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo BACKUP ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL1 failed Returns $RC
      exit 8
    else
      ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL1=`cat ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL1.out|awk '{print $11}'`
      cat ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL1.out
    fi
  ;;
  *)
    echo Case is not valid
    exit 8
  ;;
esac
db2 -v  "connect to $DB"
db2 -v  "insert into tablem values(500,'EEE')"
db2 -v  "insert into tablem values(600,'FFF')"
db2 -v  "insert into tablea values(400,'DDD')"
db2 -v  "insert into tablea values(500,'EEE')"
db2 -v  "insert into tablea values(600,'FFF')"
db2 -v  "insert into tablem values(700,'GGG')"
case $CASE in
  1 | 2 | 3)
  ;;
  4)
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental include logs" >  ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo BACKUP ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2 failed Returns $RC
      exit 8
    else
      ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2=`cat ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out|awk '{print $11}'`
      cat ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out
    fi
  ;;
  *)
    echo Case is not valid
    exit 8
  ;;
esac
db2 -v  "connect to $DB"

db2 -v  "insert into tablem values(800,'HHH')"
db2 -v  "insert into tablem values(900,'III')"
db2 -v  "insert into tablec values(400,'DDD')"
db2 -v  "insert into tablec values(500,'EEE')"
db2 -v  "insert into tablec values(600,'FFF')"
db2 -v  "insert into tablea values(700,'GGG')"
db2 -v  "insert into tablea values(800,'HHH')"
db2 -v  "insert into tablea values(900,'III')"
db2 -v  "commit"
db2 -v  "connect reset"

ls -l $CONTAINERPATH/log/archlog/$DB/*
db2 get db cfg for $DB|grep "First active log file"


case $CASE in
  1)
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online" >  OFFLINEBACKUPTIMENORMAL.out
    RC=$?
    if [ $RC -ne 0 ]
      then
        echo BACKUP OFFLINEBACKUPTIMENORMAL failed Returns $RC
        exit 8
      else
        OFFLINEBACKUPTIMENORMAL=`cat OFFLINEBACKUPTIMENORMAL.out|awk '{print $11}'`
        cat OFFLINEBACKUPTIMENORMAL.out
    fi
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
    db2 -v  "restore db $DB rebuild with all tablespaces in image taken at $OFFLINEBACKUPTIMENORMAL on '$CONTAINERPATH/tablespace/$DB' DBPATH on '$CONTAINERPATH/metadata/$DB' WITHOUT PROMPTING"
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Restore failed Returns $RC
      exit 8
    fi
    db2 -v  "rollforward database $DB to end of logs and stop "
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Rollforward failed Returns $RC
      exit 8
    fi

    
    db2 -v  "restore db $DB tablespace taken at $OFFLINEBACKUPTIMEBIG WITHOUT PROMPTING"
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Restore failed Returns $RC
      exit 8
    fi
    db2 -v  "rollforward database $DB to end of logs and stop"
    
    db2 -v  "connect to $DB"
    db2 -v  "select count(*) from tablea"
    db2 -v  "select count(*) from tableb"
    db2 -v  "select count(*) from tablem"
    db2 -v  "commit"
    db2 -v  "connect reset"
  ;;
  2)
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online" >  ONLINEBACKUPTIMENORMAL.out
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo BACKUP ONLINEBACKUPTIMENORMAL failed Returns $RC
      exit 8
    else
      ONLINEBACKUPTIMENORMAL=`cat ONLINEBACKUPTIMENORMAL.out|awk '{print $11}'`
      cat ONLINEBACKUPTIMENORMAL.out
    fi
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
    db2 -v  "restore db $DB rebuild with all tablespaces in image taken at $ONLINEBACKUPTIMENORMAL on '$CONTAINERPATH/tablespace/$DB' DBPATH on '$CONTAINERPATH/metadata/$DB' WITHOUT PROMPTING"
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Restore failed Returns $RC
      exit 8
    fi
    db2 -v  "rollforward database $DB to end of logs and stop "
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Rollforward failed Returns $RC
      exit 8
    fi
    
    db2 -v  "restore db $DB tablespace taken at $ONLINEBACKUPTIMEBIG WITHOUT PROMPTING"
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Restore failed Returns $RC
      exit 8
    fi
    db2 -v  "rollforward database $DB to end of logs and stop"
    
    db2 -v  "connect to $DB"
    db2 -v  "select count(*) from tablea"
    db2 -v  "select count(*) from tableb"
    db2 -v  "select count(*) from tablem"
    db2 -v  "commit"
    db2 -v  "connect reset"
  ;;

  3)
    db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online include logs" >  ONLINEBACKUPTIMENORMALWTIHLOGS.out
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo BACKUP ONLINEBACKUPTIMENORMALWTIHLOGS failed Returns $RC
      exit 8
    else
      ONLINEBACKUPTIMENORMALWTIHLOGS=`cat ONLINEBACKUPTIMENORMALWTIHLOGS.out|awk '{print $11}'`
      cat ONLINEBACKUPTIMENORMALWTIHLOGS.out
    fi
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
    db2 -v  "restore db $DB rebuild with all tablespaces in image taken at $ONLINEBACKUPTIMENORMALWTIHLOGS on '$CONTAINERPATH/tablespace/$DB' DBPATH on '$CONTAINERPATH/metadata/$DB' LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"

    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Restore failed Returns $RC
      exit 8
    fi
    db2 get db cfg for $DB|grep -i log
    echo "List log Files after rebuild tablespaces:" `ls -R $PWD/logretain`

    db2 -v  "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
    RC=$?
    if [ $RC -ne 0 ] && [ $RC -ne 2 ]
    then
      echo Rollforward failed Returns $RC
      exit 8
    fi
    
    rm -rf $PWD/logretain/*
    db2 -v  "restore db $DB tablespace taken at $ONLINEBACKUPTIMEBIGWTIHLOGS LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Restore failed Returns $RC
      exit 8
    fi
    echo "List log Files after restore tablespace:" `ls -R $PWD/logretain`
    db2 -v  "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
    
    db2 -v  "connect to $DB"
    db2 -v  "select count(*) from tablea"
    db2 -v  "select count(*) from tableb"
    db2 -v  "select count(*) from tablem"
    db2 -v  "commit"
    db2 -v  "connect reset"
  ;;
  4)

    db2 -v  "backup database $DB tablespace (SYSCATSPACE,USERSPACE1,URSPACE,MYSPACE) online incremental include logs" >  ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo BACKUP ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2 failed Returns $RC
      exit 8
    else
      ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2=`cat ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out|awk '{print $11}'`
      cat ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2.out
    fi
    printf "Restore Database out of incremental tablespace backups $DB\n"
    exit 8
    smooth_drop $DB
    mkdir -p $CONTAINERPATH/tablespace/$DB
    mkdir -p $CONTAINERPATH/tablespaceu/$DB
    mkdir -p $CONTAINERPATH/tablespacem/$DB
    mkdir -p $CONTAINERPATH/tablespaceb/$DB
    mkdir -p $CONTAINERPATH/metadata/$DB
    mkdir -p $CONTAINERPATH/log/archlog/$DB
    mkdir -p $CONTAINERPATH/log/$DB
    mkdir -p $PWD/logretain
    db2 -v  "restore db $DB rebuild with all tablespaces in image incremental taken at $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2 LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Restore incremental failed Returns $RC
      exit 8
    fi
    db2 -v  "restore db $DB incremental taken at $ONLINEBACKUPTIMENORMALWTIHLOGSFULL LOGTARGET '$PWD/logretain'"
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Restore incremental full failed Returns $RC
      exit 8
    fi
    db2 -v  "restore db $DB incremental taken at $ONLINEBACKUPTIMENORMALWTIHLOGSINCREMENTAL2 LOGTARGET '$PWD/logretain'"
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Restore incremental full failed Returns $RC
      exit 8
    fi
    db2 -v  "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"
    RC=$?
    if [ $RC -ne 0 ] && [ $RC -ne 2 ]
    then
      echo Rollforward failed Returns $RC
      exit 8
    fi

    rm -rf $PWD/logretain/*
    db2 -v  "restore db $DB tablespace taken at $ONLINEBACKUPTIMEBIGWTIHLOGS LOGTARGET '$PWD/logretain' WITHOUT PROMPTING"
    RC=$?
    if [ $RC -ne 0 ]
    then
      echo Restore failed Returns $RC
      exit 8
    fi
    echo "List log Files after restore tablespace:" `ls -R $PWD/logretain`
    db2 -v  "rollforward database $DB to end of logs and stop overflow log path ('$PWD/logretain')"

    db2 -v  "connect to $DB"
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
