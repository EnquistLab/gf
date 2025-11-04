-- ---------------------------------------------------------------------------
-- Assign or impute growth forms to species
--
-- WARNINGS
-- 	1. 	The following columns in the target table will be created. If they already 
--		exist, they will be replaced: gf, gf_conf, gf_conf_flag, gf_method, genus.
--		Recommend backing up before running this script.
--	2. 	Target table MUST have the following taxonomic fields: family, 
--		species. 
-- 
-- ---------------------------------------------------------------------------

-- ------------------------------------------------------
-- Parameters (the only ones you should need to set
-- ------------------------------------------------------

-- Name of table of species be updated and name of schema containing species table
/* syntax:
\set sch_spp <SCHEMA_CONTAINING_USER_SPECIES_TABLE>
\set tbl_spp <USER_SPECIES_TABLE>
*/
\set sch_spp boyle
\set tbl_spp bien_ranges_species

\set sch_spp analytical_db
\set tbl_spp species_growth_forms

-- ------------------------------------------------------
-- Main
-- ------------------------------------------------------

-- Schema of prepared growth form tables
\set sch_gf growthforms 


\c vegbien
SET search_path TO :sch_spp;

--
-- Add growth form columns to target table
-- 

ALTER TABLE :tbl_spp
DROP COLUMN IF EXISTS gf,
DROP COLUMN IF EXISTS gf_conf,
DROP COLUMN IF EXISTS gf_conf_flag,
DROP COLUMN IF EXISTS gf_method
;

ALTER TABLE :tbl_spp
ADD COLUMN gf text,
ADD COLUMN gf_conf DECIMAL(3,2),
ADD COLUMN gf_conf_flag text,
ADD COLUMN gf_method text
;

--
-- Add genus column and populate
-- 

ALTER TABLE :tbl_spp
ADD COLUMN IF NOT EXISTS genus text
;
UPDATE :tbl_spp
SET genus=split_part(species, ' ', 1)
;

--
-- Index target table
-- 

\set sppidx :tbl_spp _species_idx
\set genidx :tbl_spp _genus_idx
\set famidx :tbl_spp _family_idx

DROP INDEX IF EXISTS :sppidx;
DROP INDEX IF EXISTS :genidx;
DROP INDEX IF EXISTS :famidx;

CREATE INDEX :sppidx ON :tbl_spp (species);
CREATE INDEX :genidx ON :tbl_spp (genus);
CREATE INDEX :famidx ON :tbl_spp (family);

--
-- Update/impute growth forms
-- 

-- Direct attribution based on species
UPDATE :tbl_spp a
SET gf=b.gf_cons,
gf_conf=b.gf_conf,
gf_conf_flag=b.gf_conf_flag,
gf_method='direct from species'
FROM :sch_gf.gf_species b
WHERE a.species=b.species
;

-- Impute from genus
UPDATE :tbl_spp a
SET gf=b.gf_cons,
gf_conf=b.gf_conf,
gf_conf_flag=b.gf_conf_flag,
gf_method='imputed from genus'
FROM :sch_gf.gf_genus b
WHERE a.genus=b.genus
AND a.gf IS NULL
;

-- Impute from family
UPDATE :tbl_spp a
SET gf=b.gf_cons,
gf_conf=b.gf_conf,
gf_conf_flag=b.gf_conf_flag,
gf_method='imputed from family'
FROM :sch_gf.gf_family b
WHERE a.family=b.family
AND a.gf IS NULL
;

/* Use this command to dump the table to CSV file, if desired:

\set fileandpath /tmp/ :tbl_spp .csv
\copy :tbl_spp to :fileandpath WITH HEADER CSV
\copy bien_ranges_species to /tmp/bien_ranges_species.csv WITH HEADER CSV

*/

