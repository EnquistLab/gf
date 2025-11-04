-- -------------------------------------------------------------------------------
-- Manual corrections to growth form attributions
-- -------------------------------------------------------------------------------

-- Schema in which growth form tables will be built
\set sch_gf growthforms
-- Source schema of growth form attributions/observations
\set sch_obs analytical_db

\c vegbien
SET search_path TO :sch_gf;

--
-- Family level
-- 

ALTER TABLE gf_family
ADD COLUMN IF NOT EXISTS notes text
;

UPDATE gf_family
SET gf_cons='herb',
gf_all='herb',
notes='Manually corrected from erroneous gf attribution tree'
WHERE family='Apodanthaceae'
;
UPDATE gf_family
SET gf_cons='hemiepiphyte',
gf_cons_obs=522,
gf_cons_prop=(522::numeric / 1733::numeric)::decimal(5,2),
notes='Manually corrected from less accurate gf attribution tree'
WHERE family='Cyclanthaceae';
;
UPDATE gf_family
SET gf_cons='herb',
gf_all='herb',
notes='Manually corrected from erroneous gf attribution tree'
WHERE family='Lejeuneaceae'
;
UPDATE gf_family
SET gf_cons='herb',
gf_all='herb',
notes='Manually corrected from erroneous gf attribution tree'
WHERE family='Lophocoleaceae'
;
UPDATE gf_family
SET gf_cons='liana',
gf_all='liana',	
gf_cons_prop=1,
inferred_from_ranks=NULL,
notes='Manually corrected from erroneous gf attribution shrub (both species are lianas)'
WHERE family='Lophopyxidaceae'
;
UPDATE gf_family
SET gf_cons='herb',
gf_all='herb',
notes='Manually corrected from inaccurate gf attribution shrub'
WHERE family='Lowiaceae'
;
UPDATE gf_family
SET gf_cons='herb',
gf_all='herb',
notes='Manually corrected from erroneous gf attribution tree'
WHERE family='Orthotrichaceae'
;
UPDATE gf_family
SET gf_cons='herb',
gf_all='herb',
notes='Manually corrected from erroneous gf attribution tree'
WHERE family='Phyllogoniaceae'
;
UPDATE gf_family
SET gf_cons='herb',
gf_all='herb',
notes='Manually corrected from erroneous gf attribution tree'
WHERE family='Pilotrichaceae'
;
UPDATE gf_family
SET gf_cons='herb',
gf_all='herb',
notes='Manually corrected from erroneous gf attribution tree'
WHERE family='Prionodontaceae'
;

--
-- Genus level
-- 

ALTER TABLE gf_genus
ADD COLUMN IF NOT EXISTS notes text
;

DELETE FROM gf_genus
WHERE family='Apodanthaceae'  -- parasites, use family attribution
;
DELETE FROM gf_genus
WHERE family='Lejeuneaceae' -- bryophytes, use family attribution
;
DELETE FROM gf_genus
WHERE family='Lophocoleaceae' -- Liverworts, use family attribution
;
DELETE FROM gf_genus
WHERE family='Lophopyxidaceae' -- all lianas, use family attribution
;
DELETE FROM gf_genus
WHERE family='Lowiaceae' -- all herbs, use family attribution
;
DELETE FROM gf_genus
WHERE family='Orthotrichaceae' -- bryophytes, use family attribution
;
DELETE FROM gf_genus
WHERE family='Phyllogoniaceae' -- bryophytes, use family attribution
;
DELETE FROM gf_genus
WHERE family='Pilotrichaceae' -- bryophytes, use family attribution
;
DELETE FROM gf_genus
WHERE family='Prionodontaceae'
;

--
-- Species level
-- 

ALTER TABLE gf_species
ADD COLUMN IF NOT EXISTS notes text
;

DELETE FROM gf_species
WHERE family='Apodanthaceae'  -- parasites, use family attribution
;
DELETE FROM gf_species
WHERE family='Lejeuneaceae' -- bryophytes, use family attribution
;
DELETE FROM gf_species
WHERE family='Lophocoleaceae' -- Liverworts, use family attribution
;
DELETE FROM gf_species
WHERE family='Lophopyxidaceae' -- all lianas, use family attribution
;
DELETE FROM gf_species
WHERE family='Lowiaceae' -- all herbs, use family attribution
;
DELETE FROM gf_species
WHERE family='Orthotrichaceae' -- bryophytes, use family attribution
;
DELETE FROM gf_species
WHERE family='Phyllogoniaceae' -- bryophytes, use family attribution
;
DELETE FROM gf_species
WHERE family='Pilotrichaceae' -- bryophytes, use family attribution
;
DELETE FROM gf_species
WHERE family='Prionodontaceae'
;





