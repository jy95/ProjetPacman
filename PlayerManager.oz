functor
import
   Pacman055random
   Ghost055random
   Pacman055other
   Ghost055other
   Pacman055superSmart


   % Les joueurs des autres groupes
   Pacman080chaser
   Ghost080chaser
   Pacman001other
   Ghost001other

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
     

      % Les joueurs des autres groupes
      [] pacman080chaser then {Pacman080chaser.portPlayer ID}
      [] ghost080chaser then {Ghost080chaser.portPlayer ID}
      [] ghost001other then {Ghost001other.portPlayer ID}
      [] pacman001other then {Pacman001other.portPlayer ID}
      end
   end
end
