# BIEN Growth Forms Module


### Contents

[I. Overview](#overview)  
[II. Usage](#usage)  

<a name="overview"></a>
### I. Overview

Code for inferring growth forms of species within the BIEN database. This is done in two general steps: first, but compiling all growth form attributions for each species, and second, inferring a single consensus growth form for each species. Family- and genus-level attributions are used to impute growth forms to species for which species-level attributions are not available.

The early 'alpha' release is a series of SQL only, with commands intended to be pasted into the postgres SQL interface (see **Usage** for sequence). Also note that some expert manual inspection and correction is required. See instructions in individual scripts. Will be redeveloped as semi-automated pipeline at a later date.


<a name="usage"></a>
### I. Usage

The scripts must be run in the following order:
1. gf_traits.sql
2. gf_obs.sql
3. gf_consensus_species.sql
4. gf_consensus_genus.sql
5. gf_consensus_family.sql
6. gf_manual_corrections.sql
7. gf_imputed


