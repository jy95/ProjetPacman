functor
import
   Input
   Browser
   CommonUtils
export
   portPlayer:StartPlayer
define
   Mannathan
   StartPlayer
   TreatStream
   ChooseNextPosition
   TargetsStateModification
   CalculateHeuristicClassic
   CalculateHeuristicHunt
   CalculateHeuristicBonus
   CalculateHeuristicGhost
   CalculateHeuristicPoint
   BestMoveClassic
   BestMoveHunt
in

  % To handle new ghost or position of current ghost(s)
   % Action : 'update' / 'remove' for the current state
   % ID Position : Action attributes (for update both, for remove only ID)
   % Each element is only present once
   fun{TargetsStateModification GhostsPosition Action}
        case Action
            of update(ID POSITION) then
                case GhostsPosition
                    of nil then target(id: ID position: POSITION)|nil
                    [] target(id: IG position:_)|T then
                        if thread IG == ID end then
                            target(id: ID position: POSITION)|T
                        else
                            GhostsPosition.1|{TargetsStateModification T Action}
                        end
                end
            [] remove(ID) then
                case GhostsPosition
                    of nil then nil
                    [] target(id: IG position:_)|T then
                        if thread IG == ID end then
                            T
                        else
                            GhostsPosition.1|{TargetsStateModification T Action}
                        end
                end
        end
   end
  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %Heuristic: Avoid Ghost, go in the direction of the bonuses, try eating points
  fun {BestMoveClassic Moves Ghosts Bonus Answer Value}
    TempValue in
    case Moves of H|T then TempValue={CalculateHeuristicClassic H Ghosts Bonus}
                            if TempValue > Value then {BestMoveClassic T Ghosts Bonus H TempValue}
                            else {BestMoveClassic T Ghosts Bonus Answer Value}
                            end
              [] nil then Answer
    end
  end

  %Heuristic: Avoid Ghost, go in the direction of the bonuses, try eating points
  fun {BestMoveHunt Moves Ghosts Bonus Answer Value}
    TempValue in
    case Moves of H|T then TempValue={CalculateHeuristicHunt H Ghosts Bonus}
                            if TempValue > Value then {BestMoveHunt T Ghosts Bonus H TempValue}
                            else {BestMoveHunt T Ghosts Bonus Answer Value}
                            end
              [] nil then Answer
    end
  end

  fun {CalculateHeuristicHunt Position Ghosts Bonus}
      Temp in
      Temp=~{CalculateHeuristicGhost Position Ghosts 0}+
      {CalculateHeuristicBonus Position Bonus 0 0}+
      {CalculateHeuristicPoint Position}
      Temp
  end
  
  fun {CalculateHeuristicClassic Position Ghosts Bonus}
      Temp in
      Temp={CalculateHeuristicGhost Position Ghosts 0}+
      {CalculateHeuristicBonus Position Bonus 0 0}+
      {CalculateHeuristicPoint Position}
      Temp
  end

  %Heuristic about Points
  fun {CalculateHeuristicPoint Position}
    % {Value.hasFeature Points PositionAsInt} andthen Points.PositionAsInt == true ?
    %TODO
    0
  end

  %Heuristic about Ghost
  %H(x)^2 to be logical with other heuristics
  fun {CalculateHeuristicGhost Position Ghosts Answer}
    case Ghosts 
      of H|T then 
      {CalculateHeuristicGhost Position T Answer+{Mannathan Position H.position}}
      [] nil then Answer*Answer %Positive answer
    end
  end

  %Heuristic about Bonus
  %(Bonus1+Bonus2)^2 - (Bonus1^2 + Bonus2^2)
  fun {CalculateHeuristicBonus Position Bonus Dist1 Dist2}
  Temp Temp2 in
    case Bonus     
      of H|T then
      Temp = {Mannathan Position H}
      Temp2= Temp*Temp
      {CalculateHeuristicBonus Position T Dist1+Temp Dist2+Temp2}
      [] nil then ~(Dist1*Dist1 - Dist2) %Negative answer
    end
  end

  fun{Mannathan P1 P2}
    Temp1 Temp2 in
      if P1.x>P2.x then Temp1 = P1.x-P2.x
      else Temp1 = P2.x-P1.x
      end
      if P1.y>P2.y then Temp2 = P1.y-P2.y
      else Temp2 = P2.y-P1.y
      end
      Temp1+Temp2
  end

   % A determinist way to decide which position should be taken by our pacman
  fun{ChooseNextPosition Mode CurrentPosition Points Ghosts PositionsBonus}
    {Browser.browse PositionsBonus}
    % X = column et Y = row
    CurrentPositionX = CurrentPosition.x
    CurrentPositionY = CurrentPosition.y
    % les mouvements possibles
    Left = pt(x: CurrentPositionX-1 y: CurrentPositionY)
    Right = pt(x: CurrentPositionX+1 y: CurrentPositionY)
    Up = pt(x: CurrentPositionX y: CurrentPositionY-1)
    Down = pt(x: CurrentPositionX y: CurrentPositionY+1)

    WrappingMoves = {CommonUtils.wrappingMoves [Left Right Up Down] nil}

    % seulement les mouvement valides
    ValidMoves = {CommonUtils.sortValidMoves WrappingMoves }
  in
    % Retrieve all the positions hold by ghost
    case Mode
      % in classical mode : take the best bonus available if there is no ghost in this
      of classic then
        
        {Delay 500}
        %{Delay 50}
        {BestMoveClassic ValidMoves Ghosts PositionsBonus.true ValidMoves.1 {CalculateHeuristicClassic ValidMoves.1 Ghosts PositionsBonus.true}}
        %{BestBonusAvailable ValidMoves Points Bonus Ghosts 0 CurrentPosition}
      % in hunt mode : simply eat the closest ghost to us
      [] hunt then
        {BestMoveHunt ValidMoves Ghosts PositionsBonus.true ValidMoves.1 {CalculateHeuristicHunt ValidMoves.1 Ghosts PositionsBonus.true}}
    end
  end

  % ID is a <pacman> ID
  fun{StartPlayer ID}
      Stream Port
  in
      {NewPort Stream Port}
      thread
	 {TreatStream Stream ID classic 0 playerState(life: Input.nbLives currentScore: 0 spawn: nil currentPosition: nil) 
   points() nil positions(true:nil false:nil)}
      end
      Port
  end
  % has as many parameters as you want
   proc{TreatStream Stream PacmanID Mode OnBoard PlayerState PointsSpawn  GhostsSpawn PositionsBonus}
      case Stream 
      of nil then skip
      
      % getId(?ID): Ask the pacman for its <pacman> ID.
      [] getId(ID)|T then
          ID = PacmanID
          {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn GhostsSpawn PositionsBonus}
      
      % assignSpawn(P): Assign the <position> P as the spawn of the pacman.
      [] assignSpawn(P)|T then NextPlayerState in
          {Record.adjoinAt PlayerState spawn P NextPlayerState}
          {TreatStream T PacmanID Mode OnBoard NextPlayerState PointsSpawn GhostsSpawn PositionsBonus}
      
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
          {TreatStream T PacmanID Mode 1 NextPlayerState PointsSpawn GhostsSpawn PositionsBonus}
        else
          ID = null
          P = null
          {TreatStream T PacmanID Mode 1 PlayerState PointsSpawn GhostsSpawn PositionsBonus}
        end

      % move(?ID ?P): Ask the pacman to chose its next <position> P (pacman is thus aware of its
      % new position). It should also give its <pacman> ID back in the message. This action is only done
      % if the pacman is considered alive, if not, ID and P should be bound to null.
      [] move(ID P)|T then
        if OnBoard == 1 andthen PlayerState.life > 0 then CurrentPosition NextPosition NextPlayerState in
            % si on joue en simultané, il faut attendre un temps random avant de répondre
            if Input.isTurnByTurn == false then
              {Delay {CommonUtils.randomNumber Input.thinkMin Input.thinkMax} }
            end
            CurrentPosition = PlayerState.currentPosition
            % On choisit la prochaine destination
            NextPosition = {ChooseNextPosition Mode CurrentPosition PointsSpawn GhostsSpawn PositionsBonus}
            % Cela prend un peu de temps donc on va attendre la fin avant de setter P 
            {Wait NextPosition}
            {Record.adjoinAt PlayerState currentPosition NextPosition NextPlayerState}
            % {Browser.browse ID#' A REPONDU '#NextPosition}

            P = NextPosition
            ID = PacmanID
            {TreatStream T PacmanID Mode OnBoard NextPlayerState PointsSpawn GhostsSpawn PositionsBonus}
        else
            P = null
            ID = null
            {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn GhostsSpawn PositionsBonus}
        end
      
      % bonusSpawn(P): Inform that a bonus has spawn at <position> P
      [] bonusSpawn(P)|T then PositionBonusTrue PositionBonusFalse NextPositionsBonusFalse NextPositionsBonus in
        %TODO
        PositionBonusFalse = {List.subtract PositionsBonus.false P} %Enleve le bonus de la liste faux
        PositionBonusTrue = {List.append [P] PositionsBonus.true}% Ajoute le bonus a la liste vrai
        %
        {Record.adjoinAt PositionsBonus false PositionBonusFalse NextPositionsBonusFalse}%Update le record avec false
        {Record.adjoinAt NextPositionsBonusFalse true PositionBonusTrue NextPositionsBonus}%update le record avec vrai

        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn GhostsSpawn NextPositionsBonus}
      
      % pointSpawn(P): Inform that a point has spawn at <position> P
      [] pointSpawn(P)|T then NextPointSpawn in
        {Record.adjoinAt PointsSpawn {CommonUtils.positionToInt P} true NextPointSpawn}
        {TreatStream T PacmanID Mode OnBoard PlayerState NextPointSpawn GhostsSpawn PositionsBonus}

      % bonusRemoved(P): Inform that a bonus has disappear from <position> P, doesn’t say who eat it.
      [] bonusRemoved(P)|T then PositionBonusTrue PositionBonusFalse NextPositionsBonusFalse NextPositionsBonus in
        %TODO
        PositionBonusFalse = {List.append [P] PositionsBonus.false} %Enleve le bonus de la liste faux
        PositionBonusTrue = {List.subtract PositionsBonus.true P}% Ajoute le bonus a la liste vrai
        %
        {Record.adjoinAt PositionsBonus false PositionBonusFalse NextPositionsBonusFalse}%Update le record avec false
        {Record.adjoinAt NextPositionsBonusFalse true PositionBonusTrue NextPositionsBonus}%update le record avec vrai
       
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn GhostsSpawn NextPositionsBonus}
      
      % pointRemoved(P): Inform that a point has disappear from <position> P, doesn’t say who eat it.
      [] pointRemoved(P)|T then NextPointSpawn in
        {Record.adjoinAt PointsSpawn {CommonUtils.positionToInt P} false NextPointSpawn}
        {TreatStream T PacmanID Mode OnBoard PlayerState NextPointSpawn GhostsSpawn PositionsBonus}

      % addPoint(Add ?ID ?NewScore): Inform that the pacman has gain the number of points given
      % in Add, and ask you your <pacman> ID and the NewScore you have.
      [] addPoint(Add ID NewScore)|T then NextPlayerState in
        NewScore = PlayerState.currentScore + Add
        ID = PacmanID
        {Record.adjoinAt PlayerState currentScore NewScore NextPlayerState}
        {TreatStream T PacmanID Mode OnBoard NextPlayerState PointsSpawn GhostsSpawn PositionsBonus}

      % gotKilled(?ID ?NewLife ?NewScore): Inform that the pacman has lost a life and pass it out
      % of the board. Ask him its <pacman> ID, its new number of lives in NewLife and its new score
      % (as you lose point when been killed). This action makes the pacman in a dead state.
      [] gotKilled(ID NewLife NewScore)|T then NextPlayerState in
        NewScore = PlayerState.currentScore - Input.penalityKill
        NewLife = PlayerState.life - 1
        ID = PacmanID
        {Record.adjoinList PlayerState [currentScore#NewScore life#NewLife] NextPlayerState}
        {TreatStream T PacmanID Mode 0 NextPlayerState PointsSpawn nil PositionsBonus}
      
      % ghostPos(ID P): Inform that the ghost with <ghost> ID is now at <position> P.
      [] ghostPos(ID P)|T then
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn 
        {TargetsStateModification GhostsSpawn update(ID P)} PositionsBonus}

      % killGhost(IDg ?IDp ?NewScore): Inform that the ghost with <ghost> IDg has been killed by you. 
      % Ask you your <pacman> IDp back and your NewScore (since killing a ghost make you gain points).
      [] killGhost(IDg IDp NewScore)|T then NextPlayerState in
        NewScore = PlayerState.currentScore + Input.rewardKill
        IDp = PacmanID
        {Record.adjoinAt PlayerState currentScore NewScore NextPlayerState}
        {TreatStream T PacmanID Mode OnBoard NextPlayerState PointsSpawn  
        {TargetsStateModification GhostsSpawn remove(IDg)} PositionsBonus}
        
      % deathGhost(ID): Inform that the ghost with <ghost> ID has been killed (by someone, you or another pacman).
      [] deathGhost(ID)|T then
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn  
        {TargetsStateModification GhostsSpawn remove(ID)} PositionsBonus}

      % setMode(M): Inform the new <mode> M.
      [] setMode(M)|T then
        {TreatStream T PacmanID M OnBoard PlayerState PointsSpawn GhostsSpawn PositionsBonus}

      [] M|T then
        {Browser.browse 'unsupported message from pacman'#M}
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn  GhostsSpawn PositionsBonus}
      end
   end
end
