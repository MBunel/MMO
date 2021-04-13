ROBOT := java -jar ~/Téléchargements/robot.jar
EMACS := emacs -batch -Q --eval "(require 'org)"

SRC_FOLDER := src
BUILD_FOLDER := build
TEMP_FOLDER := tmp

#OWL_FILES := $(wildcard $(SRC_FOLDER)/ComposantesMMO/*.owl)

# Définition en extension pour le débug
OWL_FILES := $(SRC_FOLDER)/ComposantesMMO/MMO_SousPartie_Carte.owl $(SRC_FOLDER)/ComposantesMMO/MMO_SousPartie_Dénotation.owl

SPARQL_QUERIES_TEST := $(wildcard tests/*.sparql)

MMV_TERMS := mmv_term.txt

MMO := mmo
MMV := mmv

MMO_IRI := http://purl.org/MMO
MMV_IRI := $(MMO_IRI)

MMO_VERSION := 0.1
MMV_VERSION := $(MMO_VERSION)

TODAY := $(shell date -I)


.PHONY: directories tests 

all: directories $(BUILD_FOLDER)/$(MMO).owl $(BUILD_FOLDER)/$(MMV).owl


# Règles de construction de l'ontologie

directories: $(BUILD_FOLDER) $(TEMP_FOLDER)

$(BUILD_FOLDER) $(TEMP_FOLDER):
	mkdir -p $@

# Fusion des différentes composantes

$(TEMP_FOLDER)/_components_merged.owl: $(OWL_FILES)
	$(ROBOT) merge $(addprefix --input , $(OWL_FILES)) --output $@

# Anotation de l'ontologie temporaire (seules les annotations
# générales doivent être mise

# TODO: à compléter/revoir


# Extraction de MMV à partir de l'ontologie temporaire

$(TEMP_FOLDER)/_$(MMV)_extracted.owl: $(TEMP_FOLDER)/_components_merged.owl
	$(ROBOT) extract --method bot --input $< --term-file $(SRC_FOLDER)/$(MMV_TERMS) --output $@

# Création des axiomes de MMO par résonement
$(TEMP_FOLDER)/_$(MMO)_reasoned.owl: $(TEMP_FOLDER)/_components_merged.owl
	$(ROBOT) reason -i $< -r HERMIT -o $@

# Extrait la documentation de MMO du readme
$(TEMP_FOLDER)/_$(MMO)_doc.txt:
	$(EMACS) readme.org --eval '(progn (org-id-goto "3877ff17-23f1-488e-9b10-57dea2b70af9") (org-ascii-export-as-ascii nil t) (write-file "$@"))'

# Extrait la documentation de MMV du readme
$(TEMP_FOLDER)/_$(MMV)_doc.txt:
	$(EMACS) readme.org --eval '(progn (org-id-goto "2812eeff-8868-4ed2-afc9-0b79d8bf78ef") (org-ascii-export-as-ascii nil t) (write-file "$@"))'


# Annotation ontologies
$(TEMP_FOLDER)/_$(MMO)_annotated.owl: $(TEMP_FOLDER)/_$(MMO)_reasoned.owl | $(TEMP_FOLDER)/_$(MMO)_doc.txt
	$(ROBOT) annotate --input $< \
		--ontology-iri $(MMO_IRI) \
		--version-iri $(MMO_IRI)/$(MMO_VERSION) \
		--annotation rdfs:comment "$(shell cat $(TEMP_FOLDER)/_$(MMO)_doc.txt)" \
		--annotation rdfs:label "Label" \
		--annotation dc:modified $(TODAY) \
		--output $@


$(TEMP_FOLDER)/_$(MMV)_annotated.owl: $(TEMP_FOLDER)/_$(MMV)_extracted.owl | $(TEMP_FOLDER)/_$(MMV)_doc.txt
	$(ROBOT) annotate --input $< \
		--ontology-iri $(MMV_IRI) \
		--version-iri $(MMV_IRI)/$(MMV_VERSION) \
		--annotation rdfs:comment "$(shell cat $(TEMP_FOLDER)/_$(MMV)_doc.txt)" \
		--annotation rdfs:label "Label" \
		--annotation dc:modified $(TODAY) \
		--output $@


# Création des versions finales MMO et MMV
# Version finale de MMO
$(BUILD_FOLDER)/$(MMO).owl: $(TEMP_FOLDER)/_$(MMO)_annotated.owl
	cp $< $@

# Version finale de MMV
$(BUILD_FOLDER)/$(MMV).owl: $(TEMP_FOLDER)/_$(MMV)_annotated.owl
	cp $< $@

# Régle pour la création de l'ontologie
tests: $(BUILD_FOLDER)/$(MMO).owl
	$(ROBOT) verify --input $< --queries $(SPARQL_QUERIES_TEST)

evaluation: $(BUILD_FOLDER)/$(MMO).owl
	$(ROBOT) report --input $< --output evaluation_report.html

clean:
	rm -r $(BUILD_FOLDER)

mrproper: clean
	rm -r $(TEMP_FOLDER)
