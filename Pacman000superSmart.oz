functor
import
   Input
   Browser
   CommonUtils
export
   portPlayer:StartPlayer
define
   Mannathan
   PositionExtractor
   FilterTile
   StartPlayer
   TreatStream
   ChooseNextPosition
   BestBonusAvailable
   ClosestGhost
   CheckFct
   TargetsStateModification
   CalculateHeuristic
   CalculateHeuristicBonus
   CalculateHeuristicGhost
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

  % Genericity function : just for checking if a position is in a list
  fun{CheckFct P}
    fun{$ X}
      X.position == P
    end
  end

  % ValidMoves : all the valid moves
  % Inputs : Points Bonus - the records that contains info for current situation
  % Inputs : Ghost - the list of positions hold by ghosts 
  % BestScore BestPosition are temp variable just for treattment
  fun{BestBonusAvailable ValidMoves Points Bonus Ghosts BestScore BestPosition}
    case ValidMoves
      of nil then BestPosition
      [] P|T then PositionAsInt in
        PositionAsInt = {CommonUtils.positionToInt P}
        % If there no ghosts and has reward better than previous one
        if {List.some Ghosts {CheckFct P} } == false then
          if {Value.hasFeature Bonus PositionAsInt} andthen Bonus.PositionAsInt == true then
            % RewardKill car il pourrait killer un ghost après avoir pris ce bonus
            {BestBonusAvailable T Points Bonus Ghosts Input.rewardKill P}
          elseif {Value.hasFeature Points PositionAsInt} andthen Points.PositionAsInt == true andthen Input.rewardPoint > BestScore then
            {BestBonusAvailable T Points Bonus Ghosts Input.rewardPoint P} 
          else
            {BestBonusAvailable T Points Bonus Ghosts BestScore BestPosition}
          end
        else
          {BestBonusAvailable T Points Bonus Ghosts BestScore BestPosition}
        end
    end
  end

  fun{ClosestGhost ValidMoves Ghost BestMove}
    case ValidMoves
      of nil then BestMove
      [] P|_ then
        % On n'utilise uniquement que le premier move autorisé - histoire d'avoir un comportement random
        P
    end
  end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %Heuristic: Avoid Ghost, go in the direction of the bonuses, try eating points
  fun {BestMove Moves Ghosts Bonus Answer Value}
    TempValue in
    case Moves of H|T then TempValue={CalculateHeuristic H Ghosts Bonus}
                            if TempValue > Value then {BestMove T Ghosts Bonus H TempValue}
                            else {BestMove T Ghosts Bonus Answer Value}
                            end
              [] nil then Answer
    end
  end
  
  fun {CalculateHeuristic Position Ghosts Bonus}
      Temp in
      Temp={CalculateHeuristicGhost Position Ghosts 0}+
      {CalculateHeuristicBonus Position Bonus 0}+
      {CalculateHeuristicPoint Position}
      %{Browser.browse Temp}
      Temp
  end


  %Heuristic about Points
  fun {CalculateHeuristicPoint Position}
    % {Value.hasFeature Points PositionAsInt} andthen Points.PositionAsInt == true ?
    %TODO
    0
  end

  %Heuristic about Ghost
  fun {CalculateHeuristicGhost Position Ghosts Answer}
    case Ghosts 
      of H|T then 
      
      0
      %{CalculateHeuristicGhost Position T Answer+{CommonUtils.distanceBetween Position Position}}
      [] nil then Answer %Positive answer
    end
  end

  %Heuristic about Bonus
  fun {CalculateHeuristicBonus Position Bonus Answer}
  Temp in
    case Bonus
     
      of H|T then
      Temp = {Mannathan Position H}
      {CalculateHeuristicBonus Position T Answer-Temp}
      [] nil then Answer %Negative answser
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
  fun{ChooseNextPosition Mode CurrentPosition Points Bonus Ghosts}
    % X = column et Y = row
    CurrentPositionX = CurrentPosition.x
    CurrentPositionY = CurrentPosition.y
    % les mouvements possibles
    Left = pt(x: CurrentPositionX-1 y: CurrentPositionY)
    Right = pt(x: CurrentPositionX+1 y: CurrentPositionY)
    Up = pt(x: CurrentPositionX y: CurrentPositionY-1)
    Down = pt(x: CurrentPositionX y: CurrentPositionY+1)
  %  {Browser.browse "WrapBefore"}
  %  {Browser.browse [Left Right Up Down]}


    WrappingMoves = {CommonUtils.wrappingMoves [Left Right Up Down] nil}
   % {Browser.browse "WrapAfter"}
   % {Browser.browse WrappingMoves}
    % seulement les mouvement valides
    ValidMoves = {CommonUtils.sortValidMoves WrappingMoves }
    ExplorerMap
    Bonuses
  in
    % Retrieve all the positions hold by ghost
    case Mode
      % in classical mode : take the best bonus available if there is no ghost in this
      of classic then
        
        %{Delay 50}
        ExplorerMap = thread {PositionExtractor Input.map 1} end
        Bonuses= {FilterTile ExplorerMap fun{$ E} E == 4 end }
        %{Browser.browse Bonuses}
        %{Delay 50}
        {BestMove ValidMoves Ghosts Bonuses ValidMoves.1 {CalculateHeuristic ValidMoves.1 Ghosts Bonuses}}
        %{BestBonusAvailable ValidMoves Points Bonus Ghosts 0 CurrentPosition}
      % in hunt mode : simply eat the closest ghost to us
      [] hunt then
        {ClosestGhost ValidMoves Ghosts CurrentPosition}
    end
  end

  % Filtering tile
   fun{FilterTile S F}
        case S
            of nil then nil
            [] H|T then
                case H
                    of Val#Position then
                        if thread {F Val} end then
                            Position|{FilterTile T F}
                        else
                            {FilterTile T F}
                        end
                    else
                        % no match
                        {FilterTile T F}
                end
        end
   end

   % Explorer each tile of the map to extract information - maybe in the stream way later
   fun{PositionExtractor Map CurrentRow}
        fun{ExtractRow List Row Column}
            case List
                of nil then nil
                [] H|T then H#pt(x: Column y: Row)|{ExtractRow T Row Column+1}
            end
        end
        fun {Append Xs Ys}
            case Xs of nil then Ys
            [] X|Xr then X|{Append Xr Ys}
            end
        end
   in
        case Map
            of nil then nil
            [] H|T then
                {Append {ExtractRow H CurrentRow 1} {PositionExtractor T CurrentRow+1}}
        end 
   end

  % ID is a <pacman> ID
  fun{StartPlayer ID}
      Stream Port
  in
      {NewPort Stream Port}
      thread
	 {TreatStream Stream ID classic 0 playerState(life: Input.nbLives currentScore: 0 spawn: nil currentPosition: nil) 
   points() bonus() nil}
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
            % si on joue en simultané, il faut attendre un temps random avant de répondre
            if Input.isTurnByTurn == false then
              {Delay {CommonUtils.randomNumber Input.thinkMin Input.thinkMax} }
            end
            CurrentPosition = PlayerState.currentPosition
            % On choisit la prochaine destination
            NextPosition = {ChooseNextPosition Mode CurrentPosition PointsSpawn BonusSpawn GhostsSpawn}
            % Cela prend un peu de temps donc on va attendre la fin avant de setter P 
            {Wait NextPosition}
            {Record.adjoinAt PlayerState currentPosition NextPosition NextPlayerState}
            % {Browser.browse ID#' A REPONDU '#NextPosition}

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
        {TreatStream T PacmanID Mode 0 NextPlayerState PointsSpawn BonusSpawn nil}
      
      % ghostPos(ID P): Inform that the ghost with <ghost> ID is now at <position> P.
      [] ghostPos(ID P)|T then
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn BonusSpawn 
        {TargetsStateModification GhostsSpawn update(ID P)}}

      % killGhost(IDg ?IDp ?NewScore): Inform that the ghost with <ghost> IDg has been killed by you. 
      % Ask you your <pacman> IDp back and your NewScore (since killing a ghost make you gain points).
      [] killGhost(IDg IDp NewScore)|T then NextPlayerState in
        NewScore = PlayerState.currentScore + Input.rewardKill
        IDp = PacmanID
        {Record.adjoinAt PlayerState currentScore NewScore NextPlayerState}
        {TreatStream T PacmanID Mode OnBoard NextPlayerState PointsSpawn BonusSpawn 
        {TargetsStateModification GhostsSpawn remove(IDg)}}
        
      % deathGhost(ID): Inform that the ghost with <ghost> ID has been killed (by someone, you or another pacman).
      [] deathGhost(ID)|T then
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn BonusSpawn 
        {TargetsStateModification GhostsSpawn remove(ID)}}

      % setMode(M): Inform the new <mode> M.
      [] setMode(M)|T then
        {TreatStream T PacmanID M OnBoard PlayerState PointsSpawn BonusSpawn GhostsSpawn}

      [] M|T then
        {Browser.browse 'unsupported message from pacman'#M}
        {TreatStream T PacmanID Mode OnBoard PlayerState PointsSpawn BonusSpawn GhostsSpawn}
      end
   end
end
