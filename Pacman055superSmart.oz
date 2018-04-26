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
   CalculateHeuristic
   CalculateHeuristicItems
   CalculateHeuristicPoint
   BestMove
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
  
  %Heuristic: depends on the Mode
  fun {BestMove Moves Ghosts Bonus Answer Points Mode Value}
    TempValue in
    case Moves of H|T then TempValue={CalculateHeuristic H Ghosts Bonus Points Mode}
                            if TempValue > Value then {BestMove T Ghosts Bonus H Points Mode TempValue}%This move is better
                            else {BestMove T Ghosts Bonus Answer Points Mode Value}%The previous move is better
                            end
              [] nil then Answer
    end
  end

  fun {CalculateHeuristic Position Ghosts Bonus Points Mode}
      Temp in
      if Mode == 0 then %Classic
        Temp=10*{CalculateHeuristicItems Position Ghosts 0 0 {List.length Ghosts}}-
        {CalculateHeuristicItems Position Bonus 0 0 {List.length Bonus}}+
        {CalculateHeuristicPoint Position Points}
      else %Hunt
        Temp=~10*{CalculateHeuristicItems Position Ghosts 0 0 {List.length Ghosts}}-
        {CalculateHeuristicItems Position Bonus 0 0 {List.length Bonus}}+
        {CalculateHeuristicPoint Position Points}
      end
      Temp
  end

  %Heuristic about Points
  %Points is the list of points up
  %1 is an arbitrary value to be coherent with other heuristics
  fun {CalculateHeuristicPoint Position Points}
     if {List.member Position Points} then 1
     else 0
     end
  end

  %Heuristic about Items
  %Being at distance d from both items is worse than being at d-1 from item1 and d+1 from item2
  %(Item1+Item2)^2 - (Item1^2 + Item2^2) /NbItem
  fun {CalculateHeuristicItems Position Items Dist1 Dist2 ItemsLength}
  Temp Temp2 Temp3 in
    case Items     
      of H|T then
        case H of target(id:_ position:pt(x:_ y:_)) then Temp = {Mannathan Position H.position}
        else Temp = {Mannathan Position H}
        end
      Temp2= Temp*Temp
      {CalculateHeuristicItems Position T Dist1+Temp Dist2+Temp2 ItemsLength}
     
      [] nil then if (ItemsLength \=0) then 
      Temp3={Float.toInt {Float.ceil {Float.'/' {Int.toFloat (Dist1*Dist1 - Dist2)} {Int.toFloat ItemsLength}}}}
      Temp3
      else
      0
      end
     % Dist1*Dist1 - Dist2%Positive answer
    end
  end

  %Mannathan distance between two positions P1 and P2 of type pt(x:_ y:_)
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
  fun{ChooseNextPosition Mode CurrentPosition Ghosts PositionsBonus PositionsPoints}

    % X = column et Y = row
    CurrentPositionX = CurrentPosition.x
    CurrentPositionY = CurrentPosition.y

    % Possible moves
    Left = pt(x: CurrentPositionX-1 y: CurrentPositionY)
    Right = pt(x: CurrentPositionX+1 y: CurrentPositionY)
    Up = pt(x: CurrentPositionX y: CurrentPositionY-1)
    Down = pt(x: CurrentPositionX y: CurrentPositionY+1)

    %Self Wrapping map
    WrappingMoves = {CommonUtils.wrappingMoves [Left Right Up Down] nil}

    % Valid moves
    ValidMoves = {CommonUtils.sortValidMoves WrappingMoves }
  in
    case Mode
      % Classic: Avoid Ghost, go to the bonuses and favorize points eating
      of classic then      
        %{Delay 500}

        {BestMove ValidMoves Ghosts PositionsBonus.true ValidMoves.1 PositionsPoints.true 0 {CalculateHeuristic ValidMoves.1 Ghosts PositionsBonus.true PositionsPoints.true 0}}


      % Hunt: Go to eat ghost, go to the bonuses and favorize points eating
      [] hunt then
        {BestMove ValidMoves Ghosts PositionsBonus.true ValidMoves.1 PositionsPoints.true 1 {CalculateHeuristic ValidMoves.1 Ghosts PositionsBonus.true PositionsPoints.true 1}}
    end
  end

  % ID is a <pacman> ID
  fun{StartPlayer ID}
      Stream Port
  in
      {NewPort Stream Port}
      thread
	 {TreatStream Stream ID classic 0 playerState(life: Input.nbLives currentScore: 0 spawn: nil currentPosition: nil)
    nil positions(true:nil false:nil) positions(true:nil false:nil)}
      end
      Port
  end
  % has as many parameters as you want
   proc{TreatStream Stream PacmanID Mode OnBoard PlayerState GhostsSpawn PositionsBonus PositionsPoints}
      case Stream 
      of nil then skip
      
      % getId(?ID): Ask the pacman for its <pacman> ID.
      [] getId(ID)|T then
          ID = PacmanID
          {TreatStream T PacmanID Mode OnBoard PlayerState GhostsSpawn PositionsBonus PositionsPoints}
      
      % assignSpawn(P): Assign the <position> P as the spawn of the pacman.
      [] assignSpawn(P)|T then NextPlayerState in
          {Record.adjoinAt PlayerState spawn P NextPlayerState}
          {TreatStream T PacmanID Mode OnBoard NextPlayerState GhostsSpawn PositionsBonus PositionsPoints}
      
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
          {TreatStream T PacmanID Mode 1 NextPlayerState GhostsSpawn PositionsBonus PositionsPoints}
        else
          ID = null
          P = null
          {TreatStream T PacmanID Mode 1 PlayerState GhostsSpawn PositionsBonus PositionsPoints}
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
            NextPosition = {ChooseNextPosition Mode CurrentPosition GhostsSpawn PositionsBonus PositionsPoints}
            % Cela prend un peu de temps donc on va attendre la fin avant de setter P 
            {Wait NextPosition}
            {Record.adjoinAt PlayerState currentPosition NextPosition NextPlayerState}
            % {Browser.browse ID#' A REPONDU '#NextPosition}

            P = NextPosition
            ID = PacmanID
            {TreatStream T PacmanID Mode OnBoard NextPlayerState GhostsSpawn PositionsBonus PositionsPoints}
        else
            P = null
            ID = null
            {TreatStream T PacmanID Mode OnBoard PlayerState  GhostsSpawn PositionsBonus PositionsPoints}
        end
      
      % bonusSpawn(P): Inform that a bonus has spawn at <position> P
      [] bonusSpawn(P)|T then PositionBonusTrue PositionBonusFalse NextPositionsBonusFalse NextPositionsBonus in

        PositionBonusFalse = {List.subtract PositionsBonus.false P} %Enleve le bonus de la liste faux
        PositionBonusTrue = {List.append [P] PositionsBonus.true}% Ajoute le bonus a la liste vrai

        {Record.adjoinAt PositionsBonus false PositionBonusFalse NextPositionsBonusFalse}%Update le record avec false
        {Record.adjoinAt NextPositionsBonusFalse true PositionBonusTrue NextPositionsBonus}%update le record avec vrai

        {TreatStream T PacmanID Mode OnBoard PlayerState GhostsSpawn NextPositionsBonus PositionsPoints}
      
      % pointSpawn(P): Inform that a point has spawn at <position> P
      [] pointSpawn(P)|T then PositionsPointsTrue PositionsPointsFalse NextPositionsPointsFalse NextPositionsPoints in

        PositionsPointsFalse = {List.subtract PositionsPoints.false P} %Enleve le point de la liste faux
        PositionsPointsTrue = {List.append [P] PositionsPoints.true}% Ajoute le point a la liste vrai
        
        {Record.adjoinAt PositionsPoints false PositionsPointsFalse NextPositionsPointsFalse}%Update le record avec false
        {Record.adjoinAt NextPositionsPointsFalse true PositionsPointsTrue NextPositionsPoints}%update le record avec vrai

        {TreatStream T PacmanID Mode OnBoard PlayerState GhostsSpawn PositionsBonus NextPositionsPoints}

      % bonusRemoved(P): Inform that a bonus has disappear from <position> P, doesn’t say who eat it.
      [] bonusRemoved(P)|T then PositionsBonusTrue PositionBonusFalse NextPositionsBonusFalse NextPositionsBonus in
        PositionBonusFalse = {List.append [P] PositionsBonus.false} %Enleve le bonus de la liste faux
        PositionsBonusTrue = {List.subtract PositionsBonus.true P}% Ajoute le bonus a la liste vrai
        
        {Record.adjoinAt PositionsBonus false PositionBonusFalse NextPositionsBonusFalse}%Update le record avec false
        {Record.adjoinAt NextPositionsBonusFalse true PositionsBonusTrue NextPositionsBonus}%update le record avec vrai
       
        {TreatStream T PacmanID Mode OnBoard PlayerState GhostsSpawn NextPositionsBonus PositionsPoints}
      
      % pointRemoved(P): Inform that a point has disappear from <position> P, doesn’t say who eat it.
      [] pointRemoved(P)|T then PositionsPointsTrue PositionsPointsFalse NextPositionsPointsFalse NextPositionsPoints in
        PositionsPointsFalse = {List.append [P] PositionsPoints.false} %Enleve le bonus de la liste faux
        PositionsPointsTrue = {List.subtract PositionsPoints.true P}% Ajoute le bonus a la liste vrai
        
        {Record.adjoinAt PositionsPoints false PositionsPointsFalse NextPositionsPointsFalse}%Update le record avec false
        {Record.adjoinAt NextPositionsPointsFalse true PositionsPointsTrue NextPositionsPoints}%update le record avec vrai
        
        {TreatStream T PacmanID Mode OnBoard PlayerState GhostsSpawn PositionsBonus NextPositionsPoints}

      % addPoint(Add ?ID ?NewScore): Inform that the pacman has gain the number of points given
      % in Add, and ask you your <pacman> ID and the NewScore you have.
      [] addPoint(Add ID NewScore)|T then NextPlayerState in
        NewScore = PlayerState.currentScore + Add
        ID = PacmanID
        {Record.adjoinAt PlayerState currentScore NewScore NextPlayerState}
        {TreatStream T PacmanID Mode OnBoard NextPlayerState GhostsSpawn PositionsBonus PositionsPoints}

      % gotKilled(?ID ?NewLife ?NewScore): Inform that the pacman has lost a life and pass it out
      % of the board. Ask him its <pacman> ID, its new number of lives in NewLife and its new score
      % (as you lose point when been killed). This action makes the pacman in a dead state.
      [] gotKilled(ID NewLife NewScore)|T then NextPlayerState in
        NewScore = PlayerState.currentScore - Input.penalityKill
        NewLife = PlayerState.life - 1
        ID = PacmanID
        {Record.adjoinList PlayerState [currentScore#NewScore life#NewLife] NextPlayerState}
        {TreatStream T PacmanID Mode 0 NextPlayerState nil PositionsBonus PositionsPoints}
      
      % ghostPos(ID P): Inform that the ghost with <ghost> ID is now at <position> P.
      [] ghostPos(ID P)|T then
        {TreatStream T PacmanID Mode OnBoard PlayerState
        {TargetsStateModification GhostsSpawn update(ID P)} PositionsBonus PositionsPoints}

      % killGhost(IDg ?IDp ?NewScore): Inform that the ghost with <ghost> IDg has been killed by you. 
      % Ask you your <pacman> IDp back and your NewScore (since killing a ghost make you gain points).
      [] killGhost(IDg IDp NewScore)|T then NextPlayerState in
        NewScore = PlayerState.currentScore + Input.rewardKill
        IDp = PacmanID
        {Record.adjoinAt PlayerState currentScore NewScore NextPlayerState}
        {TreatStream T PacmanID Mode OnBoard NextPlayerState   
        {TargetsStateModification GhostsSpawn remove(IDg)} PositionsBonus PositionsPoints}
        
      % deathGhost(ID): Inform that the ghost with <ghost> ID has been killed (by someone, you or another pacman).
      [] deathGhost(ID)|T then
        {TreatStream T PacmanID Mode OnBoard PlayerState 
        {TargetsStateModification GhostsSpawn remove(ID)} PositionsBonus PositionsPoints}

      % setMode(M): Inform the new <mode> M.
      [] setMode(M)|T then
        {TreatStream T PacmanID M OnBoard PlayerState GhostsSpawn PositionsBonus PositionsPoints}

      [] M|T then
        {Browser.browse 'unsupported message from pacman'#M}
        {TreatStream T PacmanID Mode OnBoard PlayerState  GhostsSpawn PositionsBonus PositionsPoints}
      end
   end
end
