-- Copyright(c) SNU VLDB Lab. All Rights Reserved (since 2016).


0. Very simple example: Oracle Recursive Subquery Factoring 
-- https://nimishgarg.blogspot.com/2010/12/recursive-subquery-factoring-with.html
-- https://nimishgarg.blogspot.com/2010/12/recursive-subquery-factoring-with_20.html

-- Example 1: Print 1 to 10
with t(a) as
(
    select 1 as a from dual
    union all
    select a+1 from t where a< 10
)
select a from t

-- Example 2: Power
with mytab(a, b, c) as
(
    select 3 a, 5 b, 1 c from dual
    union all
    select a, b-1, c*a from mytab where b > 0
)
select a,5-b b, c pow from mytab

-- Example 3: Fibonacci Series
with mytab(a,b,c) as
(
    select 0 a, 1 b, 1 c from dual
    union all
    select b,c,b+c from mytab where a < 100
)
select a,b,c fib from mytab

-- NOTE: related error: "ORA-32044: 순환 WITH 질의를 실행하는 중 주기가 감지되었습니다." 
-- See on why: https://stackoverflow.com/questions/24387957/getting-error-as-ora-32044-cycle-detected-while-executing-recursive-with-query
-- Also ask ChatGPT why and how to fix it. "The following query will encounter an error when run in Oracle. How to fix it?"
-- Is ChatGPT correct? 


-- A correct version 1 (using CYCLE clause)
with mytab(a,b,c) as
(
    select 1 a, 1 b, 0 c from dual
    union all
    select b,c,b+c from mytab where a < 100
)
cycle a,b,c set is_loop to 'Y' default 'N'
select a,b,c fib from mytab

-- In the previous case, a row forms a cycle if one of its ancestor rows has the same values for all the columns
-- in the column alias list for query_name that are referenced in the WHERE clause of the recursive member

-- you can solve this error using the CYCLE clause. The CYCLE clause allows you to specify the columns that form a cycle.
-- A row is considered to form a cycle if one of its ancestor rows has the same values for the cycle columns.

-- refer to the following URL for more details.
-- https://developer-sam.de/2023/02/get-a-list-of-quarters-by-year-with-recursive-ctes-with-clause/
-- https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html (cycle_clause)


-- A correct version 2 (using level column)
with mytab(a,b,c,lvl) as
(
    select 0 a, 1 b, 1 c, 1 lvl from dual
    union all
    select b,c,b+c, lvl+1  from mytab where lvl < 10
)
select lvl,a,b,c fib from mytab


-- This sample comes from the following URL.
-- https://oracle-base.com/articles/11g/recursive-subquery-factoring-11gr2


DROP TABLE parent PURGE;

CREATE TABLE parent (
  id        NUMBER,
  parent_id NUMBER,
  CONSTRAINT tab1_pk PRIMARY KEY (id),
  CONSTRAINT tab1_tab1_fk FOREIGN KEY (parent_id) REFERENCES parent(id)
);

CREATE INDEX parent_id_idx ON parent(parent_id);

INSERT INTO parent VALUES (1, NULL);
INSERT INTO parent VALUES (2, 1);
INSERT INTO parent VALUES (3, 2);
INSERT INTO parent VALUES (4, 2);
INSERT INTO parent VALUES (5, 4);
INSERT INTO parent VALUES (6, 4);
INSERT INTO parent VALUES (7, 1);
INSERT INTO parent VALUES (8, 7);
INSERT INTO parent VALUES (9, 1);
INSERT INTO parent VALUES (10, 9);
INSERT INTO parent VALUES (11, 10);
INSERT INTO parent VALUES (12, 9);
COMMIT;

SET PAGESIZE 20 LINESIZE 110

--============================================================================
-- A recursive subquery factoring clause must contain two query blocks 
-- combined by a UNION ALL set operator. The first block is known as 
-- the anchor member, which can not reference the query name. It can be 
-- made up of one or more query blocks combined by the UNION ALL, UNION, 
-- INTERSECT or MINUS set operators. The second query block is known as 
-- the recursive member, which must reference the query name once.
--
-- The following query uses a recursive WITH clause to perform a tree walk. 
-- The anchor member queries the root nodes by testing for records with 
-- no parents. The recursive member successively adds the children to the 
-- root nodes.
--============================================================================

WITH ancestor(id, ancestor_id) AS (
  -- Anchor member.
  SELECT id, parent_id
  FROM   parent
  UNION ALL
  -- Recursive member.
  SELECT p.id , a.ancestor_id
  FROM   parent p, ancestor a
  WHERE  p.parent_id = a.id
)
SELECT id,
       ancestor_id
FROM   ancestor
where ancestor_id is not null;

--Result: ?

-- Can we prune node or branch? How?

--=============================================================================
-- The ordering of the rows is specified using either two SEARCH clauses
-- 1. BREADTH FIRST BY : Sibling rows are returned before child rows 
--    are processed.
-- 2. DEPTH FIRST BY : Child rows are returned before siblings are processed.
--============================================================================

WITH ancestor (id, ancestor_id) AS (
	..
)
SEARCH BREADTH FIRST BY id SET order1 
--or, SEARCH DEPTH FIRST BY id SET order1
SELECT id,
       parent_id
FROM   ancestor 
ORDER BY order1;

Practice
1. Write recursive SQL which deduces all direct or indirect supervisor-subordinate pair 
   (i.e., super_id, super_name, sub_id, sub_name) from emp table. 


2. Write recursive SQL which retrieve the names of all direct or indirect subordinates of JONES in Emp table. 


3. Write recursive SQL which retrieve the names of all direct or indirect supervisors of Smith in Emp table. 


4. Another example using recursive SQL in Oracle: https://nimishgarg.blogspot.com/2010/12/recursive-subquery-factoring-with_28.html


---OLD STYLE: CONNECT BY PRIOR
select
    lpad(ename,(level*4)+length(ename),'-') data,
    empno eid,
    ename,
    level lvl
from
    scott.emp
connect by prior
    empno=mgr
start with
    empno=7839

-- NEW Style: RECURSIVE SUBQUERY FACTORING

with myemp(eid, ename, lvl) as
(
    select empno, ename, 1 as lvl from scott.emp where mgr is null
    union all
    select empno, e.ename, lvl+1 from scott.emp e, myemp m where e.mgr=m.eid
) search depth first by eid set seq
select lpad(ename,(lvl*4)+length(ename),'-') data, eid, ename, lvl from myemp order by seq

-- #Alternatively you can have siblings processed prior to children. Change DEPTH to BREADTH

