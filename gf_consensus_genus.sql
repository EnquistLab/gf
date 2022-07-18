-- ---------------------------------------------------------------------------
-- Infer consensus growth form for genus from compiled BIEN growth form 
-- attributions
--
-- Steps:
-- * Append standardized gf obs from trait table and vfoi
-- * Infer predominant (consensus) growth form
-- * If >1 gf with similar proportions of attributions (=obs), use largest attainable
--   E.g., if both tree and shrub are common, use tree
--
--
-- Assumes:
-- * Taxa have been standardized
-- * Each species and genus are in exactly one family
--
-- Date: 13 Jul 2022
-- ---------------------------------------------------------------------------


\set  sch_gf growthforms	-- Schema in which growth form tables will be built
\set sch_obs analytical_db	-- Source schema of growth form attributions/observations

\c vegbien
SET search_path TO :sch_gf;

-- Clean up some taxonomic anomalies before starting
-- Need better solution earlier on
DELETE FROM gf_traits_genus WHERE family IS NULL;
DELETE FROM gf_vfoi_genus WHERE family IS NULL;

--
-- Genus level growth form observations
--

-- Create genus gf table
DROP TABLE IF EXISTS gf_genus_obs;
CREATE TABLE gf_genus_obs (
family text,
genus text,
gf text,
obs_taxon_rank text,
obs integer
);


-- Extract from compiled species growth forms
INSERT INTO gf_genus_obs (
family,
genus,
gf,
obs_taxon_rank,
obs
)
SELECT
family,
genus,
gf,
'species',
SUM(obs) AS obs
FROM gf_species_obs
WHERE genus IS NOT NULL
GROUP BY family, genus, gf
;

-- Extract from compiled genus attributions in traits table
INSERT INTO gf_genus_obs (
family,
genus,
gf,
obs_taxon_rank,
obs
)
SELECT
family,
genus,
gf,
'genus',
SUM(obs) AS obs
FROM gf_traits_genus
WHERE genus IS NOT NULL
GROUP BY family, genus, gf
;

-- Extract from compiled genus attributions in traits table
INSERT INTO gf_genus_obs (
family,
genus,
gf,
obs_taxon_rank,
obs
)
SELECT
family,
genus,
gf,
'genus',
SUM(obs) AS obs
FROM gf_vfoi_genus
WHERE genus IS NOT NULL
GROUP BY family, genus, gf
;

-- Make unique with sum of attributions and compiled source ranks
DROP TABLE IF EXISTS gf_genus_obs_uniq;
CREATE TABLE gf_genus_obs_uniq AS
SELECT 
family,
genus,
gf,
NULL::text AS inferred_from_ranks,
SUM(obs) AS obs
FROM gf_genus_obs
WHERE genus IS NOT NULL
GROUP BY family, genus, gf
ORDER BY family, genus, gf
;

-- Save genus + gf + rank combinations
-- Grouped by genus + gf
DROP TABLE IF EXISTS gf_genus_inferred_from_rank;
CREATE TABLE gf_genus_inferred_from_rank AS
SELECT DISTINCT genus, gf, obs_taxon_rank AS inferred_from_rank
FROM gf_genus_obs
ORDER BY genus, gf, obs_taxon_rank
;

-- Grouped by genus only; well need this later
DROP TABLE IF EXISTS gf_all_genus_inferred_from_rank;
CREATE TABLE gf_all_genus_inferred_from_rank AS
SELECT DISTINCT genus, obs_taxon_rank AS inferred_from_rank
FROM gf_genus_obs
ORDER BY genus, obs_taxon_rank
;

UPDATE gf_genus_obs_uniq a
SET inferred_from_ranks=b.inferred_from_ranks
FROM (
SELECT genus, gf,
	string_agg(inferred_from_rank, ',') AS inferred_from_ranks
FROM gf_genus_inferred_from_rank
GROUP BY genus, gf
) b
WHERE a.genus=b.genus
AND a.gf=b.gf
;

DROP TABLE gf_genus_obs;
ALTER TABLE gf_genus_obs_uniq RENAME TO gf_genus_obs;
DROP TABLE IF EXISTS gf_genus_obs_temp;
CREATE TABLE gf_genus_obs_temp (LIKE gf_genus_obs INCLUDING ALL);
INSERT INTO gf_genus_obs_temp (
family,
genus,
gf,
inferred_from_ranks,
obs
)
SELECT 
family,
genus,
gf,
inferred_from_ranks,
obs
FROM gf_genus_obs
ORDER BY family,
genus,
gf
;
DROP TABLE gf_genus_obs;
ALTER TABLE gf_genus_obs_temp RENAME TO gf_genus_obs;

--
-- Determine consensus genus gf
--

-- Add size sort order for growth forms
ALTER TABLE gf_genus_obs
ADD COLUMN IF NOT EXISTS gf_size smallint default null
;
UPDATE gf_genus_obs
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


DROP TABLE IF EXISTS gf_genus;
CREATE TABLE gf_genus (
family text,
genus text,
gf_cons text,
gf_cons_obs integer,
total_obs integer,
gf_cons_prop numeric,
gf_all text
);

-- Select gf with most attributions
INSERT INTO gf_genus (
	family,
	genus,
	gf_cons,
	gf_cons_obs
)
SELECT DISTINCT ON (genus)
	family,
	genus,
	gf,
	obs
FROM gf_genus_obs
WHERE gf IS NOT NULL
ORDER BY genus, obs DESC, gf_size DESC
;

-- Add total attributions
UPDATE gf_genus a
SET total_obs=b.totobs
FROM (
SELECT genus, sum(obs) AS totobs
FROM gf_genus_obs
WHERE gf IS NOT NULL
GROUP BY genus
) b
WHERE a.genus=b.genus
;
UPDATE gf_genus
SET gf_cons_prop=(gf_cons_obs::numeric / total_obs::numeric)::decimal(4,1)
; 

-- Add all gf obs to allow them to be searched
UPDATE gf_genus a
SET gf_all=b.gf_all
FROM (
SELECT genus, 
	string_agg(gf, ',') AS gf_all
FROM (
SELECT genus, gf
FROM gf_genus_obs
ORDER BY genus, gf
) x
GROUP BY genus
) b
WHERE a.genus=b.genus
;

-- Add column "inferred_from_rank"

ALTER TABLE gf_genus
ADD COLUMN IF NOT EXISTS inferred_from_ranks text
;

UPDATE gf_genus a
SET inferred_from_ranks=b.inferred_from_ranks
FROM (
SELECT genus, 
	string_agg(inferred_from_rank, ',') AS inferred_from_ranks
FROM gf_all_genus_inferred_from_rank
GROUP BY genus
) b
WHERE a.genus=b.genus
;

DROP TABLE IF EXISTS gf_all_genus_inferred_from_rank;
DROP TABLE IF EXISTS gf_genus_inferred_from_rank;



