-- ---------------------------------------------------------------------------
-- Infer consensus growth form for family from compiled BIEN growth form 
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
--
-- Date: 13 Jul 2022
-- ---------------------------------------------------------------------------


\set  sch_gf growthforms	-- Schema in which growth form tables will be built
\set sch_obs analytical_db	-- Source schema of growth form attributions/observations

\c vegbien
SET search_path TO :sch_gf;

--
-- Family-level growth forms observations
--

-- Create family gf table
DROP TABLE IF EXISTS gf_family_obs;
CREATE TABLE gf_family_obs (
family text,
gf text,
obs_taxon_rank text,
obs integer
);


-- Extract from compiled species growth forms
INSERT INTO gf_family_obs (
family,
gf,
obs_taxon_rank,
obs
)
SELECT
family,
gf,
'species',
SUM(obs) AS obs
FROM gf_species_obs
WHERE family IS NOT NULL
GROUP BY family, gf
;


-- Extract from compiled genus growth forms
INSERT INTO gf_family_obs (
family,
gf,
obs_taxon_rank,
obs
)
SELECT
family,
gf,
'genus',
SUM(obs) AS obs
FROM gf_genus_obs
WHERE family IS NOT NULL
GROUP BY family, gf
;

-- Extract from family attributions in traits table
INSERT INTO gf_family_obs (
family,
gf,
obs_taxon_rank,
obs
)
SELECT
family,
gf,
'family',
SUM(obs) AS obs
FROM gf_traits_family
WHERE family IS NOT NULL
GROUP BY family, gf
;

-- Extract from family attributions in observations table
INSERT INTO gf_family_obs (
family,
gf,
obs_taxon_rank,
obs
)
SELECT
family,
gf,
'family',
SUM(obs) AS obs
FROM gf_vfoi_family
WHERE family IS NOT NULL
GROUP BY family, gf
;

-- Make unique with sum of attributions and compiled source ranks
DROP TABLE IF EXISTS gf_family_obs_uniq;
CREATE TABLE gf_family_obs_uniq AS
SELECT 
family,
gf,
NULL::text AS inferred_from_ranks,
SUM(obs) AS obs
FROM gf_family_obs
GROUP BY family, gf
ORDER BY family, gf
;

-- Save family + gf + rank combinations
-- Grouped by family + gf
DROP TABLE IF EXISTS gf_family_inferred_from_rank;
CREATE TABLE gf_family_inferred_from_rank AS
SELECT DISTINCT family, gf, obs_taxon_rank AS inferred_from_rank
FROM gf_family_obs
ORDER BY family, gf, obs_taxon_rank
;

-- Grouped by family only; well need this later
DROP TABLE IF EXISTS gf_all_family_inferred_from_rank;
CREATE TABLE gf_all_family_inferred_from_rank AS
SELECT DISTINCT family, obs_taxon_rank AS inferred_from_rank
FROM gf_family_obs
ORDER BY family, obs_taxon_rank
;

UPDATE gf_family_obs_uniq a
SET inferred_from_ranks=b.inferred_from_ranks
FROM (
SELECT family, gf,
	string_agg(inferred_from_rank, ',') AS inferred_from_ranks
FROM gf_family_inferred_from_rank
GROUP BY family, gf
) b
WHERE a.family=b.family
AND a.gf=b.gf
;

DROP TABLE gf_family_obs;
ALTER TABLE gf_family_obs_uniq RENAME TO gf_family_obs;
DROP TABLE IF EXISTS gf_family_obs_temp;
CREATE TABLE gf_family_obs_temp (LIKE gf_family_obs INCLUDING ALL);
INSERT INTO gf_family_obs_temp (
family,
gf,
inferred_from_ranks,
obs
)
SELECT 
family,
gf,
inferred_from_ranks,
obs
FROM gf_family_obs
ORDER BY family,
gf
;
DROP TABLE gf_family_obs;
ALTER TABLE gf_family_obs_temp RENAME TO gf_family_obs;

--
-- Determine consensus family gf
--

-- Add size sort order for growth forms
ALTER TABLE gf_family_obs
ADD COLUMN IF NOT EXISTS gf_size smallint default null
;
UPDATE gf_family_obs
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


DROP TABLE IF EXISTS gf_family;
CREATE TABLE gf_family (
family text,
gf_cons text,
gf_cons_obs integer,
total_obs integer,
gf_cons_prop numeric,
gf_all text
);

-- Select gf with most attributions
INSERT INTO gf_family (
	family,
	gf_cons,
	gf_cons_obs
)
SELECT DISTINCT ON (family)
	family,
	gf,
	obs
FROM gf_family_obs
WHERE gf IS NOT NULL
ORDER BY family, obs DESC, gf_size DESC
;

-- Add total attributions
UPDATE gf_family a
SET total_obs=b.totobs
FROM (
SELECT family, sum(obs) AS totobs
FROM gf_family_obs
WHERE gf IS NOT NULL
GROUP BY family
) b
WHERE a.family=b.family
;
UPDATE gf_family
SET gf_cons_prop=(gf_cons_obs::numeric / total_obs::numeric)::decimal(5,2)
; 

-- Add all gf obs to allow them to be searched
UPDATE gf_family a
SET gf_all=b.gf_all
FROM (
SELECT family, 
	string_agg(gf, ',') AS gf_all
FROM (
SELECT family, gf
FROM gf_family_obs
ORDER BY family, gf
) x
GROUP BY family
) b
WHERE a.family=b.family
;

-- Add column "inferred_from_rank"

ALTER TABLE gf_family
ADD COLUMN IF NOT EXISTS inferred_from_ranks text
;

UPDATE gf_family a
SET inferred_from_ranks=b.inferred_from_ranks
FROM (
SELECT family, 
	string_agg(inferred_from_rank, ',') AS inferred_from_ranks
FROM gf_all_family_inferred_from_rank
GROUP BY family
) b
WHERE a.family=b.family
;

DROP TABLE IF EXISTS gf_all_family_inferred_from_rank;
DROP TABLE IF EXISTS gf_family_inferred_from_rank;
