# Exécutables
ROBOT := java -jar ~/Téléchargements/robot.jar
EMACS := emacs -batch -Q --eval "(require 'org)"

# Dossiers nécessaires
SRC_FOLDER := src
BUILD_FOLDER := build
TEMP_FOLDER := tmp
TESTS_FOLDER := tests

# Fichiers Owl
#OWL_FILES := $(wildcard $(SRC_FOLDER)/ComposantesMMO/*.owl)
# Définition en extension pour le débug
OWL_FILES := $(SRC_FOLDER)/ComposantesMMO/MMO_SousPartie_Carte.owl $(SRC_FOLDER)/ComposantesMMO/MMO_SousPartie_Dénotation.owl

# Axiomes pour le raisonnement
AXIOM_GEN := SubClass EquivalentClass DisjointClasses DataPropertyCharacteristic EquivalentDataProperties SubDataProperty ClassAssertion PropertyAssertion EquivalentObjectProperty InverseObjectProperties ObjectPropertyCharacteristic SubObjectProperty

# Requêtes pour les tests unitaires de MMO
SPARQL_QUERIES_TEST := $(wildcard $(TESTS_FOLDER)/*.sparql)

# Fichier listant les termes à extraire pour construire MMV
MMV_TERMS := mmv_term.txt

# Nom des fichiers finaux (sans extension) pour MMO et MMV
MMO := mmo
MMV := mmv

# URI de MMO et de MMV
MMO_IRI := http://purl.org/MMO
MMV_IRI := $(MMO_IRI)

# Version de MMO et de MMV
MMO_VERSION := 0.1
MMV_VERSION := $(MMO_VERSION)

# Date du jour. Pour définit la date de dernière mise à jour
TODAY := $(shell date -I)


# Variables pour la documentation
MMO_README_SUBTREE := 3877ff17-23f1-488e-9b10-57dea2b70af9
MMV_README_SUBTREE := 2812eeff-8868-4ed2-afc9-0b79d8bf78ef

# Liste des fichiers à générer
FILES_TO_MAKE := $(addprefix $(BUILD_FOLDER)/, $(MMV).ttl $(MMV).owl $(MMO).ttl $(MMO).owl)


# Défini les régles à executer à chaque fois
.PHONY: directories tests

# Règles de construction de l'ontologie

# Régle générale
all: directories $(FILES_TO_MAKE)

# Construction des dossiers nécessaires
directories: $(BUILD_FOLDER) $(TEMP_FOLDER)

# Construction des dossiers nécessaires
$(BUILD_FOLDER) $(TEMP_FOLDER):
	@echo "Creation of $@ folder"
	@mkdir -p $@

# Fusion des différentes composantes
$(TEMP_FOLDER)/_components_merged.owl: $(OWL_FILES)
	@echo "Merging $(OWL_FILES)"
	@$(ROBOT) merge $(addprefix --input , $(OWL_FILES)) --output $@

# Extraction de MMV à partir de l'ontologie temporaire
$(TEMP_FOLDER)/_$(MMV)_extracted.owl: $(TEMP_FOLDER)/_components_merged.owl
	@echo "Extraction of $(MMV)'s concepts"
	@$(ROBOT) extract --method bot --input $< --term-file $(SRC_FOLDER)/$(MMV_TERMS) --output $@

# Création des axiomes de MMO par résonement
#
# "annotate-inferred-axioms true" permet d'indiquer quels sont les axiomes qui
# ont été inférés (ne marche qu'avec les axiome type subclass)
#
# "equivalent-classes-allowed asserted-only" renvoie une erreur si
# des équivalences simple (A ≡ B) sont inférées
#
# "exclude-tautologies all" permet de virer les tautologies (A owl:topProperty B)
# créées lors de l'inférence
#
$(TEMP_FOLDER)/_$(MMO)_reasoned.owl: $(TEMP_FOLDER)/_components_merged.owl
	@echo "Reasoning on $(MMO) with : $(AXIOM_GEN) axioms"
	@$(ROBOT) reason -i $< \
		-r HERMIT \
		--annotate-inferred-axioms false \
		--equivalent-classes-allowed asserted-only \
		--axiom-generators "$(AXIOM_GEN)" \
		--exclude-tautologies all \
		-o $@

# Extrait la documentation de MMO du readme
$(TEMP_FOLDER)/_$(MMO)_doc.txt:
	@echo "Extraction of $(MMO) documentation"
	@$(EMACS) readme.org --eval '(progn (org-id-goto "$(MMO_README_SUBTREE)") (org-ascii-export-as-ascii nil t) (write-file "$@"))'

# Extrait la documentation de MMV du readme
$(TEMP_FOLDER)/_$(MMV)_doc.txt:
	@echo "Extraction of $(MMV) documentation"
	@$(EMACS) readme.org --eval '(progn (org-id-goto "$(MMV_README_SUBTREE)") (org-ascii-export-as-ascii nil t) (write-file "$@"))'

# Annotation ontologie MMO
$(TEMP_FOLDER)/_$(MMO)_annotated.owl: $(TEMP_FOLDER)/_$(MMO)_reasoned.owl | $(TEMP_FOLDER)/_$(MMO)_doc.txt
	@echo "Annotation of $(MMO)"
	@$(ROBOT) annotate --input $< \
		--ontology-iri $(MMO_IRI) \
		--version-iri $(MMO_IRI)/$(MMO_VERSION) \
		--annotation rdfs:comment "$(shell cat $(TEMP_FOLDER)/_$(MMO)_doc.txt)" \
		--annotation rdfs:label "Label" \
		--annotation dc:modified $(TODAY) \
		--annotation owl:versionInfo $(MMO_VERSION) \
		--output $@

# Annotation ontologie MMV
$(TEMP_FOLDER)/_$(MMV)_annotated.owl: $(TEMP_FOLDER)/_$(MMV)_extracted.owl | $(TEMP_FOLDER)/_$(MMV)_doc.txt
	@echo "Annotation of $(MMV)"
	@$(ROBOT) annotate --input $< \
		--ontology-iri $(MMV_IRI) \
		--version-iri $(MMV_IRI)/$(MMV_VERSION) \
		--annotation rdfs:comment "$(shell cat $(TEMP_FOLDER)/_$(MMV)_doc.txt)" \
		--annotation rdfs:label "Label" \
		--annotation dc:modified $(TODAY) \
		--annotation owl:versionInfo $(MMO_VERSION) \
		--output $@


# Création des versions finales MMO et MMV

# Version finale de MMO
$(BUILD_FOLDER)/$(MMO).owl: $(TEMP_FOLDER)/_$(MMO)_annotated.owl
	@echo "Creation of $(MMO).owl"
	@cp $< $@

# Version finale de MMV
$(BUILD_FOLDER)/$(MMV).owl: $(TEMP_FOLDER)/_$(MMV)_annotated.owl
	@echo "Creation of $(MMV).owl"
	@cp $< $@

%.ttl: %.owl
	@echo "Conversion of $< in $@"
	@$(ROBOT) convert --input $< --output $@

# Tests unitaires MMO
tests: $(BUILD_FOLDER)/$(MMO).owl
	@echo "Verification of $(MMO).owl"
	@$(ROBOT) verify --input $< --queries $(SPARQL_QUERIES_TEST)

# Evaluation MMO
evaluation: $(BUILD_FOLDER)/$(MMO).owl
	@echo "Evaluation of $(MMO).owl"
	@$(ROBOT) report --input $< --output evaluation_report.html

# Règles de nettoyage
# Suppression des fichiers temporaires
clean:
	@echo "Removing $(TEMP_FOLDER) folder"
	@rm -r $(TEMP_FOLDER)

# Suppression de toutes les productions
mrproper: clean
	@echo "Removing $(BUILD_FOLDER) folder"
	@rm -r $(BUILD_FOLDER)

