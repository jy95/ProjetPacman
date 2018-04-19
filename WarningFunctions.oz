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
define
   SpawnAllPoints
   SpawnAllBonus
   SpawnAllGhosts
   SpawnAllPacmans
   InitAllPointsAndBonus
   ForAllProc
   AssignSpawn
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

end