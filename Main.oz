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
   % custom functions
   PositionExtractor
   FilterTile
   AssignSpawn
   IsAPacman
   InitAllPointsAndBonus
   GeneratePlayers
   SpawnAllPlayers
   SpawnAllPoints
   SpawnAllBonus
   % SpawnAllGhosts % TODO à faire
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
                {Send PortGUI spawnPoint(P)}
                % Prévenir les pacmans de ce nouveau point
                {List.forAll Pacmans {Warn PortGUI P} }
                {SpawnAllPoints PortGUI T Pacmans}
        end
   end

   % Spawn all the bonus on GUI and warn all the pacmans
   proc{SpawnAllBonus PortGUI BonusSpawn Pacmans}
        % Procédure interne pour gérer la portée lexical
        fun{Warn Gui Point}
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
                {List.forAll Pacmans {Warn PortGUI B} }
                {SpawnAllBonus PortGUI T Pacmans}
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

        % Leur assigner un spawn d'origine
        {AssignSpawn Players GhostSpawn PacmanSpawn}
        
        % Init les points sur la GUI
        {InitAllPointsAndBonus PortGUI PointsSpawn BonusSpawn}

        % Faire apparaitre les points/bonus et en prévenir les pacmans
        {SpawnAllPoints PortGUI PointsSpawn Pacmans}
        {SpawnAllBonus PortGUI BonusSpawn Pacmans}

        % Faire apparaitre les joueurs
        % A finir car il faut prévenir les autres joueurs
        % {SpawnAllPlayers PortGUI Players}

        % Début du jeu

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
