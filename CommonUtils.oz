functor
import
   Input
   OS
   Number
   Float
export
   allowedMove:AllowedPosition
   sortValidMoves:SortValidMoves
   distancesTo:DistancesTo
define
   AllowedPosition
   SortValidMoves
   WantedRow
   WantedColumn
   WantedElement
   DistanceBetween
   DistancesTo
in
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
   % X rely on NRow , Y on NColumn
   fun{AllowedPosition Position}
      X = Position.x
      Y = Position.y
   in
      % On sort des limites du double tableau
      if X =< 0 orelse X > Input.nRow orelse Y =< 0 orelse Y > Input.nColumn then
	    false
      else
        % On se prend peut être un mur dans la figure 
	    {WantedElement X Y} == 1
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
        % ici calcul de l'hypoténus comme heuristic ; pas le cours d'IA ici ^^
        % racine de (xA − xB)2 + (yA − yB)2
        {Float.sqrt {IntToFloat ({Number.pow (P1.x - P2.x) 2} + {Number.pow (P1.y - P2.y) 2})} }
   end

   fun{DistancesTo List Target}
      case List
        of H|T then thread {DistanceBetween H Target} end|{DistancesTo T Target}
        [] nil then nil
      end
   end
end