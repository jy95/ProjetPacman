# Mozart
OZ=ozc
OZENGINE=ozengine

# Plateform dependent commands
COPY=cp # sur Windows , remplacer par copy
REMOVE=rm # sur Windows , remplacer par del

# fichiers
FILES=Input CommonUtils WarningFunctions StateWatcher Ghost055other Pacman055superSmart Pacman055superShy Pacman055other PlayerManager GUI Main
SOURCES=$(FILES:=.oz)
OBJECTS=$(FILES:=.ozf)
PICTURES_FOLDER=pics
COMPILED_FOLDER=bin
OTHER_PLAYERS_FOLDER=otherGroups
COMPILED_FILES=$(addprefix $(COMPILED_FOLDER)/,$(FILES:=.ozf))
MAIN_FILE=$(addprefix $(COMPILED_FOLDER)/,Main.ozf)

# TODO ; faire la receipe de base (cad sans faire 'make all' mais make) ; à voir selon enoncé

# main task
all: bin pics copyPlayers $(OBJECTS)

# copy our pictures to destination
pics: bin	
	cp -r $(PICTURES_FOLDER) $(COMPILED_FOLDER)

# the temp folder to store all the files - useful to have a clean folder with everything compiled
bin:	
	mkdir -p $(COMPILED_FOLDER)

# besoin des joueurs random pour l'instant ; par la suite remplacer par joueurs des autres
copyPlayers: bin
	$(COPY) Ghost000random.ozf $(addprefix $(COMPILED_FOLDER)/,Ghost000random.ozf)
	$(COPY) Pacman000random.ozf $(addprefix $(COMPILED_FOLDER)/,Pacman000random.ozf)
	cp -r $(addprefix $(OTHER_PLAYERS_FOLDER)/,.) $(COMPILED_FOLDER)

# Compile tous les fichiers et stocker dans bin
$(OBJECTS):	$(SOURCES)
	$(OZ) -c $(patsubst %.ozf,%.oz,$@) -o $(addprefix $(COMPILED_FOLDER)/,$@)

.PHONY : clean
# sans doute un rmdir serait plus simple mais windows n'en a pas un simple ^^
clean :
	$(REMOVE) -r $(COMPILED_FOLDER)