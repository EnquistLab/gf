-- ---------------------------------------------------------------------------
-- BIEN Growth Forms
--
-- Purpose: add growth forms to list of species with range models
-- 
-- Steps:
-- * Query BIEN trait table for species GFs
-- * Mine analytical table for species GFs
-- * Merge above lists by species & extract consensus GF
-- * Join GFs to BIEN range model species list
-- * Impute GFs for remaining species if possible
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
SET applies_to_rank='species'
WHERE scrubbed_genus IS NOT NULL 
AND scrubbed_species_binomial IS NULL
;
UPDATE gf_traits_raw
SET applies_to_rank='species'
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

UPDATE gf_traits_raw_homonym_genera
SET check_species=1 
WHERE (scrubbed_genus='Fabricia' AND scrubbed_family='Lamiaceae') -- Total mess, check species
OR (scrubbed_genus='Fabricia' AND scrubbed_family='Myrtaceae') -- Total mess, check species
OR (scrubbed_genus='Gerardia' AND scrubbed_family='Acanthaceae') -- Total mess, check species
OR (scrubbed_genus='Gerardia' AND scrubbed_family='Orobanchaceae') -- Total mess, check species
OR (scrubbed_genus='Podocarpus' AND scrubbed_family='Unknown') -- Check species
OR (scrubbed_genus='Rhipogonum' AND scrubbed_family='Liliaceae') -- Update all to Rhipogonaceae
;

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
-- Extract traits by taxon
--

-- Extract species traits
DROP TABLE IF EXISTS gf_traits_species;
CREATE TABLE gf_traits_species AS
SELECT DISTINCT scrubbed_family as family, scrubbed_genus as genus, 
scrubbed_species_binomial as species,
trait_value as gf, COUNT(*) AS trait_obs
FROM gf_traits_raw
WHERE scrubbed_species_binomial IS NOT NULL
GROUP BY scrubbed_family, scrubbed_genus, scrubbed_species_binomial,
trait_value
ORDER BY scrubbed_family, scrubbed_genus, scrubbed_species_binomial,
trait_value
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

-- Extract genus traits
DROP TABLE IF EXISTS gf_traits_genus;
CREATE TABLE gf_traits_genus AS
SELECT scrubbed_family as family, scrubbed_genus as genus, 
trait_value as gf, COUNT(*) AS trait_obs
FROM gf_traits_raw
WHERE scrubbed_genus IS NOT NULL AND scrubbed_species_binomial IS NULL
GROUP BY scrubbed_family, scrubbed_genus, trait_value
ORDER BY scrubbed_family, scrubbed_genus, trait_value
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

-- Extract family traits
DROP TABLE IF EXISTS gf_traits_family;
CREATE TABLE gf_traits_family AS
SELECT scrubbed_family as family,
trait_value as gf, COUNT(*) AS trait_obs
FROM gf_traits_raw
WHERE scrubbed_family IS NOT NULL 
AND scrubbed_genus IS NULL AND scrubbed_species_binomial IS NULL
GROUP BY scrubbed_family, trait_value
ORDER BY scrubbed_family, trait_value
;



