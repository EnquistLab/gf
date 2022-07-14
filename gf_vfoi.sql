-- ---------------------------------------------------------------------------
-- Extract raw growth forms from BIEN  analuytical observation table
--
-- Steps:
-- * Query BIEN table view_full_occurrent_individual for species GFs
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


