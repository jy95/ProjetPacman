functor
import
   Pacman000random
   Ghost000random
   Pacman055other
   Ghost055other
   Pacman055superSmart
   Pacman055superShy

   % Les joueurs des autres groupes
   Pacman080chaser
   Ghost080chaser
   Pacman001other
   Ghost001other
   Ghost061other
   Pacman061human
   Pacman061other

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
      [] pacman055other then {Pacman055other.portPlayer ID}
      [] pacman055superSmart then {Pacman055superSmart.portPlayer ID}
      [] ghost055other then {Ghost055other.portPlayer ID}
      [] pacman055superShy then {Pacman055superShy.portPlayer ID}
     

      % Les joueurs des autres groupes
      [] pacman080chaser then {Pacman080chaser.portPlayer ID}
      [] ghost080chaser then {Ghost080chaser.portPlayer ID}
      [] ghost001other then {Ghost001other.portPlayer ID}%groupe85
      [] pacman001other then {Pacman001other.portPlayer ID}
      [] pacman061other then {Pacman061other.portPlayer ID}
      [] ghost061other then {Ghost061other.portPlayer ID}
      [] pacman061human then {Pacman061human.portPlayer ID}
      end
   end
end
