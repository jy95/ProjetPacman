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
   GeneratePlayers
in
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
                {Append {ExtractRow H CurrentRow 0} {PositionExtractor T CurrentRow+1}}
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
   fun{GeneratePlayers GUI NbPacmans NbGhosts PacmanList GhostList ColorPacman ColorGhost Result} 
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
            {Send GUI initGhost(GhostPlayer)}
            Player = player(id: GhostPlayer port: {PlayerManager.playerGenerator GhostList.1 GhostPlayer})
            {GeneratePlayers GUI NbPacmans NbGhosts-1 PacmanList GhostList.2 ColorPacman ColorGhost.2 Player|Result}
        elseif NbGhosts == 0 andthen NbPacmans > 0 then PacmanPlayer in
            % No more ghost but still pacmans left
            PacmanPlayer = pacman(id:IdPacman color:ColorPacman.1 name:PacmanList.1)
            {Send GUI initPacman(PacmanPlayer)}
            Player = player(id: PacmanPlayer port: {PlayerManager.playerGenerator PacmanList.1 PacmanPlayer})
            {GeneratePlayers GUI NbPacmans-1 NbGhosts PacmanList.2 GhostList ColorPacman.2 ColorGhost Player|Result}
        else
            % Pick up whatever kind of player randonly
            RandomNumber = {CommonUtils.randomNumber 0 NbPacmans+NbGhosts}
            if RandomNumber < NbPacmans then PacmanPlayer in
                % It should be a pacman
                PacmanPlayer = pacman(id:IdPacman color:ColorPacman.1 name:PacmanList.1)
                {Send GUI initPacman(PacmanPlayer)}
                Player = player(id: PacmanPlayer port: {PlayerManager.playerGenerator PacmanList.1 PacmanPlayer})
                {GeneratePlayers GUI NbPacmans-1 NbGhosts PacmanList.2 GhostList ColorPacman.2 ColorGhost Player|Result}
            else GhostPlayer in
                % It should be a ghost
                GhostPlayer = ghost(id:IdGhost color:ColorGhost.1 name:GhostList.1)
                {Send GUI initGhost(GhostPlayer)}
                Player = player(id: GhostPlayer port: {PlayerManager.playerGenerator GhostList.1 GhostPlayer})
                {GeneratePlayers GUI NbPacmans NbGhosts-1 PacmanList GhostList.2 ColorPacman ColorGhost.2 Player|Result}
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

   % Game general behaviour - TurnByTurn
   proc{TurnByTurn PortGUI}
        % les pacmans et ghost mélangés selon un ordre random
        Players = {GeneratePlayers PortGUI Input.nbPacman Input.nbGhost Input.pacman Input.ghost Input.colorPacman Input.colorGhost nil}
        % les lieux de spawn : ghost / pacman / bonus / points
        ExplorerMap = thread {PositionExtractor Input.map 0} end
        GhostSpawn = {FilterTile ExplorerMap fun{$ E} E == 3 end }
        PacmanSpawn = {FilterTile ExplorerMap fun{$ E} E == 2 end }
        BonusSpawn = {FilterTile ExplorerMap fun{$ E} E == 4 end }
        PointsSpawn = {FilterTile ExplorerMap fun{$ E} E == 0 end }
   in
        % Leur assigner un spawn d'origine
        {AssignSpawn Players GhostSpawn PacmanSpawn}

        % Init the GUI

        % TODO le reste , d'abord corriger les niemes corrections d'énoncé XD
   end
   % TODO add additionnal function

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
