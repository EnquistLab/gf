-- --------------------------------------------------------------------------
-- Custom script to create new table species_growth_forms in the BIEN analytical database.
-- After running this, run gf_imput with the appropriate parameters.
-- --------------------------------------------------------------------------

DROP TABLE IF EXISTS species_growth_forms;
CREATE TABLE species_growth_forms AS
SELECT taxon_id, family, genus, species
FROM taxon
WHERE taxon_rank='species'
;

ALTER TABLE species_growth_forms ADD PRIMARY KEY (taxon_id);
CREATE INDEX species_growth_forms_family_idx ON species_growth_forms (family);
CREATE INDEX species_growth_forms_genus_idx ON species_growth_forms (genus);
CREATE INDEX species_growth_forms_species_idx ON species_growth_forms (species);


