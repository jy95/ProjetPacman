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

   % Game general behaviour - TurnByTurn
   proc{TurnByTurn PortGUI}
        fun{GenerateOrder NbPacmans NbGhosts PacmanList GhostList Result}
            local 
                RandomNumber 
            in
                if PacmanList == nil andthen GhostList == nil then
                    % Nothing left : return the result
                    Result
                elseif NbPacmans == 0 andthen NbGhosts > 0 then GhostPlayer GhostId in
                    % No more pacmans but still ghosts left
                    GhostId = Input.nbGhost-NbGhosts+1
                    GhostPlayer = ghost(id: GhostId port: {PlayerManager.playerGenerator GhostList.1 GhostId})
                    {GenerateOrder NbPacmans NbGhosts-1 PacmanList GhostList.2 GhostPlayer|Result}
                elseif NbGhosts == 0 andthen NbPacmans > 0 then PacmanPlayer PacmanId in
                    % No more ghost but still pacmans left
                    PacmanId = Input.nbGhost-NbPacmans+1
                    PacmanPlayer = pacman(id: PacmanId port: {PlayerManager.playerGenerator PacmanList.1 PacmanId})
                    {GenerateOrder NbPacmans-1 NbGhosts PacmanList.2 GhostList PacmanPlayer|Result}
                else
                    % Pick up whatever kind of player randonly
                    RandomNumber = {CommonUtils.randomNumber 0 NbPacmans+NbGhosts}
                    if RandomNumber < NbPacmans then PacmanPlayer PacmanId in
                        % It should be a pacman
                        PacmanId = Input.nbGhost-NbPacmans+1
                        PacmanPlayer = pacman(id: PacmanId port: {PlayerManager.playerGenerator PacmanList.1 PacmanId})
                        {GenerateOrder NbPacmans-1 NbGhosts PacmanList.2 GhostList PacmanPlayer|Result}
                    else GhostPlayer GhostId in
                        % It should be a ghost
                        GhostId = Input.nbGhost-NbGhosts+1
                        GhostPlayer = ghost(id: GhostId port: {PlayerManager.playerGenerator GhostList.1 GhostId})
                        {GenerateOrder NbPacmans NbGhosts-1 PacmanList GhostList.2 GhostPlayer|Result}
                    end
                end
            end
        end
        % les pacmans et ghost mélangés selon un ordre random
        Players = {GenerateOrder Input.nbPacman Input.nbGhost Input.pacman Input.ghost nil}
        % les lieux de spawn : ghost / pacman / bonus / points
        ExplorerMap = thread {PositionExtractor Input.map 0} end
        GhostSpawn = {FilterTile ExplorerMap fun{$ E} E == 3 end }
        PacmanSpawn = {FilterTile ExplorerMap fun{$ E} E == 2 end }
        BonusSpawn = {FilterTile ExplorerMap fun{$ E} E == 4 end }
        PointsSpawn = {FilterTile ExplorerMap fun{$ E} E == 0 end }
   in
        % Determine order for ghost/pacman(s)
        {Browser.browse Players}
        {Browser.browse GhostSpawn}
        {Browser.browse PacmanSpawn}
        {Browser.browse BonusSpawn}
        {Browser.browse PointsSpawn}
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
