functor
import
   Input
   OS
export
   allowedMove:AllowedPosition
   sortValidMoves:SortValidMoves
   randomNumber:RandomNumber
   positionToInt:PositionToInt
   compareMoves:CompareMoves
   wrappingMoves:WrappingMoves
define
   AllowedPosition
   SortValidMoves
   WantedRow
   WantedColumn
   WantedElement
   DistanceBetween
   CompareMoves
   RandomNumber
   PositionToInt
   WrappingMoves
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
      {WantedColumn {WantedRow Input.map Y} X}
   end

   % A way to detect if a position is allowed - boolean type exists :)
   % Verfiy if wall
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
   % Manage the self-wrapping of the MAP
   fun{WrappingMoves List Acc}
        case List
            of H|T then
                if H.x==0 then {WrappingMoves T pt(x: Input.nColumn y: H.y)|Acc}
                elseif H.x==(Input.nColumn+1) then {WrappingMoves T pt(x: 1 y: H.y)|Acc}
                elseif H.y==0 then {WrappingMoves T pt(x: H.x y: Input.nRow)|Acc}
                elseif H.y==(Input.nColumn+1) then {WrappingMoves T pt(x: H.x y: 1)|Acc}
                else {WrappingMoves T pt(x: H.x y: H.y)|Acc}
                end
            [] nil then nil
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

   % A funny-easy way to access more quickly to next element (instead of list loop) 
   % mostly useful for pacman (with its own data structure) so that it could act a little quick that ghost 
   % Y : row ; x : column
   fun{PositionToInt P}
      (P.y * Input.nRow) + P.x
   end
end