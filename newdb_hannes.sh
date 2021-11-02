-- This CLP file was created using DB2LOOK Version "10.5" 
-- Timestamp: Thu Apr  6 09:38:17 CEST 2017
-- Database Name: TESTS          
-- Database Manager Version: DB2/AIX64 Version 10.5.8      
-- Database Codepage: 850
-- Database Collating Sequence is: IDENTITY
-- Alternate collating sequence(alt_collate): null
-- varchar2 compatibility(varchar2_compat): OFF


--------------------------------------------------------
-- Generate CREATE DATABASE command
--------------------------------------------------------

CREATE DATABASE TESTS
	AUTOMATIC STORAGE YES
	ON '/node1/data0/db2/S2T01/IT99/tablespace/TESTS'
	DBPATH ON '/node1/data0/db2/S2T01/IT99/metadata/TESTS/'
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
	 MAXSIZE NONE 

;

CONNECT TO TESTS;

COMMIT WORK;

CONNECT RESET;

TERMINATE;

