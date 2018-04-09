functor
import
   Input
   OS
   Number
   Float
   Value
export
   allowedMove:AllowedPosition
   sortValidMoves:SortValidMoves
   bestDirectionForGhost:BestDirectionForGhost
   randomNumber:RandomNumber
define
   AllowedPosition
   SortValidMoves
   WantedRow
   WantedColumn
   WantedElement
   DistanceBetween
   CompareMoves
   BestDirectionForGhost
   RandomNumber
in
   % Generate a random number between I and J
   fun{RandomNumber I J}
        (({OS.rand} mod (J-I+1)) + I)
   end

   % A way to access the wanted NRow I want
   fun lazy{WantedRow List LineNumber}
      if LineNumber == 1 then List.1 else {WantedRow List.2 LineNumber-1} end
   end
   
   % A way to access the wanted NColumn I want
   fun lazy{WantedColumn List ColumnNumber}
      if ColumnNumber == 1 then List.1 else {WantedColumn List.2 ColumnNumber-1} end
   end
   
   % Combine them to got the element I want
   fun lazy{WantedElement X Y}
      {WantedColumn {WantedRow Input.map X} Y}
   end

   % A way to detect if a position is allowed - boolean type exists :)
   % X rely on NColumn , Y on NRow
   fun{AllowedPosition Position}
      X = Position.x
      Y = Position.y
   in
      % On sort des limites du double tableau
      if Y =< 0 orelse Y > Input.nRow orelse X =< 0 orelse X > Input.nColumn then
	    false
      else
        % On se prend peut être un mur dans la figure 
	    {WantedElement X Y} \= 1
      end
   end

   % Inspiré de la Cfilter du cours
   % Cela prend du temps pour parcourrir le double tableau à la facon Oz
   fun{SortValidMoves List}
        case List
            of H|T then
                if thread {AllowedPosition H} end then
                    H|{SortValidMoves T}
                else
                    {SortValidMoves T}
                end
            [] nil then nil
        end
   end
   
   % Compute the distance between two positions
   fun{DistanceBetween P1 P2}
        % ici calcul de l'hypoténus comme heuristic ; aussi appellé Distance de Manhattan ^^
        % racine de (xA − xB)2 + (yA − yB)2
        {Float.sqrt {IntToFloat ({Number.pow (P1.x - P2.x) 2} + {Number.pow (P1.y - P2.y) 2})} }
   end
   
   % Compare
   fun{CompareMoves NewMove NewTarget LastMove LastTarget Operator}
        {Value.Operator {DistanceBetween NewMove NewTarget} {DistanceBetween LastMove LastTarget} }
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
                        if {CompareMoves Target H BestMove PreviousTarget '<'} then
	                        {BestDirectionForGhost Mode T Target H Target ResultMove ResultTarget}
                        else
	                        {BestDirectionForGhost Mode T Target BestMove PreviousTarget ResultMove ResultTarget}
                        end
                    [] hunt then
                        % run away of killer pacman(s) - maximal path
                        if {CompareMoves Target H BestMove PreviousTarget '>'} then
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
end