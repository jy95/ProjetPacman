functor
%import
export
    % Toutes nos fonctions du type SpawnAllPlayers ,etc qui préviennent la GUI et/ou les joueurs
   spawnAllPoints:SpawnAllPoints
   spawnAllBonus:SpawnAllBonus
   spawnAllGhosts:SpawnAllGhosts
   spawnAllPacmans:SpawnAllPacmans
   initAllPointsAndBonus:InitAllPointsAndBonus
   assignSpawn:AssignSpawn
   hidePoint: HidePoint
   hideBonus: HideBonus
   hideGhost: HideGhost
   hidePacman: HidePacman
   setMode: SetMode
   applyMove: ApplyMove
   displayWinner: DisplayWinner
   lifeUpdate: LifeUpdate
   scoreUpdate: ScoreUpdate
define
   SpawnAllPoints
   SpawnAllBonus
   SpawnAllGhosts
   SpawnAllPacmans
   InitAllPointsAndBonus
   ForAllProc
   AssignSpawn
   HidePoint
   HideBonus
   HideGhost
   HidePacman
   SetMode
   ApplyMove
   DisplayWinner
   LifeUpdate
   ScoreUpdate
in
    % List.forAll en concurrence
   proc{ForAllProc List Proc}
    case List
        of nil then skip
        [] H|T then
            thread {Proc H} end
            {ForAllProc T Proc}
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

   % Hide the point Point on GUI and warn all the pacmans
   proc{HidePoint PortGUI Point Pacmans}
        % Procédure interne pour gérer la portée lexical
        fun{Warn Gui P}
            proc{$ X}
                case X
                    of player(id:pacman(id:_ color:_ name:_) port: Z) then
                        {Send Z pointRemoved(P)}
                else
                    skip
                end
            end
        end
    in
        % Prevenir le GUI de ce point effacé
        {Send PortGUI hidePoint(Point)}
        % Prévenir les pacmans de ce point effacé
        thread {ForAllProc Pacmans {Warn PortGUI Point} } end  
   end

   % Hide the point Point on GUI and warn all the pacmans
   proc{HideBonus PortGUI Bonus Pacmans}
        % Procédure interne pour gérer la portée lexical
        fun{Warn Gui P}
            proc{$ X}
                case X
                    of player(id:pacman(id:_ color:_ name:_) port: Z) then
                        {Send Z bonusRemoved(P)}
                else
                    skip
                end
            end
        end
    in
        % Prevenir le GUI de ce point effacé
        {Send PortGUI hideBonus(Bonus)}
        % Prévenir les pacmans de ce point effacé
        thread {ForAllProc Pacmans {Warn PortGUI Bonus} } end    
   end

    %Hide the ghost Ghost on Gui and warn all the pacmans
    proc{HideGhost PortGUI Ghost Pacmans}
        % Procédure interne pour gérer la portée lexical
        fun{Warn ID}
            proc{$ X}
                case X
                    of player(id:pacman(id:_ color:_ name:_) port: Z) then
                       {Send Z deathGhost(ID)}
                else
                    skip
                end
            end
        end  
    in
        % avertir le GUI de sa disparition
        {Send PortGUI hideGhost(Ghost.id)}
        % prévenir tous les pacmans de sa disparition
        thread {ForAllProc Pacmans {Warn Ghost.id}} end
   end

   %Hide the pacMan pacMan on Gui and warn all the Ghosts
    proc{HidePacman PortGUI Pacman Ghosts}
        % Procédure interne pour gérer la portée lexical
        fun{Warn ID}
            proc{$ X}
                case X
                    of player(id:pacman(id:_ color:_ name:_) port: Z) then
                       {Send Z deathGhost(ID)}
                else
                    skip
                end
            end
        end  
    in
        % avertir le GUI de sa disparition
        {Send PortGUI hidePacman(Pacman.id)}
        % prévenir tous les ghosts de sa disparition
        thread {ForAllProc Ghosts {Warn Pacman.id}} end
   end

   %Une qui prévient le GUI du changement de mode + prévenir tous les joueurs du changement (setMode(M))
    proc{SetMode PortGUI M Pacmans Ghosts}
        % Procédure interne pour gérer la portée lexical
        fun{Warn M}
            proc{$ X}
                case X
                    of player(id:pacman(id:_ color:_ name:_) port: Z) then
                       {Send Z setMode(M)}
                else
                    skip
                end
            end
        end  
    in
        % avertir le GUI du changement de mode
        {Send PortGUI setMode(M)}
        % prévenir tous les ghosts et pacmans du changement de mode
        thread {ForAllProc Ghosts {Warn M}} end
        thread {ForAllProc Pacmans {Warn M}} end
   end

  % une/deux warningFunction (à ta préférence) qui affiche le pacman/ghost sur le GUI
  % (movePacman/moveGhost) et qui prévient les joueurs opposés de son mouvement 
  % (pacmanPos(ID P)/ghostPos(ID P))
    proc{ApplyMove PortGUI Player Position Adversories}
        % Procédure interne pour gérer la portée lexical
        fun{Warn ID P}
            proc{$ X}
                case X
                    of player(id:pacman(id:_ color:_ name:_) port: Z) then
                       {Send Z ghostPos(ID P)}
                    [] player(id:ghost(id:_ color:_ name:_) port: Z) then
                       {Send Z pacmanPos(ID P)}
                else
                    skip
                end
            end
        end  
    in
        % avertir le GUI du mouvement
        case Player
                of player(id:pacman(id:_ color:_ name:_) port: Z) then
                    {Send PortGUI movePacman(Player.id Position)}
                [] player(id:ghost(id:_ color:_ name:_) port: Z) then
                    {Send PortGUI moveGhost(Player.id Position)}
                else
                    skip
                
        end
        % prévenir tous les adversaires du move
        thread {ForAllProc Adversories {Warn Player.id Position}} end
    end
    
    %proc{DisplayWinner PortGUI}
    %TODO
    %{Send PortGUI displayWinner ID}
    %end

    %proc {LifeUpdate Pacman}
    %TODO
        %{Send Pacman.port gotKilled(?ID ?NewLife ?NewScore)}
    %end

    %proc {ScoreUpdate Pacman}
    %TODO
   %     {Send Pacman.port addPoint(Add ?ID ?NewScore)}
    %end
end