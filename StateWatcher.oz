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
    CurrentPositionsWithoutDeathPlayers
    IsPacmanFinallyDead
    HandlePacmansDeath
    HandleGhostDeath
    FindBestPlayer
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
    % spawnPositions : un record à deux clés (pacmans/ghosts) avec des listes similaires à currentPositions 
    % currentPositions : une liste qui contient la dernière position de chaque joueur (par exemple pt(y: 1 x:5)#player(id: <pacman> port: p)|... ) 
    % deaths : record qui contient sous les clés suivants "pacmans" et "ghosts" une liste des joueurs tombés au champ de bataille sous le bon mapping
    % pointsOff : liste des position sur lequel un point a déjà été récupéré . par exemple pt(y: 2 x:7)|...
    % bonusOff :  liste des position sur lequel un bonus a déjà été récupéré . par exemple pt(y: 2 x:7)|...
    % pointsAndTime : liste de points déjà pris comme tuples T#pt(x: y:) ou T sera un nombre en turnByTurn ; un temps en simultaneious
    % bonusAndTime : liste de bonus déjà pris , comme pointsAndTime
    % pacmansAndTime : liste de players(ID: <pacman> , port : P) défini comme tuple T#Player(...) , comme pointsAndTime
    % ghostsAndTime : pareil que le précedent , pour les ghosts
  
   % Procédure qui va vérifier les différents timers 
   % CurrentState ; voir spec dans LaunchTurn
   % NewState : le nouveau state
   % IsFinished : boolean qui permet de savoir si le jeu est fini (utile dans la proc qui l'appelle)
   proc{RespawnChecker CurrentState NewState IsFinished}
        % les variables common used pour le check des timers
        TurnNumber = CurrentState.turnNumber
        PortGUI  = CurrentState.portGUI
        CurrentTime = CurrentState.currentTime
        BonusTime = CurrentState.bonusTime
        % la liste de tous les joueurs
        Pacmans = CurrentState.pacmans
        Ghosts = CurrentState.ghosts
        % proc qui filtre les ..AndTime et qui retourne tout ceux qui matchent selon le mode
        % Un peu comme une méthode partition , elle va rejetter le contenu qui ne matche pas dans une autre variable
        % ResultList ; tout ceux qui matchent (en débarrasant au passage le T histoire d'avoir accès à la data)
        % NewAndTimeList ; comme AndTimeList mais avec les éléments qui matche pas
        % FailedList ; AndTimeList sauf les éléments de ResultList
        % TimelyFilterConstraint AndTimePoints Points NewTimePoints NewPointsOff TurnNumber Input.respawnTimePoint
        proc{TimelyFilterConstraint AndTimeList ResultList FailedList NewAndTimeList TurnNumber ConstraintTime}
            case AndTimeList
                of nil then
                    ResultList = nil
                    FailedList = nil
                    NewAndTimeList = nil
                [] T#D|L then
                    % En turnByTurn on ne récupère que les tuples avec T + ConstraintTime = TurnNumber
                    % https://moodleucl.uclouvain.be/mod/forum/discuss.php?d=280621
                    if Input.isTurnByTurn then
                        if T + ConstraintTime == TurnNumber then R in
                            ResultList = D|R
                            {TimelyFilterConstraint L R FailedList NewAndTimeList TurnNumber ConstraintTime}
                        else Y Z in
                            FailedList = D|Y
                            NewAndTimeList = T#D|Z
                            {TimelyFilterConstraint L ResultList Y Z TurnNumber ConstraintTime}
                        end
                    % En simultané ; il faut checker que {Time.time} - T >= ConstraintTime 
                    else
                        if {Time.time} - CurrentTime >= ConstraintTime then R in
                            ResultList = D|R
                            {TimelyFilterConstraint L R FailedList NewAndTimeList TurnNumber ConstraintTime}
                        else Y Z in
                            FailedList = D|Y
                            NewAndTimeList = T#D|Z
                            {TimelyFilterConstraint L ResultList Y Z TurnNumber ConstraintTime}
                        end
                    end
            end
        end
        % Nouvelles valeurs : pour gérer le changement d'état
        NewPointsOff
        NewBonusOff
        NewDeadPacmans
        NewDeadGhosts
        NewMode
        % Les listes permettant de gérer les respawn
        AndTimePoints = CurrentState.pointsAndTime
        AndTimeGhosts = CurrentState.ghostsAndTime
        AndTimePacmans = CurrentState.pacmansAndTime
        AndTimeBonus = CurrentState.bonusAndTime
        % Les nouvelles valeurs des précédentes
        NewTimePoints
        NewTimeGhosts
        NewTimePacmans
        NewTimeBonus
        % les nouveaux 
        Points
        Bonus
        PacmansD
        GhostsD
   in
        % 0. Est ce qu'il y a encore un pacman en vie
        if CurrentState.nbPacmans == 0 then
            IsFinished = true
            NewState = CurrentState
        else
            % 1. vérification : les 4 RespawnTime
            
            % 1.1 les points
            % On récupère dans Points les positions qui peuvent réapparaitrent
            % Dans NewTimePoints , AndTimePoints sans les éléments précédents
            % NewPointsOff : Les points qui sont toujours off
            {TimelyFilterConstraint AndTimePoints Points NewTimePoints NewPointsOff TurnNumber Input.respawnTimePoint}
            {WarningFunctions.spawnAllPoints PortGUI Points Pacmans}
        
            % 1.2 les bonus
            {TimelyFilterConstraint AndTimeBonus Bonus NewTimeBonus NewBonusOff TurnNumber Input.respawnTimeBonus}
            {WarningFunctions.spawnAllBonus PortGUI Bonus Pacmans}
        
            % 1.3 les pacmans
            {TimelyFilterConstraint AndTimePacmans PacmansD NewTimePacmans NewDeadPacmans  TurnNumber Input.respawnTimePacman}
            {WarningFunctions.spawnAllPacmans PortGUI PacmansD Ghosts}

            % 1.4 les ghosts
            {TimelyFilterConstraint AndTimeGhosts GhostsD NewTimeGhosts NewDeadGhosts TurnNumber Input.respawnTimeGhost}
            {WarningFunctions.spawnAllGhosts PortGUI GhostsD Pacmans}

            % 2. vérification : le huntTime (si le mode était hunt)
            if CurrentState.mode == hunt then
                % si le bonus time est expiré
                if ( Input.isTurnByTurn andthen TurnNumber mod Input.huntTime ==0 ) orelse
                   ( Input.isTurnByTurn == false andthen {Time.time} - BonusTime  >= Input.huntTime ) then
                    NewMode = classic
                    % Si on était en mode bonus , il faut prévenir du changement
                    if CurrentState.mode \= classic then
                        {WarningFunctions.setMode PortGUI classic Pacmans Ghosts}
                    end
                else
                    NewMode = CurrentState.mode
                end
            else
                NewMode = CurrentState.mode
            end

            % le nouvel état
            {Record.adjoinList CurrentState [
                mode#NewMode
                deaths#deaths(ghosts: NewDeadGhosts pacmans: NewDeadPacmans)
                bonusOff#NewBonusOff
                pointsOff#NewPointsOff
                % les nouveaux
                pointsAndTime#NewTimePoints
                pacmansAndTime#NewTimePacmans
                ghostsAndTime#NewTimeGhosts
                bonusAndTime#NewTimeBonus
            ] NewState}
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
   
   % Check if dead pacman with 0 life tries to send a move message 
   fun{IsPacmanFinallyDead Pacman DeathsList}
    case DeathsList
        of nil then false
        [] P|T then
            if P == Pacman then
                true
            else
                {IsPacmanFinallyDead Pacman T}
            end
    end
   end

   % Return the list of alive players
   fun{GetLastKnownPosition Ghosts Pacmans Deaths AlreadyDeathPacmans CurrentPositions SpawnPosition Result}
    case Ghosts
        of G|T then
            if {IsStillAlive Deaths.ghosts G} then
                {GetLastKnownPosition T Pacmans Deaths AlreadyDeathPacmans CurrentPositions SpawnPosition {
                    GetLastKnownPositionForPlayer G CurrentPositions SpawnPosition.ghosts
                }|Result}
            else
                {GetLastKnownPosition T Pacmans Deaths AlreadyDeathPacmans CurrentPositions SpawnPosition Result}
            end
        [] nil then
            case Pacmans
                of P|L then
                    % empecher un vieux pacman avec life 0 de s'y trouver
                    if {IsStillAlive Deaths.pacmans P} andthen {IsPacmanFinallyDead P AlreadyDeathPacmans} == false then
                        {GetLastKnownPosition Ghosts L Deaths AlreadyDeathPacmans CurrentPositions SpawnPosition {
                            GetLastKnownPositionForPlayer P CurrentPositions SpawnPosition.pacmans
                        }|Result}
                    else
                        {GetLastKnownPosition Ghosts L Deaths AlreadyDeathPacmans CurrentPositions SpawnPosition Result}
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
   
   % Remove the death player from currentPositions
   fun{CurrentPositionsWithoutDeathPlayers CurrentPositions DeathsList}
    case CurrentPositions
        of nil then nil
        [] _#Player|T then
            % Ce joueur doit être viré
            if {List.some DeathsList fun{$ X} X == Player end} then
                {CurrentPositionsWithoutDeathPlayers T DeathsList}
            else
                CurrentPositions.1|{CurrentPositionsWithoutDeathPlayers T DeathsList}
            end
    end
   end

   % Handle dead pacman(s) by ghost Killer
   % Killer : the ghost that kills a/many pacman(s)
   % Ghosts and Pacamns : All the players that should be aware of this event
   % NotDeadPacmans and PacmansFinallyDead : temp variables just for treatement
   % Victims and PacmansNotDead : the result (just like List.partition)
   proc{HandlePacmansDeath PortGUI Killer Ghosts Pacmans NotDeadPacmans PacmansFinallyDead Victims PacmansNotDead}
    case Pacmans
        of nil then 
            Victims = PacmansFinallyDead
            PacmansNotDead = NotDeadPacmans
        [] P|T then CurrentLife NewScore ID in
            % On prévient le tueur 
            {Send Killer.port killPacman(P.id)}

            % On prévient les ghosts de la mort du pacman 
            {WarningFunctions.hidePacman PortGUI P Ghosts}

            % On prévient la victime
            {Send P.port gotKilled(ID CurrentLife NewScore)}

            % On prévient la GUI de la perte de point/vie du pacman
            {Send PortGUI lifeUpdate(ID CurrentLife)}
            {Send PortGUI scoreUpdate(ID NewScore)}
            
            % Ce joueur va définitivement être viré
            if CurrentLife == 0 then
                {HandlePacmansDeath PortGUI Killer Ghosts T NotDeadPacmans P|PacmansFinallyDead Victims PacmansNotDead}
            else
                {HandlePacmansDeath PortGUI Killer Ghosts T P|NotDeadPacmans PacmansFinallyDead Victims PacmansNotDead}
            end
    end
   end
   
   % Un peu comme HandlePacmansDeath sauf que c'est fait pour gérer des ghosts par un pacman
   proc{HandleGhostDeath PortGUI Killer PacmansList Pacmans}
    case PacmansList
        of nil then skip
        [] G|T then
            % On prévient le tueur  killGhost(IDg ?IDp ?NewScore):
            {Send Killer.port killGhost(G.id _ _)}

            % On prévient les pacmans de la mort du ghost - deathGhost(ID)
            {WarningFunctions.hideGhost PortGUI G Pacmans}

            % On prévient la victime
            {Send G.port gotKilled()}
            
            % La victime suivante
            {HandleGhostDeath PortGUI Killer T Pacmans}
    end
   end

   proc{HandleMove CurrentPlayer Position TempState StateAfterMove}
        % le player qu'on traite actuellement
        UserPort = CurrentPlayer.port
        PortGUI = TempState.portGUI
        % Savoir s'il s'agit d'un pacman ; true si c'est le cas
        CheckPacmanType = {IsAPacman CurrentPlayer}
        % all the dead players
        Deaths = TempState.deaths
        % all the finally known deaths pacmans
        FinallyDeathPacmans = TempState.pacmansWithNoLife
        % La liste des morts à vérifier - (eh oui possible d'assigner une variable de cette facon)
        CheckDeathList = if CheckPacmanType then Deaths.pacmans else Deaths.ghosts end
        % Les pacmans/ghosts de la partie
        Ghosts = TempState.ghosts
        Pacmans = TempState.pacmans
        % La position courante de tous les joueurs
        LastKnownPosition = TempState.currentPositions
        SpawnPosition = TempState.spawnPositions
        CurrentPositions = {GetLastKnownPosition Ghosts Pacmans Deaths FinallyDeathPacmans LastKnownPosition SpawnPosition nil}
        % Tous les autres joueurs sur la position passée en paramètre (en supposant bien sur que notre joueur y est pas (encore) 
        PlayersOnThisPosition = {FindPlayersOnPosition CurrentPositions Position}
        % Les joueurs de type opposés au notre
        OpponentList = {FindOpponents PlayersOnThisPosition CheckPacmanType}
        % savoir si le pacman pourra récupérer le point/bonus si toujours en vie
        StillAvailable
        % les variables pour checker le gain de points/bonus
        PointsOff = TempState.pointsOff
        PointsSpawn = TempState.pointsSpawn
        BonusOff = TempState.bonusOff
        BonusSpawn = TempState.bonusSpawn
        % Les nouvelles variables pour l'update du state
        NewPointsOff
        NewBonusOff
        NewCurrentPositions
        NewBonusTime
        NewMode
        % gérer les morts
        NewNbPacmans
        NewDeadGhosts
        NewDeadPacmans
        NewFinallyDeathPacmans
    in
        % Si le joueur est mort entretemps après son message , il ne peut plus agir
        % Petit check supplémentaire : empecher un pacman mort de "tricher" (s'il n'a plus de vie)
        if {IsStillAlive CheckDeathList CurrentPlayer} == false orelse {IsPacmanFinallyDead CurrentPlayer FinallyDeathPacmans} then
            % On skip son tour - aucun changement d'état
            StateAfterMove = TempState
        else
            % On bouge en prévention le ghost/pacman
            {WarningFunctions.applyMove PortGUI CurrentPlayer Position if CheckPacmanType then Ghosts else Pacmans end }

            % S'il y n'a pas des ennemis, on peut enregistrer sa position sans soucis
            if OpponentList == nil then
                StillAvailable = true
                NewFinallyDeathPacmans = FinallyDeathPacmans
                NewDeadGhosts = Deaths.ghosts
                NewDeadPacmans = Deaths.pacmans
                NewNbPacmans = TempState.nbPacmans
                % sa nouvelle position
                NewCurrentPositions = {List.append Position#CurrentPlayer|nil 
                                        {CurrentPositionsWithoutDeathPlayers LastKnownPosition CurrentPlayer|nil} }

            else
                % Selon le mode et notre type, on se fait tuer par le premier ennemi ou on tue tout le monde
                if TempState.mode == classic then Victims PacmansNotDead in
                    % En mode normal, Le pacman se fait tuer par le premier ghost
                    if CheckPacmanType then KillerPlayer in
                        KillerPlayer = OpponentList.1

                        % sous traitter les warnings aux joueurs concernées
                        {HandlePacmansDeath PortGUI KillerPlayer Ghosts CurrentPlayer|nil nil nil Victims PacmansNotDead}

                        % on le vire des positions courantes
                        NewCurrentPositions = {CurrentPositionsWithoutDeathPlayers LastKnownPosition CurrentPlayer|nil}

                        % On décrémente le nombre de pacmans selon le nombre d'éléments dans Victims
                        NewNbPacmans = TempState.nbPacmans - {List.length Victims}

                        % On rajoute cette nouvelles victime aux précédentes
                        NewFinallyDeathPacmans = {List.append FinallyDeathPacmans Victims}

                        % Les joueurs avec encore de la vie sont rajoutés
                        NewDeadPacmans = {List.append Deaths.pacmans PacmansNotDead}

                        % Aucun mort à rajouter du côté des ghots)
                        NewDeadGhosts = Deaths.ghosts

                        % Ce pacman ne peut plus agir
                        StillAvailable=false

                    % Le ghost tue tout les pacmans sur son chemin
                    else

                        % sous traitter les warnings aux joueurs concernées
                        {HandlePacmansDeath PortGUI CurrentPlayer Ghosts OpponentList nil nil Victims PacmansNotDead}

                        % on le vire des positions courantes
                        NewCurrentPositions = {CurrentPositionsWithoutDeathPlayers LastKnownPosition OpponentList}

                        % On décrémente le nombre de pacmans selon le nombre d'éléments dans Victims
                        NewNbPacmans = TempState.nbPacmans - {List.length Victims}

                        % On rajoute cette nouvelles victime aux précédentes
                        NewFinallyDeathPacmans = {List.append FinallyDeathPacmans Victims}

                        % Les joueurs avec encore de la vie sont rajoutés
                        NewDeadPacmans = {List.append Deaths.pacmans PacmansNotDead}

                        % Aucun mort à rajouter du côté des ghots)
                        NewDeadGhosts = Deaths.ghosts

                        % Ce ghost peut agir mais CheckPacmanType= false
                        StillAvailable=true
                        
                    end
                else
                    % En mode bonus, le nombre de pacmans reste le même
                    NewNbPacmans = TempState.nbPacmans
                    NewDeadPacmans = Deaths.pacmans
                    NewFinallyDeathPacmans = FinallyDeathPacmans

                    % Le pacman tue tout les ghosts
                    if CheckPacmanType then 
                        
                        % sous traitter les warnings aux joueurs concernées
                        {HandleGhostDeath PortGUI CurrentPlayer OpponentList Pacmans}

                        % on le vire des positions courantes
                        NewCurrentPositions = {CurrentPositionsWithoutDeathPlayers LastKnownPosition OpponentList}

                        % Des morts à rajouter du côté des ghots
                        NewDeadGhosts = {List.append Deaths.ghosts OpponentList}

                        % Ce pacman peut agir mais CheckPacmanType= false
                        StillAvailable=true

                    % Le ghost se fait tuer par le premier pacman
                    else 
                        
                        % sous traitter les warnings aux joueurs concernées
                        {HandleGhostDeath PortGUI OpponentList.1 CurrentPlayer|nil Pacmans}

                        % on le vire des positions courantes
                        NewCurrentPositions = {CurrentPositionsWithoutDeathPlayers LastKnownPosition CurrentPlayer|nil}

                        % Des morts à rajouter du côté des ghots
                        NewDeadGhosts = {List.append Deaths.ghosts CurrentPlayer|nil}

                        % Ce pacman ne peut plus agir
                        StillAvailable=false
                        
                    end
                end
            end

            % Pour gérer les gains
            if StillAvailable andthen CheckPacmanType then
                % Sauvergarde la nouvelle position
                % On prend un point
                if {List.some PointsOff fun{$ X} X == Position end } == false andthen
                       {List.some PointsSpawn fun{$ X} X == Position end } then NewScore ID in
                    % Prévenir que le joueur a gagné un point
                    {Send UserPort addPoint(Input.rewardPoint ID NewScore)}
                    % Prévenir la GUI des changements
                    {Send PortGUI scoreUpdate(ID NewScore)}

                    % Prévenir tous les joueurs que le point a disparu + GUI
                    {WarningFunctions.hidePoint PortGUI Position Pacmans}

                    % mettre cette position comme off
                    NewPointsOff = Position|PointsOff
                    NewBonusOff = BonusOff
                    NewBonusTime = TempState.bonusTime
                    NewMode = TempState.mode

                % On prend un bonus
                elseif {List.some BonusOff fun{$ X} X == Position end } == false andthen
                            {List.some BonusSpawn fun{$ X} X == Position end } then
                    
                    % Prévenir du changement de mode
                    {WarningFunctions.setMode PortGUI hunt Pacmans Ghosts}
                    % prévenir tous les joueurs du changement de mode
                    {WarningFunctions.hideBonus PortGUI Position Pacmans}

                    % mettre cette position comme off
                    NewMode = hunt
                    NewBonusOff =  Position|BonusOff
                    NewPointsOff = PointsOff
                    NewBonusTime = {Time.time}
                    
                % Rien du tout , on garde les mêmes variables
                else
                    NewPointsOff = PointsOff
                    NewBonusOff = BonusOff
                    NewBonusTime = TempState.bonusTime
                    NewMode = TempState.mode
                end
            % Rien du tout , on garde les mêmes variables
            else
                NewPointsOff = PointsOff
                NewBonusOff = BonusOff
                NewBonusTime = TempState.bonusTime
                NewMode = TempState.mode
            end
            
            % Update du final state
             {Record.adjoinList TempState [
                pointsOff#NewPointsOff
                bonusOff#NewBonusOff
                bonusTime#NewBonusTime
                currentPositions#NewCurrentPositions
                deaths#deaths(pacmans: NewDeadPacmans ghosts: NewDeadGhosts)
                pacmansWithNoLife#NewFinallyDeathPacmans
                nbPacmans#NewNbPacmans
                mode#NewMode
             ] StateAfterMove}
        end
    end
  % find the best pacman of this game - pour une fois, je m'autorise à utiliser un paramètre optionel
  proc{FindBestPlayer PortGUI Pacmans BestPlayer BestScore}
    ID
    NewScore
  in
    case Pacmans
        of nil then
            if BestPlayer \= null then
                {Send PortGUI displayWinner(BestPlayer)}
            end
        [] P|T then
            
            % On récupère son score en lui faisant gagner 0 points aka rien du tout :)
            {Send P.port addPoint(0 ID NewScore)}

            % si son score est meilleur , on devient le meilleur
            if BestPlayer \= null andthen NewScore > BestScore then
                {FindBestPlayer PortGUI T ID NewScore}
            % Si on avait personne , il devient notre meilleur joueur
            elseif BestPlayer == null then
                {FindBestPlayer PortGUI T ID NewScore}
            % On garde le même pacman
            else
                {FindBestPlayer PortGUI T BestPlayer BestScore}
            end
    end
  end

  proc{TreatStream Stream State}
    % {Browser.browse Stream.1}
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
            % trouver le best pacman en les interrogant tous avec addPoint (avec un Add de 0)
            {FindBestPlayer State.portGUI State.pacmans null null}
            {TreatStream T State}
        
        % Incrémente son currentTime
        [] increaseTime|T then
            {TreatStream T {Record.adjoinList State [currentTime#{Time.time}]} }

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
            {Browser.browse 'Unsupported Message'#M}
            {TreatStream T State}
    end
  end
end