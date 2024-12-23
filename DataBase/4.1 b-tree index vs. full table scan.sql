-- Copyright(c) SNU VLDB Lab. (since 2005). All Rights Reserved.
-- Ch 10. Tree Index Script - Index vs. Full Table Scan 

-------------------------------------------------------------
-- DIASLE automatic shared memory managment which has been introduce since Oracle 10g  
conn scott/tiger as sysdba;
alter system set memory_target = 0;
alter system set sga_target = 0;
show parameters db_cache_size;  /* set as 128MB in my computer */ 
--------------------------------------------------------------

conn scott/tiger

drop table TEST;

create table TEST (a int, b int, c varchar2(650));

-- Insert 1,000,000 tuples into test table
BEGIN
    FOR i IN 1..100 LOOP
        FOR j IN 1..10000 LOOP
        	INSERT INTO TEST (a, b, c) values ((i-1)*10000+j, j, rpad('X', 650, 'X'));
	END LOOP;
    END LOOP;
END;
/

-- Block size= 8K ==> 10 Tuples per Block ==> 100000 blocks(= 800M)

COLUMN table_name FORMAT a15
COLUMN segment_name FORMAT a15
COLUMN tablespace_name FORMAT a15

select table_name, tablespace_name, blocks, pct_free, avg_row_len, avg_space
from user_tables
where table_name = 'TEST';

-- Analyze TEST table:  
analyze table TEST compute statistics;

select table_name, tablespace_name, blocks, pct_free, avg_row_len, avg_space
from user_tables
where table_name = 'TEST';

-- For details about Oracle parameters and data dictionary, 
-- Please refer to http://download-west.oracle.com/docs/cd/B10501_01/server.920/a96536/toc.htm 

ALTER SESSION SET optimizer_features_enable = '9.2.0';

-----------------------------------
-- Create an index on Test table --
-----------------------------------
create index TEST_A on TEST (a);

-- Analyze test_a indexes 
analyze index TEST_A validate structure;

-- Check the index information using INDEX_STATS
-- (http://download-west.oracle.com/docs/cd/B10501_01/server.920/a96536/ch2451.htm#1317269)
select height, blocks, lf_rows, lf_blks, lf_rows_len, br_rows, br_blks, br_rows_len
from index_stats 
where name = 'TEST_A';

analyze index TEST_A compute statistics;

-- refer to https://docs.oracle.com/cd/B12037_01/server.101/b10755/statviews_1061.htm#i1578369
-- for detailed explanation of user_indexes. 
select blevel, leaf_blocks, distinct_keys, avg_leaf_blocks_per_key, avg_data_blocks_per_key,
       clustering_factor, last_analyzed
from user_indexes 
where index_name = 'TEST_A';

-- NOTE: clustering factor!!

----------------
-- INDEX DUMP -- 
----------------
conn scott/tiger as sysdba

select object_name, object_id 
from dba_objects
where object_type = 'INDEX' and owner =  'SCOTT';

alter session set events 'immediate trace name treedump level xxxxx';

-- open a trace file in $oracle_home\admin\$db_name$\udump
-- check the format of an index file

----------------------------------------
-- Indexed Access vs. Full Table Scan -- 
----------------------------------------

-- See this blog:
-- https://amplitude.engineering/how-a-single-postgresql-config-change-improved-slow-query-performance-by-50x-85593b8991b0

ALTER SESSION SET optimizer_features_enable = '9.2.0';

set autot on;
set timing on;

select b
from TEST
where a = 1;

select b
from TEST
where a between 1 and 10;

-- It is not always good to use index. Why? 
-- Optimizer may choose to use full table scan, instead of index. 
select sum(b)
from TEST 
where a between 1 and 300000;

-- What is the cost model of full table scan and index scan in Oracle? Cost-based Optimizer  
-- vs. Rule-based optimization (a rule of thumb): 
-- When the selectivity of a query is smaller than 5~10%, use index, 
-- otherwise use full table scan.

-- It is important to understand some assumptions made by query optimizer 
-- and cost model of each plan 
-- Oracle DBMS shows its cost model in `admin/udump/xxx.trc` file 

-- NOTE: Index Scan vs. Full Table Scan: db_file_multiblock_read_counts = 16
-- Full Table Scan I/O cost model (in Oracle 9.2) 
select b
from TEST
where a = 1;
--       - # of Blocks / k 
--       - (note that k != MBRC. Why? because some blocks might be already cached
--       - approximately 10 when MBRC = 16
select b
from TEST
where a = 1;
-- Index Scan I/O cost model 
--       - index block traversals + data block accesses
--       - selectivity * clustering factor
-- see also user_indexes for clustering_factor! 
-- what is clustering factor??

----------------------------------------
-- More Examples of Clustering Factor --
----------------------------------------
create index TEST_B on TEST(b);
analyze index TEST_B validate structure;

select height, blocks, lf_rows, lf_blks, lf_rows_len, br_rows, br_blks, br_rows_len
from index_stats 
where name = 'TEST_B';

analyze index TEST_B compute statistics;

select blevel, leaf_blocks, distinct_keys, avg_leaf_blocks_per_key, avg_data_blocks_per_key,
       clustering_factor, last_analyzed
from user_indexes 
where index_name = 'TEST_B';

SELECT SUM(A) 
FROM TEST
WHERE B = 10;

---------------------------------------------------------
-- An example of index-only access method: 
-- Note that the answer to this query can be computed 
-- without accessing tuples in heap file. Why? 
---------------------------------------------------------
SELECT COUNT(*) 
FROM TEST
WHERE B = 10;

create table NONCLUSTERED
as select x.* from (select * from TEST order by DBMS_RANDOM.random) x;

create index NONCLUSTERED_IDX on NONCLUSTERED (a);
analyze index NONCLUSTERED_IDX validate structure;

select height, blocks, lf_rows, lf_blks, lf_rows_len, br_rows, br_blks, br_rows_len
from index_stats 
where name = 'NONCLUSTERED_IDX';

analyze index NONCLUSTERED_IDX compute statistics;

select blevel, leaf_blocks, distinct_keys, avg_leaf_blocks_per_key, avg_data_blocks_per_key,
       clustering_factor, last_analyzed
from user_indexes 
where index_name = 'NONCLUSTERED_IDX';

select /*+ index(t) */ sum(b)
from TEST t
where a between 1 and 10000;  

select /*+ index(t) */ sum(a)
from TEST t
where b between 1 and 10000;  

select /*+ index(t) */ sum(b)
from NONCLUSTERED t
where a between 1 and 10000;  

--------------------------------------------------------
-- How to compare the cost when there are more than 2 --
-- available indexes for the given query ??           --
--------------------------------------------------------

select sum(b)
from test
where a between 1 and 10000 and b between 1 and 5000

