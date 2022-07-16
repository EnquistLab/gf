-- ---------------------------------------------------------------------------
-- Assign confidence scores to growth form attributions at species, genus and
-- family level. 

--
--
-- Assumes:
-- * Taxa have been standardized
--
-- Date: 13 Jul 2022
-- ---------------------------------------------------------------------------

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

\set obs_thresh 100			-- Min number of observations for confidence penalty

\c vegbien
SET search_path TO :sch_gf;

--
-- Species growth form confidence
--

ALTER TABLE gf_species 
DROP COLUMN IF EXISTS gf_conf,
DROP COLUMN IF EXISTS gf_conf_flag
;
ALTER TABLE gf_species
ADD COLUMN gf_conf decimal(4,3),
ADD COLUMN gf_conf_flag text
;

-- gf_conf = prop_gf_cons minus discount factor that ranges
-- from 0 (total_obs>=100) to .99 (total_obs=1)
-- In other words, discount prop_gf_cons by up to 20% if total obs<100
UPDATE gf_species
SET gf_conf=GREATEST(
prop_gf_cons-((1-(LEAST(total_obs,100)::numeric/100))/9),
0)
;
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


--
-- Genus growth form confidence
--

