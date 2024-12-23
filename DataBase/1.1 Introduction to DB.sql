-- Copyright SNU VLDB Lab. All Rights Reserved.
-- Ch 1. example.sql

--*******************************-- 
-- How to enable "SET AUTOTRACE" --
--*******************************-- 
-- Launch an SQL*Plus window;
-- step 1;
-- 1. log in with "conn SYSTEM/your_pass_word"
-- 2. (Linux)   run @%oracle_home%/rdbms/admin/utlxplan
--    (Windows) run @%oracle_home%\rdbms\admin\utlxplan 
--              (oracle_home: e.g., c:\Oracle19c\WINDOWS.X64_193000_db_home)  
-- 3. grant all on plan_table to public
-- step 2
-- 4. log in as "SYSDBA": e.g. "conn system/your_password as sysdba";
-- 5. (Linux)   run @%ORACLE_HOME%/sqlplus/admin/plustrce 
--    (Windows) run @%ORACLE_HOME%\sqlplus\admin\plustrce 
--    ** Note1: %ORACLE_HOME% is an environmental variable which means the home directory of Oracle installed in your computer.
--        You can check the environment variable ORACLE_HOME using regedit in Window. 
--        (hkey_local_machines -> software -> oracle)
--        If you are using Oracle VM(i.e. virtual machine) in Linux, 
--        $ORACLE_HOME, instead of %ORACLE_HOME%, should be used
--    ** Note2: If an error message 'PLUSTRACE' does not exist' is encountered, ignore it. If you see "Grant succeeded." at the end, that is okay.
--    ** Note3: However, if you meet v_$Sesstat related error message, you should run "step1".
-- 6. Grant PLUSTRACE to PUBLIC;
-- 7. log in as normal user: e.g. conn scott/tiger

--*********************************************************-- 
-- How to enable "SET AUTOTRACE"  in Oracle VM environment --
--*********************************************************-- 
exit;
sqlplus system/oracle;
@?/rdbms/admin/utlxplan;
 grant all on plan_table to public;
exit;
sqlplus sys/oracle@localhost/orcl as sysdba -- we will use plugable DB not Oracle sid(orcl12c)
@$ORACLE_HOME/sqlplus/admin/plustrce
Grant PLUSTRACE to PUBLIC;
----------------------------------------------------------------------------------------------------------

--**************************************
--* Section 1.5.1 The Relational Model *
--**************************************

conn scott/tiger

-- three sample relations in scott account: emp, dept, salgrade
-- conceptual schema of scott database

-- In Oracle LiveSQL, create scott schema using the script 
-- in https://github.com/snu-bkms1/SNU-BKMS1-S2024/blob/main/oracle/scott.sql
-- You can save the script and re-run the script whenever you sign in 

desc emp;
desc dept;
desc salgrade;

set lines 200;
select * from emp;
select * from dept;

-- + integrity constraint: e.g. every employee has his unique empno (Section 3.2, Section 5.7)

--*********************************
--* Section 1.6 - Queries in DBMS *
--*********************************

select empno, ename from emp;
select * from emp where deptno = 20;  
select * from emp where deptno = 20 and sal >= 2000; 
select deptno, count(*) from emp group by deptno;
select deptno, avg(sal) from emp group by deptno;
select ename, dname, loc from emp e, dept d where e.deptno = d.deptno; 

-- + advanced SQL (chater 25) 
SELECT ENAME, SAL, PERCENT_RANK() OVER (ORDER BY SAL DESC) as PR FROM emp; 

-- + data mining (Chapter 26) 

--*************************************************
--* Section 1.5.2 Levels of Abstraction in a DBMS *
--*************************************************

-- CONCEPTUAL SCHEMA of scott database
desc emp;
desc dept;
desc salgrade;

set lines 100;

-- PHYSICAL SCHEMA: e.g. Index 

set autotrace on;
select * from emp where deptno = 30;
create index emp_deptno on emp(deptno); -- Check what step appears in Oracle execution plan.
select * from emp where deptno = 30;

-- In Oracle LiveSQL, you can check execution plan in the following way ------------- 
create index emp_deptno on emp (deptno);

select /*+ gather_plan_statistics */ * from emp e where deptno = 10;

select *  
from   table(dbms_xplan.display_cursor(:LIVESQL_LAST_SQL_ID, format => 'typical'));

select /*+ gather_plan_statistics full(e) */ * from emp e where deptno = 10;

select *  
from   table(dbms_xplan.display_cursor(:LIVESQL_LAST_SQL_ID, format => 'typical'));
--------------------------------------------------------------------------------------

-- EXTERNAL SCHEMA or VIEW : an example

-- In order to create a view in regular Oracle environment, 
-- a user need to be granted "create view" privilege.
-- conn system/manager;
conn system/your_password;
grant create view to scott;
conn scott/tiger
create or replace view dept_sal as select deptno, avg(sal) avg_sal from emp group by deptno;
select * from dept_sal;

-- In Oracle LiveSQL, you need not the privildge.
create or replace view myview as select ename, sal from emp where deptno = 10; 

select /*+ gather_plan_statistics */ * from  myview;
select *  
from   table(dbms_xplan.display_cursor(:LIVESQL_LAST_SQL_ID, format => 'typical'));


--***********************************
--* Section 1.5.3 Data Independence *
--***********************************

-- *****************************
-- Logical data independence: *
-- *****************************

-- CHANGE in logical or conceptual schema
alter table emp rename to emp2;

-- what happens for the next query?
select * from dept_sal;

-- redefine the external schema
create or replace view dept_sal as select deptno, avg(sal) avg_sal from emp2 group by deptno;

-- then, what happens for the next query?
select * from dept_sal;

alter table emp2 rename to emp;
drop view dept_sal;

-- *****************************
-- Physical data independence: *
-- *****************************

set autotrace on;
select * from emp where deptno = 30;
create index emp_deptno on emp(deptno); -- Check what step appears in Oracle execution plan.
select * from emp where deptno = 30;
drop index emp_deptno;
select * from emp where deptno = 30;

-- NOTE: in the above scenario, the select statement itselt is not changed at all.
--	 users specifies only WHAT (S)HE WANTS?, not HOW?
--	 Then, who determines HOW?

-- In the above example, though physical schema has changed (i.e. creation/deletion of index),
-- the select statement still works. That is, we do not need to change the select query statement at all.

set autot off;

--***************
--* Section 1.7 *
--***************

-- Transaction example: money transfer
drop table account;
create table account (id number, balance number, primary key(id));

insert into account values (1, 100); -- 100$ in account 1
insert into account values (2, 200); -- 200$ in account 2
commit;

-- An example of "money transfer" transfer
-- TX1: Move 10$ from account 1 to account 2
-- BEGIN transaction; (implicit in SQL*Plus)
update account set balance = balance - 10 where id = 1;
update account set balance = balance + 10 where id = 2;
COMMIT; 

-----------------------------------------------------------------------------------
-- TX concept: ONE of GREAT IDEAS in Computer Science 
-- Once you simply define the money transfer transaction with BEGIN .. COMMIT,
-- DBMS (e.g., Oracle) will do the rest to guarantee its ACID 
-- upon concurrent transation and failures. 
-- When you design/implement the transaction using FILE SYSTEM,
-- YOU HAVE TO care and code every aspect of ACID. 
-----------------------------------------------------------------------------------

-----------------------------------
-- 1.7.2 Atomicity and Durability -
-----------------------------------

-- TX2: Move 10$ from account 1 to account 2
-- begin transaction; (implicit in SQL*Plus)
update account set balance = balance - 10 where id = 1;
-- 1. When system crashes while tx is in progress: (e.g. shutdown your computer at this moment.)
update account set balance = balance + 10 where id = 2;
commit; /* THINK ABOUT WHAT SHOULD HAPPEN for durability inside computer (CH. 18) */

-- 2. After rebooting your computer and connecting scott/tiger,
--    check the status of table ACCOUNT.
-- Durability: The effect of T1 should be persistent even in spite of crash 
--             because T1 has successufully committed; 
-- Atomicity: T2 should have no effect on database 
--              because the system crashed before T2 commits; 

------------------------------------------
-- 1.7.1 Concurrency Control: Isolation  -
------------------------------------------

-- Unfortunately, Oracle LiveSQL do not support multiple sessions. 

-- LOCKING for concurrency control
select sal from emp where ename = 'SMITH';
update emp set sal = sal + 100 where ename = 'SMITH';
select sal from emp where ename = 'SMITH';

-- Open another SQLPlus session S2
select sal from emp where ename = 'SMITH';
-- sal?
update emp set sal = sal * 1.1 where ename = 'SMITH';
-- What happens? why?

-- execute commit in session S1
commit;
-- Then, what happens in S2?

----------------------------------------------
-- DEADLOCK: Do it yourself                 --
-- 1. Make a deadlock scenario              --  
-- 2. Observe how Oracle resoloves deadlock --  
----------------------------------------------

-- Reset the scott/tiger schema
-- 1. close session S2; 
-- 2. run  @$ORACLE_HOME/rdbms/admin/utlsampl.sql  (Linux)
--    run  @$ORACLE_HOME/rdbms/admin/utlsampl.sql  (Windows)
conn / as sysdba --(or exit; then, sqlplus system/manager)
@$ORACLE_HOME/rdbms/admin/utlsampl.sql 
