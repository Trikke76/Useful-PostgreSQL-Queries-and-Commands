--- A Collection of usefull PGSQL Queries found over the internet 
--- Some part was taken from : https://gist.github.com/anvk/475c22cbca1edc5ce94546c871460fdd



-------------------
--- USER / ROLE ---
-------------------

-- Grant all rights on schema to a role/user
grant all on schema <schema> to <role>;

-- Grant a role to a user
grant <role> to <user>;

-- Revoke a role from a user
revoke <role> from <user>;

-- Switch to an other user
set role <user>;

-- Create user with login rights
create role <new role> login;
grant role,role,role, … to user;

-- Give (extra )rights to a role
ALTER USER <role> WITH ..... ex: CREATEROLE;



---------------------------------------
--- DATABASE / TABLES / CONNECTIONS ---
---------------------------------------

-- Place the db in read only mode
ALTER DATABASE <foobar> SET default_transaction_read_only = true;
reload postgres (sig hub) no restart needed

-- Check connections:
select datname, usename, backend_start, query_start, state_change,state,client_addr from pg_stat_activity;

-- Terminate idle connections:
select pg_terminate_backend(pid) from pg_stat_activity where state='idle';

-- Drop all connections
select pg_terminate_backend(pid) from pg_stat_activity where datname = ‘<database>’;

-- rename database name:
alter database <database> rename to <new db name>;

-- check permissions on table
select * from information_schema.role_table_grants where table_name = 'build';

-- Total size of the biggest 10 tables;
SELECT
t.tablename,
pg_size_pretty(pg_total_relation_size('"' || t.schemaname || '"."' || t.tablename || '"')) AS table_total_disc_size
FROM pg_tables t
WHERE
t.schemaname = 'public'
ORDER BY
pg_total_relation_size('"' || t.schemaname || '"."' || t.tablename || '"') DESC
LIMIT 10;

-- Check if a backup is running
select pg_is_in_backup();

-- Stop a running backup
select pg_stop_backup();
    
--------------------
-- Data Integrity --
--------------------    
    
-- Cache Hit Ratio
select sum(blks_hit)*100/sum(blks_hit+blks_read) as hit_ratio from pg_stat_database;
-- (perfectly )hit_ration should be > 90%

-- Anomalies
select datname, (xact_commit100)/nullif(xact_commit+xact_rollback,0) as c_commit_ratio, (xact_rollback100)/nullif(xact_commit+xact_rollback, 0) as c_rollback_ratio, deadlocks, conflicts, temp_files, pg_size_pretty(temp_bytes) from pg_stat_database;

-- c_commit_ratio should be > 95%
-- c_rollback_ratio should be < 5%
-- deadlocks should be close to 0
-- conflicts should be close to 0
-- temp_files and temp_bytes watch out for them

-- Table Sizes
select relname, pg_size_pretty(pg_total_relation_size(relname::regclass)) as full_size, pg_size_pretty(pg_relation_size(relname::regclass)) as table_size, pg_size_pretty(pg_total_relation_size(relname::regclass) - pg_relation_size(relname::regclass)) as index_size from pg_stat_user_tables order by pg_total_relation_size(relname::regclass) desc limit 10;

-- Another Table Sizes Query
SELECT nspname || '.' || relname AS "relation", pg_size_pretty(pg_total_relation_size(C.oid)) AS "total_size" FROM pg_class C LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace) WHERE nspname NOT IN ('pg_catalog', 'information_schema') AND C.relkind <> 'i' AND nspname !~ '^pg_toast' ORDER BY pg_total_relation_size(C.oid) DESC;

-- Database Sizes
select datname, pg_size_pretty(pg_database_size(datname)) from pg_database order by pg_database_size(datname);

-- Unused Indexes
select * from pg_stat_all_indexes where idx_scan = 0;
-- idx_scan should not be = 0

-- Write Activity(index usage)
select s.relname, pg_size_pretty(pg_relation_size(relid)), coalesce(n_tup_ins,0) + 2 * coalesce(n_tup_upd,0) - coalesce(n_tup_hot_upd,0) + coalesce(n_tup_del,0) AS total_writes, (coalesce(n_tup_hot_upd,0)::float * 100 / (case when n_tup_upd > 0 then n_tup_upd else 1 end)::float)::numeric(10,2) AS hot_rate, (select v[1] FROM regexp_matches(reloptions::text,E'fillfactor=(d+)') as r(v) limit 1) AS fillfactor from pg_stat_all_tables s join pg_class c ON c.oid=relid order by total_writes desc limit 50;
-- hot_rate should be close to 100

-- Does table needs an Index
SELECT relname, seq_scan-idx_scan AS too_much_seq, CASE WHEN seq_scan-idx_scan>0 THEN 'Missing Index?' ELSE 'OK' END, pg_relation_size(relname::regclass) AS rel_size, seq_scan, idx_scan FROM pg_stat_all_tables WHERE schemaname='public' AND pg_relation_size(relname::regclass)>80000 ORDER BY too_much_seq DESC;

-- cache hit rates (should not be less than 0.99)
SELECT sum(heap_blks_read) as heap_read, sum(heap_blks_hit)  as heap_hit, (sum(heap_blks_hit) - sum(heap_blks_read)) / sum(heap_blks_hit) as ratio
FROM pg_statio_user_tables;

-- table index usage rates (should not be less than 0.99)
SELECT relname, 100 * idx_scan / (seq_scan + idx_scan) percent_of_times_index_used, n_live_tup rows_in_table
FROM pg_stat_user_tables 
ORDER BY n_live_tup DESC;

-- Get a list of tables with indexes
select
    t.relname as table_name,
    i.relname as index_name,
    string_agg(a.attname, ',') as column_name
from
    pg_class t,
    pg_class i,
    pg_index ix,
    pg_attribute a
where
    t.oid = ix.indrelid
    and i.oid = ix.indexrelid
    and a.attrelid = t.oid
    and a.attnum = ANY(ix.indkey)
    and t.relkind = 'r'
    and t.relname not like 'pg_%'
group by  
    t.relname,
    i.relname
order by
    t.relname,
    i.relname;
                                                                                                    
-- List Tables with the size and the index size 
SELECT
    table_name,
    pg_size_pretty(table_size) AS table_size,
    pg_size_pretty(indexes_size) AS indexes_size,
    pg_size_pretty(total_size) AS total_size
FROM (
    SELECT
        table_name,
        pg_table_size(table_name) AS table_size,
        pg_indexes_size(table_name) AS indexes_size,
        pg_total_relation_size(table_name) AS total_size
    FROM (
        SELECT ('"' || table_schema || '"."' || table_name || '"') AS table_name
        FROM information_schema.tables
    ) AS all_tables
    ORDER BY total_size DESC
) AS pretty_sizes

                                                                                                    
-- List every Index in the database with there size
WITH tbl_spc AS (
SELECT ts.spcname AS spcname
FROM pg_tablespace ts 
JOIN pg_database db ON db.dattablespace = ts.oid
WHERE db.datname = current_database()
)
(
SELECT
t.schemaname,
t.tablename,
pg_table_size('"' || t.schemaname || '"."' || t.tablename || '"') AS table_disc_size,
NULL as index,
0 as index_disc_size,
COALESCE(t.tablespace, ts.spcname) AS tablespace
FROM pg_tables t, tbl_spc ts

UNION ALL

SELECT
i.schemaname,
i.tablename,
0,
i.indexname,
pg_relation_size('"' || i.schemaname || '"."' || i.indexname || '"'),
COALESCE(i.tablespace, ts.spcname)
FROM pg_indexes i, tbl_spc ts
)
ORDER BY table_disc_size DESC,index_disc_size DESC;
                                                                                                    
                                                                                                    
    
-- How many indexes are in cache
SELECT sum(idx_blks_read) as idx_read, sum(idx_blks_hit) as idx_hit, (sum(idx_blks_hit) - sum(idx_blks_read)) / sum(idx_blks_hit) as ratio FROM pg_statio_user_indexes;

-- Dirty Pages
select buffers_clean, maxwritten_clean, buffers_backend_fsync from pg_stat_bgwriter;
-- maxwritten_clean and buffers_backend_fsyn better be = 0

-- Sequential Scans
select relname, pg_size_pretty(pg_relation_size(relname::regclass)) as size, seq_scan, seq_tup_read, seq_scan / seq_tup_read as seq_tup_avg from pg_stat_user_tables where seq_tup_read > 0 order by 3,4 desc limit 5;
-- seq_tup_avg should be < 1000

-- Checkpoints
select 'bad' as checkpoints from pg_stat_bgwriter where checkpoints_req > checkpoints_timed;
                                                
-- Check for indexes, drop and recreate them
# \d history_uint
              Table "public.history_uint"
 Column |     Type      |           Modifiers
--------+---------------+-------------------------------
 itemid | bigint        | not null
 clock  | integer       | not null default 0
 value  | numeric(20,0) | not null default '0'::numeric
 ns     | integer       | not null default 0
Indexes:
    "history_uint_1" btree (itemid, clock)


# drop index history_uint_1;
DROP INDEX

# create index CONCURRENTLY history_uint_1 on history_uint (itemid, clock);

--------------
-- Activity --
--------------

-- Most CPU intensive queries (PGSQL v9.4)
SELECT substring(query, 1, 50) AS short_query, round(total_time::numeric, 2) AS total_time, calls, rows, round(total_time::numeric / calls, 2) AS avg_time, round((100 * total_time / sum(total_time::numeric) OVER ())::numeric, 2) AS percentage_cpu FROM pg_stat_statements ORDER BY total_time DESC LIMIT 20;

-- Most time consuming queries (PGSQL v9.4)
SELECT substring(query, 1, 100) AS short_query, round(total_time::numeric, 2) AS total_time, calls, rows, round(total_time::numeric / calls, 2) AS avg_time, round((100 * total_time / sum(total_time::numeric) OVER ())::numeric, 2) AS percentage_cpu FROM pg_stat_statements ORDER BY avg_time DESC LIMIT 20;

-- Maximum transaction age
select client_addr, usename, datname, clock_timestamp() - xact_start as xact_age, clock_timestamp() - query_start as query_age, query from pg_stat_activity order by xact_start, query_start;
-- Long-running transactions are bad because they prevent Postgres from vacuuming old data. This causes database bloat and, in extreme circumstances, shutdown due to transaction ID (xid) wraparound. Transactions should be kept as short as possible, ideally less than a minute.

-- Bad xacts
select * from pg_stat_activity where state in ('idle in transaction', 'idle in transaction (aborted)');

-- Waiting Clients
select * from pg_stat_activity where waiting;

-- Waiting Connections for a lock
SELECT count(distinct pid) FROM pg_locks WHERE granted = false;

-- Connections
select client_addr, usename, datname, count(*) from pg_stat_activity group by 1,2,3 order by 4 desc;

-- User Connections Ratio
select count(*)*100/(select current_setting('max_connections')::int) from pg_stat_activity;

-- Average Statement Exec Time
select (sum(total_time) / sum(calls))::numeric(6,3) from pg_stat_statements;

-- Most writing (to shared_buffers) queries
select query, shared_blks_dirtied from pg_stat_statements where shared_blks_dirtied > 0 order by 2 desc;

-- Block Read Time
select * from pg_stat_statements where blk_read_time <> 0 order by blk_read_time desc;

---------------
-- Vacuuming --
---------------

-- Last Vacuum and Analyze time
select relname,last_vacuum, last_autovacuum, last_analyze, last_autoanalyze from pg_stat_user_tables;

-- Total number of dead tuples need to be vacuumed per table
select n_dead_tup, schemaname, relname from pg_stat_all_tables;

-- Total number of dead tuples need to be vacuumed in DB
select sum(n_dead_tup) from pg_stat_all_tables;

-- Check the size of all the databases
SELECT d.datname AS Name, pg_catalog.pg_get_userbyid(d.datdba) AS Owner,
  CASE WHEN pg_catalog.has_database_privilege(d.datname, 'CONNECT')
    THEN pg_catalog.pg_size_pretty(pg_catalog.pg_database_size(d.datname)) 
    ELSE 'No Access' 
  END AS SIZE 
FROM pg_catalog.pg_database d 
ORDER BY 
  CASE WHEN pg_catalog.has_database_privilege(d.datname, 'CONNECT') 
    THEN pg_catalog.pg_database_size(d.datname)
    ELSE NULL 
  END;

-- Check the size of all the tables
SELECT relname as "Table",
pg_size_pretty(pg_total_relation_size(relid)) As "Size",
pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) as "External Size"
FROM pg_catalog.pg_statio_user_tables ORDER BY pg_total_relation_size(relid) DESC;

-- Vacuum Command
VACUUM (VERBOSE, ANALYZE);

---------------
--- QUERIES ---
---------------

-- show running queries
SELECT pid, age(clock_timestamp(), query_start), usename, query 
FROM pg_stat_activity 
WHERE query != '<IDLE>' AND query NOT ILIKE '%pg_stat_activity%' 
ORDER BY query_start desc;

-- Queries which are running for more than 2 minutes
SELECT now() - query_start as "runtime", usename, datname, waiting, state, query FROM pg_stat_activity WHERE now() - query_start > '2 minutes'::interval ORDER BY runtime DESC;

-- Queries which are running for more than 9 seconds
SELECT now() - query_start as "runtime", usename, datname, waiting, state, query FROM pg_stat_activity WHERE now() - query_start > '9 seconds'::interval ORDER BY runtime DESC;

-- kill running query
SELECT pg_cancel_backend(procpid);

-- kill idle query
SELECT pg_terminate_backend(procpid);







