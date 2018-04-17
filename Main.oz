functor
import
   GUI
   Input
   PlayerManager
   Browser
   CommonUtils
define
   WindowPort
   TurnByTurn
   PositionExtractor
   FilterTile
   AssignSpawn
   IsAPacman
   InitAllPointsAndBonus
   GeneratePlayers
   SpawnAllPoints
   SpawnAllBonus
   SpawnAllGhosts
   SpawnAllPacmans
   ForAllProc
   InitGame
   LaunchTurn
   HandlePlayerTurn % TODO
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

   proc{HandlePlayerTurn CurrentPlayer TempState Deaths NewPointsOff NewBonusOff UpdatedState UpdatedDeaths  
   UpdatedPointsOff UpdatedBonusOff}
        % TODO
        skip
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
   % Deaths : record qui contient sous les clés suivants "pacmans" et "ghosts" une liste des joueurs tombés au champ de bataille sous le bon mapping
   % PointsOff : liste des position sur lequel un point a déjà été récupéré . par exemple pt(y: 2 x:7)|...
   % BonusOff :  liste des position sur lequel un bonus a déjà été récupéré . par exemple pt(y: 2 x:7)|...
   proc{LaunchTurn Turn CurrentState Deaths PointsOff BonusOff}
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
        % les variables common used ici
        % Pour le check de timer
        TurnNumber = CurrentState.turnNumber
        PortGUI  = CurrentState.portGUI
        CurrentTime = CurrentState.currentTime
        BonusTime = CurrentState.bonusTime
        % la liste de tous les joueurs
        Pacmans = CurrentState.pacmans
        Ghosts = CurrentState.ghosts
        % Nouvelles valeurs avant de demander au joueur courant de move
        NewPointsOff
        NewBonusOff
        NewDeadPacmans
        NewDeadGhosts
        NewMode
   in
        % 0. Est ce qu'il y a encore un pacman en vie
        if nbPacmans == 0 then
            {Send PortGUI displayWinner(CurrentState.bestPlayer)}
        else

            % 1. vérification : les 4 RespawnTime
            % 1.1 les points
            if {CheckTimer TurnNumber Input.respawnTimePoint CurrentTime} then
                {SpawnAllPoints PortGUI PointsOff Pacmans}
                % Plus de points déjà utilisés
                NewPointsOff = nil
            else
                NewPointsOff = PointsOff
            end
        
            % 1.2 les bonus
            if {CheckTimer TurnNumber Input.respawnTimeBonus CurrentTime} then
                {SpawnAllBonus PortGUI BonusOff Pacmans}
                NewBonusOff = nil
            else
                NewBonusOff = BonusOff
            end
        
            % 1.3 les pacmans
            if {CheckTimer TurnNumber Input.respawnTimePacman CurrentTime} then
                % TODO une variable qui ne reprendre que les pacmans morts avec life >= +1
                {SpawnAllPacmans PortGUI Deaths.pacmans Ghosts}
                NewDeadPacmans = nil
            else
                NewDeadPacmans = Deaths.pacmans
            end

            % 1.4 les ghosts
            if {CheckTimer TurnNumber Input.respawnTimeGhost CurrentTime} then
                % TODO une variable qui ne reprendre que les ghosts morts
                {SpawnAllGhosts PortGUI Deaths.ghosts Pacmans}
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

            % 3. Prendre le premier joueur de la liste
            case Turn
                of CurrentPlayer|T then TempState UpdatedState UpdatedDeaths UpdatedPointsOff UpdatedBonusOff in
                    % Enregistrer dans un record temporaire les eventuels updates
                    {Record.adjoinAt CurrentState mode NewMode TempState}

                    % Sous traitter la gestion des mouvement dans une autre proc
                    {HandlePlayerTurn   CurrentPlayer TempState   deaths(pacmans: NewDeadPacmans ghosts: NewDeadGhosts)  
                                        NewPointsOff    NewBonusOff    UpdatedState UpdatedDeaths 
                                        UpdatedPointsOff UpdatedBonusOff}

                    % Appel récursif avec les nouvelles variables
                    {LaunchTurn T UpdatedState UpdatedDeaths UpdatedPointsOff UpdatedBonusOff}
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
   
   % assignSpawn for all players
   proc{AssignSpawn Players GhostSpawn PacmanSpawn}
        case Players
            of player(id:K port: P)|T then
                case K
                    of pacman(id:_ color:_ name:_) then
                        {Send P assignSpawn(PacmanSpawn.1)}
                        {AssignSpawn T GhostSpawn PacmanSpawn.2}
                else
                    {Send P assignSpawn(GhostSpawn.1)}
                    {AssignSpawn T GhostSpawn.2 PacmanSpawn}
                end
            [] nil then skip
        end
   end

   % Initialiaze the GUI
   % init all the points and bonus
   proc{InitAllPointsAndBonus PortGUI PointsSpawn BonusSpawn}
    case PointsSpawn
        of P|T then
            {Send PortGUI initPoint(P)}
            {InitAllPointsAndBonus PortGUI T BonusSpawn}
        [] nil then
            case BonusSpawn
                of B|L then
                    {Send PortGUI initBonus(B)}
                    {InitAllPointsAndBonus PortGUI PointsSpawn L}
                [] nil then skip
            end
    end
   end
   
   % Spawn all the points on GUI and warn all the pacmans
   proc{SpawnAllPoints PortGUI PointsSpawn Pacmans}
        % Procédure interne pour gérer la portée lexical
        fun{Warn Gui Point}
            proc{$ X}
                case X
                    of player(id:pacman(id:_ color:_ name:_) port: Z) then
                        {Send Z pointSpawn(Point)}
                else
                    skip
                end
            end
        end
    in
        case PointsSpawn
            of nil then skip
            [] P|T then
                % Prevenir le GUI de ce nouveau point
                {Send PortGUI spawnPoint(P)}
                % Prévenir les pacmans de ce nouveau point
                thread {ForAllProc Pacmans {Warn PortGUI P} } end
                {SpawnAllPoints PortGUI T Pacmans}
        end
   end
   proc{SpawnAllGhosts PortGUI Ghosts Pacmans}
        % Procédure interne pour gérer la portée lexical
        fun{Warn ID Position}
            proc{$ X}
                case X
                    of player(id:pacman(id:_ color:_ name:_) port: Z) then
                       {Send Z ghostPos(ID Position)}
                else
                    skip
                end
            end
        end  
    in
        case Ghosts
            of nil then skip
            [] player(id:ID port: G)|T then Position in
                % obliger le fantome à spawn et à récupérer sa position
                {Send G spawn(_ Position)}

                % avertir le GUI de sa présence
                {Send PortGUI spawnGhost(ID Position)}

                % prévenir tous les pacmans de sa présence
                thread {ForAllProc Pacmans {Warn ID Position}} end

                % les suivants
                {SpawnAllGhosts PortGUI T Pacmans}
        end
   end

   proc{SpawnAllPacmans PortGUI Pacmans Ghosts}
        % Procédure interne pour gérer la portée lexical
        fun{Warn ID Position}
            proc{$ X}
                case X
                    of player(id:ghost(id:_ color:_ name:_) port: Z) then
                       {Send Z pacmanPos(ID Position)}
                else
                    skip
                end
            end
        end  
    in
        case Pacmans
            of nil then skip
            [] player(id:ID port: P)|T then Position in
                % obliger le pacman à spawn et à récupérer sa position
                {Send P spawn(_ Position)}

                % avertir le GUI de sa présence
                {Send PortGUI spawnPacman(ID Position)}
                % prévenir tous les pacmans de sa présence
                thread {ForAllProc Ghosts {Warn ID Position}} end

                % les suivants
                {SpawnAllPacmans PortGUI T Ghosts}
        end
   end

   % Spawn all the bonus on GUI and warn all the pacmans
   proc{SpawnAllBonus PortGUI BonusSpawn Pacmans}
        % Procédure interne pour gérer la portée lexical
        fun{Warn Point}
            proc{$ X}
                case X
                    of player(id:pacman(id:_ color:_ name:_) port: Z) then
                        {Send Z bonusSpawn(Point)}
                else
                    skip
                end
            end
        end
    in
        case BonusSpawn
            of nil then skip
            [] B|T then
                {Send PortGUI spawnPoint(B)}
                % Prévenir les pacmans de ce nouveau point
                thread {ForAllProc Pacmans {Warn B} } end
                {SpawnAllBonus PortGUI T Pacmans}
        end
   end
   
   % Init Game (+ GUI)
   proc{InitGame PortGUI Data}
        
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
                {AssignSpawn Players GhostSpawn PacmanSpawn}

                % Init les points sur la GUI
                {InitAllPointsAndBonus PortGUI PointsSpawn BonusSpawn}

                % Faire apparaitre les points/bonus et en prévenir les pacmans
                {SpawnAllPoints PortGUI PointsSpawn Pacmans}
                {SpawnAllBonus PortGUI BonusSpawn Pacmans}

                % Faire apparaitre les joueurs
                % Spawn ghosts et pacman ne font que prévenir la GUI et les membres de l'autre type leur présence
                {SpawnAllGhosts PortGUI Ghosts Pacmans}
                {SpawnAllPacmans PortGUI Pacmans Ghosts}

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
   in
        % Récupeer dans deux listes les deux types de players - utile pour d'autres méthodes
        {List.partition Players IsAPacman Pacmans Ghosts}
        
        % Init le jeu
        {InitGame PortGUI data(players: Players ghostSpawn: GhostSpawn pacmanSpawn: PacmanSpawn
                                pointsSpawn: PointsSpawn bonusSpawn: BonusSpawn
                                ghosts: Ghosts pacmans: Pacmans)}

        % Lancement du tour par tour
        {LaunchTurn Turn currentState(
            portGUI: PortGUI
            currentTime: {Time.time}
            bonusTime: _
            turnNumber: 1
            mode: classic
            pacmans: Pacmans
            ghosts: Ghosts
            nbPacmans: Input.nbPacman
            bestPlayer: _
            bestScore: _
            currentPositions: occupedPositions()
            lastPositions: nil
        ) deaths(ghosts: nil pacmans: nil) nil nil}

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
