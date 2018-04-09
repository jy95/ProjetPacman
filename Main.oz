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
in
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
        Players = {GenerateOrder Input.nbPacman Input.nbGhost Input.pacman Input.ghost nil}
   in
        % Determine order for ghost/pacman(s)
        {Browser.browse 'test'#Players}
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
