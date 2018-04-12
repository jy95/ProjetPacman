# Mozart
OZ=ozc
OZENGINE=ozengine

# Plateform dependent commands
COPY=cp # sur Windows , remplacer par copy
REMOVE=rm # sur Windows , remplacer par del

# fichiers
FILES=Input CommonUtils Ghost000other Pacman000other PlayerManager GUI Main
SOURCES=$(FILES:=.oz)
OBJECTS=$(FILES:=.ozf)
COMPILED_FOLDER=bin
COMPILED_FILES=$(COMPILED_FOLDER)/$(FILES:=.ozf)
MAIN_FILE=$(COMPILED_FOLDER)/Main.ozf

# other things

all: bin copyPlayers $(COMPILED_FILES)

bin: $(COMPILED_FOLDER)
	mkdir -p $(COMPILED_FOLDER)

# besoin des joueurs random pour l'instant ; par la suite remplacer par joueurs des autres
copyPlayers: bin
	$(COPY) Ghost000random.ozf $(COMPILED_FOLDER)/Ghost000random.ozf
	$(COPY) Ghost000random.ozf $(COMPILED_FOLDER)/Pacman000random.ozf

# Compile tous les fichiers et stocker dans bin
$(COMPILED_FILES): 	bin $(SOURCES)
	$(OZ) -c $@ -o $(BIN)/$@

.PHONY : clean
clean :
	$(REMOVE) $(COMPILED_FILES)