-- ---------------------------------------------------------------------------
-- Assign confidence scores to growth form attributions at species, genus and
-- family level. 
--
-- ---------------------------------------------------------------------------

-- -----------------------------------------------------------
-- Confidence score (gf_conf) parameters
-- -----------------------------------------------------------

/* Growth form attributions low sample size penalty threshold
Min number of attributions below which additional low sample size penalty is 
subtracted from gf_cons_prop in calculating gf_conf. 
Recommend pthresh=100 to ensure that parameter pdenom also works as intended
*/
\set pthresh 100

/* Penalty denominator
For values of gf_cons_prop<:obs_thresh obs_thresh, penalty subtracted
is a proportion ranging from 0 to gf_cons_prop (i.e., 100% of gf_cons_prop), 
calculated as follows:

1-(pthresh/100))/pdenom

At pthresh=100 and pdenom=10, the maxiumum additional penalty is 0.1 (10%) 
at  gf_cons_prop=1. At pthresh=100 and pdenom=5, the maxiumum penalty rises 
to ~0.2 (20%).
*/
\set pdenom 5 

/* Maximum low-species-gf-assessment penalty
Maximum proportion by which genus of family gf_conf is penalized due to low 
proportion of total species assessed to growth form. This occurs when 
spp_gf_prop=0 (i.e., gf_cons based on family and/or genus attributions only)
*/
\set pmax_spp_gf 0.2

-- -----------------------------------------------------------
-- Schema parameters
-- -----------------------------------------------------------

-- Schema in which growth form tables will be built
\set sch_gf growthforms
-- Source schema of growth form attributions/observations
\set sch_obs analytical_db

-- -----------------------------------------------------------
-- Main
-- -----------------------------------------------------------

-- Connect to DB & working schema
\c vegbien
SET search_path TO :sch_gf;

--
-- Species growth form confidence
--

ALTER TABLE gf_species 
DROP COLUMN IF EXISTS penalty_gf_low_n,
DROP COLUMN IF EXISTS gf_conf,
DROP COLUMN IF EXISTS gf_conf_flag
;
ALTER TABLE gf_species
ADD COLUMN penalty_gf_low_n decimal(3,2),
ADD COLUMN gf_conf decimal(3,2),
ADD COLUMN gf_conf_flag text
;

/* Calculate gf_conf penalty for low gf sample size
gf_conf = gf_cons_prop minus discount factor that ranges
from 0 (total_obs>=100) to .99 (total_obs=1)
In other words, discount gf_cons_prop by up to ~20% if total obs<100
*/
UPDATE gf_species
SET 
penalty_gf_low_n = -(1-(LEAST(total_obs,:pthresh)::numeric/100))/:pdenom
;

-- Apply penalty to gf_conf
UPDATE gf_species
SET gf_conf = GREATEST( gf_cons_prop + penalty_gf_low_n, 0 )
;

-- Set gf_flag
UPDATE gf_species
SET gf_conf_flag=
CASE
WHEN gf_conf>=0.90 THEN 'very high'
WHEN gf_conf<0.90 AND gf_conf>=0.75 THEN 'high'
WHEN gf_conf<0.75 AND gf_conf>=0.5 THEN 'med'
WHEN gf_conf<0.5 AND gf_conf>=0.25 THEN 'low'
WHEN gf_conf<0.25 THEN 'very low'
ELSE NULL
END
;

/* Query for manually inspecting relevant columns
Keep commented out

SELECT family, species, gf_all, gf_cons, gf_cons_obs, total_obs, gf_cons_prop, penalty_gf_low_n, gf_conf, gf_conf_flag
FROM gf_species
ORDER BY split_part(species, ' ', 2)
LIMIT 25
OFFSET 3400
;

*/

--
-- Genus growth form confidence
--

ALTER TABLE gf_genus 
DROP COLUMN IF EXISTS penalty_gf_low_n,
DROP COLUMN IF EXISTS spp,
DROP COLUMN IF EXISTS spp_gf,
DROP COLUMN IF EXISTS spp_gf_prop,
DROP COLUMN IF EXISTS penalty_spp_gf_low_n,
DROP COLUMN IF EXISTS gf_conf,
DROP COLUMN IF EXISTS gf_conf_flag
;
ALTER TABLE gf_genus
ADD COLUMN penalty_gf_low_n decimal(3,2),
ADD COLUMN spp INTEGER DEFAULT 0,
ADD COLUMN spp_gf INTEGER DEFAULT 0,
ADD COLUMN spp_gf_prop double precision,
ADD COLUMN penalty_spp_gf_low_n decimal(3,2),
ADD COLUMN gf_conf decimal(3,2),
ADD COLUMN gf_conf_flag text
;

-- Calculate low gf sample penalty
UPDATE gf_genus
SET 
penalty_gf_low_n = -(1-(LEAST(total_obs,:pthresh)::numeric/100))/:pdenom
;

-- Count total species in genus
UPDATE gf_genus a
SET spp=b.spp
FROM (
SELECT genus, COUNT(DISTINCT species) AS spp
FROM :sch_obs.taxon
WHERE taxon_rank='species'
GROUP BY genus
) b
WHERE a.genus=b.genus
;

-- Count species in genus with gf assigned
UPDATE gf_genus a
SET spp_gf=b.spp_assessed
FROM (
SELECT genus, COUNT(DISTINCT species) AS spp_assessed
FROM gf_species
WHERE gf_cons IS NOT NULL
GROUP BY genus
) b
WHERE a.genus=b.genus
;

-- Calclate proportion of species in genus with gf assigned
UPDATE gf_genus
SET spp_gf_prop = spp_gf::numeric / spp::numeric
WHERE spp>0
;

-- Calculate low species assessed penalty
UPDATE gf_genus
SET penalty_spp_gf_low_n = - ( ( 1 - spp_gf_prop ) * :pmax_spp_gf )
;

-- Calculate gf_conf
UPDATE gf_genus
SET gf_conf = GREATEST( gf_cons_prop + penalty_gf_low_n + penalty_spp_gf_low_n, 0 )
;

-- Set gf_flag
UPDATE gf_genus
SET gf_conf_flag=
CASE
WHEN gf_conf>=0.90 THEN 'very high'
WHEN gf_conf<0.90 AND gf_conf>=0.75 THEN 'high'
WHEN gf_conf<0.75 AND gf_conf>=0.5 THEN 'med'
WHEN gf_conf<0.5 AND gf_conf>=0.25 THEN 'low'
WHEN gf_conf<0.25 THEN 'very low'
ELSE NULL
END
;

/* Query for manually inspecting relevant columns
Keep commented out

SELECT family, genus, 
gf_all, gf_cons, 
-- gf_cons_obs, 
total_obs, gf_cons_prop, penalty_gf_low_n,
spp, spp_gf, spp_gf_prop::decimal(4,3), penalty_spp_gf_low_n as penalty_spp_gf,
gf_conf, gf_conf_flag
FROM gf_genus
LIMIT 25
OFFSET 1000
;

*/


--
-- Family growth form confidence
--

ALTER TABLE gf_family 
DROP COLUMN IF EXISTS penalty_gf_low_n,
DROP COLUMN IF EXISTS spp,
DROP COLUMN IF EXISTS spp_gf,
DROP COLUMN IF EXISTS spp_gf_prop,
DROP COLUMN IF EXISTS penalty_spp_gf_low_n,
DROP COLUMN IF EXISTS gf_conf,
DROP COLUMN IF EXISTS gf_conf_flag
;
ALTER TABLE gf_family
ADD COLUMN penalty_gf_low_n decimal(3,2),
ADD COLUMN spp INTEGER DEFAULT 0,
ADD COLUMN spp_gf INTEGER DEFAULT 0,
ADD COLUMN spp_gf_prop double precision,
ADD COLUMN penalty_spp_gf_low_n decimal(3,2),
ADD COLUMN gf_conf decimal(3,2),
ADD COLUMN gf_conf_flag text
;

-- Calculate low gf sample penalty
UPDATE gf_family
SET 
penalty_gf_low_n = -(1-(LEAST(total_obs,:pthresh)::numeric/100))/:pdenom
;

-- Count total species in family
UPDATE gf_family a
SET spp=b.spp
FROM (
SELECT family, COUNT(DISTINCT species) AS spp
FROM :sch_obs.taxon
WHERE taxon_rank='species'
GROUP BY family
) b
WHERE a.family=b.family
;

-- Count species in family with gf assigned
UPDATE gf_family a
SET spp_gf=b.spp_assessed
FROM (
SELECT family, COUNT(DISTINCT species) AS spp_assessed
FROM gf_species
WHERE gf_cons IS NOT NULL
GROUP BY family
) b
WHERE a.family=b.family
;

-- Calclate proportion of species in family with gf assigned
UPDATE gf_family
SET spp_gf_prop = spp_gf::numeric / spp::numeric
WHERE spp>0
;

-- Calculate low proportion species assessed penalty
UPDATE gf_family
SET penalty_spp_gf_low_n = - ( ( 1 - spp_gf_prop ) * :pmax_spp_gf )
;

-- Calculate gf_conf
UPDATE gf_family
SET gf_conf = GREATEST( gf_cons_prop + penalty_gf_low_n + penalty_spp_gf_low_n, 0 )
;

-- Set gf_flag
UPDATE gf_family
SET gf_conf_flag=
CASE
WHEN gf_conf>=0.90 THEN 'very high'
WHEN gf_conf<0.90 AND gf_conf>=0.75 THEN 'high'
WHEN gf_conf<0.75 AND gf_conf>=0.5 THEN 'med'
WHEN gf_conf<0.5 AND gf_conf>=0.25 THEN 'low'
WHEN gf_conf<0.25 THEN 'very low'
ELSE NULL
END
;

/* Query for manually inspecting relevant columns
Keep commented out

SELECT family, 
gf_all, gf_cons, 
-- gf_cons_obs, 
total_obs, gf_cons_prop, penalty_gf_low_n, 
spp, spp_gf, spp_gf_prop::decimal(4,3), penalty_spp_gf_low_n as penalty_spp_gf,
gf_conf, gf_conf_flag
FROM gf_family
LIMIT 25
OFFSET 0
;

*/

--
-- Index the final tables
--

-- gf_species
DROP INDEX IF EXISTS gf_species_family_idx;
DROP INDEX IF EXISTS gf_species_genus_idx;
DROP INDEX IF EXISTS gf_species_species_idx;
DROP INDEX IF EXISTS gf_species_gf_conf_flag_idx;

CREATE INDEX gf_species_family_idx ON gf_species (family);
CREATE INDEX gf_species_genus_idx ON gf_species (genus);
CREATE INDEX gf_species_species_idx ON gf_species (species);
CREATE INDEX gf_species_gf_conf_flag_idx ON gf_species (gf_conf_flag);

-- gf_genus
DROP INDEX IF EXISTS gf_genus_family_idx;
DROP INDEX IF EXISTS gf_genus_genus_idx;
DROP INDEX IF EXISTS gf_genus_gf_conf_flag_idx;

CREATE INDEX gf_genus_family_idx ON gf_genus (family);
CREATE INDEX gf_genus_genus_idx ON gf_genus (genus);
CREATE INDEX gf_genus_gf_conf_flag_idx ON gf_genus (gf_conf_flag);

-- gf_family
DROP INDEX IF EXISTS gf_family_family_idx;
DROP INDEX IF EXISTS gf_family_gf_conf_flag_idx;

CREATE INDEX gf_family_family_idx ON gf_family (family);
CREATE INDEX gf_family_gf_conf_flag_idx ON gf_family (gf_conf_flag);
