functor
import
   GUI
   Input
   PlayerManager
   Browser
   % Nos fonctions utilitaires
   CommonUtils
   % Nos fonctions de warning
   WarningFunctions
   % Notre treatStream pour gérer l'état du jeu
   StateWatcher
define
   WindowPort
   TurnByTurn
   PositionExtractor
   FilterTile
   IsAPacman
   GeneratePlayers
   ForAllProc
   InitGame
   LaunchTurn
in
   % Detect 
   fun{IsAPacman X}
    case X
        of player(id:pacman(id:_ color:_ name:_) port: _) then
            true
        else
            false
    end
   end

   % List.forAll en concurrence
   proc{ForAllProc List Proc}
    case List
        of nil then skip
        [] H|T then
            thread {Proc H} end
            {ForAllProc T Proc}
    end
   end

   % Explorer each tile of the map to extract information - maybe in the stream way later
   fun{PositionExtractor Map CurrentRow}
        fun{ExtractRow List Row Column}
            case List
                of nil then nil
                [] H|T then H#pt(x: Column y: Row)|{ExtractRow T Row Column+1}
            end
        end
        fun {Append Xs Ys}
            case Xs of nil then Ys
            [] X|Xr then X|{Append Xr Ys}
            end
        end
   in
        case Map
            of nil then nil
            [] H|T then
                {Append {ExtractRow H CurrentRow 1} {PositionExtractor T CurrentRow+1}}
        end 
   end

   % Filtering tile
   fun{FilterTile S F}
        case S
            of nil then nil
            [] H|T then
                case H
                    of Val#Position then
                        if thread {F Val} end then
                            Position|{FilterTile T F}
                        else
                            {FilterTile T F}
                        end
                    else
                        % no match
                        {FilterTile T F}
                end
        end
   end

   % Gere le tour par tour
   % Turn la liste infinie des joueurs
   % StateWatcherPort : notre agent chargé d'accomplir les taches du Main
   proc{LaunchTurn Turn StateWatcherPort}
        % savoir si cela vaut la peine de refaire un tour de boucle
        IsFinished
   in
        % On checke les respawn et la fin du mode hunt 
        {Send StateWatcherPort checkTimers(IsFinished)}

        if IsFinished == true then
            {Send StateWatcherPort displayWinner}
        else
            % 3. Prendre le premier joueur de la liste
            case Turn
                of CurrentPlayer|T then Position in
                    
                    % Pour débug ; delai de 5s
                    {Delay 5000}

                    % envoi d'un message move ; ici grâce au CurrentPlayer on a déjà l'ID
                    {Send CurrentPlayer.port move(_ Position)}

                    % Puisque nous sommes en turnByTurn ; on doit attendre la réponse du joueur
                    if Position \= null then
                        % Sous traitter la gestion des mouvement dans StateWatcher
                        {Send StateWatcherPort move(CurrentPlayer Position)}
                    end

                    % le turnNumber augmente et le currentTime est resetté à l'heure courante
                    {Send StateWatcherPort increaseTurn}

                    % Appel récursif avec les nouvelles variables
                    {LaunchTurn T StateWatcherPort}
            else
                % Jamais le cas en théorie puisque c'est une liste récursive
                skip
            end

        end

   end
   
   % Initialiaze all the player(s) found in Input.oz
   % Also initGhost/initPacman the generated players to GUI
   fun{GeneratePlayers PortGUI NbPacmans NbGhosts PacmanList GhostList ColorPacman ColorGhost Result} 
        RandomNumber
        Player
        IdGhost = Input.nbGhost-NbGhosts+1
        IdPacman = Input.nbPacman-NbPacmans+1
    in
        if PacmanList == nil andthen GhostList == nil then
            % Nothing left : return the result
            Result
        elseif NbPacmans == 0 andthen NbGhosts > 0 then GhostPlayer in
            % No more pacmans but still ghosts left
            GhostPlayer = ghost(id:IdGhost color:ColorGhost.1 name:GhostList.1)
            {Send PortGUI initGhost(GhostPlayer)}
            Player = player(id: GhostPlayer port: {PlayerManager.playerGenerator GhostList.1 GhostPlayer})
            {GeneratePlayers PortGUI NbPacmans NbGhosts-1 PacmanList GhostList.2 ColorPacman ColorGhost.2 Player|Result}
        elseif NbGhosts == 0 andthen NbPacmans > 0 then PacmanPlayer in
            % No more ghost but still pacmans left
            PacmanPlayer = pacman(id:IdPacman color:ColorPacman.1 name:PacmanList.1)
            {Send PortGUI initPacman(PacmanPlayer)}
            Player = player(id: PacmanPlayer port: {PlayerManager.playerGenerator PacmanList.1 PacmanPlayer})
            {GeneratePlayers PortGUI NbPacmans-1 NbGhosts PacmanList.2 GhostList ColorPacman.2 ColorGhost Player|Result}
        else
            % Pick up whatever kind of player randonly
            RandomNumber = {CommonUtils.randomNumber 0 NbPacmans+NbGhosts}
            if RandomNumber < NbPacmans then PacmanPlayer in
                % It should be a pacman
                PacmanPlayer = pacman(id:IdPacman color:ColorPacman.1 name:PacmanList.1)
                {Send PortGUI initPacman(PacmanPlayer)}
                Player = player(id: PacmanPlayer port: {PlayerManager.playerGenerator PacmanList.1 PacmanPlayer})
                {GeneratePlayers PortGUI NbPacmans-1 NbGhosts PacmanList.2 GhostList ColorPacman.2 ColorGhost Player|Result}
            else GhostPlayer in
                % It should be a ghost
                GhostPlayer = ghost(id:IdGhost color:ColorGhost.1 name:GhostList.1)
                {Send PortGUI initGhost(GhostPlayer)}
                Player = player(id: GhostPlayer port: {PlayerManager.playerGenerator GhostList.1 GhostPlayer})
                {GeneratePlayers PortGUI NbPacmans NbGhosts-1 PacmanList GhostList.2 ColorPacman ColorGhost.2 Player|Result}
            end
        end
    end
   
   % Init Game (+ GUI)
   % Result : un record qui va sauvergarder les positions d'origine
   proc{InitGame PortGUI Data DefaultPositions}
        % Au final, dans DefaultPositions on aura un les clés suivantes dans le record :
        % spawnPositions = un record qui va stocker sous 2 clés (pacmans et ghosts) les lieux de spawn des joueurs : 
        % Position#player(id: <pacman/ghost> port: P) 
        % currentPositions : une liste qui contient la dernière position de chaque joueur 
        % (par exemple pt(y: 1 x:5)#player(id: <pacman> port: p)|... )
        % Current ; accumulateur pour stocker le résultat intermédiaire; ResultRecord pour la réponse
        proc{RetrieveSpawnPosition Players GhostSpawn PacmanSpawn Current ResultRecord}
            SpawnPositions = Current.spawnPositions
            CurrentPositions = Current.currentPositions
            SpawnPositionsPacmans = SpawnPositions.pacmans
            SpawnPositionsGhosts = SpawnPositions.ghosts
            NewCurrent
            PositionsList
        in
            case Players
                of nil then ResultRecord = Current
            else
                if {IsAPacman Players.1} then NewPacman SpawnPacmanList in
                    % Ajouter cette position de ce pacman dans LastPositions , sous la forme Position#player(..)
                    NewPacman = PacmanSpawn.1#Players.1
                    SpawnPacmanList = NewPacman|SpawnPositionsPacmans
                    PositionsList = NewPacman|CurrentPositions
                    % Pour updater
                    {Record.adjoinList Current [
                        currentPositions#PositionsList
                        spawnPositions#positions(ghosts: SpawnPositionsGhosts pacmans: SpawnPacmanList) 
                    ] NewCurrent}
                    % Appel récursif
                    {RetrieveSpawnPosition Players.2 GhostSpawn PacmanSpawn.2 NewCurrent ResultRecord}
                else SpawnGhostList NewGhost in
                    % Ajouter cette position de ce ghost dans LastPositions
                    NewGhost = GhostSpawn.1#Players.1
                    SpawnGhostList = NewGhost|SpawnPositionsGhosts
                    PositionsList = NewGhost|CurrentPositions
                    % Pour updater
                    {Record.adjoinList Current [
                        currentPositions#PositionsList
                        spawnPositions#positions(ghosts: SpawnGhostList pacmans: SpawnPositionsPacmans) 
                    ] NewCurrent}
                    % Appel récursif
                    {RetrieveSpawnPosition Players.2 GhostSpawn.2 PacmanSpawn NewCurrent ResultRecord}
                end
            end
        end
    in
        case Data
            of data(players: Players 
                    ghostSpawn: GhostSpawn
                    pacmanSpawn: PacmanSpawn
                    pointsSpawn: PointsSpawn
                    bonusSpawn: BonusSpawn
                    ghosts: Ghosts
                    pacmans: Pacmans) then
                
                thread
                % Leur assigner un spawn d'origine
                {WarningFunctions.assignSpawn Players GhostSpawn PacmanSpawn}

                % Récupérer les positions assignées de base
                {RetrieveSpawnPosition Players GhostSpawn PacmanSpawn 
                positions(currentPositions: nil spawnPositions: positions(pacmans: nil ghosts: nil) ) DefaultPositions} 

                % Init les points sur la GUI
                {WarningFunctions.initAllPointsAndBonus PortGUI PointsSpawn BonusSpawn}

                % Faire apparaitre les points/bonus et en prévenir les pacmans
                {WarningFunctions.spawnAllPoints PortGUI PointsSpawn Pacmans}
                {WarningFunctions.spawnAllBonus PortGUI BonusSpawn Pacmans}

                % Faire apparaitre les joueurs
                % Spawn ghosts et pacman ne font que prévenir la GUI et les membres de l'autre type leur présence
                {WarningFunctions.spawnAllGhosts PortGUI Ghosts Pacmans}
                {WarningFunctions.spawnAllPacmans PortGUI Pacmans Ghosts}

                end
        else
            skip
        end
   end

   % Game general behaviour - TurnByTurn
   proc{TurnByTurn PortGUI}
        % les pacmans et ghost mélangés selon un ordre random - une liste récursive pour gérer les tours
        Turn = {GeneratePlayers PortGUI Input.nbPacman Input.nbGhost Input.pacman Input.ghost Input.colorPacman Input.colorGhost Turn}
        % La liste simple des players : sans récursivité
        Players = {List.take Turn Input.nbPacman+Input.nbGhost}
        % La liste simple des deux types de players
        Ghosts
        Pacmans
        % les lieux de spawn : ghost / pacman / bonus / points
        ExplorerMap = thread {PositionExtractor Input.map 1} end
        GhostSpawn = {FilterTile ExplorerMap fun{$ E} E == 3 end }
        PacmanSpawn = {FilterTile ExplorerMap fun{$ E} E == 2 end }
        BonusSpawn = {FilterTile ExplorerMap fun{$ E} E == 4 end }
        PointsSpawn = {FilterTile ExplorerMap fun{$ E} E == 0 end }
        % Default positions : les lieux de spawn + les positions courantes
        DefaultPositions
        % Port for state handler
        WatcherPort
   in
        % Récupeer dans deux listes les deux types de players - utile pour d'autres méthodes
        {List.partition Players IsAPacman Pacmans Ghosts}
        
        % Init le jeu
        {InitGame PortGUI data(players: Players ghostSpawn: GhostSpawn pacmanSpawn: PacmanSpawn
                                pointsSpawn: PointsSpawn bonusSpawn: BonusSpawn
                                ghosts: Ghosts pacmans: Pacmans) DefaultPositions}
        
        % Create port for state agent
        % et on le sette à l'état de base
        WatcherPort = {StateWatcher.portWindow currentState(
            % les variables pour gérer les tours
            portGUI: PortGUI
            currentTime: {Time.time}
            bonusTime: _
            turnNumber: 1
            mode: classic
            % Tous les pacmans et ghosts du jeu
            pacmans: Pacmans
            ghosts: Ghosts
            nbPacmans: Input.nbPacman
            % les lieux de spawn et les positions courantes
            spawnPositions: DefaultPositions.spawnPositions
            currentPositions: DefaultPositions.currentPositions
            % Stockage des morts respectifs
            deaths: deaths(ghosts: nil pacmans: nil) % Pour gérer les morts habituels dans le jeux
            pacmansWithNoLife: nil % pour exclure définitivement un pacman de jouer un prochain move
            % les points/bonus déjà consommés (une liste)
            pointsOff: nil
            bonusOff: nil
            % Les points bonus déjà sur la map (sous forme d'une liste)
            bonusSpawn: BonusSpawn
            pointsSpawn: PointsSpawn
        )}

        % Lancement du tour par tour
        {LaunchTurn Turn WatcherPort}
 
   end

   thread
      % Create port for window
      WindowPort = {GUI.portWindow}
      
      % Open window
      {Send WindowPort buildWindow}

      if Input.isTurnByTurn then
        {TurnByTurn WindowPort}
      else
        {Browser.browse 'TODO'}
      end
      
   end

end
