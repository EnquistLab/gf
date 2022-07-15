-- ---------------------------------------------------------------------------
-- Imputed growth form for remaining species for which direct attributions
-- are not available, based on genus and family growth forms
--
-- Date: 14 Jul 2022
-- ---------------------------------------------------------------------------

\set  sch_gf growthforms	-- Schema in which growth form tables will be built
\set sch_obs analytical_db	-- Source schema of growth form attributions/observations
\set  sch_spp boyle			-- Source schema of master species list

\c vegbien
SET search_path TO :sch_gf;
