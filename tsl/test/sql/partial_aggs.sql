-- This file and its contents are licensed under the Timescale License.
-- Please see the included NOTICE for copyright information and
-- LICENSE-TIMESCALE for a copy of the license.

-- TEST1 count with integers
create table foo (a integer, b integer, c integer);
insert into foo values( 1 , 10 , 20);
insert into foo values( 1 , 11 , 20);
insert into foo values( 1 , 12 , 20);
insert into foo values( 1 , 13 , 20);
insert into foo values( 1 , 14 , 20);
insert into foo values( 2 , 14 , 20);
insert into foo values( 2 , 15 , 20);
insert into foo values( 2 , 16 , 20);
insert into foo values( 3 , 16 , 20);


create or replace view v1(a , partial)
as
 SELECT a, _timescaledb_internal.partialize_agg( count(b)) from foo group by a;

create table t1 as select * from v1;

select a, _timescaledb_internal.finalize_agg( 'count("any")', null, null, partial, cast('1' as int8) ) from t1
group by a order by a ;

insert into t1 select * from t1;
select a, _timescaledb_internal.finalize_agg( 'count("any")', null, null, partial, cast('1' as int8) ) from t1
group by a order by a ;

--TEST2 sum numeric and min on float--
drop table t1;
drop view v1;
drop table foo;

create table foo (a integer, b numeric , c float);
insert into foo values( 1 , 10 , 20);
insert into foo values( 1 , 20 , 19);
insert into foo values( 1 , 30 , 11.0);
insert into foo values( 1 , 40 , 200);
insert into foo values( 1 , 50 , -10);
insert into foo values( 2 , 10 , 20);
insert into foo values( 2 , 20 , 20);
insert into foo values( 2 , 30 , 20);
insert into foo values( 3 , 40 , 0);


create or replace view v1(a , partialb, partialminc)
as
 SELECT a,  _timescaledb_internal.partialize_agg( sum(b)) , _timescaledb_internal.partialize_agg( min(c)) from foo group by a;

create table t1 as select * from v1;

select a, _timescaledb_internal.finalize_agg( 'sum(numeric)', null, null, partialb, cast('1' as numeric) ) sumb, _timescaledb_internal.finalize_agg( 'min(double precision)', null, null, partialminc, cast('1' as float8) ) minc from t1 group by a order by a ;

insert into foo values( 3, 0, -1);
insert into foo values( 5, 40, 10);
insert into foo values( 5, 40, 0);
--note that rows for 3 get added all over again + new row
--sum aggfnoid 2114, min aggfnoid is 2136 oid  numeric is 1700
insert into t1 select * from v1 where ( a = 3 ) or a = 5;
select a, _timescaledb_internal.finalize_agg( 'sum(numeric)', null, null, partialb, cast('1' as numeric) ) sumb, _timescaledb_internal.finalize_agg( 'min(double precision)', null, null, partialminc, cast('1' as float8) ) minc from t1 group by a order by a ;

--TEST3 sum with expressions 
drop table t1;
drop view v1;
drop table foo;

create table foo (a integer, b numeric , c float);
insert into foo values( 1 , 10 , 20);
insert into foo values( 1 , 20 , 19);
insert into foo values( 1 , 30 , 11.0);
insert into foo values( 1 , 40 , 200);
insert into foo values( 1 , 50 , -10);
insert into foo values( 2 , 10 , 20);
insert into foo values( 2 , 20 , 20);
insert into foo values( 2 , 30 , 20);
insert into foo values( 3 , 40 , 0);
insert into foo values(10, NULL, NULL);
insert into foo values(11, NULL, NULL);
insert into foo values(11, NULL, NULL);
insert into foo values(12, NULL, NULL);

create or replace view v1(a , b, partialb, partialminc)
as
 SELECT a, b, _timescaledb_internal.partialize_agg( sum(b+c)) , _timescaledb_internal.partialize_agg( min(c)) from foo group by a, b ;

create table t1 as select * from v1;

insert into foo values( 3, 0, -1);
insert into foo values( 5, 40, 10);
insert into foo values( 5, 40, 0);
insert into foo values(12, 10, 20);
insert into t1 select * from v1 where ( a = 3 and b = 0 ) or a = 5 or (a = 12 and b = 10) ;

--results should match query: select a, sum(b+c), min(c) from foo group by a order by a;
--sum aggfnoid 2111 for float8, min aggfnoid is 2136 oid  numeric is 1700
select a, _timescaledb_internal.finalize_agg( 'sum(double precision)', null, null, partialb, null::float8 ) sumcd, _timescaledb_internal.finalize_agg( 'min(double precision)', null, null, partialminc, cast('1' as float8) ) minc from t1 group by a order by a ;

insert into t1 select * from v1;
select a, _timescaledb_internal.finalize_agg( 'sum(double precision)', null, null, partialb, null::float8 ) sumcd, _timescaledb_internal.finalize_agg( 'min(double precision)', null, null, partialminc, cast('1' as float8) ) minc from t1 group by a order by a ;

-- TEST4 with collation (text), NULLS and timestamp --
drop table t1;
drop view v1;
drop table foo;

create table foo (a integer, b numeric , c text, d timestamptz);
insert into foo values( 1 , 10 , 'hello', '2010-01-01 09:00:00-08');
insert into foo values( 1 , 20 , 'abc', '2010-01-02 09:00:00-08');
insert into foo values( 1 , 30 , 'abcd',  '2010-01-03 09:00:00-08');
insert into foo values( 1 , 40 , 'abcde', NULL );
insert into foo values( 1 , 50 , NULL,  '2010-01-01 09:00:00-08');
--group with all values for c and d same
insert into foo values( 2 , 10 ,  'hello', '2010-01-01 09:00:00-08');
insert into foo values( 2 , 20 , 'hello', '2010-01-01 09:00:00-08');
insert into foo values( 2 , 30 , 'hello', '2010-01-01 09:00:00-08');
--group with all values for c and d NULL 
insert into foo values( 3 , 40 , NULL, NULL);
insert into foo values( 3 , 50 , NULL, NULL);
insert into foo values(11, NULL, NULL, NULL);
insert into foo values(11, NULL, 'hello', '2010-01-02 09:00:00-05');
--group with all values for c and d NULL and later add non-null. 
insert into foo values(12, NULL, NULL, NULL);


create or replace view v1(a , b, partialb, partialc, partiald)
as
 SELECT a, b, _timescaledb_internal.partialize_agg( sum(b)) , _timescaledb_internal.partialize_agg( min(c)) , _timescaledb_internal.partialize_agg(max(d)) from foo group by a, b ;

create table t1 as select * from v1;

--sum 2114, collid 0, min(text) 2145, collid 100, max(ts) 2127
insert into foo values(12, 10, 'hello', '2010-01-02 09:00:00-05');
insert into t1 select * from v1 where  (a = 12 and b = 10) ;

--select a, sum(b), min(c) , max(d) from foo group by a order by a;
--results should match above query
select a, _timescaledb_internal.finalize_agg( 'sum(numeric)', null, null, partialb, null::numeric ) sumb
, _timescaledb_internal.finalize_agg( 'min(text)', 'pg_catalog', 'default', partialc, null::text ) minc 
, _timescaledb_internal.finalize_agg( 'max(timestamp with time zone)', null, null, partiald, null::timestamptz ) maxd from t1 group by a order by a ;

--with having clause --
select a, b ,  _timescaledb_internal.finalize_agg( 'min(text)', 'pg_catalog', 'default', partialc, null::text ) minc, _timescaledb_internal.finalize_agg( 'max(timestamp with time zone)', null, null, partiald, null::timestamptz ) maxd from t1  where b is not null group by a, b having _timescaledb_internal.finalize_agg( 'max(timestamp with time zone)', null, null, partiald, null::timestamptz ) is not null order by a, b;


--TEST5 test with TOAST data

drop table t1;
drop view v1;
drop table foo;
create table foo( a integer, b timestamptz, toastval TEXT);
-- Set storage type to EXTERNAL to prevent PostgreSQL from compressing my
-- easily compressable string and instead store it with TOAST
ALTER TABLE foo ALTER COLUMN toastval SET STORAGE EXTERNAL;
SELECT count(*) FROM create_hypertable('foo', 'b');

INSERT INTO foo VALUES( 1,  '2004-10-19 10:23:54', $$ this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k. this must be over 2k.
$$);
INSERT INTO foo VALUES(1,  '2005-10-19 10:23:54', $$ I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.  I am a tall big giraffe in the zoo.
$$);
INSERT INTO foo values( 1, '2005-01-01 00:00:00+00', NULL);
INSERT INTO foo values( 2, '2005-01-01 00:00:00+00', NULL);

--SELECT * FROM chunk_relation_size_pretty('foo');

create or replace  view v1(a, partialb, partialtv) as select a, _timescaledb_internal.partialize_agg( max(b) ), _timescaledb_internal.partialize_agg( min(toastval)) from foo group by a;

create table t1 as select * from v1;

-- 2145 min(text), 2127 max(timestamp)
-- select regprocedureout( 2127);
insert into t1 select * from v1;
select a, _timescaledb_internal.finalize_agg( 'max(timestamp with time zone)', null, null, partialb, null::timestamptz ) maxb, substring(_timescaledb_internal.finalize_agg( 'min(text)', 'pg_catalog', 'default', partialtv, null::text ) from 1 for 20) mintv
from t1 group by a order by a;

---select a, max(b), substring( min(toastval) from 1 for 20)  from foo group by a;

