functor
import
   %Pacman000random
   %Ghost000random
   Pacman000other
   Ghost000other
export
   playerGenerator:PlayerGenerator
define
   PlayerGenerator
in
   % Kind is one valid name to describe the wanted player, ID is either the <pacman> ID, either the <ghost> ID corresponding to the player
   fun{PlayerGenerator Kind ID}
      case Kind
      %of pacman000random then {Pacman000random.portPlayer ID}
      %[] ghost000random then {Ghost000random.portPlayer ID}
      of pacman000other then {Pacman000other.portPlayer ID}
      [] ghost000other then {Ghost000other.portPlayer ID}
      end
   end
end
