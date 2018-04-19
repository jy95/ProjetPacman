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
   % Pour gérer les respawns
   RespawnChecker
   % Pour récupérer 
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

   % Procédure qui va vérifier les différents timers 
   % CurrentState ; voir spec dans LaunchTurn
   % NewState : le nouveau state
   % IsFinished : boolean qui permet de savoir si le jeu est fini (utile dans la proc qui l'appelle)
   proc{RespawnChecker CurrentState NewState IsFinished}
        % fonction qui return un boolean pour savoir s'il faut faire quelque chose
        fun{CheckTimer TurnNumber ConstraintTime TimeStart}
            if Input.isTurnByTurn then
                (TurnNumber mod ConstraintTime) == 0
            else
                % Time.time return a number of seconds
                % Return true if number of seconds to wait to have a new spawn is ok
                ({Time.time} - TimeStart) >= ConstraintTime
            end
        end
        % les variables common used pour le check des timers
        TurnNumber = CurrentState.turnNumber
        PortGUI  = CurrentState.portGUI
        CurrentTime = CurrentState.currentTime
        BonusTime = CurrentState.bonusTime
        PointsOff = CurrentState.pointsOff
        BonusOff = CurrentState.bonusOff
        % la liste de tous les joueurs
        Pacmans = CurrentState.pacmans
        Ghosts = CurrentState.ghosts
        % les morts connus
        Deaths = CurrentState.deaths
        % Nouvelles valeurs : pour gérer le changement d'état
        NewPointsOff
        NewBonusOff
        NewDeadPacmans
        NewDeadGhosts
        NewMode 
   in
        % 0. Est ce qu'il y a encore un pacman en vie
        if nbPacmans == 0 then
            IsFinished = true
            NewState = CurrentState
        else
            % 1. vérification : les 4 RespawnTime
            % 1.1 les points
            if {CheckTimer TurnNumber Input.respawnTimePoint CurrentTime} then
                {WarningFunctions.spawnAllPoints PortGUI PointsOff Pacmans}
                % Plus de points déjà utilisés
                NewPointsOff = nil
            else
                NewPointsOff = PointsOff
            end
        
            % 1.2 les bonus
            if {CheckTimer TurnNumber Input.respawnTimeBonus CurrentTime} then
                {WarningFunctions.spawnAllBonus PortGUI BonusOff Pacmans}
                NewBonusOff = nil
            else
                NewBonusOff = BonusOff
            end
        
            % 1.3 les pacmans
            if {CheckTimer TurnNumber Input.respawnTimePacman CurrentTime} then
                % Warning la variable dpot reprendre que les pacmans morts avec life >= +1
                {WarningFunctions.spawnAllPacmans PortGUI Deaths.pacmans Ghosts}
                NewDeadPacmans = nil
            else
                NewDeadPacmans = Deaths.pacmans
            end

            % 1.4 les ghosts
            if {CheckTimer TurnNumber Input.respawnTimeGhost CurrentTime} then
                % TODO une variable qui ne reprendre que les ghosts morts
                {WarningFunctions.spawnAllGhosts PortGUI Deaths.ghosts Pacmans}
                NewDeadGhosts = nil
            else
                NewDeadGhosts = Deaths.ghosts
            end

            % 2. vérification : le huntTime (si le mode était hunt)
            if CurrentState.mode == hunt then
                % TODO prolongement du bonus si un pacman en reprend un durant cette période
                if {CheckTimer TurnNumber Input.huntTime BonusTime} then
                    % TODO le setMode qui prévient tout le monde du changement de mode
                    NewMode = classic
                else
                    NewMode = CurrentState.mode
                end
            else
                NewMode = CurrentState.mode
            end

            % le nouvel état
            IsFinished = false
            NewState = {Record.adjoinList CurrentState [
                mode#NewMode
                deaths#deaths(ghosts: NewDeadGhosts pacmans: NewDeadPacmans)
                bonusOff#NewBonusOff
                pointsOff#NewPointsOff
            ]}
        end

   end

   % Gere le tour par tour
   % Turn la liste infinie des joueurs
   % CurrentState : record qui stocke diverses informations du jeu
    % portGUI : le port sur lequel on envoit les infos destinés au GUI
    % currentTime : l'heure actuelle (utile seulement pour le jeu en simultané; _ sinon)
    % bonusTime : l'heure du dernier bonus attrapé , pour gérer le "reset the timing" si on est dans la bonne période.
    % turnNumber le numéro du tour (utile seulement pour le jeu turnbyturn ; _ sinon)
    % mode : the current mode
    % pacmans : tous les pacmans du jeu
    % ghosts : tous les ghosts du jeu
    % nbPacmans : le nombre de pacmans encore en vie 
    % bestPlayer: un <pacman>
    % bestScore: le meilleur score de ce pacman , pour comparer par la suite
    % currentPositions : un record avec pour clé les positions occupées (traduit par la fct PositionToInt) les joueurs présents par exemple l( 25: player(id: pacman<> , port: Z)||... ) )
    % lastPositions : une liste qui contient la dernière position de chaque joueur (par exemple pt(y: 1 x:5)#player(id: <pacman> port: p)|... ) 
    % deaths : record qui contient sous les clés suivants "pacmans" et "ghosts" une liste des joueurs tombés au champ de bataille sous le bon mapping
    % pointsOff : liste des position sur lequel un point a déjà été récupéré . par exemple pt(y: 2 x:7)|...
    % bonusOff :  liste des position sur lequel un bonus a déjà été récupéré . par exemple pt(y: 2 x:7)|...
   proc{LaunchTurn Turn CurrentState}
        % le state updaté après le check des timers / bonus mode
        TempState
        % le state updaté après le move d'un joueur
        StateAfterMove
        % le state updaté (uniquement pour gérer la contrainte du turnByTurn)
        FinalState
        % savoir si cela vaut la peine de refaire un tour de boucle
        IsFinished
        % le tour courant
        CurrentTurnNumber = CurrentState.turnNumber
        % TODO à voir s'elle peut aussi être utiliser dans le mode concurrent ; pour l'instant je la laisse ici
        proc{HandleMove CurrentPlayer Position TempState StateAfterMove}
            % le player qu'on traite actuellement
            UserId = CurrentPlayer.id
            UserPort = CurrentPlayer.port
            % les variables utiles dans le traittement - TODO
            % les nouvelles variables pour updater les changements de state - TODO
        in
            % selon le mode
                % les pacmans/ghosts se font violemment tués par un ghost/pacman
                % Seul un ghost/pacman peut s'approprier le résultat de ce kill
            % Si un joueur crève
                % Si c'est un ghost (cas simple), 
                    % on avertit les pacmans/GUI + un message gotKilled à la victime
                    % on l'ajoute à la liste des victimes
                % Si c'est un pacman (cas complexe) ;
                    % On prévient les ghost/GUI de sa disparition + un message killPacman au tueur et gotKilled à la victime
                    % S'il lui reste de la vie >0 , on l'ajoute à la liste des victime (pour éviter sa résurrection)
            % Cas simple : l'obtention d'un point par un pacman
                % Si point toujours disponible , le pacman gagne ce point et le point disparait du GUI
                % Tous les pacmans recoivent les messages pointRemoved
            % Cas simple : l'obtention d'un bonus par un pacman
                % Si bonus toujours disponible, le bonusTime est updaté au temps courant
                    % Si le mode n'était pas déjà en hunt, tout le monde recoit un message setMode
                    % Les pacmans sont notifiés de sa disparition  
            skip
        end
   in
        % On récupère le nouvel état - les respawn et la fin du mode hunt d'un pacman
        {RespawnChecker CurrentState TempState IsFinished}

        if IsFinished == true then
            % TODO trouver le best pacman en les interrogant tous avec addPoint (avec un Add de 0)
            {Send TempState.portGUI displayWinner(TempState.bestPlayer)}
        else

            % 3. Prendre le premier joueur de la liste
            case Turn
                of CurrentPlayer|T then Position in
                    
                    % envoi d'un message move ; ici grâce au CurrentPlayer on a déjà l'ID
                    {Send CurrentPlayer.port move(_ Position)}

                    %{Browser.browse "Player : "#CurrentPlayer.id#" wants to move to "#Position}

                    % Sous traitter la gestion des mouvement dans une autre proc
                    {HandleMove CurrentPlayer Position TempState StateAfterMove}

                    % Un ieme update de state specifique au turnByTurn : le turnNumber augmente 
                    % et le currentTime est resetté à l'heure courante
                    {Record.adjoinList StateAfterMove [
                        turnNumber#CurrentTurnNumber+1
                        currentTime#{Time.time}
                    ] FinalState} 

                    % Appel récursif avec les nouvelles variables
                    {LaunchTurn T FinalState}
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

   % Spawn all players
   % Peut etre un thread dedans pour les lancer en même temps , pour aussi générer le mode simultané
   % proc{SpawnAllPlayers PortGUI Players}

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
   in
        % Récupeer dans deux listes les deux types de players - utile pour d'autres méthodes
        {List.partition Players IsAPacman Pacmans Ghosts}
        
        % Init le jeu
        {InitGame PortGUI data(players: Players ghostSpawn: GhostSpawn pacmanSpawn: PacmanSpawn
                                pointsSpawn: PointsSpawn bonusSpawn: BonusSpawn
                                ghosts: Ghosts pacmans: Pacmans) DefaultPositions}

        % Lancement du tour par tour
        {LaunchTurn Turn currentState(
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
            deaths: deaths(ghosts: nil pacmans: nil)
            % les points/bonus déjà consommés (une liste)
            pointsOff: nil
            bonusOff: nil
            % Les points bonus déjà sur la map (sous forme d'une liste)
            bonusSpawn: BonusSpawn
            pointsSpawn: PointsSpawn
        )}
 
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
