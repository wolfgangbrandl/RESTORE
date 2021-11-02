#!/usr/bin/bash
#-------------------------------------------------------
# HELP Message
# ------------------------------------------------------
print_help ()
{
  printf "Usage: restore-offline2rollforward.bash -d <Databasename Source> -p <backup path> -t <timestamp> \n"
  printf " -d    Database name\n"
  printf " -p    Path where backup Image can be found\n"
  printf " -t    timestamp of the selected backup image\n"
  printf "EXAMPLE : restore-offline2rollforward.bash -d SAM1 -p /node1/data0/db2/S2T01/IT99/backup -t 20171025152057\n"
}

function stop_applications()
{
DB=$1
for a in `db2 list applications|grep $DB|awk '{print $3}'`
do
  echo force Application $a
  db2 force application \($a\)
done
}
#######################
#### MAIN #############
#######################
#-------------------------------------------------------
# MAIN
# ------------------------------------------------------
while [[ $# -gt 1 ]]
do
  key="$1"

    case $key in
      -d|--database)
        DB="$2"
        shift # past argument
      ;;
      -p|--path)
        BKPDIR="$2"
        shift # past argument
      ;;
      -t|--timestamp)
        TAKENAT="$2"
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
  shift # past argument or value
done
if [ "$DB" == "" ]
then
  printf "Database has to be defined \n"
  print_help
  exit 8
fi

if [ ! -d $BKPDIR ]
then
  printf "Path has to be defined or does not exist\n"
  print_help
  exit 8
fi
if [ "$TAKENAT" == "" ]
then
  printf " Timestamp is not defined \n"
  print_help
  exit 8
fi


db2 connect to $DB
db2 quiesce database immediate force connections
db2 unquiesce database
stop_applications $DB
db2 terminate
db2 restore database $DB from $BKPDIR TAKEN AT $TAKENAT WITHOUT PROMPTING
db2 rollforward db $DB to end of logs and stop
