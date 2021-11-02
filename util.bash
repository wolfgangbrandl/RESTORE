#!/usr/bin/bash
#-------------------------------------------------------------------
# stoppt alle Applikationen fuer die mitgegebene DB
#-------------------------------------------------------------------
function create_db ()
{
  DBT=$1
  CONT=$2
  LOG=$3
  printf "Anlegen der Source Datenbank %s with Automatic Storage\n" "$DBT"
  mkdir -p "$CONT"/tablespace/"$DBT"
  mkdir -p "$CONT"/TS_U_SPACE/"$DBT"
  mkdir -p "$CONT"/TS_M_SPACE/"$DBT"
  mkdir -p "$CONT"/TS_B_SPACE/"$DBT"
  mkdir -p "$CONT"/TS_N_SPACE/"$DBT"
  mkdir -p "$CONT"/metadata/"$DBT"
  mkdir -p "$LOG"/log/archlog/"$DBT"
  mkdir -p "$LOG"/log/"$DBT"
  db2 -v "CREATE DATABASE $DBT
        AUTOMATIC STORAGE YES
        ON '$CONT/tablespace/$DBT'
        DBPATH ON '$CONT/metadata/$DBT'
        USING CODESET IBM-850 TERRITORY AT
        COLLATE USING IDENTITY
        PAGESIZE 4096
        DFT_EXTENT_SZ 32
        CATALOG TABLESPACE MANAGED BY AUTOMATIC STORAGE
         EXTENTSIZE 4
         AUTORESIZE YES
         INITIALSIZE 32 M
         MAXSIZE NONE
        TEMPORARY TABLESPACE MANAGED BY AUTOMATIC STORAGE
         EXTENTSIZE 32
         FILE SYSTEM CACHING
        USER TABLESPACE MANAGED BY AUTOMATIC STORAGE
         EXTENTSIZE 32
         AUTORESIZE YES
         INITIALSIZE 32 M
         MAXSIZE NONE"

  db2 -v  "update db cfg for $DBT using newlogpath $LOG/log/$DBT"
  db2 +o connect to "$DBT"
  db2 +o connect reset

}
#-------------------------------------------------------------------
# Check Backup
#-------------------------------------------------------------------
check_backup ()
{
  RC=$1
  File=$2
  basefilename=$(awk 'BEGIN{FS="."}{print $1}' "$File" )
  if [ "$RC" -ne 0 ]
  then
    printf "BACKUP %s failed\n" "$basefilename"
    exit 8
  else
    base=$(grep "The timestamp for this backup image is" "$File" | awk '{print $11}')
    cat "$File"
    echo "$base"
    return "$base"
  fi
}

#-------------------------------------------------------------------
# stoppt alle Applikationen fuer die mitgegebene DBT
#-------------------------------------------------------------------
function force ()
{
  for a in $(db2 list applications|grep "$1"|awk '{print $3}')
  do
    printf "force Application: %s\n" "$a"
    db2 force application \("$a"\)
  done
}
#-------------------------------------------------------------------
# check return code
#-------------------------------------------------------------------
check_RC ()
{
  RC=$1
  MSG=$2
  if [ "$RC" -ne 0 ]
  then
    if [ "$RC" -ne 2 ]
    then
      printf "%s Returns: %s\n"  "$MSG" "$RC"
      exit 8
    fi
  fi
}
#-------------------------------------------------------------------
# check db2 return code
#-------------------------------------------------------------------
check_sqlcode ()
{
  sqlcode=$1
  msg=$2
  if [[ $sqlcode == 1271 ]]; then
    echo "Warning not all tablespaces restored"
    return 0
  fi ; 
  if [[ $sqlcode != 0 ]]; then
    error_msg="$msg rc = $sqlcode"
    printf "Datum: %s  Error: %s\n"  "$(date)" "$error_msg"
    exit 8
  fi ; 
}

#-------------------------------------------------------------------
# Befuellen der Tabellen
#-------------------------------------------------------------------
insert_into_table ()
{
  DBT=$1
  tablename=$2
  maxc=$3
  sqlcode=$(db2 +o -ec  "connect to $DBT")
  check_sqlcode "$sqlcode" "Connect failed "
  ccnt=0
  pid=$$
  while [ $ccnt -lt "$maxc" ]; do
    let ccnt++
    obj=$( < /dev/random tr -dc 'a-zA-Z0-9  ' | fold -w 32 | head -n 1)
    db2 +o +c "insert into $tablename (pid,object) values($pid,'$obj')"
  done
  db2 +o commit
  db2 +o connect reset
}
#-------------------------------------------------------------------
# Update der Tabellen   
#-------------------------------------------------------------------
update_table ()
{
  DBT=$1
  tablename=$2
  sqlcode=$(db2 +o -ec  "connect to $DBT")
  check_sqlcode "$sqlcode" "Connect failed "
  obj=$( < /dev/random tr -dc 'a-zA-Z0-9  ' | fold -w 32 | head -n 1)
  short=${obj:0:1}
  db2 -v "update $tablename set object='$obj' where object like '$short%'"
}

#-------------------------------------------------------------------
# Versucht die mitgegebene Datenbank zu stoppen und dann zu loeschen
#-------------------------------------------------------------------
function smooth_drop_without_archive_logs ()
{
  DBT=$1
  CONT=$2
  LOG=$3
  force "$DBT"
  db2 +o connect to "$DBT"
  RC=$?
  if [ $RC -ne 0 ]
  then
    printf "Database %s does not exist" "$DBT"
    db2 uncatalog database "$DBT"
  else
    db2 QUIESCE DATABASE IMMEDIATE FORCE CONNECTIONS
    db2 UNQUIESCE DATABASE
    db2 +o connect reset
    db2 drop database "$DBT"
    db2 uncatalog database "$DBT"
  fi
  rm -rf  "$CONT"/tablespace/"$DBT"/*
  rm -rf  "$CONT"/TS_U_SPACE/"$DBT"/*
  rm -rf  "$CONT"/TS_M_SPACE/"$DBT"/*
  rm -rf  "$CONT"/TS_B_SPACE/"$DBT"/*
  rm -rf  "$CONT"/TS_N_SPACE/"$DBT"/*
  rm -rf  "$CONT"/metadata/"$DBT"/*
  rm -rf  "$LOG"/log/"$DBT"/*
  rm -rf  "$PWD"/logretain/*

  mkdir -p "$CONT"/tablespace/"$DBT"
  mkdir -p "$CONT"/TS_U_SPACE/"$DBT"
  mkdir -p "$CONT"/TS_M_SPACE/"$DBT"
  mkdir -p "$CONT"/TS_B_SPACE/"$DBT"
  mkdir -p "$CONT"/TS_N_SPACE/"$DBT"
  mkdir -p "$CONT"/metadata/"$DBT"
  mkdir -p "$LOG"/log/"$DBT"
  mkdir -p "$PWD"/logretain
}
#-------------------------------------------------------
# Versucht die mitgegebene Datenbank zu stoppen und dann zu koeschen
#-------------------------------------------------------
function smooth_drop ()
{
  DBT=$1
  CONT=$2
  LOG=$3
  force "$DBT"
  db2 +o connect to "$DBT"
  RC=$?
  if [ $RC -ne 0 ]
  then
    printf "Database %s does not exist" "$DBT"
    db2 uncatalog database "$DBT"
  else
    db2 "QUIESCE DATABASE IMMEDIATE FORCE CONNECTIONS"
    db2 "UNQUIESCE DATABASE"
    db2 +o "connect reset"
    db2 drop database "$DBT"
    db2 uncatalog database "$DBT"
  fi
  rm -rf  "$CONT"/tablespace/"$DBT"/* 
  rm -rf  "$CONT"/TS_U_SPACE/"$DBT"/* 
  rm -rf  "$CONT"/TS_M_SPACE/"$DBT"/* 
  rm -rf  "$CONT"/TS_B_SPACE/"$DBT"/* 
  rm -rf  "$CONT"/TS_N_SPACE/"$DBT"/* 
  rm -rf  "$CONT"/metadata/"$DBT"/* 
  rm -rf  "$LOG"/log/archlog/"$DBT"/* 
  rm -rf  "$LOG"/log/"$DBT"/* 
  rm -rf  "$PWD"/logretain/*

  mkdir -p "$CONT"/tablespace/"$DBT"
  mkdir -p "$CONT"/TS_U_SPACE/"$DBT"
  mkdir -p "$CONT"/TS_M_SPACE/"$DBT"
  mkdir -p "$CONT"/TS_B_SPACE/"$DBT"
  mkdir -p "$CONT"/TS_N_SPACE/"$DBT"
  mkdir -p "$CONT"/metadata/"$DBT"
  mkdir -p "$LOG"/log/archlog/"$DBT"
  mkdir -p "$LOG"/log/"$DBT"
  mkdir -p "$PWD"/logretain
}

#-------------------------------------------------------
# Monitoring Table content
#-------------------------------------------------------
function mon_table ()
{
  DBT=$1
  printf "Table Content\n"
  db2 +o connect to "$DBT"
  db2 -x   "select 'TABLEA Count: ' || count(*) from QTEST.TABLEA WITH UR"
  db2 -x   "select 'TABLEB Count: ' || count(*) from QTEST.TABLEB WITH UR"
  db2 -x   "select 'TABLEC Count: ' || count(*) from QTEST.TABLEC WITH UR"
  db2 -x   "select 'TABLEG Count: ' || count(*) from QTEST.TABLEG WITH UR"
  db2 -x   "select 'TABLEM Count: ' || count(*) from QTEST.TABLEM WITH UR"
  db2 -x   "select 'TABLEN Count: ' || count(*) from QTEST.TABLEN WITH UR"
  db2 -x   "select 'TABLEA Max:   ' || max(uptime) from QTEST.TABLEA WITH UR"
  db2 -x   "select 'TABLEB Max:   ' || max(uptime) from QTEST.TABLEB WITH UR"
  db2 -x   "select 'TABLEC Max:   ' || max(uptime) from QTEST.TABLEC WITH UR"
  db2 -x   "select 'TABLEG Max:   ' || max(uptime) from QTEST.TABLEG WITH UR"
  db2 -x   "select 'TABLEM Max:   ' || max(uptime) from QTEST.TABLEM WITH UR"
  db2 -x   "select 'TABLEN Max:   ' || max(uptime) from QTEST.TABLEN WITH UR"
  db2 +o connect reset
}
#-------------------------------------------------------
# Monitoring Tablespace State
#-------------------------------------------------------
function mon_tablespace ()
{
  DBT=$1
  printf "Tablespace State\n"
  db2 +o connect to "$DBT"
  db2 -x "select varchar(TBSP_NAME,20) as TABLESPACE,varchar(TBSP_STATE,15) as STATE  from table(sysproc.MON_GET_TABLESPACE('',-1))"
  db2 +o connect reset
}
#-------------------------------------------------------
# Monitoring Database Container Path
#-------------------------------------------------------
function mon_container ()
{
  DBT=$1
  printf "Database Containers\n"
  db2 +o connect to "$DBT"
  db2 -x  "SELECT DBPARTITIONNUM, char(TYPE,40), char(PATH,100) FROM TABLE(ADMIN_LIST_DB_PATHS()) AS FILES"
  db2 +o connect reset
}
#-------------------------------------------------------
# Create tables generated
#-------------------------------------------------------
function create_table ()
{
  DBT=$1
  TABLENAME=$2
  TABLESPACE=$3
  db2 +o connect to "$DBT"
  db2 -v  "create table $QUAL.$TABLENAME (ind integer not null generated always as identity (start with 1 increment by 1),
                  pid integer not null default 1,
                  crtime timestamp not null default current timestamp,
                  uptime timestamp not null generated always for each row on update as row change timestamp,
                  object varchar(255) ,
                  primary key (ind,crtime)
                  ) in $TABLESPACE"
  db2 +o connect reset
}
#-------------------------------------------------------
# Create tables non generated
#-------------------------------------------------------
function create_tablenon_generated ()
{
  DBT=$1
  TABLENAME=$2
  TABLESPACE=$3
  db2 -x -o connect to "$DBT"
  db2 -v  "create table $QUAL.$TABLENAME (ind integer not null default 100,
                  pid integer not null default 1,
                  crtime timestamp not null default current timestamp,
                  uptime timestamp not null default current timestamp,
                  object varchar(255) ,
                  primary key (ind,crtime)
                  ) in $TABLESPACE"
  db2 -x -o connect reset
}
