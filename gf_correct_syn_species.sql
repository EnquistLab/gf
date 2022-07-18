-- -------------------------------------------------------------------
-- Optional step to correct growth forms and taxon names for species 
-- whose names were changed during import due to taxonomic errors.
--
-- Warnings:
--	1. Run *AFTER* "gf_impute.sql"
--	2. This will add columns to the original table with the corrected 
--	family, genus and species names. Only run if this schema is 
--	acceptable.
-- -------------------------------------------------------------------

-- Schema of prepared growth form tables
\set sch_gf growthforms 
-- Schema containing target species table to be updated
\set sch_spp boyle
-- Name of target species table
\set tbl_spp bien_ranges_species

\c vegbien
SET search_path TO :sch_spp;

--
-- Add growth form columns to target table
-- 

ALTER TABLE :tbl_spp
DROP COLUMN IF EXISTS name_updated,
DROP COLUMN IF EXISTS acc_family,
DROP COLUMN IF EXISTS acc_genus,
DROP COLUMN IF EXISTS acc_species
;

ALTER TABLE :tbl_spp
ADD COLUMN name_updated INTEGER DEFAULT NULL,
ADD COLUMN acc_family text,
ADD COLUMN acc_genus text,
ADD COLUMN acc_species text
;

--
-- Update/impute growth forms for synonymous names
-- 

-- Populate accepted names ane reset gf fields for synonymous names
UPDATE :tbl_spp a
SET 
name_updated=1,
acc_family=b.family,
acc_genus=b.genus,
acc_species=b.species,
gf=NULL,
gf_conf=NULL,
gf_conf_flag=NULL,
gf_method=NULL
FROM :sch_gf.gf_syn_spp b
WHERE a.family=b.family_orig
AND a.genus=b.genus_orig
AND a.species=b.species_orig
;

-- Direct attribution based on species
UPDATE :tbl_spp a
SET gf=b.gf_cons,
gf_conf=b.gf_conf,
gf_conf_flag=b.gf_conf_flag,
gf_method='direct from species'
FROM :sch_gf.gf_species b
WHERE a.acc_species=b.species
AND a.name_updated=1
;

-- Impute from genus
UPDATE :tbl_spp a
SET gf=b.gf_cons,
gf_conf=b.gf_conf,
gf_conf_flag=b.gf_conf_flag,
gf_method='imputed from genus'
FROM :sch_gf.gf_genus b
WHERE a.acc_genus=b.genus
AND a.name_updated=1
AND a.gf IS NULL
;

-- Impute from family
UPDATE :tbl_spp a
SET gf=b.gf_cons,
gf_conf=b.gf_conf,
gf_conf_flag=b.gf_conf_flag,
gf_method='imputed from family'
FROM :sch_gf.gf_family b
WHERE a.acc_family=b.family
AND a.name_updated=1
AND a.gf IS NULL
;

/* 
-- Query for checking results
-- Keep commented out

SELECT 
family, genus, species, name_updated,
acc_family, acc_genus, acc_species, 
gf, gf_conf, gf_conf_flag, gf_method
FROM bien_ranges_species
WHERE name_updated=1
LIMIT 25
;
*/