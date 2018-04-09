functor
import
   Browser
   CommonUtils
export
   portPlayer:StartPlayer
define   
   StartPlayer
   TreatStream
   % functions custom
   ChooseNextPosition
   TargetsStateModification
in
   % To handle new pacman or position of current pacman(s)
   % Action : 'update' / 'remove' for the current state ; isDone : if filter/update is already done
   % ID Position : Action attributes (for update both, for remove only ID)
   % Each element is only present once
   fun{TargetsStateModification PacmansPosition Action IsDone}
        case PacmansPosition
            of nil then
                case Action
                    of update(ID POSITION) then
                        if IsDone then
                            nil
                        else
                            target(position: POSITION id: ID)
                        end
                    [] remove(ID) then
                        % Nothing to do on empty list
                        nil
                end
            [] P|T then
                case Action
                    of update(ID POSITION) then
                        if IsDone == false andthen P.id == ID then
                            target(position: POSITION id: ID)|{TargetsStateModification T Action true}
                        else
                            P|{TargetsStateModification T Action IsDone}
                        end
                    [] remove(ID) then
                        if IsDone == false andthen P.id == ID then
                            {TargetsStateModification T Action true}
                        else
                            P|{TargetsStateModification T Action IsDone}
                        end
                end
        end
   end

   % A determinist way to decide which position should be taken by our ghost
   fun{ChooseNextPosition Mode PacmansPosition CurrentPosition BestPosition PreviousTarget}
            % X = row et Y = column
            CurrentPositionX = CurrentPosition.x
            CurrentPositionY = CurrentPosition.y
            % les mouvements possibles
            Left = pt(x: CurrentPositionX y: CurrentPositionY-1)
            Right = pt(x: CurrentPositionX y: CurrentPositionY+1)
            Up = pt(x: CurrentPositionX+1 y: CurrentPositionY)
            Down = pt(x: CurrentPositionX-1 y: CurrentPositionY)
            % seulement les mouvement valides
            ValidMoves = {CommonUtils.sortValidMoves [Left Right Up Down] }
        in
            case PacmansPosition
                of nil then BestPosition
                [] P|T then ResultMove ResultTarget LastTarget in

                    % First iteration so take the first pacman I saw
                    if PreviousTarget == nil then
                        LastTarget = P.position
                    else
                        LastTarget = PreviousTarget
                    end
                    % Procédure qui va setter les deux variables local pour déterminer le bon choix
                    {CommonUtils.bestDirectionForGhost Mode ValidMoves P.position BestPosition LastTarget 
                    ResultMove ResultTarget}

                    % histoire d'être sur que les résultats sont bien bound - 
                    % à voir si c'est pas mieux de le mettre quand T est nil
                    {Wait ResultMove}
                    {Wait ResultTarget}

                    % Appel récursif avec les nouveaux parametres
                    {ChooseNextPosition Mode T CurrentPosition ResultMove ResultTarget}
            end
   end

   % ID is a <ghost> ID
   fun{StartPlayer ID}
    Stream Port
   in
      {NewPort Stream Port}
      thread
	 {TreatStream Stream classic ID playerPosition(spawn: nil currentPosition: nil) 0 nil}
      end
      Port
   end

% has as many parameters as you want
   proc{TreatStream Stream Mode GhostId PlayerPosition OnBoard PacmansPosition}

      case Stream 
        of nil then skip

        % getId(?ID): Ask the ghost for its <ghost> ID.
        [] getId(ID)|T then
            ID = GhostId
            {TreatStream T Mode GhostId PlayerPosition OnBoard PacmansPosition}
    
        % assignSpawn(P): Assign the <position> P as the spawn of the ghost
        [] assignSpawn(P)|T then
            % Au début pas de position courante donc currentPosition à nil
            {TreatStream T Mode GhostId playerPosition(spawn: P currentPosition: nil) OnBoard PacmansPosition}

        % spawn(?ID ?P): Spawn the ghost on the board. The ghost should answer its <ghost> ID and
        % its <position> P (which should be the same as the one assigned as spawn. This action is only
        % done if the ghost is not on the board. It places the ghost on the board.
        [] spawn(ID P)|T then
            if OnBoard == 0 then Position in
                Position = PlayerPosition.spawn
                ID =  GhostId
                P = Position
                % spawn devient notre position courante
                {TreatStream T Mode GhostId playerPosition(spawn: Position currentPosition: Position) 1 PacmansPosition}
            else
                {TreatStream T Mode GhostId PlayerPosition OnBoard PacmansPosition}
            end

        % move(?ID ?P): Ask the ghost to chose its next <position> P (ghost is thus aware of its new
        % position). It should also give its <ghost> ID back in the message. This action is only done if
        % the pacman is considered on the board, if not, ID and P should be bound to null.
        [] move(ID P)|T then NextPosition in
            if OnBoard == 1 then CurrentPosition Spawn in
                CurrentPosition = PlayerPosition.currentPosition
                Spawn = PlayerPosition.spawn
                % On choisit la prochaine destination
                NextPosition = {ChooseNextPosition Mode PacmansPosition CurrentPosition CurrentPosition nil}
                % Cela prend un peu de temps donc on va attendre la fin avant de setter P 
                {Wait NextPosition}
                P = NextPosition
                ID = GhostId
                {TreatStream T Mode GhostId playerPosition(spawn: Spawn currentPosition: NextPosition) 
                OnBoard PacmansPosition}
            else
                ID = null
                P = null
                {TreatStream T Mode GhostId PlayerPosition OnBoard PacmansPosition}
            end 

        % gotKilled(): Inform the ghost that it had been killed and pass it out of the board.
        [] gotKilled()|T then
            % I cleaned the PacmansPosition so that no worry to have later
            {TreatStream T Mode GhostId PlayerPosition 0 nil}

        % pacmanPos(ID P): Inform that the pacman with <pacman> ID is now at <position> P.
        [] pacmanPos(ID P)|T then
            {TreatStream T Mode GhostId PlayerPosition OnBoard 
            {TargetsStateModification PacmansPosition update(ID P) false} }
            
        % killPacman(ID): Inform that the pacman with <pacman> ID has been killed by you
        [] killPacman(ID)|T then
            {TreatStream T Mode GhostId PlayerPosition OnBoard {TargetsStateModification PacmansPosition remove(ID) false} }

        % deathPacman(ID): Inform that the pacman with <pacman> ID has been killed (by someone, you or another ghost).
        [] deathPacman(ID)|T then
            {TreatStream T Mode GhostId PlayerPosition OnBoard {TargetsStateModification PacmansPosition remove(ID) false} }

        % setMode(M): Inform the new <mode> M
        [] setMode(M)|T then
            {TreatStream T M GhostId PlayerPosition OnBoard PacmansPosition}
        
        [] M|T then
            {Browser.browse 'unsupported message'#M}
            {TreatStream T Mode GhostId PlayerPosition OnBoard PacmansPosition}

      end
   end
end
