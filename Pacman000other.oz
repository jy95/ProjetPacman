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

      % addPoint(Add ?ID ?NewScore): Inform that the pacman has gain the number of points given
      % in Add, and ask you your <pacman> ID and the NewScore you have.
      [] addPoint(Add ID NewScore)|T then NextPlayerState in
        NewScore = PlayerState.currentScore + Add
        ID = PacmanID
        {Record.adjoinAt PlayerState currentScore NewScore NextPlayerState}
        {TreatStream T PacmanID Mode OnBoard NextPlayerState PointsSpawn BonusSpawn GhostsSpawn}

      % gotKilled(?ID ?NewLife ?NewScore): Inform that the pacman has lost a life and pass it out
      % of the board. Ask him its <pacman> ID, its new number of lives in NewLife and its new score
      % (as you lose point when been killed). This action makes the pacman in a dead state.
      [] gotKilled(ID NewLife NewScore)|T then NextPlayerState in
        NewScore = PlayerState.currentScore - Input.penalityKill
        NewLife = PlayerState.life - 1
        ID = PacmanID
        {Record.adjoinList PlayerState [currentScore#NewScore life#NewLife] NextPlayerState}
        {TreatStream T PacmanID Mode 0 NextPlayerState PointsSpawn BonusSpawn GhostsSpawn}
      
      % ghostPos(ID P): Inform that the ghost with <ghost> ID is now at <position> P.
      [] ghostPos(ID P)|T then NewGhostsSpawn in
        {Record.adjoinAt PlayerState ID P NewGhostsSpawn}
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn BonusSpawn NewGhostsSpawn}

      % killGhost(IDg ?IDp ?NewScore): Inform that the ghost with <ghost> IDg has been killed by you. 
      % Ask you your <pacman> IDp back and your NewScore (since killing a ghost make you gain points).
      [] killGhost(IDg IDp NewScore)|T then NewGhostsSpawn NextPlayerState in
        {Record.subtract GhostsSpawn IDg NewGhostsSpawn}
        NewScore = PlayerState.currentScore + Input.rewardKill
        IDp = PacmanID
        {Record.adjoinAt PlayerState currentScore NewScore NextPlayerState}
        {TreatStream T PacmanID Mode OnBoard NextPlayerState PointsSpawn BonusSpawn NewGhostsSpawn}

      % deathGhost(ID): Inform that the ghost with <ghost> ID has been killed (by someone, you or another pacman).
      [] deathGhost(ID)|T then NewGhostsSpawn in
        {Record.subtract GhostsSpawn ID NewGhostsSpawn}
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn BonusSpawn NewGhostsSpawn}

      % setMode(M): Inform the new <mode> M.
      [] setMode(M)|T then
        {TreatStream T PacmanID M OnBoard PlayerState PointsSpawn BonusSpawn GhostsSpawn}

      [] M|T then
        {Browser.browse 'unsupported message'#M}
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn BonusSpawn GhostsSpawn}
      end
   end
end
