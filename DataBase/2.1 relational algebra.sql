-- Copyright SNU VLDB Lab. All Rights Reserved.
-- Ch 4. example.sql
-- This example script is intended to show how SQL covers relational alagebra's basic operations
-- with its Select-From-Where syntax.

set echo on
set pause on

conn scott/tiger
-- Reset the scott/tiger schema
conn / as sysdba; 
-- in case of Oracle VM, instead use the following command 
-- conn sys/oracle@localhost/orcl as sysdba
@$ORACLE_HOME/rdbms/admin/utlsampl.sql


-- @%ORACLE_HOME%\sqlplus\demo\demobld; -- 9i: 
-- @%ORACLE_HOME%\RDBMS\ADMIN\utlsampl; -- 10g, 11g;
-- @/u01/app/oracle/product/12.2/db_1/rdbms/admin/utlsampl.sql; -- 12c 

-- recall the sample database schema and instance
--conn scott/tiger
sqlplus scott/tiger 
desc emp
desc dept
select * from emp;
select * from dept;

--***************
--* Section 4.2 *
--***************

---------------
-- projection -
---------------

select ename, sal
from emp;
-- input relation schema vs. output result (relation) schema

select sal, ename
from emp;
-- Note 1: The column orders in emp schema and projection list are different!
-- Note 2: Two results from the above two queries are same. 
--         The order of columns does not matter. 

select job
from emp;
-- note: duplication in the result table (It is not SET but Multi-set or Bag
-- Relational algebra: set semantics vs. SQL: bag semantics

-- How to eliminate duplicate tuples from the result: 
select distinct job
from emp;

--------------
-- selection -
--------------

select * 
from emp
where deptno = 30;

select * 
from emp
where not(deptno = 30);
-- where deptno != 30; or where deptno <> 30; 

select * 
from emp
where deptno = 30 and sal > 2000;

select * 
from emp
where deptno = 30 or sal > 2000;

select * 
from emp
where deptno = 30 and (job = 'CLERK' or sal > 2000);

-- selection, then projection
select ename, sal
from emp
where deptno = 30;

-----------------------------------
-- union, difference, intesection -
-----------------------------------

-- create two sample relations r, s
-- relation r = {1, 2, 2, 3, 3, 3}
-- relation s = {1, 1, 1, 2, 2, 3}

create table r (a number);
insert into r values(1);
insert into r values(2);
insert into r values(2);
insert into r values(3);
insert into r values(3);
insert into r values(3);
commit;

create table s (a number);
insert into s values(1);
insert into s values(1);
insert into s values(1);
insert into s values(2);
insert into s values(2);
insert into s values(3);
commit;

select * from r
union 
select * from s;
-- note: no bag semantics!! ugly, isn't it?

select * from r
union all
select * from s;

select * from r
intersect
select * from s;

select * from r
minus
select * from s;

--select * from r
--intersect all
--select * from s;

--select * from r
--minus all
--select * from s;
-- Oracle does not support "{intersect, minus} all"

drop table r;
drop table s;
------------------
-- cross product -
------------------

select *
from emp, dept;
-- note: how many tuples in the result table?


select deptno
from emp, dept;
-- error? why? duplicate column name in the result

select emp.deptno
from emp, dept;
-- error? why?

select e.deptno
from emp e, dept d;
-- better way: use tuple variable e.g. e, d 

------------------------------------------------------
-- join - we will study more examples in ch5.example -
------------------------------------------------------

select *
from emp, dept
where emp.deptno < dept.deptno;

-- Equi-join 
select *
from emp, dept
where emp.deptno = dept.deptno;

-- ANSI standard join syntax
select *
from emp natural join dept;

-- Self-join 
select *
from emp e1, emp e2
where e1.mgr = e2.empno;

-- What about division? Note that Oracle does not support "divide" command.
select * 
from R divide by S;

-- Simple example showing how to "divide" R with S using the basic SQL features.
create table r(a int, b int);
create table s(b int);

insert into r values(1,1);
insert into r values(1,2);
insert into r values(1,4);
insert into r values(2,1);
insert into r values(2,3);
insert into r values(3,3);
insert into r values(3,4);
insert into r values(4,1);
insert into r values(4,4);
insert into s values(1);
insert into s values(4);

select distinct x.a
from r x
where not exists(
select *
from s y
where not exists(
select *
from r z
 where (z.a=x.a) and (z.b=y.b)));

drop table r;
drop table s;
