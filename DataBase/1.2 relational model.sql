-- Copyright SNU VLDB Lab. All Rights Reserved.
-- Ch 3. example.sql

-- Customize glogin file @ $oracle_home/sqlplus/admin folder
--                         (e.g., c:\Oracle19c\WINDOWS.X64_193000_db_home)
set linesize 120
set pagesize 80

----------------------------------------
--====== RESET SCOTT/TIGER SCHEMA ======
----------------------------------------
-- When necessary, you can reset the scott/tiger schema in the following steps.
conn / as sysdba -- or, exit; then, sqlplus system/manager)
@$ORACLE_HOME/rdbms/admin/utlsampl.sql -- Oracle version: 19c 

-- When you are using lower Oracle version, 
-- @/u01/app/oracle/product/12.2/db_1/rdbms/admin/utlsampl.sql; -- 12c 
-- @%ORACLE_HOME%\RDBMS\ADMIN\utlsampl;   -- 10g, 11g;
-- @%ORACLE_HOME%\sqlplus\demo\demobld;   -- 9i: 

-- When you are using VM, follow the next step  
--    1. conn system/oracle (or exit; then, sqlplus sys/oracle@localhost/orcl as sysdba) 
--    2. @$ORACLE_HOME/rdbms/admin/utlsampl.sql  -- VM
-- If "SP2-0306: Invalid option" error is encountered while executing the above "conn" command 
-- (this error occurs probably because you are using Oracle VM), 
-- THEN try "conn system/manager"; 

---------------------------
--====== Section 3.1 ======
---------------------------

-- Oracle allow to refer column in "order by" clause either by name or by order 
select ename, empno from emp order by ename;
select ename, empno from emp order by 1;

select 1 from emp; -- Note: in the select clause, '1' does not mean 1st column. 

---------------------------
--====== Section 3.2 ======
---------------------------

-- For more complete built-in data types in Oracle, 
-- do googling with "Oracle built-in data types"

-- For more complete understanding ICs in Oracle,
-- please refer to "Oracle Application Development Guide" and 
--                  https://docs.oracle.com/database/121/CNCPT/datainte.htm#CNCPT422
-- You can download or view it from Oracle Technology Network.

-- Simple domain constraint

DESC DEPT; -- Note that the type of DEPTNO column in DEPT table is NUMBER;

INSERT INTO DEPT VALUES ('XX', 'DATABASE', 'SUWON');
-- what happens? what violation?

INSERT INTO DEPT VALUES ('50', 'DATABASE', 'SUWON');
-- what happens? why OK? 

INSERT INTO EMP VALUES
        (NULL, 'SIMON',  'DBA', 7902,
        TO_DATE('17-12-1980', 'DD-MM-YYYY'),  800, NULL, 50);
-- what happens? what problems?

INSERT INTO DEPT VALUES (50, 'VLDB', 'SUWON');
-- what happens? no problem in real-world? 

rollback;
-- undo

-- More on Oracle DATE type
DESC EMP; -- Note that the type of HIREDATE column in EMP table is DATE;
select * from emp where hiredate = to_date('23-01-1982','dd-mm-yyyy');
select * from emp where to_char(hiredate,'yyyy') = 1981;
select * from emp where to_char(hiredate,'mm') = 04;
select * from emp where hiredate > to_date('81/09/01','yy/mm/dd');
-- how to change date format in SQL*Plus
alter session set nls_date_format='dd-Mon-yyyy hh:mi:sspm';
alter session set nls_date_format='dd/Mon/yyyy'; 

--************************--
-- Primary key constraint --
--************************--

create table hello (a int, b char(1), primary key(a));

select constraint_name from user_constraints where table_name = 'HELLO';
-- system-generated constraints name
-- instead, you can specify the constraint name explicitly

drop table hello;
create table hello (a int, b char(1), constraint hello_pk primary key(a));
select constraint_name from user_constraints where table_name = 'HELLO';

insert into hello values (1,'A');
insert into hello values (1,'A');
-- what happens? what violation?
insert into hello values (2,'A');
-- OK!

-- Please refer to utlsampl.sql and check what column is declared as primary key in each of EMP and DEPT tables. 

--***********************--
-- Unique key constraint --
--***********************--

drop table hello;
create table hello (a int, b char(1), constraint hello_pk primary key(a), 
					constraint hello_uk unique(b));
insert into hello values (1,'A');
insert into hello values (2,'A');

select index_name from user_indexes where table_name = 'HELLO';
-- NOTE: in Oracle, when a primary key or unique key is declared,
--	a corresponding index is AUTOMATICALLY created. Think WHY?

--************************--
-- Foreign key constraint --
--************************--

create table parent (a int, b char(1), primary key(a));
create table child (c int, d int, 
		constraint child_fk foreign key(d) references parent(a));

-- or, you can use the schema change command 'alter table'
drop table child;
create table child (c int, d int);
alter table child add constraint child_fk foreign key(d) references parent(a);

insert into parent values (1,'A');

insert into child values (1,1);
insert into child values (1,null);
insert into child values (1,2);
-- what happens? why?

delete from child where d = 2;
delete from parent where a = 1;
-- what happens? why?
delete from child where d = 1; 
delete from parent where a = 1;
-- OK! why?

-- Please open utlsampl.sql and check what column in EMP table is declared as FOREIGN KEY and which table/column column it refers to. 

---------------------------
--====== Section 3.3 ======
---------------------------

-- in case of update & delete in parent tables, what other options are available?
-- foreign key(..) references parent(..) on delete {cascade|set null|no action(default)}
drop table child;
create table child (c int, d int, 
		constraint child_fk foreign key(d) references parent(a) on delete cascade);

-- Note: Oracle does not support "on update cascade" option!
-- If necessary, you can create your own update cascade package using trigger & pl/sql.

-- Deferring constraint check
drop table child;
drop table parent;
-- what happens? why?

create table parent (a int, b char(1), primary key(a));
create table child (c int, d int, 
		constraint child_fk foreign key(d) references parent(a) deferrable);

set constraint child_fk deferred;
insert into child values (1,2);
insert into parent values (2,'B');
commit;

drop table child;
drop table parent;


-- Oracle allows foreign key to refer to UNIQUE column as well as Primary Key.
-- Why is referenced attribute required to be PRIMARY KEY or UNIQUE? 
create table parent (a int, b char(1), primary key(a), unique(b));
create table child (c int, d char(1), 
		constraint child_fk foreign key(d) references parent(b));

---------------------------------------------------------------------------------------------------
-- DIY (Do It Yourself): 
-- More complex example about Foreign Key, including self-referencing FK and REFERENTIAL ACTIONS --
---------------------------------------------------------------------------------------------------
DROP TABLE EMP2;
DROP TABLE DEPT2;
CREATE TABLE DEPT2
       (DEPTNO NUMBER(2) CONSTRAINT PK_DEPT2 PRIMARY KEY,
	DNAME VARCHAR2(14) ,
	LOC VARCHAR2(13) ) ;
CREATE TABLE EMP2
       (EMPNO NUMBER(4) CONSTRAINT PK_EMP2 PRIMARY KEY,
	ENAME VARCHAR2(10),
	JOB VARCHAR2(9),
	MGR NUMBER(4) CONSTRAINT FK_MGR REFERENCES EMP2 ON DELETE CASCADE, -- Oracle Options: NO ACTION, CASCADE, SET NULL
	HIREDATE DATE,
	SAL NUMBER(7,2),
	COMM NUMBER(7,2),
	DEPTNO NUMBER(2) CONSTRAINT FK_DEPTNO2 REFERENCES DEPT2 ON DELETE CASCADE);

INSERT INTO DEPT2 VALUES (10,'ACCOUNTING','NEW YORK');
INSERT INTO DEPT2 VALUES (20,'RESEARCH','DALLAS');
INSERT INTO DEPT2 VALUES (30,'SALES','CHICAGO');
INSERT INTO DEPT2 VALUES (40,'OPERATIONS','BOSTON');

INSERT INTO EMP2 VALUES (7839,'KING','PRESIDENT',NULL,to_date('17-11-1981','dd-mm-yyyy'),5000,NULL,10);
INSERT INTO EMP2 VALUES (7566,'JONES','MANAGER',7839,to_date('2-4-1981','dd-mm-yyyy'),2975,NULL,20);
INSERT INTO EMP2 VALUES (7698,'BLAKE','MANAGER',7839,to_date('1-5-1981','dd-mm-yyyy'),2850,NULL,30);
INSERT INTO EMP2 VALUES (7782,'CLARK','MANAGER',7839,to_date('9-6-1981','dd-mm-yyyy'),2450,NULL,10);
INSERT INTO EMP2 VALUES (7788,'SCOTT','ANALYST',7566,to_date('13-7-87','dd-mm-rr')-85,3000,NULL,20);
INSERT INTO EMP2 VALUES (7902,'FORD','ANALYST',7566,to_date('3-12-1981','dd-mm-yyyy'),3000,NULL,20);
INSERT INTO EMP2 VALUES (7369,'SMITH','CLERK',7902,to_date('17-12-1980','dd-mm-yyyy'),800,NULL,20);
INSERT INTO EMP2 VALUES (7499,'ALLEN','SALESMAN',7698,to_date('20-2-1981','dd-mm-yyyy'),1600,300,30);
INSERT INTO EMP2 VALUES (7521,'WARD','SALESMAN',7698,to_date('22-2-1981','dd-mm-yyyy'),1250,500,30);
INSERT INTO EMP2 VALUES (7900,'JAMES','CLERK',7698,to_date('3-12-1981','dd-mm-yyyy'),950,NULL,30);
INSERT INTO EMP2 VALUES (7654,'MARTIN','SALESMAN',7698,to_date('28-9-1981','dd-mm-yyyy'),1250,1400,30);
INSERT INTO EMP2 VALUES (7844,'TURNER','SALESMAN',7698,to_date('8-9-1981','dd-mm-yyyy'),1500,0,30);
INSERT INTO EMP2 VALUES (7876,'ADAMS','CLERK',7788,to_date('13-7-87', 'dd-mm-rr')-51,1100,NULL,20);
INSERT INTO EMP2 VALUES (7934,'MILLER','CLERK',7782,to_date('23-1-1982','dd-mm-yyyy'),1300,NULL,10);
commit;

DELETE FROM DEPT2 WHERE DEPTNO = 30;      -- Check Blake, Allen, Ward, James and Martin from EMP2 table
DELETE FROM EMP2  WHERE ENAME = 'JONES';  -- Check Scott, Ford from EMP2 table 
DELETE FROM DEPT2 WHERE DEPTNO = 10;      -- Check EMP2 table. What about DEPT2 table?

DROP TABLE EMP2;
DROP TABLE DEPT2;

---------------------------
--====== Section 3.4 ======
---------------------------
-- We will learn more about SQL query from ch 4 & 5. 

SELECT E.ename, E.sal FROM emp E, dept D
WHERE E.deptno = D.deptno and D.loc = 'NEW YORK';

set autot on; 
-- more about "SET AUTOTRACE": 
-- https://docs.oracle.com/cd/A97630_01/server.920/a96533/autotrac.htm

SELECT E.ename, E.sal FROM emp E, dept D
WHERE E.deptno = D.deptno and D.loc = 'NEW YORK';

-- Execution Plan: an HOW used to get the result, automatically chosen by Oracle DBMS
-- Statistics: The statistics are recorded by the server when your statement executes 
--              and indicate the system resources required to execute your statement. 

-- How many different HOWs exist for the above query?
-- Note that different HOWs will return the same result. 

---------------------------
--====== Section 3.5 ======
---------------------------
-- Skip

----------------------------
--====== Section 3.6 =======
----------------------------

-- simple view example 
drop view my_emp;
create or replace view my_emp
as select empno, ename, sal from emp where deptno = 30;

--------------------------------------------------
--IF you have trouble in executinng the above "create view" command
-- (e.g., encountering the message "1행에 오류: ORA-01031: 권한이 불충분합니다 (Insufficient priviledge)"
--THEN do the followings
-      1. conn / as sysdba;
--     2. GRANT CREATE VIEW to SCOTT;
--     3. conn scott/tiger; 
-------------------------------------------------

select * from my_emp;

select * from my_emp where sal > 1500;
--  |  The above query againt VIEW my_emp will be AUTOMATICALLY translated 
--  |  into following query for BASE TABLE emp 
--  V  by Oracle Query Optimizer
select ename, sal from emp where deptno = 30 and sal > 1500;

-- join view
drop view join_view;
create view join_view
as select ename, dname from emp, dept where emp.deptno = dept.deptno;

select * from join_view;

-- view dependency on base table

drop table emp;
-- what happens to my_emp?
select * from user_views where view_name = 'MY_EMP';
-- it is still alive!
select * from my_emp;

----------------------------------
-- re-create/populate EMP table
----------------------------------
CREATE TABLE EMP
       (EMPNO NUMBER(4) CONSTRAINT PK_EMP PRIMARY KEY,
	ENAME VARCHAR2(10),
	JOB VARCHAR2(9),
	MGR NUMBER(4),
	HIREDATE DATE,
	SAL NUMBER(7,2),
	COMM NUMBER(7,2),
	DEPTNO NUMBER(2) CONSTRAINT FK_DEPTNO REFERENCES DEPT);
INSERT INTO EMP VALUES (7369,'SMITH','CLERK',7902,to_date('17-12-1980','dd-mm-yyyy'),800,NULL,20);
INSERT INTO EMP VALUES (7499,'ALLEN','SALESMAN',7698,to_date('20-2-1981','dd-mm-yyyy'),1600,300,30);
INSERT INTO EMP VALUES (7521,'WARD','SALESMAN',7698,to_date('22-2-1981','dd-mm-yyyy'),1250,500,30);
INSERT INTO EMP VALUES (7566,'JONES','MANAGER',7839,to_date('2-4-1981','dd-mm-yyyy'),2975,NULL,20);
INSERT INTO EMP VALUES (7654,'MARTIN','SALESMAN',7698,to_date('28-9-1981','dd-mm-yyyy'),1250,1400,30);
INSERT INTO EMP VALUES (7698,'BLAKE','MANAGER',7839,to_date('1-5-1981','dd-mm-yyyy'),2850,NULL,30);
INSERT INTO EMP VALUES (7782,'CLARK','MANAGER',7839,to_date('9-6-1981','dd-mm-yyyy'),2450,NULL,10);
INSERT INTO EMP VALUES (7788,'SCOTT','ANALYST',7566,to_date('13-JUL-87','dd-mm-rr')-85,3000,NULL,20);
INSERT INTO EMP VALUES (7839,'KING','PRESIDENT',NULL,to_date('17-11-1981','dd-mm-yyyy'),5000,NULL,10);
INSERT INTO EMP VALUES (7844,'TURNER','SALESMAN',7698,to_date('8-9-1981','dd-mm-yyyy'),1500,0,30);
INSERT INTO EMP VALUES (7876,'ADAMS','CLERK',7788,to_date('13-JUL-87', 'dd-mm-rr')-51,1100,NULL,20);
INSERT INTO EMP VALUES (7900,'JAMES','CLERK',7698,to_date('3-12-1981','dd-mm-yyyy'),950,NULL,30);
INSERT INTO EMP VALUES (7902,'FORD','ANALYST',7566,to_date('3-12-1981','dd-mm-yyyy'),3000,NULL,20);
INSERT INTO EMP VALUES (7934,'MILLER','CLERK',7782,to_date('23-1-1982','dd-mm-yyyy'),1300,NULL,10);
commit;

select * from my_emp; -- it still works!

---------------------------------
--====== View updatability ======
---------------------------------

-- SINGLE VIEW
insert into my_emp values(9999, 'SIMON',10000);
select * from emp;
select * from my_emp; -- what about 'SIMON'?

-- HOW to prevent the above this scenario? 'WITH CHECK OPTION'
create or replace view my_emp
as select empno, ename, sal 
from emp 
where deptno = 30
WITH CHECK OPTION;

-- JOIN VIEW
insert into join_view values('SIMON','DATABASE');
-- What happens? Why?

-- Aggregate VIEW
create materialized view avg_sal_view as
select deptno, avg(sal) avg_sal
from emp
group by deptno; 
--------------------------------------------------
--When you encouhave an error while executing the above "create materialized view" command
--THEN do the followings
-      1. conn / as sysdba;
--     2. GRANT CREATE MATERIALIZED VIEW to SCOTT;
--     3. conn scott/tiger; 
-------------------------------------------------

select * from avg_sal_view;
insert into avg_sal_view values (40, 1000);
-- What happens? Why? 

----------------------------------
--======= View and security ======
----------------------------------
grant select on my_emp to hr;

-- If "SP2-0306: Invalid option" error is encountered for the following "conn" command 
-- (this error occurs probably because you are using Oracle VM Oralce 12c), 
-- then try "conn system/oracle"; 
conn / as sysdba; 
alter user hr account unlock;
alter user hr identified by hr;

conn hr/hr;
select * from scott.my_emp;

conn scott/tiger; 
drop view my_emp;

-----------------------------------
--====== 3.7 Schema evolution =====
-----------------------------------

-- Schema evolution using "alter table": some examples
alter table emp add (new number default 0);
alter table emp drop column hiredate;
alter table emp set unused column comm;
select * from emp; 
alter table emp add constraint mgr_fk foreign key(mgr) references emp;
