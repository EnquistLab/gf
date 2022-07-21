-- ---------------------------------------------------------------------------
-- Change owner of growth forms schema and tables
-- 
-- Notes:
--	1. 	Execute ALTER SCHEMA command directly. 
-- 	2.	Use ALTER TABLE command to generate ALTER TABLE commands,
--		then copy/paste to execute the commands.
-- ---------------------------------------------------------------------------

-- Database containing growth form schema
\set db_gf vegbien
-- Growth form schema
\set sch_gf growthforms
-- New owner of growth forms tables
\set new_owner bien

\c :db_gf
set search_path to :sch_gf;


ALTER SCHEMA :sch_gf OWNER TO :new_owner;

SELECT 'ALTER TABLE ' || sch.table_name || ' OWNER TO ' || :'new_owner' || ';' 
FROM information_schema.tables sch
WHERE table_schema = :'sch_gf';

