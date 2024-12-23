-- Copyright(c) SNU VLDB Lab. (since 2005). All Rights Reserved.
-- cube.sql

-- This sample data comes from Jim Gray's original cube paper

create table sales (model varchar2(10), year varchar(10), color varchar(10),
                    sales number);

insert into sales values ('Chevy', '1990', 'Red', 5);
insert into sales values ('Chevy', '1990', 'White', 87);
insert into sales values ('Chevy', '1990', 'Blue', 62);
insert into sales values ('Chevy', '1991', 'Red', 54);
insert into sales values ('Chevy', '1991', 'White', 95);
insert into sales values ('Chevy', '1991', 'Blue', 49);
insert into sales values ('Chevy', '1992', 'Red', 31);
insert into sales values ('Chevy', '1992', 'White', 54);
insert into sales values ('Chevy', '1992', 'Blue', 71);
insert into sales values ('Ford', '1990', 'Red', 64);
insert into sales values ('Ford', '1990', 'White', 62);
insert into sales values ('Ford', '1990', 'Blue', 63);
insert into sales values ('Ford', '1991', 'Red', 52);
insert into sales values ('Ford', '1991', 'White', 9);
insert into sales values ('Ford', '1991', 'Blue', 55);
insert into sales values ('Ford', '1992', 'Red', 27);
insert into sales values ('Ford', '1992', 'White', 62);
insert into sales values ('Ford', '1992', 'Blue', 39);

commit;

-- using scott's emp table
-------------
-- roll-up --
-------------

SELECT job, deptno, sum(sal)
FROM emp
GROUP BY rollup(job,deptno); 

-- GROUP BY + UNION ALL
SELECT job, deptno, sum(sal)
FROM emp
group by job,deptno
UNION ALL
SELECT job, NULL, sum(sal)
FROM emp 
GROUP BY job
UNION ALL
SELECT NULL, NULL, sum(sal)
FROM emp 

----------
-- cube --
----------

SELECT job, deptno, sum(sal)
FROM emp
GROUP BY cube(job,deptno); 

-- GROUP BY + UNION ALL

SELECT job, deptno, sum(sal)
FROM emp
group by job,deptno
UNION ALL
SELECT job, NULL, sum(sal)
FROM emp 
GROUP BY job
UNION ALL
SELECT NULL, deptno, sum(sal)
FROM emp 
GROUP BY deptno
UNION ALL
SELECT NULL, NULL, sum(sal)
FROM emp 

-----------------------
-- GROUPING function --
-----------------------

SELECT job, deptno, sum(sal), 
       grouping(job) as JOB, grouping(deptno) as DEPTNO
FROM emp
GROUP BY cube(job,deptno);

SELECT DECODE(grouping(job),1,'ALL', job) as JOB,
       DECODE(grouping(deptno),1,'ALL',deptno) as DEPTNO, 
       sum(sal)
FROM emp
GROUP BY cube(job,deptno);
