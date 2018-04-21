functor
import
    Browser
    Input
    % Nos fonctions pour prévenir les gens
    WarningFunctions
export
    portWindow:StartWindow
define
    StartWindow
    RespawnChecker
    TreatStream
    HandleMove
    IsStillAlive
    IsAPacman
    FindTupleInList
    GetLastKnownPositionForPlayer
    GetLastKnownPosition
    FindPlayersOnPosition
    FindOpponents
in
% Explication sur le state qui gère le jeu: il s'agit d'un record qui stocke diverses informations du jeu :
    % portGUI : le port sur lequel on envoit les infos destinés au GUI
    % currentTime : l'heure actuelle (utile seulement pour le jeu en simultané; _ sinon)
    % bonusTime : l'heure du dernier bonus attrapé , pour gérer le "reset the timing" si on est dans la bonne période.
    % turnNumber le numéro du tour (utile seulement pour le jeu turnbyturn ; _ sinon)
    % mode : the current mode
    % pacmans : tous les pacmans du jeu
    % ghosts : tous les ghosts du jeu
    % nbPacmans : le nombre de pacmans encore en vie 
    % spawnPositions : juste une manière de vérifier après respawn que le joueur se fait tuer
    % currentPositions : une liste qui contient la dernière position de chaque joueur (par exemple pt(y: 1 x:5)#player(id: <pacman> port: p)|... ) 
    % deaths : record qui contient sous les clés suivants "pacmans" et "ghosts" une liste des joueurs tombés au champ de bataille sous le bon mapping
    % pointsOff : liste des position sur lequel un point a déjà été récupéré . par exemple pt(y: 2 x:7)|...
    % bonusOff :  liste des position sur lequel un bonus a déjà été récupéré . par exemple pt(y: 2 x:7)|...
  
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

  fun{StartWindow InitState}
      Stream Port
  in
      {NewPort Stream Port}
      thread
	 {TreatStream Stream InitState}
      end
      Port
  end
   
   % Function that will check if the asked pacman/ghost is not already dead 
   fun{IsStillAlive CheckList Asker}
    case CheckList
        of nil then true
        [] H|T then
            if H == Asker then false else {IsStillAlive T Asker} end
    end
   end

   % Detect 
   fun{IsAPacman X}
    case X
        of player(id:pacman(id:_ color:_ name:_) port: _) then
            true
        else
            false
    end
   end
   
   % Returns the tuple Position#ID ; null if not found
   fun{FindTupleInList SearchList Player}
    case SearchList
        of nil then null
        [] _#player(id: FoundID port: _)|T then
            if Player.id == FoundID then
                SearchList.1
            else
                {FindTupleInList T Player}
            end
    end
   end

   % Return for an alive player it last position
   % So currentPosition if already moved
   % or spawnPosition if just revived
    fun{GetLastKnownPositionForPlayer ID CurrentPositions SpawnPosition}
        TempResult = {FindTupleInList CurrentPositions ID}
    in
        if TempResult \= null then
            TempResult
        else
            % On suppose que le joueur est toujours en vie donc à son lieu de spawn
            {FindTupleInList SpawnPosition ID}
        end
    end

   % Return the list of alive players
   fun{GetLastKnownPosition Ghosts Pacmans Deaths CurrentPositions SpawnPosition Result}
    case Ghosts
        of G|T then
            if {IsStillAlive Deaths.ghosts G} then
                {GetLastKnownPosition T Pacmans Deaths CurrentPositions SpawnPosition {
                    GetLastKnownPositionForPlayer G CurrentPositions SpawnPosition
                }|Result}
            else
                {GetLastKnownPosition T Pacmans Deaths CurrentPositions SpawnPosition Result}
            end
        [] nil then
            case Pacmans
                of P|L then
                    if {IsStillAlive Deaths.pacmans P} then
                        {GetLastKnownPosition Ghosts L Deaths CurrentPositions SpawnPosition {
                            GetLastKnownPositionForPlayer P CurrentPositions SpawnPosition
                        }|Result}
                    else
                        {GetLastKnownPosition Ghosts L Deaths CurrentPositions SpawnPosition Result}
                    end
                [] nil then
                    Result
            end
    end
   end

   fun{FindPlayersOnPosition CurrentPositions Position}
    case CurrentPositions
        of nil then nil
        [] P#_|T then
            if P == Position then
                CurrentPositions.1.2|{FindPlayersOnPosition T Position}
            else
                {FindPlayersOnPosition T Position}
            end
    end
   end

   fun{FindOpponents PlayerList CheckIsAPacman}
    case PlayerList
        of nil then nil
        [] P|T then
            % On est un pacman , donc on doit trouver des ghosts
            if CheckIsAPacman then
                if {IsAPacman P } then
                    {FindOpponents T CheckIsAPacman}
                else
                    P|{FindOpponents T CheckIsAPacman}
                end
            % On est un ghost , donc on doit trouver des pacmans
            else
                if {IsAPacman P } then
                    P|{FindOpponents T CheckIsAPacman}
                else
                    {FindOpponents T CheckIsAPacman}
                end
            end
    end
   end

   % TODO A finir
   proc{HandleMove CurrentPlayer Position TempState StateAfterMove}
        % le player qu'on traite actuellement
        UserId = CurrentPlayer.id
        UserPort = CurrentPlayer.port
        % Savoir s'il s'agit d'un pacman ; true si c'est le cas
        CheckPacmanType = {IsAPacman CurrentPlayer}
        % all the dead players
        Deaths = TempState.deaths
        % La liste des morts à vérifier - (eh oui possible d'assigner une variable de cette facon)
        CheckDeathList = if CheckPacmanType then Deaths.pacmans else Deaths.ghosts end
        % Les pacmans/ghosts de la partie
        Ghosts = TempState.ghosts
        Pacmans = TempState.pacmans
        % La position courante de tous les joueurs
        LastKnownPosition = TempState.currentPositions
        SpawnPosition = TempState.spawnPositions
        CurrentPositions = {GetLastKnownPosition Ghosts Pacmans Deaths LastKnownPosition SpawnPosition nil}
        % Tous les autres joueurs sur la position passée en paramètre (en supposant bien sur que notre joueur y est pas (encore) 
        PlayersOnThisPosition = {FindPlayersOnPosition CurrentPositions Position}
        % Les joueurs de type opposés au notre
        OpponentList = {FindOpponents PlayersOnThisPosition CheckPacmanType}
        % savoir si le pacman pourra récupérer le point/bonus si toujours en vie
        StillAvailable
        % La liste de tous les joueurs ; utile pour les fonctions de notitication
        AllPlayers = {List.append Ghosts Pacmans}
        % les variables pour checker le gain de points/bonus
        PointsOff = TempState.pointsOff
        PointsSpawn = TempState.pointsSpawn
        BonusOff = TempState.bonusOff
        BonusSpawn = TempState.bonusSpawn
        % Les nouvelles variables pour l'update du state
        NewPointsOff
        NewBonusOff
        NewCurrentPosition
        NewBonusTime
        NewMode
    in
        % Si le joueur est mort entretemps après son message , il ne peut plus agir
        if {IsStillAlive CheckDeathList CurrentPlayer} == false then
            % On skip son tour - aucun changement d'état
            StateAfterMove = TempState
        else
            % Pour tester les collisions
            if OpponentList == nil then
                StillAvailable = true
            else
                % Selon le mode et notre type, on se fait tuer par le premier ennemi ou on tue tout le monde
                if TempState.mode == classic then
                    skip
                else
                    skip
                end

            end

            % Pour gérer les gains
            if StillAvailable andthen CheckPacmanType then
                % Sauvergarde la nouvelle position
                % On prend un point
                if {List.some PointsOff fun{$ X} X == Position end } == false andthen
                       {List.some PointsSpawn fun{$ X} X == Position end } then
                    % Prévenir que le joueur a gagné un point
                    {Send UserPort addPoint(Input.rewardPoint _ _)}
                    % TODO Prévenir tous les joueurs que le point a disparu

                    % mettre cette position comme off
                    NewPointsOff = PointsOff|Position
                    NewBonusTime = TempState.bonusTime

                % On prend un bonus
                elseif {List.some BonusOff fun{$ X} X == Position end } == false andthen
                            {List.some BonusSpawn fun{$ X} X == Position end } then
                    
                    % TODO prévenir tous les joueurs du changement de mode

                    % mettre cette position comme off
                    NewBonusOff = NewBonusOff|Position
                    NewBonusTime = {Time.time}
                    
                % Rien du tout , on garde les mêmes variables
                else
                    NewPointsOff = PointsOff
                    NewBonusOff = BonusOff
                    NewBonusTime = TempState.bonusTime
                end
            end

            % Pour débug
            %{Delay 250000000}
            
            % Update du final state
             {Record.adjoinList TempState [
                pointsOff#NewPointsOff
                bonusOff#NewBonusOff
                bonusTime#NewBonusTime
             ] StateAfterMove}
        end
    end

  proc{TreatStream Stream State}
    {Browser.browse Stream.1}
    case Stream
        of nil then skip
        
        % Retourne le state quand il est demandé dans le Main
        [] getState(X)|T then
            X = State
            {TreatStream T State}
        
        % On checke les timers de respawn en profitant de notifier si la partie est finie
        [] checkTimers(F)|T then NewState in
            {RespawnChecker State NewState F}
            {TreatStream T NewState}

        % Va chercher le gagnant parmi tous les pacmans et l'afficher via la GUI
        [] displayWinner|T then
            % TODO A modifier, faut la calculer à la fin
            % TODO trouver le best pacman en les interrogant tous avec addPoint (avec un Add de 0)
            {Send State.portGUI displayWinner(State.bestPlayer)}
            {TreatStream T State}

        % Incremente le tour + set son currentTime
        [] increaseTurn|T then FinalState CurrentTurnNumber in
            % le tour courant
            CurrentTurnNumber = State.turnNumber
            {Record.adjoinList State [
                        turnNumber#CurrentTurnNumber+1
                        currentTime#{Time.time}
            ] FinalState}
            {TreatStream T FinalState}
        
        % Gére le mouvement d'un player
        [] move(CurrentPlayer Position)|T then StateAfterMove in
            {HandleMove CurrentPlayer Position State StateAfterMove}
            {TreatStream T StateAfterMove}
        
        [] M|T then
            {TreatStream T State}
    end
  end
end