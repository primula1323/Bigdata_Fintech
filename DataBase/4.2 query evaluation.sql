--===================================================================
-- Copyright(c) SNU VLDB Lab. (since 2005). All Rights Reserved.
-- Ch 14. example.sq
--===================================================================

conn scott/tiger

COLUMN table_name FORMAT a10
COLUMN tablespace_name FORMAT a15
COLUMN column_name FORMAT a10
COLUMN index_name FORMAT a10
COLUMN index_type FORMAT a10
COLUMN data_type FORMAT a10
COLUMN low_value FORMAT a10
COLUMN high_value FORMAT a10

--===================================
--  Create and Populate TEST TABLE --
--===================================
drop table test;
create table test (a int, b int, c varchar2(650));

BEGIN
    FOR i IN 1..10 LOOP
        FOR j IN 1..10000 LOOP
            INSERT INTO TEST (a, b, c) values ((i-1)*10000+j, j, rpad('X', 650, 'X'));
        END LOOP;
    END LOOP;
END; 
/

-- block size = 8K, 10 tuples / page (PCT_FREE = 10%), avg. tuple size = 665 bytes, 
-- 10000 blocks (= 80M)
-- 
analyze table test compute statistics;
select table_name, tablespace_name, blocks, pct_free, avg_row_len, avg_space
from user_tables
where table_name = 'TEST';

--=================================================================
-- DIASLE automatic shared memory managment since Oracle 10g     -- 
conn scott/tiger as sysdba;
-- alter system set memory_target = 0;
-- alter system set sga_target = 0;
show parameters db_cache_size;  /* set to 64MB in my computer */ 
-- ALTER SYSTEM SET db_cache_size = 64M SCOPE= both; 
--=================================================================

conn scott/tiger;

-- create test_idx_a, test_idx_b and analyze
create index test_idx_a on test(a);
create index test_idx_b on test(b);
-- create index test_idx_ab on test(a,b);
analyze index test_idx_a compute statistics;
analyze index test_idx_b compute statistics;

set lines 200;
select index_name, blevel, leaf_blocks, distinct_keys, avg_leaf_blocks_per_key, avg_data_blocks_per_key, clustering_factor, last_analyzed
from user_indexes 
where index_name in ('TEST_IDX_A', 'TEST_IDX_B');


--=============
-- 14.4 Join --
--=============

-- In this example, we will use optimizer mode '9.2.0'. 
-- It takes only the IO cost into account, not CPU cost. 
alter session set optimizer_features_enable = '9.2.0'

--===============================
-- create/populate SMALL TABLE --
--===============================

drop table SMALL;
create table SMALL (a int, b int, c varchar2(650));
BEGIN
    FOR i IN 1..10000 LOOP
            INSERT INTO SMALL (a, b, c) values (i, i, rpad('X', 650, 'X'));
    END LOOP;
END;
/

-- 10 tuples/block, 1000 blocks, total = 8MB
analyze table small compute statistics;
select table_name, tablespace_name, blocks, pct_free, avg_row_len, avg_space
from user_tables
where table_name = 'SMALL';

create index small_idx_a on small(a);
analyze index small_idx_a compute statistics;

select index_name, blevel, leaf_blocks, distinct_keys, avg_leaf_blocks_per_key, avg_data_blocks_per_key, clustering_factor, last_analyzed
from user_indexes 
where index_name = 'SMALL_IDX_A'; 

--==================
-- JOIN: examples --
--==================

-- A quick review of join
select ename, dname
from emp e, dept d
where e.deptno = d.deptno

set autot off;
-- nested loop algorithm
select * from emp;
select * from dept;

-- sort merge algorithm
select * from emp order by deptno;
select * from dept order by deptno;

-- hash algorithm : a very simple hash function mod(deptno, 17)
select ename, deptno, mod(deptno, 17) from emp;
select deptno, mod(deptno, 17), dname from dept;

--================
-- JOIN METHODS ==
--================

--======================
-- Simple Nested Loop == 
--======================
set autot traceonly
set timing on

-- (Force Oracle to Use Full Table Scan, instead of 'Small_IDX_A')
-- full(t): use full table scan for table t vs. index(t): use index if available
-- Thus, Tuple-Oriented Nested Loop Join: COST MODEL = M + Pm*M*N 
-- NOTE: This query plan might take more than 1 hour in your desk-top pc.
--       If you want to test how long it takes in your pc, run it, but....
-- ** Note the "consistent gets" in Statistics
--       (compare to indexed nested loop join)
-- For more hints in Oracle, See https://docs.oracle.com/database/121/TGSQL/tgsql_influence.htm#TGSQL267
select /*+ use_nl(t1, t2) full(t1) full(t2) */ sum(t1.b + t2.b)
from test t1, small t2
where t1.a = t2.a;

-- instead, run this one which will run quite faster. How much faster?
-- compare the above query with the below one in terms of 'consistent gets' number
select /*+ use_nl(t1, t2) full(t1) full(t2) */ sum(t1.b + t2.b)
from test t1, small t2
where t1.a = t2.a and t1.a between 1 and 1000;

--==========================
-- JOIN ORDER IMPORTANT!! ==
--==========================
-- the hint "ordered" enforce the optimizer to consider only
-- the join order (t2, t1). 
select /*+ ordered use_nl(t1, t2) full(t1) full(t2) */ sum(t1.b + t2.b)
from small t2, test t1
where t1.a = t2.a; 

--=======================
-- Indexed Nested Loop == 
--=======================
select /*+ ordered use_nl(t1, t2) full(t1) */ sum(t1.b + t2.b)
from test t1, small t2
where t1.a = t2.a; 

select /*+ use_nl(t1, t2) full(t2) */ sum(t1.b + t2.b)
from test t1, small t2
where t1.a = t2.a; 

select /*+ ordered use_nl(t1, t2) full(t1) */ sum(t1.b + t2.b)
from small t1, test t2
where t1.a = t2.a; 

--=======================================
-- Page & Block Nested Loop in Oracle? == 
--=======================================
Oracle DO NOT support Page & Block Nested Loop!!

--===========================
-- SORT-MERGE & HASH JOIN  == 
--===========================

select /*+ use_merge(t1, t2) */ sum(t1.a + t2.a)
from test t1, small t2
where t1.b = t2.b;
-- SORT (JOIN)

select /*+ use_hash(t1, t2) */ sum(t1.a + t2.a)
from test t1, small t2
where t1.b = t2.b;
-- HASH JOIN

-- SORT-MERGE and HASH JOIN COST MODEL: Too Complex!!
-- Excuse me for not providing EXACT information!!

-- Without any hint, which plan does Oracle choose?
-- No hint on access method, join method, and join order
select sum(t1.a + t2.a)
from test t1, small t2
where t1.b = t2.b;

-- WHICH JOIN METHOD? Q.O do it very intelligently!!

--=====================================
-- Join method for NON-EQUALITY JOIN == 
--=====================================

select sum(t1.b + t2.b)
from test t1, small t2
where t1.a <= t2.a and t1.a between 1 and 1000 and t2.a between 1 and 100
-- hash can not support "<", ">" etc.

select /*+ use_hash(t1, t2) */ sum(t1.b + t2.b)
from test t1, small t2
where t1.a <= t2.a and t1.a between 1 and 1000 and t2.a between 1 and 100
-- hash can not support "<", ">" etc.

select sum(t1.b + t2.b)
from test t1, small t2
where t1.a != t2.a and t1.a between 1 and 1000 and t2.a between 1 and 100

select /*+ use_merge(t1,t2) */ sum(t1.b + t2.b)
from test t1, small t2
where t1.a != t2.a and t1.a between 1 and 1000 and t2.a between 1 and 100
-- both sort_merge and hash can not support "!=".

--================================================================
-- Copyright(c) SNU VLDB Lab. (since 2005). All Rights Reserved. --
-- Ch 12. example.sql                                           --
--================================================================

-- Sample tables TEST and SMALL --
COLUMN table_name FORMAT a10
COLUMN column_name FORMAT a10
COLUMN index_name FORMAT a10
COLUMN index_type FORMAT a10
COLUMN data_type FORMAT a10
COLUMN num_distinct FORMAT 99999999
COLUMN low_value FORMAT a20
COLUMN high_value FORMAT a20
COLUMN density FORMAT .9999999999

drop table test;
create table test (a int, b int, c varchar2(650));

BEGIN
    FOR i IN 1..10 LOOP
        FOR j IN 1..1000 LOOP
        	INSERT INTO TEST (a, b, c) values ((i-1)*1000+j, j, rpad('X', 650, 'X'));
	END LOOP;
    END LOOP;
END;
/

-- block size: 8K
-- TEST  TABLE  10 tuples per block ==> 1000 blocks(= 8M)

--==================================
-- 12.1 SYSTEM CATALOGs: Examples --
--==================================

-- analyze and check TEST and SMALL tables
analyze table TEST compute statistics;

-- table statistics: # of pages, # of tuples 
select table_name, blocks, num_rows
from user_tables
where table_name in ('TEST', 'SMALL');

--================================================================
-- attribute statistics: # of distinct values, min/max, density --
-- NOTE: two assumptions in attribute statistics                --
-- 1. UNIFORM VALUE DISTRIBUTION                                -- 
-- 2. ATTRIBUTE VALUE INDEPENDENCE                              -- 
--================================================================
select table_name, column_name, data_type, num_distinct, low_value, high_value, density
from user_tab_columns
where table_name in ('TEST');

create index test_idx_a on test(a);
analyze index test_idx_a compute statistics;

-- index # of distinct keys, # of blocks, clustering factor, height (or level)
select table_name, index_name, blevel, leaf_blocks, distinct_keys, num_rows, 
	clustering_factor, last_analyzed
from user_indexes
where table_name in ('TEST');

-- check the relationship between index and columns
desc user_ind_columns;

-- Access Path Selections: full table scan vs. index
set autotrace on

-- Column B is uniformly distributed. That is, B has no skew.
select * from test where b between 1 and 100;    

-- NOTE: in reality, unlike the assumption 2 above, 
-- value distributions of A and B columns are not independent 
select * from test where a between 1 and 100 and b between 1 and 100; 

--=============
-- Histogram --
--=============

-- skewed data distribution and histogram
drop table SKEWED;
create table SKEWED (a int, b int, c varchar2(650));

BEGIN
    FOR i IN 1..100 LOOP
        FOR j IN 1..i LOOP
        	insert into SKEWED (a, b, c) values (i, i, rpad('X', 650, 'X'));
	END LOOP;
    END LOOP;
END; 
/

analyze table SKEWED compute statistics;
create index skewed_idx_a on skewed(a);
analyze index skewed_idx_a compute statistics;

select sum(b) from skewed where a between 91 and 100;
select sum(b) from skewed where a between 1 and 10;

--=============================================
-- Create histogram on column A, as follows. --
--=============================================
analyze table skewed compute statistics FOR COLUMNS A;

select sum(b) from skewed where a between 91 and 100;
select sum(b) from skewed where a between 1 and 10;
-- What plan does the optimizer choose? same plan? 
-- Different plan! Why? because of histogram. Think about it!

-- Bind Variable and Histogram
-- SQL with bind variable can not exploit histogram during optimization.
variable my_var number
execute :my_var := 1
select * from skewed where a = :my_var;
execute :my_var := 100
select * from skewed where a = :my_var;

-- or use '&my_var';
-- "variable var" is intended for PL/SQL usage.

drop table skewed;
