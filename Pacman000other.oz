functor
import
   Input
   Browser
   Record
   CommonUtils
export
   portPlayer:StartPlayer
define   
   StartPlayer
   TreatStream
   ExplorerMap
in
  % ID is a <pacman> ID
   fun{StartPlayer ID}
      Stream Port
   in
      {NewPort Stream Port}
      ExplorerMap = thread {CommonUtils.positionExtractor Input.map 0} end
      thread
	 {TreatStream Stream ID classic 0 playerState(life: Input.nbLives currentScore: 0 spawn: nil currentPosition: nil) 
   points() bonus() ghosts()}
      end
      Port
   end
  % has as many parameters as you want
   proc{TreatStream Stream PacmanID Mode OnBoard PlayerState PointsSpawn BonusSpawn GhostsSpawn}
      case Stream 
      of nil then skip
      
      % getId(?ID): Ask the pacman for its <pacman> ID.
      [] getId(ID)|T then
          ID = PacmanID
          {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn BonusSpawn GhostsSpawn}
      
      % assignSpawn(P): Assign the <position> P as the spawn of the pacman.
      [] assignSpawn(P)|T then NextPlayerState in
          {Record.adjoinAt PlayerState spawn P NextPlayerState}
          {TreatStream T PacmanID Mode OnBoard NextPlayerState PointsSpawn BonusSpawn GhostsSpawn}
      
      % spawn(?ID ?P): Spawn the pacman on the board. The pacman should answer its <pacman> ID
      % and its <position> P (which should be the same as the one assigned as spawn. This action is
      % only done if the pacman is not on the board and has still lives. It places the pacman on the
      % board. ID and P should be bound to null if the pacman is not able to spawn (no more lives back).
      [] spawn(ID P)|T then
        if OnBoard == 0 andthen PlayerState.life > 0 then Position NextPlayerState in
          Position = PlayerState.spawn
          % spawn devient notre position courante
          {Record.adjoinAt PlayerState currentPosition Position NextPlayerState}
          ID = PacmanID
          P = Position
          {TreatStream T PacmanID Mode 1 NextPlayerState PointsSpawn BonusSpawn GhostsSpawn}
        else
          ID = null
          P = null
          {TreatStream T PacmanID Mode 1 PlayerState PointsSpawn BonusSpawn GhostsSpawn}
        end

      % move(?ID ?P): Ask the pacman to chose its next <position> P (pacman is thus aware of its
      % new position). It should also give its <pacman> ID back in the message. This action is only done
      % if the pacman is considered alive, if not, ID and P should be bound to null.
      [] move(ID P)|T then
        if OnBoard == 1 andthen PlayerState.life > 0 then CurrentPosition NextPosition NextPlayerState in
            CurrentPosition = PlayerState.currentPosition
            % On choisit la prochaine destination
            % TODO à finir ; juste pas enfin aujourd'hui de faire la fonction
            NextPosition = pt(x: 1 y: 1)
            % Cela prend un peu de temps donc on va attendre la fin avant de setter P 
            {Wait NextPosition}
            {Record.adjoinAt PlayerState currentPosition NextPosition NextPlayerState}
            P = NextPosition
            ID = PacmanID
            {TreatStream T PacmanID Mode OnBoard NextPlayerState PointsSpawn BonusSpawn GhostsSpawn}
        else
            P = null
            ID = null
            {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn BonusSpawn GhostsSpawn}
        end
      
      % bonusSpawn(P): Inform that a bonus has spawn at <position> P
      [] bonusSpawn(P)|T then NextBonusSpawn in
        {Record.adjoinAt BonusSpawn {CommonUtils.positionToInt P} true NextBonusSpawn}
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn NextBonusSpawn GhostsSpawn}
      
      % pointSpawn(P): Inform that a point has spawn at <position> P
      [] pointSpawn(P)|T then NextPointSpawn in
        {Record.adjoinAt PointsSpawn {CommonUtils.positionToInt P} true NextPointSpawn}
        {TreatStream T PacmanID Mode OnBoard PlayerState NextPointSpawn BonusSpawn GhostsSpawn}

      % bonusRemoved(P): Inform that a bonus has disappear from <position> P, doesn’t say who eat it.
      [] bonusRemoved(P)|T then NextBonusSpawn in
        {Record.adjoinAt BonusSpawn {CommonUtils.positionToInt P} false NextBonusSpawn}
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn NextBonusSpawn GhostsSpawn}
      
      % pointRemoved(P): Inform that a point has disappear from <position> P, doesn’t say who eat it.
      [] pointRemoved(P)|T then NextPointSpawn in
        {Record.adjoinAt PointsSpawn {CommonUtils.positionToInt P} false NextPointSpawn}
        {TreatStream T PacmanID Mode OnBoard PlayerState NextPointSpawn BonusSpawn GhostsSpawn}

      [] M|T then
        {Browser.browse 'unsupported message'#M}
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn BonusSpawn GhostsSpawn}
      end
   end
end
