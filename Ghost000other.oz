functor
import
   Browser
   CommonUtils
   Input
export
   portPlayer:StartPlayer
define   
   StartPlayer
   TreatStream
   ChooseNextPosition
   TargetsStateModification
   BestDirectionForGhost
in
   % To handle new pacman or position of current pacman(s)
   % Action : 'update' / 'remove' for the current state
   % ID Position : Action attributes (for update both, for remove only ID)
   % Each element is only present once
   fun{TargetsStateModification PacmansPosition Action}
        case Action
            of update(ID POSITION) then
                case PacmansPosition
                    of nil then target(id: ID position: POSITION)|nil
                    [] target(id: IG position:_)|T then
                        if thread IG == ID end then
                            target(id: ID position: POSITION)|T
                        else
                            PacmansPosition.1|{TargetsStateModification T Action}
                        end
                end
            [] remove(ID) then
                case PacmansPosition
                    of nil then nil
                    [] target(id: IG position:_)|T then
                        if thread IG == ID end then
                            T
                        else
                            PacmansPosition.1|{TargetsStateModification T Action}
                        end
                end
        end
   end

   % Compute the best direction to take , based on previous one
   % Inputs : Moves and Target are the current variable
   % Inputs: BestMove and PreviousTarget keep trace of previous work
   % ResultMove and ResultTarget are the final result
   proc{BestDirectionForGhost Mode Moves Target BestMove PreviousTarget ResultMove ResultTarget}
        case Moves
            of H|T then
                case Mode
                    of classic then
                        % A more interessting target to hunt - minimal path
                        if {CommonUtils.compareMoves Target H BestMove PreviousTarget '<'} then
	                        {BestDirectionForGhost Mode T Target H Target ResultMove ResultTarget}
                        else
	                        {BestDirectionForGhost Mode T Target BestMove PreviousTarget ResultMove ResultTarget}
                        end
                    [] hunt then
                        % run away of killer pacman(s) - maximal path
                        if {CommonUtils.compareMoves Target H BestMove PreviousTarget '>'} then
	                        {BestDirectionForGhost Mode T Target H Target ResultMove ResultTarget}
                        else
	                        {BestDirectionForGhost Mode T Target BestMove PreviousTarget ResultMove ResultTarget}
                        end
                end 
 
            [] nil then
                ResultMove = BestMove
                ResultTarget = PreviousTarget
        end
    end

   % A determinist way to decide which position should be taken by our ghost
   fun{ChooseNextPosition Mode PacmansPosition CurrentPosition BestPosition PreviousTarget}
            % X = column et Y = row
            CurrentPositionX = CurrentPosition.x
            CurrentPositionY = CurrentPosition.y
            % les mouvements possibles
            Left = pt(x: CurrentPositionX-1 y: CurrentPositionY)
            Right = pt(x: CurrentPositionX+1 y: CurrentPositionY)
            Up = pt(x: CurrentPositionX y: CurrentPositionY-1)
            Down = pt(x: CurrentPositionX y: CurrentPositionY+1)
            WrappingMoves = {CommonUtils.wrappingMoves [Left Right Up Down] nil}
            % seulement les mouvement valides
            ValidMoves = {CommonUtils.sortValidMoves WrappingMoves}
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
                    {BestDirectionForGhost Mode ValidMoves P.position BestPosition LastTarget 
                    ResultMove ResultTarget}

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
        [] assignSpawn(P)|T then NextPlayerState in
            {Record.adjoinAt PlayerPosition spawn P NextPlayerState}
            {TreatStream T Mode GhostId NextPlayerState OnBoard PacmansPosition}

        % spawn(?ID ?P): Spawn the ghost on the board. The ghost should answer its <ghost> ID and
        % its <position> P (which should be the same as the one assigned as spawn. This action is only
        % done if the ghost is not on the board. It places the ghost on the board.
        [] spawn(ID P)|T then
            if OnBoard == 0 then Position NextPlayerState in 
                Position = PlayerPosition.spawn
                ID =  GhostId
                P = Position
                {Record.adjoinAt PlayerPosition currentPosition Position NextPlayerState}
                {TreatStream T Mode GhostId NextPlayerState 1 PacmansPosition}
            else
                {TreatStream T Mode GhostId PlayerPosition OnBoard PacmansPosition}
            end

        % move(?ID ?P): Ask the ghost to chose its next <position> P (ghost is thus aware of its new
        % position). It should also give its <ghost> ID back in the message. This action is only done if
        % the pacman is considered on the board, if not, ID and P should be bound to null.
        [] move(ID P)|T then
            if OnBoard == 1 then CurrentPosition NextPosition NextPlayerPosition in
                % si on joue en simultané, il faut attendre un temps random avant de répondre
                if Input.isTurnByTurn == false then
                    {Delay {CommonUtils.randomNumber Input.thinkMin Input.thinkMax} }
                end
                CurrentPosition = PlayerPosition.currentPosition
                % On choisit la prochaine destination
                NextPosition = {ChooseNextPosition Mode PacmansPosition CurrentPosition CurrentPosition nil}
                % Cela prend un peu de temps donc on va attendre la fin avant de setter P 
                {Wait NextPosition}
                {Record.adjoinAt PlayerPosition currentPosition NextPosition NextPlayerPosition}
                % {Browser.browse ID#' A REPONDU '#NextPosition}
                
                P = NextPosition
                ID = GhostId
                {TreatStream T Mode GhostId NextPlayerPosition OnBoard PacmansPosition}
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
            {TargetsStateModification PacmansPosition update(ID P) }}
            
        % killPacman(ID): Inform that the pacman with <pacman> ID has been killed by you
        [] killPacman(ID)|T then
            {TreatStream T Mode GhostId PlayerPosition OnBoard 
            {TargetsStateModification PacmansPosition remove(ID) } }

        % deathPacman(ID): Inform that the pacman with <pacman> ID has been killed (by someone, you or another ghost).
        [] deathPacman(ID)|T then
            {TreatStream T Mode GhostId PlayerPosition OnBoard 
            {TargetsStateModification PacmansPosition remove(ID) } }

        % setMode(M): Inform the new <mode> M
        [] setMode(M)|T then
            {TreatStream T M GhostId PlayerPosition OnBoard PacmansPosition}
        
        [] M|T then
            {Browser.browse 'unsupported message'#M}
            {TreatStream T Mode GhostId PlayerPosition OnBoard PacmansPosition}

      end
   end
end
