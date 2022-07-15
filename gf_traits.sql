-- ---------------------------------------------------------------------------
-- Extract raw growth forms from BIEN traits tables
--
-- Steps:
-- * Query BIEN trait table for species GFs
-- * Resolve taxonomic issues, if any
-- * Separate raw species, genus and family traits attributions
--
-- Date: 7 Jul 2022
-- ---------------------------------------------------------------------------

\set sch_obs analytical_db
\set  sch_gf growthforms
\set  sch_rangespp boyle

\c vegbien
CREATE SCHEMA IF NOT EXISTS :sch_gf;
SET search_path TO :sch_gf;

--
-- Extract growth forms from traits table
--

DROP TABLE IF EXISTS gf_traits_raw;
CREATE TABLE gf_traits_raw AS
SELECT id, scrubbed_family, scrubbed_genus, scrubbed_species_binomial,
trait_name, trait_value,
country, state_province, authorship, authorship_contact, citation_bibtex,
project_pi, is_individual_trait, is_species_trait
FROM :sch_obs.agg_traits
WHERE trait_name IN ('whole plant growth form')
;
-- Backup this table since it takes so long to create
DROP TABLE IF EXISTS gf_traits_raw_bak;
CREATE TABLE gf_traits_raw_bak (like gf_traits_raw including all);
INSERT INTO  gf_traits_raw_bak SELECT * FROM gf_traits_raw;

--
-- Clean up, index and add metadata
--

-- For backward compatibility so don't have to delete this from backup table
DELETE FROM gf_traits_raw
WHERE  trait_name='whole plant growth form diversity'
;
DELETE FROM gf_traits_raw
WHERE scrubbed_family IS NULL 
AND scrubbed_genus IS NULL 
AND scrubbed_species_binomial IS NULL
;

DROP INDEX IF EXISTS gf_traits_raw_scrubbed_family_idx;
DROP INDEX IF EXISTS gf_traits_raw_scrubbed_genus_idx;
DROP INDEX IF EXISTS gf_traits_raw_scrubbed_species_binomial_idx);
DROP INDEX IF EXISTS gf_traits_raw_trait_name_idx;
DROP INDEX IF EXISTS gf_traits_raw_trait_value_idx;

CREATE INDEX gf_traits_raw_scrubbed_family_idx ON gf_traits_raw(scrubbed_family);
CREATE INDEX gf_traits_raw_scrubbed_genus_idx ON gf_traits_raw(scrubbed_genus);
CREATE INDEX gf_traits_raw_scrubbed_species_binomial_idx ON gf_traits_raw(scrubbed_species_binomial);
CREATE INDEX gf_traits_raw_trait_name_idx ON gf_traits_raw(trait_name);
CREATE INDEX gf_traits_raw_trait_value_idx ON gf_traits_raw(trait_value);

ALTER TABLE gf_traits_raw
ADD COLUMN applies_to_rank text DEFAULT NULL
;
UPDATE gf_traits_raw
SET applies_to_rank='species'
WHERE scrubbed_species_binomial IS NOT NULL
;
UPDATE gf_traits_raw
SET applies_to_rank='genus'
WHERE scrubbed_genus IS NOT NULL 
AND scrubbed_species_binomial IS NULL
;
UPDATE gf_traits_raw
SET applies_to_rank='family'
WHERE scrubbed_family IS NOT NULL 
AND scrubbed_genus IS NULL
AND scrubbed_species_binomial IS NULL
;

DROP INDEX IF EXISTS gf_traits_raw_applies_to_rank_idx;
CREATE INDEX gf_traits_raw_applies_to_rank_idx ON gf_traits_raw(applies_to_rank);

-- VALIDATION: Check that all values apply to either family or genus or species
-- MUST RETURN t
SELECT NOT EXISTS (
SELECT * FROM gf_traits_raw WHERE applies_to_rank IS NULL
) AS applies_to_rank_not_null;

-- Check for homonyms species in >1 family
-- Validation must return f
SELECT EXISTS (
SELECT * FROM (
SELECT scrubbed_species_binomial, COUNT(DISTINCT scrubbed_family) AS fams 
FROM gf_traits_raw 
WHERE scrubbed_species_binomial IS NOT NULL
GROUP BY scrubbed_species_binomial 
HAVING COUNT(DISTINCT scrubbed_family)>1
) a
) AS has_homonym_species_gf_traits_raw
; 

/* 
-- If preceding validation returns false, extract homonyms here and correct manually
-- Make table of species in >1 family
DROP TABLE IF EXISTS gf_traits_raw_homonyms;
CREATE TABLE gf_traits_raw_homonyms AS
SELECT DISTINCT a.scrubbed_family, a.scrubbed_species_binomial 
FROM gf_traits_raw a JOIN (
SELECT scrubbed_species_binomial, COUNT(DISTINCT scrubbed_family) AS fams 
FROM gf_traits_raw 
GROUP BY scrubbed_species_binomial 
HAVING COUNT(DISTINCT scrubbed_family)>1
) b 
ON a.scrubbed_species_binomial=b.scrubbed_species_binomial
;       

--
-- Update homonyms here by species (hard-coded)
-- This is hard coded and needs to be checked each time
--

-- This updates erroneous instances of family='Araliaceae', species='Irvingia malayana'
UPDATE gf_traits_raw
SET scrubbed_family='Irvingiaceae'
WHERE scrubbed_species_binomial='Irvingia malayana'
;                                      
 */
 
-- Check for homonyms genera in >1 family
-- Validation must return f
SELECT EXISTS (
SELECT * FROM (
SELECT scrubbed_genus, COUNT(DISTINCT scrubbed_family) AS fams 
FROM gf_traits_raw 
WHERE scrubbed_genus IS NOT NULL
GROUP BY scrubbed_genus 
HAVING COUNT(DISTINCT scrubbed_family)>1
) a
) AS has_homonym_genera_gf_traits_raw
; 

-- If preceding validation returns false, extract homonyms here and correct manually
-- Make table of genera in >1 family
DROP TABLE IF EXISTS gf_traits_raw_homonym_genera;
CREATE TABLE gf_traits_raw_homonym_genera AS
SELECT DISTINCT a.scrubbed_genus, a.scrubbed_family
FROM gf_traits_raw a JOIN (
SELECT scrubbed_genus, COUNT(DISTINCT scrubbed_family) AS fams 
FROM gf_traits_raw 
GROUP BY scrubbed_genus 
HAVING COUNT(DISTINCT scrubbed_family)>1
) b 
ON a.scrubbed_genus=b.scrubbed_genus
ORDER BY a.scrubbed_genus, a.scrubbed_family
;    
ALTER TABLE gf_traits_raw_homonym_genera
ADD COLUMN is_homonym_genus smallint default 0,
ADD COLUMN check_species smallint default 0
;

-- Manually update homonym genera
UPDATE gf_traits_raw_homonym_genera
SET is_homonym_genus=1
WHERE (scrubbed_genus='Adelia' AND scrubbed_family='Oleaceae')
OR (scrubbed_genus='Afzelia' AND scrubbed_family='Orobanchaceae')
OR (scrubbed_genus='Benthamia' AND scrubbed_family='Boraginaceae')
OR (scrubbed_genus='Bergenia' AND scrubbed_family='Lythraceae')
OR (scrubbed_genus='Cordia' AND scrubbed_family='Boraginaceae')
OR (scrubbed_genus='Fabricia' AND scrubbed_family='Lamiaceae') -- Total mess, check species
OR (scrubbed_genus='Fabricia' AND scrubbed_family='Myrtaceae') -- Total mess, check species
OR (scrubbed_genus='Gaertnera' AND scrubbed_family='Asteraceae')
OR (scrubbed_genus='Gerardia' AND scrubbed_family='Acanthaceae') -- Total mess, check species
OR (scrubbed_genus='Gerardia' AND scrubbed_family='Orobanchaceae') -- Total mess, check species
OR (scrubbed_genus='Heteropteris' AND scrubbed_family='Malpighiaceae')
OR (scrubbed_genus='Heteropteris' AND scrubbed_family='Pteridaceae')
OR (scrubbed_genus='Matthiola' AND scrubbed_family='Rubiaceae')
OR (scrubbed_genus='Michelia' AND scrubbed_family='Lecythidaceae')
OR (scrubbed_genus='Myroxylon' AND scrubbed_family='Salicaceae')
OR (scrubbed_genus='Parsonsia' AND scrubbed_family='Lythraceae')
OR (scrubbed_genus='Pentagonia' AND scrubbed_family='Campanulaceae')
OR (scrubbed_genus='Podocarpus' AND scrubbed_family='Unknown') -- Check species
OR (scrubbed_genus='Rhipogonum' AND scrubbed_family='Liliaceae') -- Update all to Rhipogonaceae
OR (scrubbed_genus='Tripteris' AND scrubbed_family='Malpighiaceae')
OR (scrubbed_genus='Tripteris' AND scrubbed_family IS NULL)
OR (scrubbed_genus='Washingtonia' AND scrubbed_family='Apiaceae')
;

-- Mark species to check in detail
UPDATE gf_traits_raw_homonym_genera
SET check_species=1 
WHERE (scrubbed_genus='Fabricia' AND scrubbed_family='Lamiaceae') -- Total mess, check species
OR (scrubbed_genus='Fabricia' AND scrubbed_family='Myrtaceae') -- Total mess, check species
OR (scrubbed_genus='Gerardia' AND scrubbed_family='Acanthaceae') -- Total mess, check species
OR (scrubbed_genus='Gerardia' AND scrubbed_family='Orobanchaceae') -- Total mess, check species
OR (scrubbed_genus='Podocarpus' AND scrubbed_family='Unknown') -- Check species
OR (scrubbed_genus='Rhipogonum' AND scrubbed_family='Liliaceae') -- Update all to Rhipogonaceae
;

-- Make table of species with homonym genera
DROP TABLE IF EXISTS gf_traits_raw_homonym_genera_temp;
CREATE TABLE gf_traits_raw_homonym_genera_temp AS
SELECT DISTINCT a.scrubbed_genus, a.scrubbed_family, b.scrubbed_species_binomial
FROM gf_traits_raw_homonym_genera a LEFT JOIN gf_traits_raw B
ON a.scrubbed_family=b.scrubbed_family AND a.scrubbed_genus=b.scrubbed_genus
WHERE a.is_homonym_genus=1
ORDER BY a.scrubbed_genus, a.scrubbed_family, b.scrubbed_species_binomial
;
ALTER TABLE gf_traits_raw_homonym_genera_temp
ADD COLUMN acc_genus text default null,
ADD COLUMN acc_family text default null,
ADD COLUMN acc_species text default null
;

--
-- Update homonyms (hard-coded)
--
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Forestiera', acc_family='Oleaceae', acc_species='Forestiera pubescens' WHERE scrubbed_species_binomial='Adelia sphaerocarpa';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Dasistoma', acc_family='Orobanchaceae', acc_species='Dasistoma macrophylla' WHERE scrubbed_species_binomial='Afzelia macrophylla';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Amsinckia', acc_family='Boraginaceae', acc_species='Amsinckia lycopsoides' WHERE scrubbed_species_binomial='Benthamia idahoensis';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Cuphaea', acc_family='Lythraceae', acc_species=NULL WHERE scrubbed_genus='Bergenia' AND scrubbed_family='Lythraceae' AND scrubbed_species_binomial IS NULL;
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Cordia', acc_family='Cordiaceae', acc_species='Cordia vestita' WHERE scrubbed_species_binomial='Cordia vestita';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Alysicarpus', acc_family='Fabaceae', acc_species='Alysicarpus zeyheri' WHERE scrubbed_species_binomial='Fabricia zeyheri';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Leptospermum', acc_family='Myrtaceae', acc_species='Leptospermum lanigerum' WHERE scrubbed_species_binomial='Fabricia pubescens';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Ambrosia', acc_family='Asteraceae', acc_species='Ambrosia tomentosa' WHERE scrubbed_species_binomial='Gaertnera discolor';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Ambrosia', acc_family='Asteraceae', acc_species='Ambrosia confertiflora' WHERE scrubbed_species_binomial='Gaertnera tenuifolia';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Ambrosia', acc_family='Asteraceae', acc_species='Ambrosia tomentosa' WHERE scrubbed_species_binomial='Gaertnera tomentosa';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Stenandrium', acc_family='Acanthaceae', acc_species='Stenandrium dulce' WHERE scrubbed_species_binomial='Gerardia floridana';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Agalinis', acc_family='Orobanchaceae', acc_species='Agalinis plukenetii' WHERE scrubbed_species_binomial='Gerardia gatesii';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Agalinis', acc_family='Orobanchaceae', acc_species='Agalinis purpurea' WHERE scrubbed_species_binomial='Gerardia keyensis';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Agalinis', acc_family='Orobanchaceae', acc_species='Agalinis skinneriana' WHERE scrubbed_species_binomial='Gerardia skinneriana';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Agalinis', acc_family='Orobanchaceae', acc_species='Agalinis setacea' WHERE scrubbed_species_binomial='Gerardia stenophylla';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Heteropterys', acc_family='Malpighiaceae', acc_species='Heteropterys laurifolia' WHERE scrubbed_species_binomial='Heteropteris laurifolia';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Heteropterys', acc_family='Malpighiaceae', acc_species='Heteropterys palmeri' WHERE scrubbed_species_binomial='Heteropteris palmeri';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Heteropterys', acc_family='Malpighiaceae', acc_species=NULL WHERE scrubbed_genus='Heteropteris' AND scrubbed_family='Malpighiaceae' AND scrubbed_species_binomial IS NULL;
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Doryopteris', acc_family='Pteridaceae', acc_species=NULL WHERE scrubbed_genus='Heteropteris' AND scrubbed_family='Pteridaceae' AND scrubbed_species_binomial IS NULL;
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Matthiola', acc_family='Brassicaceae', acc_species='Matthiola parviflora' WHERE scrubbed_species_binomial='Matthiola parviflora';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Chydenanthus', acc_family='Lecythidaceae', acc_species='Chydenanthus excelsus' WHERE scrubbed_species_binomial='Michelia excelsa';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Barringtonia', acc_family='Lecythidaceae', acc_species='Barringtonia macrostachya' WHERE scrubbed_species_binomial='Michelia macrostachya';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Myroxylon', acc_family='Fabaceae', acc_species='Myroxylon balsamum' WHERE scrubbed_species_binomial='Myroxylon balsamiferum';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Myroxylon', acc_family='Fabaceae', acc_species=NULL WHERE scrubbed_genus='Myroxylon' AND scrubbed_family='Salicaceae' AND scrubbed_species_binomial IS NULL;
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Cuphea', acc_family='Lythraceae', acc_species='Cuphea aspera' WHERE scrubbed_species_binomial='Parsonsia lythroides';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Cuphea', acc_family='Lythraceae', acc_species='Cuphea procumbens' WHERE scrubbed_species_binomial='Parsonsia procumbens';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Legousia', acc_family='Campanulaceae', acc_species='Legousia hybrida' WHERE scrubbed_species_binomial='Pentagonia hybrida';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Podocarpus', acc_family='Podocarpaceae', acc_species='Podocarpus salignus' WHERE scrubbed_species_binomial='Podocarpus saligna';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Ripogonum', acc_family='Liliaceae', acc_species='Ripogonum scandens' WHERE scrubbed_species_binomial='Rhipogonum scandens';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Osteospermum', acc_family='Asteraceae', acc_species='Osteospermum scariosum' WHERE scrubbed_species_binomial='Tripteris aghillana';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Osteospermum', acc_family='Asteraceae', acc_species='Osteospermum sinuatum' WHERE scrubbed_species_binomial='Tripteris sinuata';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Osteospermum', acc_family='Asteraceae', acc_species='Osteospermum spathulatum' WHERE scrubbed_species_binomial='Tripteris spathulata';
UPDATE gf_traits_raw_homonym_genera_temp SET acc_genus='Osmorhiza', acc_family='Apiaceae', acc_species='Osmorhiza occidentalis' WHERE scrubbed_species_binomial='Washingtonia ambigua';
DELETE FROM gf_traits_raw_homonym_genera_temp WHERE scrubbed_genus='Tripteris' AND scrubbed_family IS NULL AND scrubbed_species_binomial IS NULL;

DROP TABLE IF EXISTS gf_traits_raw_homonym_genera;
ALTER TABLE gf_traits_raw_homonym_genera_temp RENAME TO gf_traits_raw_homonym_genera;

-- Update original table, keeping original names
ALTER TABLE gf_traits_raw
ADD COLUMN IF NOT EXISTS scrubbed_family_orig text default NULL,
ADD COLUMN IF NOT EXISTS scrubbed_genus_orig text default NULL,
ADD COLUMN IF NOT EXISTS scrubbed_species_binomial_orig text default NULL,
ADD COLUMN IF NOT EXISTS name_updated smallint default 0
;
UPDATE gf_traits_raw 
SET scrubbed_family_orig=scrubbed_family,
scrubbed_genus_orig=scrubbed_genus,
scrubbed_species_binomial_orig=scrubbed_species_binomial
;
DROP INDEX IF EXISTS gf_traits_raw_scrubbed_family_orig_idx;
DROP INDEX IF EXISTS gf_traits_raw_scrubbed_genus_orig_idx;
DROP INDEX IF EXISTS gf_traits_raw_scrubbed_species_binomial_orig_idx;
CREATE INDEX gf_traits_raw_scrubbed_family_orig_idx ON gf_traits_raw (scrubbed_family_orig);
CREATE INDEX gf_traits_raw_scrubbed_genus_orig_idx ON gf_traits_raw (scrubbed_genus_orig);
CREATE INDEX gf_traits_raw_scrubbed_species_binomial_orig_idx ON gf_traits_raw (scrubbed_species_binomial);

-- backup main traits table again
DROP TABLE IF EXISTS gf_traits_raw_bak2;
CREATE TABLE gf_traits_raw_bak2 (like gf_traits_raw including all);
INSERT INTO  gf_traits_raw_bak2 SELECT * FROM gf_traits_raw;


UPDATE gf_traits_raw a
SET scrubbed_family=b.acc_family,
scrubbed_genus=b.acc_genus,
scrubbed_species_binomial=b.acc_species,
name_updated=1
FROM gf_traits_raw_homonym_genera b
WHERE b.scrubbed_family=a.scrubbed_family_orig
AND b.scrubbed_genus=a.scrubbed_genus_orig
AND b.scrubbed_species_binomial=a.scrubbed_species_binomial_orig
;
UPDATE gf_traits_raw a
SET scrubbed_family=b.acc_family,
scrubbed_genus=b.acc_genus,
scrubbed_species_binomial=NULL,
name_updated=1
FROM gf_traits_raw_homonym_genera b
WHERE b.scrubbed_family=a.scrubbed_family_orig
AND b.scrubbed_genus=a.scrubbed_genus_orig
AND b.scrubbed_species_binomial IS NULL
;
-- Delete this one altogether
DELETE FROM gf_traits_raw
WHERE scrubbed_genus='Tripteris'
AND (scrubbed_family IS NULL OR TRIM(scrubbed_family)='')
AND (scrubbed_species_binomial IS NULL OR TRIM(scrubbed_species_binomial)='')
;

-- Check the results
SELECT scrubbed_family_orig, scrubbed_genus_orig, scrubbed_species_binomial_orig,
scrubbed_family, scrubbed_genus, scrubbed_species_binomial
FROM gf_traits_raw
WHERE name_updated=1
ORDER BY scrubbed_family_orig, scrubbed_genus_orig, scrubbed_species_binomial_orig
;

-- Validate again
SELECT EXISTS (
SELECT * FROM (
SELECT scrubbed_genus, COUNT(DISTINCT scrubbed_family) AS fams 
FROM gf_traits_raw 
WHERE scrubbed_genus IS NOT NULL
GROUP BY scrubbed_genus 
HAVING COUNT(DISTINCT scrubbed_family)>1
) a
) AS has_homonym_genera_gf_traits_raw
; 


--
-- Prep final raw data
--

-- Set growth form name to all lower case
UPDATE gf_traits_raw
SET trait_value=lower(trait_value)
;

-- Remove asterisks (common, for some reason)
UPDATE gf_traits_raw
SET trait_value=REPLACE(trait_value, '*', '')
;

-- Trim whitespace, set empty strings to null and remove null value rows
UPDATE gf_traits_raw
SET trait_value=TRIM(trait_value)
;
UPDATE gf_traits_raw
SET trait_value=NULL
WHERE trait_value=''
;
DELETE FROM gf_traits_raw
WHERE trait_value IS NULL
;

-- Final backup of raw gf_traits table 
DROP TABLE IF EXISTS gf_traits_raw_bak_final;
CREATE TABLE gf_traits_raw_bak_final (like gf_traits_raw including all);
INSERT INTO  gf_traits_raw_bak_final SELECT * FROM gf_traits_raw;

--
-- Extract table of unique trait values for manual correction & lookup table
--

DROP TABLE IF EXISTS gf_verbatim_traits;
CREATE TABLE gf_verbatim_traits AS
SELECT DISTINCT trait_value AS gf_verbatim,
NULL::text AS gf,             -- standard gf code
NULL::smallint AS is_woody,   -- 0|1|NULL, default NULL
NULL::text AS substrate,      -- terrestrial|climber|epiphyte|aquatic
NULL::text AS other,          -- other attributes, semi-standardized
0::smallint AS is_useless     -- 0|1, default 0 (no), not interpretable
FROM gf_traits_raw
ORDER BY trait_value
;

\copy gf_verbatim_traits to '/tmp/gf_verbatim_traits.csv' WITH HEADER CSV

/* 
IMPORTANT!!!
You MUST edit gf_verbatim_traits.txt manually before next step
When done, rename the file to gf_verbatim_traits_final.txt and place in /tmp folder
*/

 
--
-- Import lookup table & update new table of scrubbed traits
--

-- Create new empty table
ALTER TABLE gf_verbatim_traits RENAME TO gf_verbatim_traits_bak;
DROP TABLE IF EXISTS gf_verbatim_traits;
CREATE TABLE gf_verbatim_traits (LIKE gf_verbatim_traits_bak INCLUDING ALL);

-- Import the edited traits
\copy gf_verbatim_traits FROM '/tmp/gf_verbatim_traits_final.csv' WITH HEADER CSV

DROP INDEX IF EXISTS gf_verbatim_traits_gf_verbatim_idx;
CREATE INDEX gf_verbatim_traits_gf_verbatim_idx ON gf_verbatim_traits(gf_verbatim);

--
-- Update the raw traits table with standardized growth form attributes
--

DROP TABLE IF EXISTS gf_traits;
CREATE TABLE gf_traits AS
SELECT id, 
scrubbed_family as family, scrubbed_genus as genus, scrubbed_species_binomial as species, scrubbed_family_orig as family_orig, scrubbed_genus_orig as genus_orig, 
scrubbed_species_binomial_orig as species_orig, name_updated, 
trait_value as gf_verbatim
FROM gf_traits_raw
;

ALTER TABLE gf_traits
ADD COLUMN gf_std text DEFAULT NULL,
ADD COLUMN is_woody smallint DEFAULT NULL,
ADD COLUMN substrate text DEFAULT NULL, 
ADD COLUMN other text DEFAULT NULL,
ADD COLUMN is_useless smallint DEFAULT 0
;

DROP INDEX IF EXISTS gf_traits_gf_verbatim_idx;
CREATE INDEX gf_traits_gf_verbatim_idx ON gf_traits(gf_verbatim);

UPDATE gf_traits a
SET gf_std=b.gf,
is_woody=b.is_woody,
substrate=b.substrate, 
other=b.other,
is_useless=b.is_useless
FROM gf_verbatim_traits b
WHERE a.gf_verbatim=b.gf_verbatim
;

UPDATE gf_traits SET gf_std=NULL WHERE TRIM(gf_std)='';
UPDATE gf_traits SET substrate=NULL WHERE TRIM(substrate)='';
UPDATE gf_traits SET other=NULL WHERE TRIM(other)='';

DROP INDEX IF EXISTS gf_traits_is_useless_idx;
CREATE INDEX gf_traits_is_useless_idx ON gf_traits(is_useless);
DELETE FROM gf_traits WHERE is_useless=1;

DROP INDEX IF EXISTS gf_traits_gf_std_idx;
DROP INDEX IF EXISTS gf_traits_family_idx;
DROP INDEX IF EXISTS gf_traits_genus_idx;
DROP INDEX IF EXISTS gf_traits_species_idx;
DROP INDEX IF EXISTS gf_traits_family_orig_idx;
DROP INDEX IF EXISTS gf_traits_genus_orig_idx;
DROP INDEX IF EXISTS gf_traits_species_orig_idx;
DROP INDEX IF EXISTS gf_traits_name_updated_idx;

CREATE INDEX gf_traits_gf_std_idx ON gf_traits(gf_std);
CREATE INDEX gf_traits_family_idx ON gf_traits(family);
CREATE INDEX gf_traits_genus_idx ON gf_traits(genus);
CREATE INDEX gf_traits_species_idx ON gf_traits(species);
CREATE INDEX gf_traits_family_orig_idx ON gf_traits(family_orig);
CREATE INDEX gf_traits_genus_orig_idx ON gf_traits(genus_orig);
CREATE INDEX gf_traits_species_orig_idx ON gf_traits(species_orig);
CREATE INDEX gf_traits_name_updated_idx ON gf_traits(name_updated);

--
-- Extract unique gf attributions with observation counts, by taxon
--

-- Species gf
DROP TABLE IF EXISTS gf_traits_species;
CREATE TABLE gf_traits_species AS
SELECT DISTINCT family, genus, species, gf_std as gf, COUNT(*) AS obs
FROM gf_traits
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
FROM gf_traits_species 
GROUP BY species 
HAVING COUNT(DISTINCT family)>1
) a
) AS has_homonym_species_gf_traits_species
; 

-- Genus gf
DROP TABLE IF EXISTS gf_traits_genus;
CREATE TABLE gf_traits_genus AS
SELECT DISTINCT family, genus, gf_std as gf, COUNT(*) AS obs
FROM gf_traits
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
FROM gf_traits_genus 
GROUP BY genus 
HAVING COUNT(DISTINCT family)>1
) a
) AS has_homonym_genera_gf_traits_genus
; 

--Family gf
DROP TABLE IF EXISTS gf_traits_family;
CREATE TABLE gf_traits_family AS
SELECT family, gf_std as gf, COUNT(*) AS obs
FROM gf_traits
WHERE family IS NOT NULL AND genus IS NULL AND species IS NULL
AND gf_std IS NOT NULL
GROUP BY family, gf
ORDER BY family, gf
;



