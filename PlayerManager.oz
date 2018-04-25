functor
import
   Pacman000random
   Ghost000random
   Pacman000other
   Ghost000other
   Pacman000superSmart
export
   playerGenerator:PlayerGenerator
define
   PlayerGenerator
in
   % Kind is one valid name to describe the wanted player, ID is either the <pacman> ID, either the <ghost> ID corresponding to the player
   fun{PlayerGenerator Kind ID}
      case Kind
      of pacman000random then {Pacman000random.portPlayer ID}
      [] ghost000random then {Ghost000random.portPlayer ID}
      [] pacman000other then {Pacman000other.portPlayer ID}
      [] pacman000superSmart then {Pacman000superSmart.portPlayer ID}
      [] ghost000other then {Ghost000other.portPlayer ID}
      end
   end
end
