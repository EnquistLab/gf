-- ---------------------------------------------------------------------------
-- BIEN Growth Forms
--
-- Purpose: add growth forms to list of species with range models
-- Requested by Cory
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

DROP TABLE IF EXISTS gf_traits_raw;
CREATE TABLE gf_traits_raw AS
SELECT id, scrubbed_family, scrubbed_genus, scrubbed_species_binomial,
trait_name, trait_value,
country, state_province, authorship, authorship_contact, citation_bibtex,
project_pi, is_individual_trait, is_species_trait
FROM :sch_obs.agg_traits
WHERE trait_name IN ('whole plant growth form', 'whole plant growth form diversity')
;

CREATE INDEX gf_traits_raw_scrubbed_family_idx ON gf_traits_raw(scrubbed_family);
CREATE INDEX gf_traits_raw_scrubbed_genus_idx ON gf_traits_raw(scrubbed_genus);
CREATE INDEX gf_traits_raw_scrubbed_species_binomial_idx ON gf_traits_raw(scrubbed_species_binomial);
CREATE INDEX gf_traits_raw_trait_name_idx ON gf_traits_raw(trait_name);
CREATE INDEX gf_traits_raw_trait_value_idx ON gf_traits_raw(trait_value);

DROP TABLE IF EXISTS gf_traits;
CREATE TABLE gf_traits AS
SELECT DISTINCT scrubbed_family, scrubbed_genus, scrubbed_species_binomial,
trait_name, trait_value, COUNT(*) AS trait_obs
FROM gf_traits_raw
GROUP BY scrubbed_family, scrubbed_genus, scrubbed_species_binomial,
trait_name, trait_value
ORDER BY scrubbed_family, scrubbed_genus, scrubbed_species_binomial,
trait_name, trait_value
;

