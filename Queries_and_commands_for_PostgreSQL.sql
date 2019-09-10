-- show running queries
SELECT pid, age(clock_timestamp(), query_start), usename, query 
FROM pg_stat_activity 
WHERE query != '<IDLE>' AND query NOT ILIKE '%pg_stat_activity%' 
ORDER BY query_start desc;

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
