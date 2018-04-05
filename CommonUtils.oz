functor
import
   Input
   OS
export
    allowedMove:AllowedPosition
define
    AllowedPosition
in
   % A way to access the wanted NRow I want
   fun{WantedRow List LineNumber}
        if LineNumber == 0 then List.1 else {WantedRow List.2 LineNumber-1} end
   end
   
   % A way to access the wanted NColumn I want
   fun{WantedColumn List ColumnNumber}
        if ColumnNumber == 0 then List.1 else {WantedColumn List.2 ColumnNumber-1} end
   end
   
   % Combine them to got the element I want
   fun{WantedElement X Y}
        {WantedColumn {WantedRow Input.map X} Y}
   end

   % A way to detect if a position is allowed - boolean type exists :)
   % X rely on NRow , Y on NColumn
   fun{AllowedPosition X Y}
        % On sort des limites du double tableau
        if X < 0 orelse X > Input.nRow orelse Y < 0 orelse Y > Input.nColumn then
            false
        % On se prend un mur dans la figure
        elseif {WantedElement X Y} == 1 then
            false
        else
            true
        end
   end

end