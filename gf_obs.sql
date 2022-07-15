-- ---------------------------------------------------------------------------
-- Extract raw growth forms from BIEN taxon observations table
--
-- Steps:
-- * Query BIEN table view_full_occurrent_individual for species GFs
-- * Resolve taxonomic issues, if any
-- * Separate raw species, genus and family traits attributions
--
-- Date: 7 Jul 2022
-- ---------------------------------------------------------------------------

\set  sch_gf growthforms	-- Schema in which growth form tables will be built
\set sch_obs analytical_db	-- Source schema of growth form attributions/observations

\c vegbien
CREATE SCHEMA IF NOT EXISTS :sch_gf;
SET search_path TO :sch_gf;

--
-- Extract growth forms from traits table
--

DROP TABLE IF EXISTS gf_vfoi_raw;
CREATE TABLE gf_vfoi_raw AS
SELECT taxonobservation_id, observation_type, datasource, 
scrubbed_family, scrubbed_genus, scrubbed_species_binomial,
growth_form
FROM :sch_obs.view_full_occurrence_individual
WHERE growth_form IS NOT NULL
;

-- Backup this table since it takes so long to create
DROP TABLE IF EXISTS gf_vfoi_raw_bak;
CREATE TABLE gf_vfoi_raw_bak (like gf_vfoi_raw);
INSERT INTO  gf_vfoi_raw_bak SELECT * FROM gf_vfoi_raw;

--
-- Clean up, index and add metadata
--

DELETE FROM gf_vfoi_raw
WHERE scrubbed_family IS NULL 
AND scrubbed_genus IS NULL 
AND scrubbed_species_binomial IS NULL
;

DROP INDEX IF EXISTS gf_vfoi_raw_scrubbed_family_idx;
DROP INDEX IF EXISTS gf_vfoi_raw_scrubbed_genus_idx;
DROP INDEX IF EXISTS gf_vfoi_raw_scrubbed_species_binomial_idx);
DROP INDEX IF EXISTS gf_vfoi_raw_growth_form_idx;

CREATE INDEX gf_vfoi_raw_scrubbed_family_idx ON gf_vfoi_raw(scrubbed_family);
CREATE INDEX gf_vfoi_raw_scrubbed_genus_idx ON gf_vfoi_raw(scrubbed_genus);
CREATE INDEX gf_vfoi_raw_scrubbed_species_binomial_idx ON gf_vfoi_raw(scrubbed_species_binomial);
CREATE INDEX gf_vfoi_raw_growth_form_idx ON gf_vfoi_raw(growth_form);

ALTER TABLE gf_vfoi_raw
ADD COLUMN applies_to_rank text DEFAULT NULL
;
UPDATE gf_vfoi_raw
SET applies_to_rank='species'
WHERE scrubbed_species_binomial IS NOT NULL
;
UPDATE gf_vfoi_raw
SET applies_to_rank='genus'
WHERE scrubbed_genus IS NOT NULL 
AND scrubbed_species_binomial IS NULL
;
UPDATE gf_vfoi_raw
SET applies_to_rank='family'
WHERE scrubbed_family IS NOT NULL 
AND scrubbed_genus IS NULL
AND scrubbed_species_binomial IS NULL
;

DROP INDEX IF EXISTS gf_vfoi_raw_applies_to_rank_idx;
CREATE INDEX gf_vfoi_raw_applies_to_rank_idx ON gf_vfoi_raw(applies_to_rank);

-- VALIDATION: Check that all values apply to either family or genus or species
-- MUST RETURN t
SELECT NOT EXISTS (
SELECT * FROM gf_vfoi_raw WHERE applies_to_rank IS NULL
) AS applies_to_rank_not_null;

--
-- Check taxonomy: homonym species, in >1 family
--

-- Prepare table, keeping original names
ALTER TABLE gf_vfoi_raw
ADD COLUMN IF NOT EXISTS scrubbed_family_orig text default NULL,
ADD COLUMN IF NOT EXISTS scrubbed_genus_orig text default NULL,
ADD COLUMN IF NOT EXISTS scrubbed_species_binomial_orig text default NULL,
ADD COLUMN IF NOT EXISTS name_updated smallint default 0
;
UPDATE gf_vfoi_raw 
SET scrubbed_family_orig=scrubbed_family,
scrubbed_genus_orig=scrubbed_genus,
scrubbed_species_binomial_orig=scrubbed_species_binomial
;
DROP INDEX IF EXISTS gf_vfoi_raw_scrubbed_family_orig_idx;
DROP INDEX IF EXISTS gf_vfoi_raw_scrubbed_genus_orig_idx;
DROP INDEX IF EXISTS gf_vfoi_raw_scrubbed_species_binomial_orig_idx;
DROP INDEX IF EXISTS gf_vfoi_raw_name_updated_idx;
CREATE INDEX gf_vfoi_raw_scrubbed_family_orig_idx ON gf_vfoi_raw (scrubbed_family_orig);
CREATE INDEX gf_vfoi_raw_scrubbed_genus_orig_idx ON gf_vfoi_raw (scrubbed_genus_orig);
CREATE INDEX gf_vfoi_raw_scrubbed_species_binomial_orig_idx ON gf_vfoi_raw (scrubbed_species_binomial);
CREATE INDEX gf_vfoi_raw_name_updated_idx ON gf_vfoi_raw(name_updated);


-- Check for homonyms species in >1 family
-- Validation must return f
SELECT EXISTS (
SELECT * FROM (
SELECT scrubbed_species_binomial, COUNT(DISTINCT scrubbed_family) AS fams 
FROM gf_vfoi_raw 
WHERE scrubbed_species_binomial IS NOT NULL
GROUP BY scrubbed_species_binomial 
HAVING COUNT(DISTINCT scrubbed_family)>1
) a
) AS has_homonym_species_gf_vfoi_raw
;

-- If preceding validation returns true, extract homonyms here and correct manually
-- Make table of species in >1 family
DROP TABLE IF EXISTS gf_vfoi_raw_homonym_species;
CREATE TABLE gf_vfoi_raw_homonym_species AS
SELECT DISTINCT a.scrubbed_family, a.scrubbed_species_binomial 
FROM gf_vfoi_raw a JOIN (
SELECT scrubbed_species_binomial, COUNT(DISTINCT scrubbed_family) AS fams 
FROM gf_vfoi_raw 
GROUP BY scrubbed_species_binomial 
HAVING COUNT(DISTINCT scrubbed_family)>1
) b 
ON a.scrubbed_species_binomial=b.scrubbed_species_binomial
;     

-- Get count if above returns 't'
SELECT COUNT(DISTINCT scrubbed_species_binomial) as species_with_homonyms,
COUNT(*)::integer - COUNT(DISTINCT scrubbed_species_binomial)::integer AS homonyms
FROM  gf_vfoi_raw_homonym_species;
/*
 species_with_homonyms | homonyms 
-----------------------+----------
                     1 |        1
Only one species, one homonym
*/

--
-- Update homonyms here by species (hard-coded)
-- This is hard coded and needs to be checked each time
--

UPDATE gf_vfoi_raw
SET scrubbed_family='Phyllanthaceae'
WHERE scrubbed_species_binomial='Antidesma laciniatum'
AND scrubbed_family='Euphorbiaceae'
;                                      

--
-- Check taxonomy: homonym genera, in >1 family
--

-- Check for homonyms genera in >1 family
-- Validation must return f
SELECT EXISTS (
SELECT * FROM (
SELECT scrubbed_genus, COUNT(DISTINCT scrubbed_family) AS fams 
FROM gf_vfoi_raw 
WHERE scrubbed_genus IS NOT NULL
GROUP BY scrubbed_genus 
HAVING COUNT(DISTINCT scrubbed_family)>1
) a
) AS has_homonym_genera_gf_vfoi_raw
; 

-- If preceding validation returns false, extract homonyms here and correct manually
-- Make table of genera in >1 family
DROP TABLE IF EXISTS gf_vfoi_raw_homonym_genera;
CREATE TABLE gf_vfoi_raw_homonym_genera AS
SELECT DISTINCT a.scrubbed_genus, a.scrubbed_family
FROM gf_vfoi_raw a JOIN (
SELECT scrubbed_genus, COUNT(DISTINCT scrubbed_family) AS fams 
FROM gf_vfoi_raw 
GROUP BY scrubbed_genus 
HAVING COUNT(DISTINCT scrubbed_family)>1
) b 
ON a.scrubbed_genus=b.scrubbed_genus
ORDER BY a.scrubbed_genus, a.scrubbed_family
;    
ALTER TABLE gf_vfoi_raw_homonym_genera
ADD COLUMN is_homonym_genus smallint default 0,
ADD COLUMN check_species smallint default 0
;

-- Get count if above returns 't'
SELECT COUNT(DISTINCT scrubbed_genus) as genera_with_homonyms,
COUNT(*)::integer - COUNT(DISTINCT scrubbed_genus)::integer AS homonyms
FROM  gf_vfoi_raw_homonym_genera;
/*
 genera_with_homonyms | homonyms 
----------------------+----------
                    4 |        4
Only 4 genera, with one homonym each
*/

-- Mark homonym genera
UPDATE gf_vfoi_raw_homonym_genera
SET is_homonym_genus=1
WHERE (scrubbed_genus='Athenaea' AND scrubbed_family='Asteraceae')
OR (scrubbed_genus='Gladiolus' AND scrubbed_family='Unknown') -- Update all to Iridaceae
OR (scrubbed_genus='Myroxylon' AND scrubbed_family='Salicaceae')
OR (scrubbed_genus='Tripteris' AND scrubbed_family='Malpighiaceae')
;

-- Mark species to check in detail
/* Not needed
UPDATE gf_vfoi_raw_homonym_genera
SET check_species=1 
WHERE (scrubbed_genus='xxx' AND scrubbed_family='xxx')
AND ...
;
*/

-- Make table of species with homonym genera
DROP TABLE IF EXISTS gf_vfoi_raw_homonym_genera_species;
CREATE TABLE gf_vfoi_raw_homonym_genera_species AS
SELECT DISTINCT a.scrubbed_genus, a.scrubbed_family, b.scrubbed_species_binomial
FROM gf_vfoi_raw_homonym_genera a LEFT JOIN gf_vfoi_raw b
ON a.scrubbed_family=b.scrubbed_family AND a.scrubbed_genus=b.scrubbed_genus
WHERE a.is_homonym_genus=1
ORDER BY a.scrubbed_genus, a.scrubbed_family, b.scrubbed_species_binomial
;
ALTER TABLE gf_vfoi_raw_homonym_genera_species
ADD COLUMN acc_genus text default null,
ADD COLUMN acc_family text default null,
ADD COLUMN acc_species text default null
;

--
-- Update homonyms (hard-coded)
--

-- Update by genus
UPDATE gf_vfoi_raw_homonym_genera_species SET acc_genus='Gladiolus', acc_family='Iridaceae', acc_species=scrubbed_species_binomial WHERE scrubbed_genus='Gladiolus' AND scrubbed_family='Unknown'; 
UPDATE gf_vfoi_raw_homonym_genera_species SET acc_genus='Athenaea', acc_family='Solanaceae', acc_species=scrubbed_species_binomial WHERE scrubbed_genus='Athenaea' AND scrubbed_family='Asteraceae'; 
UPDATE gf_vfoi_raw_homonym_genera_species SET acc_genus='Myroxylon', acc_family='Fabaceae', acc_species=scrubbed_species_binomial WHERE scrubbed_genus='Myroxylon' AND scrubbed_family='Salicaceae'; 

-- Update by species if genus or species changes as well as family
UPDATE gf_vfoi_raw_homonym_genera_species SET acc_species='Myroxylon balsamum' WHERE scrubbed_species_binomial='Myroxylon balsamiferum'; -- update species as well
UPDATE gf_vfoi_raw_homonym_genera_species SET acc_genus='Osteospermum', acc_family='Asteraceae', acc_species='Osteospermum monocephalum' WHERE scrubbed_species_binomial='Tripteris monocephala';
UPDATE gf_vfoi_raw_homonym_genera_species SET acc_genus='Osteospermum', acc_family='Asteraceae', acc_species='Osteospermum volkensii' WHERE scrubbed_species_binomial='Tripteris volkensii';

-- backup main traits table again
DROP TABLE IF EXISTS gf_vfoi_raw_bak2;
CREATE TABLE gf_vfoi_raw_bak2 (like gf_vfoi_raw including all);
INSERT INTO  gf_vfoi_raw_bak2 SELECT * FROM gf_vfoi_raw;

-- Update names in main table
UPDATE gf_vfoi_raw a
SET scrubbed_family=b.acc_family,
scrubbed_genus=b.acc_genus,
scrubbed_species_binomial=b.acc_species,
name_updated=1
FROM gf_vfoi_raw_homonym_genera_species b
WHERE b.scrubbed_family=a.scrubbed_family_orig
AND b.scrubbed_genus=a.scrubbed_genus_orig
AND b.scrubbed_species_binomial=a.scrubbed_species_binomial_orig
;
UPDATE gf_vfoi_raw a
SET scrubbed_family=b.acc_family,
scrubbed_genus=b.acc_genus,
scrubbed_species_binomial=NULL,
name_updated=1
FROM gf_vfoi_raw_homonym_genera_species b
WHERE b.scrubbed_family=a.scrubbed_family_orig
AND b.scrubbed_genus=a.scrubbed_genus_orig
AND b.scrubbed_species_binomial IS NULL
;

-- Check the results
SELECT scrubbed_family_orig, scrubbed_genus_orig, scrubbed_species_binomial_orig,
scrubbed_family, scrubbed_genus, scrubbed_species_binomial
FROM gf_vfoi_raw
WHERE name_updated=1
ORDER BY scrubbed_family_orig, scrubbed_genus_orig, scrubbed_species_binomial_orig
;

-- Validate again
SELECT EXISTS (
SELECT * FROM (
SELECT scrubbed_genus, COUNT(DISTINCT scrubbed_family) AS fams 
FROM gf_vfoi_raw 
WHERE scrubbed_genus IS NOT NULL
GROUP BY scrubbed_genus 
HAVING COUNT(DISTINCT scrubbed_family)>1
) a
) AS has_homonym_genera_gf_vfoi_raw
; 

--
-- Prep final raw data
--

-- Set growth form name to all lower case
UPDATE gf_vfoi_raw
SET growth_form=lower(growth_form)
;

-- Trim whitespace, set empty strings to null and remove null value rows
UPDATE gf_vfoi_raw
SET growth_form=TRIM(growth_form)
;
UPDATE gf_vfoi_raw
SET growth_form=NULL
WHERE growth_form=''
;
DELETE FROM gf_vfoi_raw
WHERE growth_form IS NULL
;

-- Final backup of raw gf_vfoi table 
DROP TABLE IF EXISTS gf_vfoi_raw_bak_final;
CREATE TABLE gf_vfoi_raw_bak_final (like gf_vfoi_raw including all);
INSERT INTO  gf_vfoi_raw_bak_final SELECT * FROM gf_vfoi_raw;







--
-- Extract table of unique trait values for manual correction & lookup table
--

DROP TABLE IF EXISTS gf_verbatim_vfoi;
CREATE TABLE gf_verbatim_vfoi AS
SELECT DISTINCT growth_form AS gf_verbatim,
NULL::text AS gf,             -- standard gf code
NULL::smallint AS is_woody,   -- 0|1|NULL, default NULL
NULL::text AS substrate,      -- terrestrial|climber|epiphyte|aquatic
NULL::text AS other,          -- other attributes, semi-standardized
0::smallint AS is_useless     -- 0|1, default 0 (no), not interpretable
FROM gf_vfoi_raw
ORDER BY growth_form
;

\copy gf_verbatim_vfoi to '/tmp/gf_verbatim_vfoi.csv' WITH HEADER CSV

/* 
IMPORTANT!!!
You MUST edit gf_verbatim_vfoi.txt manually before next step
When done, rename the file to gf_verbatim_vfoi_final.txt and place in /tmp folder
*/

 
--
-- Import lookup table & update new table of scrubbed traits
--

-- Create new empty table
ALTER TABLE gf_verbatim_vfoi RENAME TO gf_verbatim_vfoi_bak;
DROP TABLE IF EXISTS gf_verbatim_vfoi;
CREATE TABLE gf_verbatim_vfoi (LIKE gf_verbatim_vfoi_bak INCLUDING ALL);

-- Import the edited traits
\copy gf_verbatim_vfoi FROM '/tmp/gf_verbatim_vfoi_final.csv' WITH HEADER CSV

DROP INDEX IF EXISTS gf_verbatim_vfoi_gf_verbatim_idx;
CREATE INDEX gf_verbatim_vfoi_gf_verbatim_idx ON gf_verbatim_vfoi(gf_verbatim);

--
-- Update the raw traits table with standardized growth form attributes
--

DROP TABLE IF EXISTS gf_vfoi;
CREATE TABLE gf_vfoi AS
SELECT gf_vfoi_raw AS id, 
scrubbed_family as family, scrubbed_genus as genus, scrubbed_species_binomial as species, scrubbed_family_orig as family_orig, scrubbed_genus_orig as genus_orig, 
scrubbed_species_binomial_orig as species_orig, name_updated, 
growth_form as gf_verbatim
FROM gf_vfoi_raw
;

ALTER TABLE gf_vfoi
ADD COLUMN gf_std text DEFAULT NULL,
ADD COLUMN is_woody smallint DEFAULT NULL,
ADD COLUMN substrate text DEFAULT NULL, 
ADD COLUMN other text DEFAULT NULL,
ADD COLUMN is_useless smallint DEFAULT 0
;

DROP INDEX IF EXISTS gf_vfoi_gf_verbatim_idx;
CREATE INDEX gf_vfoi_gf_verbatim_idx ON gf_vfoi(gf_verbatim);

UPDATE gf_vfoi a
SET gf_std=b.gf,
is_woody=b.is_woody,
substrate=b.substrate, 
other=b.other,
is_useless=b.is_useless
FROM gf_verbatim_vfoi b
WHERE a.gf_verbatim=b.gf_verbatim
;

UPDATE gf_vfoi SET gf_std=NULL WHERE TRIM(gf_std)='';
UPDATE gf_vfoi SET substrate=NULL WHERE TRIM(substrate)='';
UPDATE gf_vfoi SET other=NULL WHERE TRIM(other)='';

DROP INDEX IF EXISTS gf_vfoi_is_useless_idx;
CREATE INDEX gf_vfoi_is_useless_idx ON gf_vfoi(is_useless);
DELETE FROM gf_vfoi WHERE is_useless=1;

DROP INDEX IF EXISTS gf_vfoi_gf_std_idx;
DROP INDEX IF EXISTS gf_vfoi_family_idx;
DROP INDEX IF EXISTS gf_vfoi_genus_idx;
DROP INDEX IF EXISTS gf_vfoi_species_idx;
DROP INDEX IF EXISTS gf_vfoi_family_orig_idx;
DROP INDEX IF EXISTS gf_vfoi_genus_orig_idx;
DROP INDEX IF EXISTS gf_vfoi_species_orig_idx;
DROP INDEX IF EXISTS gf_vfoi_name_updated_idx;

CREATE INDEX gf_vfoi_gf_std_idx ON gf_vfoi(gf_std);
CREATE INDEX gf_vfoi_family_idx ON gf_vfoi(family);
CREATE INDEX gf_vfoi_genus_idx ON gf_vfoi(genus);
CREATE INDEX gf_vfoi_species_idx ON gf_vfoi(species);
CREATE INDEX gf_vfoi_family_orig_idx ON gf_vfoi(family_orig);
CREATE INDEX gf_vfoi_genus_orig_idx ON gf_vfoi(genus_orig);
CREATE INDEX gf_vfoi_species_orig_idx ON gf_vfoi(species_orig);
CREATE INDEX gf_vfoi_name_updated_idx ON gf_vfoi(name_updated);

--
-- Extract unique gf attributions with observation counts, by taxon
--

-- Species gf
DROP TABLE IF EXISTS gf_vfoi_species;
CREATE TABLE gf_vfoi_species AS
SELECT DISTINCT family, genus, species, gf_std as gf, COUNT(*) AS obs
FROM gf_vfoi
WHERE species IS NOT NULL
AND gf_std IS NOT NULL
GROUP BY family, genus, species, gf
ORDER BY family, genus, species, gf
;

-- Check for homonyms species in >1 family; shouldn't be any at this stage
-- Validation must return f
SELECT EXISTS (
SELECT * FROM (
SELECT species, COUNT(DISTINCT family) AS fams 
FROM gf_vfoi_species 
GROUP BY species 
HAVING COUNT(DISTINCT family)>1
) a
) AS has_homonym_species_gf_vfoi_species
; 

-- Genus gf
DROP TABLE IF EXISTS gf_vfoi_genus;
CREATE TABLE gf_vfoi_genus AS
SELECT DISTINCT family, genus, gf_std as gf, COUNT(*) AS obs
FROM gf_vfoi
WHERE genus IS NOT NULL AND species IS NULL
AND gf_std IS NOT NULL
GROUP BY family, genus, gf
ORDER BY family, genus, gf
;

-- Check for homonyms genera in >1 family; shouldn't be any at this stage
-- Validation must return f
SELECT EXISTS (
SELECT * FROM (
SELECT genus, COUNT(DISTINCT family) AS fams 
FROM gf_vfoi_genus 
GROUP BY genus 
HAVING COUNT(DISTINCT family)>1
) a
) AS has_homonym_genera_gf_vfoi_genus
; 

--Family gf
DROP TABLE IF EXISTS gf_vfoi_family;
CREATE TABLE gf_vfoi_family AS
SELECT family, gf_std as gf, COUNT(*) AS obs
FROM gf_vfoi
WHERE family IS NOT NULL AND genus IS NULL AND species IS NULL
AND gf_std IS NOT NULL
GROUP BY family, gf
ORDER BY family, gf
;








