./DB2_Crash_Recovery_from_Tablespace_Backups_Big_Online_Incremental.bash -m INITDB -s TESTS  | tee init.out
./DB2_Crash_Recovery_from_Tablespace_Backups_Big_Online_Incremental.bash -m WORK -s TESTS | tee work.out
./DB2_Crash_Recovery_from_Tablespace_Backups_Big_Online_Incremental.bash -m WORKWITHREORGRUNSTATBIG -s TESTS | tee workreorg.out
./DB2_Crash_Recovery_from_Tablespace_Backups_Big_Online_Incremental.bash -m RESTOREWITHARCHLOGS -s TESTS | tee restorewithlogs.out
./DB2_Crash_Recovery_from_Tablespace_Backups_Big_Online_Incremental.bash -m BACKUPBIG -s TESTS | tee backupbig.out
./DB2_Crash_Recovery_from_Tablespace_Backups_Big_Online_Incremental.bash -m WORK -s TESTS | tee work1.out
./DB2_Crash_Recovery_from_Tablespace_Backups_Big_Online_Incremental.bash -m WORKWITHREORGRUNSTATBIG -s TESTS | tee workreorg2.out
./DB2_Crash_Recovery_from_Tablespace_Backups_Big_Online_Incremental.bash -m RESTOREWITHOUTARCHLOGS -s TESTS | tee restorewithoutlogs.out

