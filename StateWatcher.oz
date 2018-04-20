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
    % bestPlayer: un <pacman>
    % bestScore: le meilleur score de ce pacman , pour comparer par la suite
    % currentPositions : un record avec pour clé les positions occupées (traduit par la fct PositionToInt) les joueurs présents par exemple l( 25: player(id: pacman<> , port: Z)||... ) )
    % lastPositions : une liste qui contient la dernière position de chaque joueur (par exemple pt(y: 1 x:5)#player(id: <pacman> port: p)|... ) 
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
   
   % TODO A finir
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
        [] move(CurrentPlayer ID Position)|T then
            % TODO ; c'est HandleMove qui doit le faire
            {TreatStream T State}
        
        [] M|T then
            {TreatStream T State}
    end
  end
end