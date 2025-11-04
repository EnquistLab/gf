# BIEN Growth Forms Module


### Contents

[I. Overview](#overview)    
[II. Methods](#methods)  
[III. Usage](#usage)   
[IV. Version info](#version)    

<a name="overview"></a>
## I. Overview

Code for inferring growth forms of species within the BIEN database. This is done in two general steps: (1) compile all growth form attributions for each species, and (2) infer a single consensus growth form for each species. Family- and genus-level attributions are used to impute growth forms to species for which species-level attributions are not available.

For each consensus growth form assigned to each species, a confidence score (0-1), categorical confidence flag ('very high', 'high', 'med', 'low', 'very low') and attribution method ('direct from species', 'imputed from family', 'imputed from genus') is also provided.

This early 'alpha' release is a series of SQL scripts, with commands intended to be pasted into the postgres SQL interface (see **[III. Usage](#usage)** for sequence). Also note that the initial import steps require manual inspection and correction of taxonomy and growth form vocabulary. See instructions in individual scripts. 

The individual scripts in this workflow will be redeveloped as semi-automated pipeline at a later date.

<a name="methods"></a>
## III. Methods

All growth form attributions at the species, genus or family level were compiled from the BIEN traits table (`agg_traits`) and the BIEN observations table (`view_full_occurrence_individual`). 

#### Taxonomy
Although taxon names had previously been standardized with the TNRS, names were checked to ensure that each species belonged to exactly one family. A small number of names (33) had homonym issues and were corrected by manual inspection.

#### Vocabulary. 
All growth form names and codes were standardized to conform to the following simplified growth form schema:

Growth form | Notes
----------- | ------
herb | includes grasses, epiphytic herbs and non-woody parasites
bambusoid | woody tree-like grasses
shrub  | includes shrubby hemi-parasites)
tree  | 
vina  | herbaceous climbers, originating on the ground
liana  | herbaceous climbers, originating on the ground
hemiepiphyte  | climbers, germinating in the forest canopy as an epipthye and secondarily sending roots to the ground.

#### Consensus growth form (`gf_cons`)
For each species, the growth form with the highest proportion of attributions (observations, or obs) was selected as the consensus growth form. 

#### Consensus growth form confidence score (`gf_conf`)
A confidence score from 0-1 was calculated for each consensus growth form attributed to each species, using the following formula:

For species, `gf_conf` is calculated as follows:

`gf_conf = GREATEST( gf_cons_prop - low_n_penalty, 0 )`  (1)

Where,

`gf_cons_prop = gf_cons_obs / total_obs`  (2)

and 

`low_n_penalty = (1-(LEAST(total_obs, pthresh)::numeric/100))/ pdenom` (3)

For genera and families, `gf_conf` is calculated as follows:

`gf_conf = GREATEST( gf_cons_prop - low_n_penalty - low_species_penalty, 0 )`  (4)

where 

`low_species_penalty = ( 1 - spp_gf_prop ) * pmax_spp_gf` (5)

In equation (2) `gf_cons_obs` is the total growth form attribution for the consensus growth form and `total_obs` is the total growth form attributions. In equation (3), `pthresh` is the minimum sample size threshold, below which the penalty is non-zero; `pdenom` is the "probability denominator", a scaling parameter which sets the maximum penalty subtracted at total_obs=0. At `pthresh`=100, `pdenom`=5 sets a maximum penalty of 0.2. That is, no species-level observations (`total_obs`=0) result in an additional 20% being subtracted from `gf_cons_prop`.

In equation (5), `spp_gf_prop` is the proportion of species in the genus or family having a growth form attribution. `pmax_spp_gf` set the maximum penalty; a `pmax_spp_gf`=0.2 caps the maximum penalty at 0.2 (20%). 

Parameter settings used were `pthresh`=100, `pdenom`=5 and `pmax_spp_gf`. Using these setting, the maximum amount by which `gf_cons_prop` can be reduced is 0.4. Use of the Postgres function GREATEST in equations (1) and (4) prevents `gf_conf` from dropping below zero.  


#### Consensus growth form confidence flag (`gf_conf_flag`)

`gf_conf_flag` converts `gf_conf` to confidence categories, as follows: 

Value | `gf_conf` range
--- | ---
very high | >=0.90
high | <0.90 AND>=0.75
med | <0.75 AND>=0.5
low | <0.5 AND>=0.25
very low | <0.25

#### Growth form imputation

For a new species list, consensus growth forms are assigned by first joining tp species, then th genera, and finally, growth form is assigned to the remining species by joining to family. For each determination, the method used to determine growth form, `gf_method`, is recorded as follows:

gf_method  | meaning
---- | ----
direct from species | gf assigned by joining on species
imputed from genus  | gf assigned by joining on genus
imputed from family | gf assigned by joining on family


<a name="usage"></a>
## III. Usage

#### 1. Create growth form database

Scripts that create the BIEN Growth Form Database are found in subdirectory `create_db` within the code repository base directory. The database scripts **must** be run in the following order:

1. `gf_traits.sql`
2. `gf_obs.sql`
3. `gf_consensus_species.sql`
4. `gf_consensus_genus.sql`
5. `gf_consensus_family.sql`
6. `gf_manual_corrections.sql`
7. `gf_conf`  

The individual scripts in this workflow will be redeveloped as semi-automated pipeline at a later date.

#### 2. Impute growth forms for species

Inferring of growth forms for a user-submitted list of species is performed by script `gf_impute.sql`. This script lives in the code repository base directory. A second optional script, `gf_correct_syn_species.sql`, may be use to correct erroneous assignments of growth forms to species which are synonyms.

***Architecture***   

* Current architecture of the BIEN Growth Tool assumes that the growth form database (GFDB) is a schema within the BIEN observation database (vegbien)  
* The user data is list of species (and their families) for which growth forms will be inferred, imported to a new table in a separate schema within the BIEN observation database.

***Prepare and import the species list***   

* The schema of the species table is simple: one column for family and one column for species. 
* Do not include authors with species names
* Although genus is use for inferring growth form, do not include it in the table. It will be extracted from the species name.
* If family is not present in the original list, run the species names through the TNRS first to attach a family name to each species. 
* Even if families are present in the original list, we *strongly* recommend running all names through the TNRS first to ensure they match to names used in the GFDB)

***Infer growth forms***   

Growth forms are inferred by running theh SQL in script `gf_impute.sql`. Before doing so, you MUST set the following parameters inside the script:

```
\set sch_spp <SCHEMA_CONTAINING_USER_SPECIES_TABLE>
\set tbl_spp <USER_SPECIES_TABLE>
```

Once all commands have been executed, run the three (commented-out) shell commands at the end of the script to export table <USER_SPECIES_TABLE> as a CSV file.

As an optional second step, before exporting the results, you may want to run script `gf_correct_syn_species.sql` to fix gf assignments to species which are synonyms. Set parameters sch_spp and tbl_spp as for `gf_impute.sql`.

<a name="version"></a>
## IV. Version info

#### 0.1
* First working beta release. Scripts run separately, in sequence shown in [II. Usage](#usage).


