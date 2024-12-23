-- Copyright(c) SNU VLDB Lab. (since 2005). All Rights Reserved.
-- Ch 9. example.sql

/* ignore this comment: OEM connection (since 10g): http://localhost:1521/em */

-- Connect Oracle with sysdba priviledge. Then, using the show command in SQL/Plus, 
-- check the setting of various Oracle database parameters
-- NOTE: To make this information to be accesible from non-sysdba account, 

-- exectute 'GRANT SELECT ON V_$PARAMETER TO PUBLIC;' command with sysdba priv.
-- AND, if you are running ***Oracle VM**, then execute the following two commands first.
-- CONN sys/oracle@localhost/orcl as sysdba
-- GRANT sysdba TO scott
CONN scott/tiger AS sysdba
SHOW PARAMETERS
SHOW PARAMETERS size
SHOW PARAMETERS memory_size
SHOW PARAMETERS db_block_size
SHOW PARAMETERS db_cache_size
SHOW parameters sga_max_target
SHOW parameters sga_max

COLUMN table_name FORMAT a15
COLUMN tablespace_name FORMAT a15
COLUMN file_name FORMAT a50
COLUMN member FORMAT a50

-- Check Oracle tablespaces, data files
SELECT * FROM DBA_TABLESPACES;
SELECT tablespace_name FROM DBA_TABLESPACES;
SELECT * FROM DBA_DATA_FILES;
SELECT file_name, file_id, tablespace_name FROM DBA_DATA_FILES;

-- Check Oracle Redo Log Group: Log Writer will write "redo log data"
-- in log groups; redo log data is used for recovery purpose 
SELECT * FROM V$LOG; 
SELECT * FROM V$LOGFILE; 
SELECT a.group#, a.status, b.type, b.member 
FROM v$log a, v$logfile b 
WHERE a.group#=b.group#(+);
-- NOTE: THE FOLLOWING SWITCH COMMAND "may not" run normally in Oracle VM.
ALTER SYSTEM SWITCH LOGFILE;
-- The following two commands are just examples. Do not execute them. 
-- ALTER DATABASE DROP LOGFILE group 3; 
-- ALTER  DATABASE ADD LOGFILE group 3 ('/data/orasys/redo03.log') SIZE 100M;

-- Adjust buffer cache size to 128MBs using the following command
ALTER SYSTEM SET db_cache_size = 128M SCOPE= both; /* SCOPE: {MEMORY, SPFILE, BOTH} */

-- If the above command does not work, do the following 
-- 1. ALSTER SYSTEM SET SGA_MAX_SIZE = 2G SCOPE = SPFILE;
-- 2. STARTUP FORCE; 
-- Oracle spfile's location: C:\Oracle19c\WINDOWS.X64_193000_db_home\database\SPFILEORCL2.ORA
-- How to change parameters: https://2factor.tistory.com/63
-- Refer to the following url about how to set memory size in Oracle
-- Oracle's Memory Architecture (Oracle 19c Concept Book, Ch14. Memory) 
-- https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/memory-architecture.html#GUID-913335DF-050A-479A-A653-68A064DCCA41
---------------------------------------------------------------------------------------------

CONN scott/tiger
ALTER SESSION SET optimizer_features_enable = '9.2.0'
/* optimizer_features_enable: 10.1.0.1, 10.1.0, 9.2.0, 9.0.1, 8.1.6, 
8.1.5, 8.1.4, 8.1.3, 8.1.0, 8.0.7, 8.0.6, 8.0.5, 8.0.4, 8.0.3, 8.0.0 */

DROP TABLE test;
CREATE TABLE test (a int, b int, c varchar2(650)) NOLOGGING TABLESPACE users;

-- Insert 1M tuples into TEST table (approximately 664 bytes per tuple) 
BEGIN
    FOR i IN 1..1000000 LOOP
         INSERT INTO TEST (a, b, c) values (i, i, rpad('X', 650, 'X'));
    END LOOP;
END;

-- Oracle19c default block Size = 8K --> 10 tuples / block
-- ==> total block # of TEST table = 100000 blocks (= 800M)

-- Analyze test table: googling with "Oracle analyze table computer statistics"
ANALYZE TABLE test COMPUTE STATISTICS;

-- TEST table information

select table_name, tablespace_name, blocks, pct_free, avg_row_len, avg_space
from user_tables
where table_name = 'TEST';

-- TEST segment information
conn scott/tiger as sysdba

COLUMN segment_name FORMAT a15
COLUMN segment_type FORMAT a15

select segment_name, segment_type, header_file, header_block, blocks,
	extents, max_extents
from dba_segments
where segment_name = 'TEST';

-- TEST extents information
COLUMN segment_name FORMAT a15
COLUMN tablespace_name FORMAT a15

select segment_name, tablespace_name, extent_id, file_id, block_id, blocks
from dba_extents
where segment_name = 'TEST';

-- shutdown Oracle service, then reboot
Startup force;

conn scott/tiger 

set timing on
set autot on

select sum(b) from test; -- OLAP style query

select * from test where a = 10000;                 -- point query 
select * from test where a between 10000 and 10010; -- range query 
update test set b = 5 where a = 10000;
rollback;
-- Oracle database @ Samsung 970 Evo 500GB Flash SSD
-- How much IO? How long does it takes? What if harddisk is used as storage?
-- you can monitor disk IO during 
-- use the iostat tool in Linux, use 성능모니터 (performance monitor ) in Windows


create index test_a on test(a);

select * from test where a = 10000;                 -- how faster than Full-Table-Scan? 
select * from test where a between 10000 and 10010; -- how faster than Full-Table-Scan? 
update test set b = 5 where a = 10000;
rollback;

-- Run the following query twice, and compare their run-times! WHY different?
select /*+ index(t test_a) */ sum(b)
from test t
where a between 1 and 100000;


================ delete from test vs. truncate table test ===================
conn scott/tiger 
set autot on

delete from test;

select sum(b)
from test;

rollback;

truncate table test;

select sum(b)
from test;

-- NOTE: High Water Mark concept!
