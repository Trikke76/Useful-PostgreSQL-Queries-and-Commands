--- USER / ROLE ---

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




--- DATABASE / CONNECTIONS ---

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

-- cache hit rates (should not be less than 0.99)
SELECT sum(heap_blks_read) as heap_read, sum(heap_blks_hit)  as heap_hit, (sum(heap_blks_hit) - sum(heap_blks_read)) / sum(heap_blks_hit) as ratio
FROM pg_statio_user_tables;

-- table index usage rates (should not be less than 0.99)
SELECT relname, 100 * idx_scan / (seq_scan + idx_scan) percent_of_times_index_used, n_live_tup rows_in_table
FROM pg_stat_user_tables 
ORDER BY n_live_tup DESC;
                                                                                                    
--- Check the size of all the databases
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


--- QUERIES ---

-- show running queries
SELECT pid, age(clock_timestamp(), query_start), usename, query 
FROM pg_stat_activity 
WHERE query != '<IDLE>' AND query NOT ILIKE '%pg_stat_activity%' 
ORDER BY query_start desc;

-- kill running query
SELECT pg_cancel_backend(procpid);

-- kill idle query
SELECT pg_terminate_backend(procpid);
