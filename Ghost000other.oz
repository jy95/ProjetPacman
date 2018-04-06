functor
import
   Input
   Browser
   OS
   CommonUtils
export
   portPlayer:StartPlayer
define   
   StartPlayer
   TreatStream
   % functions custom
   ChooseNextPosition
in
   % A determinist way to decide which position should be taken by our ghost
   fun{ChooseNextPosition PacmansPosition CurrentPosition BestPosition PreviousTarget}
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
                        LastTarget = P
                    else
                        LastTarget = PreviousTarget
                    end
                    % Procédure qui va setter les deux variables local pour déterminer le bon choix
                    {CommonUtils.bestDirection ValidMoves P.position BestPosition LastTarget ResultMove ResultTarget}
                    % Probablement pas besoin d'un wait sur ResultMove ResultTarget
                    % Puisque j'ai codé cette partie en determinist dataflow
                
                    % Appel récursif avec les nouveaux parametres
                    {ChooseNextPosition T CurrentPosition ResultMove ResultTarget}
            end
   end

   % ID is a <ghost> ID
   fun{StartPlayer ID}
    Stream Port
   in
      {NewPort Stream Port}
      thread
	 {TreatStream Stream nil nil 0 nil}
      end
      Port
   end

% has as many parameters as you want
   proc{TreatStream Stream GhostId Position OnBoard PacmansPosition}

      case Stream 
        of nil then skip

        % getId(?ID): Ask the ghost for its <ghost> ID.
        [] getId(ID)|T then
            ID = GhostId
            {TreatStream T GhostId Position OnBoard PacmansPosition}
    
        % assignSpawn(P): Assign the <position> P as the spawn of the ghost
        [] assignSpawn(P)|T then
            {TreatStream T GhostId P OnBoard PacmansPosition}

        % spawn(?ID ?P): Spawn the ghost on the board. The ghost should answer its <ghost> ID and
        % its <position> P (which should be the same as the one assigned as spawn. This action is only
        % done if the ghost is not on the board. It places the ghost on the board.
        [] spawn(ID P)|T then
            if OnBoard == 0 then
                ID =  GhostId
                P = Position
                {TreatStream T GhostId Position 1 PacmansPosition}
            else
                {TreatStream T GhostId Position OnBoard PacmansPosition}
            end

        % move(?ID ?P): Ask the ghost to chose its next <position> P (ghost is thus aware of its new
        % position). It should also give its <ghost> ID back in the message. This action is only done if
        % the pacman is considered on the board, if not, ID and P should be bound to null.
        [] move(ID P)|T then NextPosition in
            if OnBoard == 1 then
                NextPosition = {ChooseNextPosition PacmansPosition Position Position nil}
                P = NextPosition
                ID = GhostId
                {TreatStream T GhostId NextPosition OnBoard PacmansPosition}
            else
                ID = null
                P = null
                {TreatStream T GhostId Position OnBoard PacmansPosition}
            end 

        % gotKilled(): Inform the ghost that it had been killed and pass it out of the board.
        [] gotKilled()|T then
            % I cleaned the PacmansPosition so that no worry to have later
            {TreatStream T GhostId Position 0 nil}

        % pacmanPos(ID P): Inform that the pacman with <pacman> ID is now at <position> P.
        [] pacmanPos(ID P)|T then
            % TODO A finir
            {TreatStream T GhostId Position OnBoard PacmansPosition}
            
        % killPacman(ID): Inform that the pacman with <pacman> ID has been killed by you
        [] killPacman(ID)|T then
            % TODO A finir : le virer dans PacmansPosition
            {TreatStream T GhostId Position OnBoard PacmansPosition}

        % deathPacman(ID): Inform that the pacman with <pacman> ID has been killed (by someone, you or another ghost).
        [] deathPacman(ID)|T then
            % TODO A finir : le virer dans PacmansPosition
            {TreatStream T GhostId Position OnBoard PacmansPosition}

        % setMode(M): Inform the new <mode> M
        [] setMode(M)|T then
            % TODO A voir ce qu'on en fait
            {TreatStream T GhostId Position OnBoard PacmansPosition}
        
        [] M|T then
            {Browser.browse 'unsupported message'#M}

      end
   end
end
