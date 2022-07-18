-- ---------------------------------------------------------------------------
-- Infer consensus growth form for speciesfrom compiled BIEN growth form 
-- attributions
--
-- Steps:
-- * Append standardized gf obs from trait table and vfoi
-- * Infer predominant (consensus) growth form
-- * If >1 gf with similar proportions of attributions (=obs), use largest attainable
--   E.g., if both tree and shrub are common, use tree
--
-- Requires the following tables:
--
--
--
-- Assumes:
-- * Taxa have been standardized
-- * Each species and genus are in exactly one family
--
-- Date: 13 Jul 2022
-- ---------------------------------------------------------------------------

\set sch_obs analytical_db
\set  sch_gf growthforms

\c vegbien
SET search_path TO :sch_gf;

-- Clean up some taxonomic anomalies before starting
-- Need better solution earlier on
DELETE FROM gf_traits_species WHERE family IS NULL;
DELETE FROM gf_vfoi_species WHERE family IS NULL;

--
-- Compile table of standardized gf attributions
--

-- Create table
DROP TABLE IF EXISTS gf_species_obs;
CREATE TABLE gf_species_obs (
family text,
genus text,
species text,
gf text,
obs integer,
obs_source text
);

-- Insert trait attributions
INSERT INTO gf_species_obs (
family,
genus,
species,
gf,
obs,
obs_source
)
SELECT 
family,
genus,
species,
gf,
obs,
'BIEN traits'
FROM gf_traits_species
;

-- Insert observation attributions
-- Insert trait attributions
INSERT INTO gf_species_obs (
family,
genus,
species,
gf,
obs,
obs_source
)
SELECT 
family,
genus,
species,
gf,
obs,
'BIEN vfoi'
FROM gf_vfoi_species
;

-- make unique
DROP TABLE IF EXISTS gf_species_obs_uniq;
CREATE TABLE gf_species_obs_uniq AS
SELECT family, genus, species, gf, 
	SUM(obs) as obs, 
    string_agg(obs_source, ',') AS obs_sources
FROM gf_species_obs
GROUP BY family, genus, species, gf
;

-- Back up and replace original table with unique values table
DROP TABLE IF EXISTS gf_species_obs_bak;
CREATE TABLE gf_species_obs_bak (LIKE gf_species_obs INCLUDING ALL);
INSERT INTO gf_species_obs_bak SELECT * FROM gf_species_obs;
DROP TABLE gf_species_obs;
ALTER TABLE gf_species_obs_uniq RENAME TO gf_species_obs;

--
-- Infer consensus gf
--

-- Add size sort order for growth forms
ALTER TABLE gf_species_obs
ADD COLUMN gf_size smallint default null
;
UPDATE gf_species_obs
SET gf_size=
CASE
WHEN gf='tree' THEN 7
WHEN gf='shrub' THEN 6
WHEN gf='liana' THEN 5
WHEN gf='bambusoid' THEN 4
WHEN gf='subshrub' THEN 3
WHEN gf='vine' THEN 2
WHEN gf='herb' THEN 1
ELSE 0
END
WHERE gf IS NOT NULL
;

-- Create table
DROP TABLE IF EXISTS gf_species;
CREATE TABLE gf_species (
family text,
genus text,
species text,
gf_cons text,
gf_cons_obs integer,
total_obs integer,
gf_cons_prop numeric,
gf_all text
);

-- Select gf with most attributions
INSERT INTO gf_species (
	family,
	genus,
	species,
	gf_cons,
	gf_cons_obs
)
SELECT DISTINCT ON (species)
	family,
	genus,
	species,
	gf,
	obs
FROM gf_species_obs
WHERE gf IS NOT NULL
ORDER BY species, obs DESC, gf_size DESC
;

-- Add total attributions
UPDATE gf_species a
SET total_obs=b.totobs
FROM (
SELECT species, sum(obs) AS totobs
FROM gf_species_obs
WHERE gf IS NOT NULL
GROUP BY species
) b
WHERE a.species=b.species
;
UPDATE gf_species
SET gf_cons_prop=(gf_cons_obs::numeric / total_obs::numeric)::decimal(4,1)
; 

-- Add all gf obs to allow them to be searched
UPDATE gf_species a
SET gf_all=b.gf_all
FROM (
SELECT species, 
	string_agg(gf, ',') AS gf_all
FROM (
SELECT species, gf
FROM gf_species_obs
ORDER BY species, gf
) x
GROUP BY species
) b
WHERE a.species=b.species
;

-- Reset default sort orders
DROP TABLE IF EXISTS gf_species_obs_temp;
CREATE TABLE gf_species_obs_temp AS
SELECT * FROM gf_species_obs
ORDER BY family, genus, species, gf
; 
DROP TABLE gf_species_obs;
ALTER TABLE gf_species_obs_temp RENAME TO gf_species_obs;

DROP TABLE IF EXISTS gf_species_temp;
CREATE TABLE gf_species_temp AS
SELECT * FROM gf_species
ORDER BY family, genus, species, gf_cons
; 
DROP TABLE gf_species;
ALTER TABLE gf_species_temp RENAME TO gf_species;


