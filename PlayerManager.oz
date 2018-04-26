functor
import
   Pacman055random
   Ghost055random
   Pacman055other
   Ghost055other
   Pacman055superSmart
export
   playerGenerator:PlayerGenerator
define
   PlayerGenerator
in
   % Kind is one valid name to describe the wanted player, ID is either the <pacman> ID, either the <ghost> ID corresponding to the player
   fun{PlayerGenerator Kind ID}
      case Kind
      of pacman055random then {Pacman055random.portPlayer ID}
      [] ghost055random then {Ghost055random.portPlayer ID}
      [] pacman055other then {Pacman055other.portPlayer ID}
      [] pacman055superSmart then {Pacman055superSmart.portPlayer ID}
      [] ghost055other then {Ghost055other.portPlayer ID}
      end
   end
end
