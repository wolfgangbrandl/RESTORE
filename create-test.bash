#!/usr/bin/bash
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
DB=$1
smooth_drop $DB
printf "Anlegen der Source Datenbank $DB\n"
mkdir -p /products/home/db2it99/tablespace/$DB 
mkdir -p /products/home/db2it99/tablespaceu/$DB 
mkdir -p /products/home/db2it99/tablespacem/$DB 
mkdir -p /products/home/db2it99/tablespaceb/$DB 
mkdir -p /products/home/db2it99/metadata/$DB 
mkdir -p /products/home/db2it99/log/archlog/$DB 
mkdir -p /products/home/db2it99/log/$DB 
rm -rf  /products/home/db2it99/tablespace/$DB/* 
rm -rf  /products/home/db2it99/tablespaceu/$DB/* 
rm -rf  /products/home/db2it99/tablespacem/$DB/* 
rm -rf  /products/home/db2it99/tablespaceb/$DB/* 
rm -rf  /products/home/db2it99/metadata/$DB/* 
rm -rf  /products/home/db2it99/log/archlog/$DB/* 
rm -rf  /products/home/db2it99/log/$DB/* 
db2 -v  "create database $DB on '/products/home/db2it99/tablespace/$DB' DBPATH on '/products/home/db2it99/metadata/$DB' "
db2 terminate
