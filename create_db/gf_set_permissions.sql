-- ---------------------------------------------------------------------------
-- Set final owner of growth forms schema and tables
-- 
-- Notes:
--	1. 	Execute ALTER SCHEMA command directly. 
-- 	2.	Use ALTER TABLE command to generate ALTER TABLE commands,
--		then copy/paste to execute the commands.
-- ---------------------------------------------------------------------------

-- New owner of growth forms tables
\set new_owner bien

-- Database containing growth form schema
\set db_gf vegbien
-- Growth form schema
\set sch_gf growthforms

-- Analytical database
\set db_adb vegbien
-- Analytical schema
\set sch_adb analytical_db

\c :db_gf
set search_path to :sch_gf;

ALTER SCHEMA :sch_gf OWNER TO :new_owner;

SELECT 'ALTER TABLE ' || sch.table_name || ' OWNER TO ' || :'new_owner' || ';' 
FROM information_schema.tables sch
WHERE table_schema = :'sch_gf';

-- Also change ownership of species_growth_forms table in analytical_db;
\c :db_adb
set search_path to :sch_adb;
ALTER TABLE :sch_adb.species_growth_forms OWNER TO :new_owner;


