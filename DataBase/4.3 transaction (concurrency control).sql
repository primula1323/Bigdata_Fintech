-- Copyright(c) SNU VLDB Lab. (since 2005). All Rights Reserved.
-- Ch 16. example.sql

-- See, for more complicated discussion, 
-- 1. http://asktom.oracle.com/
-- 2. RW Consistency ppt by tom kyte
-- 3. Oracle Database Concept Book (https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/data-concurrency-and-consistency.html)
-- 4. Oracle Concurrency Control White Paper by Ken Jacobs
-- 5. Oracle Essential Book: Ch 8. Concurrency Control

conn / as sysdba
COLUMN table_name FORMAT a15
COLUMN tablespace_name FORMAT a15
COLUMN file_name FORMAT a60

-- Check Oracle tablespaces, data files: Undo (rollback) tablespace and undo data files
SELECT tablespace_name FROM DBA_TABLESPACES;
SELECT file_name FROM DBA_DATA_FILES;

conn scott/tiger 

--=============================
-- Ch 16.1 : ACID properties --
--=============================
drop table account;
create table account (id number, balance number);
insert into account values (1, 1000);
insert into account values (2, 2000);
commit;

-- T1: transfer 100$ from Account1 to Account2: 
-- Atomicity and Durability has to be guaranteed by Oracle
-- Consistnecy should be guaranteed by developer
-- BEGIN: a new tx will implicitly start in SQL/Plus by running any DML statement. 
update account set balance = balance - 100 where id = 1; 
update account set balance = balance + 100 where id = 2; 
-- rollback; 
commit;

truncate table account; 
insert into account values (1, 1000);
insert into account values (2, 2000);
commit;

--- Isolation (acId) 
--- T0: Monitoring lock status 
-- Oracle Lock: https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-LOCK.html
-- Oracle Database Reference: https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-LOCK.html

conn scott/tiger as sysdba;

-- Q1:
select sid, type, lmode, request, block
from v$lock 
where TYPE = 'TX'

-- T1: transfer 100$ from Account1 to Account2: 
update account set balance = balance - 100 where id = 1; 
-- Run T0's Q1
-- NOTE: automatic record-level fine-grained locking by Oracle 
--       --> developers are free from the burden of manual locking
--       --> application developer's productivity increases!!

-- Open new SQL/plus window
-- T2: increase account 2's balance by 200;
update account set balance = balance + 200 where id = 2;  
-- Run T0's Q1

-- T1 
update account set balance = balance + 100 where id = 2; 
-- what happens to T1's update statement? why?
-- Run T0's Q1

-- T2
commit;
-- at this moment, what happens to T1? why?

-- T1
commit;


--====================================
-- Ch 16.2 ~  : Concurrency Control -- 
--====================================
drop table account;
create table account (id number, balance number);

insert into account values (1, 100);
commit;

----------------------------------------------------
-- Part 1. from the view point of Read operations --
----------------------------------------------------

-- Under "READ COMMITTED" mode
T1:
update account set balance = balance + 10
where id = 1;

-- make another scott/tiger connection; that is, start a new SQL*Plus
T2:
conn scott/tiger;

select * from account where id = 1;
-- balance value? no problem?
-- the value 100 represents a normal state(that is, commited value)
-- "no dirty read"
T1:
commit;

T2:
select * from account where id = 1;
-- what happens? why?
-- "non-repeatable read"
-- the value 110 represents yet another normal state.
-- In this mode, it reads the snapshot of DB when "the SQL statement" starts!!

T3:
insert into account values(2, 200);

T2:
select * from account;
select * from account where id = 1;
select sum(balance) from account;
-- result? no problem?

T3:
commit;

T2:
select * from account;
select * from account where id = 1;
select sum(balance) from account;
-- result? no problem?
-- the existing tuple (1, 110) does not change.
-- however, the values of sum are different!
-- why? This is "phantom phenomenon", due to the newly inserted tuple (2, 200)

---------------------------------------- 
-- Another Example of Phantom: Delete --
----------------------------------------

truncate table account; 
insert into account values (1, 100);
commit;

T1:
delete from account where id = 1;
select * from account;

T2:
insert into account values (1,150);
commit;

T1:
select * from account;
-- Another "phantom phenomenon"

-- In summary, under "Read Committed" mode, you can experience
-- both "non repeatable read" and "phantom"

------------------------------------
-- Now, under "SERIALIZABLE" mode --
------------------------------------

truncate table account; 
insert into account values (1, 100);
commit;

T2:
alter session set isolation_level = serializable;
select * from account; 
-- note that a new transaction starts implicitly!

T1:
update account set balance = balance + 10
where id = 1;

T2:
select * from account where id = 1;
-- balance value? no problem?
-- the balance value 100 represents a normal state(that is, commited value)
-- "no dirty read"
T1:
commit;

T2:
select * from account where id = 1;
-- what happens? why?
-- under "SERIALIZABLE" mode, no "non-repeatable read"!!! 
-- that is, you read the same 100, even after the T1 change the value into 110..

T3:
insert into account values(2, 200);

T2:
select * from account;
select * from account where id = 1;
select sum(balance) from account;
-- result? no problem?

T3:
commit;

T2:
select * from account;
select * from account where id = 1;
select sum(balance) from account;
-- result? 
-- under "SERIALIZABLE" mode, the values of sum() are same!!!
-- no "phantom phenomenon"! 

-- In summary, under "SERIALIZABLE" mode, you do not experience
-- either "non repeatable read" or "phantom"!
-- In the mode, it reads the snapshot of DB when the transaction started!!

rollback;

T2:
alter session set isolation_level = read committed;
variable bal number;
execute select  balance into :bal from account where id = 1;

T1: 
update account set balance = balance + 10
where id = 1;

T2: 
update account set balance = :bal * 1.1
where id = 1;

T1:
commit;

T2:
select * from account where id = 1;
-- result? no problem?
-- "scholar lost update" problem

rollback;

--------------
-- Deadlock -- 
--------------
T1:
truncate table account;
insert into account values (1, 100);
insert into account values (2, 200);
commit;

update account set balance = balance + 10
where id = 1;

T2:
update account set balance = balance * 1.1
where id = 2;

T1:
update account set balance = balance + 10
where id = 2;

-- you can check the blocking-waiting relationship in either ways.
-- 1. select * from dba_waiters;
-- 2. $ORACLE_HOME\rdbms\admin\utllock.sql 

T2:
update account set balance = balance * 1.1
where id = 1;

-- what happens? why? 
-- How Oracle solves the problem?
-- It is an example of deadlock. In non-distributed database, Oracle uses 
-- "wait-for graph" for deadlock detection.(For distrisbuted DB, "time-out" is used)
-- And, if a deadlock detected, Oracle roll-backs one of the statements involved in
-- the deadlock. For the one-statment roll-backed transaction, program can roll back the
-- TR explicity, or begins to re-execute the statment after.

Error at line 1:
ORA-00060: deadlock detected while waiting for resource

-- Victim Transaction (say T1) is chosen and its statement will be rollbacked.
-- What happen to non-victim (say T2)? It remains still blocked by victim transaction.
-- Note: Oracle will not roll back the entire victim transaction. 
-- After receiving the deadlock message, victim transaction must decide 
-- whether 1) to commit the ourstanding work, 2) roll it back, or 
-- 3) continue down an alternative path and commit late. 

