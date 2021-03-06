//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

contract Tournament{
    
    uint256 public idCntr=0;
    
    struct tournamentInfo{
        uint startTime;
        uint endTime;
        uint256 entryFee;
        uint256 reward;
        uint256 rewardToAdmin;
        address tournamentAdmin;
        address winnerAddress;
        uint256 noOfParticipants;
        bool iscancelled;
    }
    
    mapping (uint256=>tournamentInfo) public tournament;
    
    mapping (uint256=>mapping(address=> bool)) public tournamentJoined;
    
    mapping (uint256=>address[]) participantsAddress;
    
    mapping(address=>uint256[]) addressToTournament;

    mapping(uint256=>mapping(address=> bool)) public feeClaimed;

    
    event eventTournamentCreated(uint _startTime,uint _endTime,uint256 _entryFee,uint256 _noOfParticipants,uint256 rewardToAdmin,uint256 rewardToParticipant);
    event eventTournamentJoined(uint256 tournamentId,uint256 entryFee,address Participant);
    event eventRewardSent(uint256 tournamentId,address winnerAddress,uint256 rewardToWinner,uint256 rewardToAdmin);
    event tournamentCancelled(uint256 tournamentId);

    //Creates tournament.
    //admin should add tournament reward to contract while calling function.
    function createTournament(uint _startTime,uint _endTime,uint256 _entryFee,uint256 _noOfParticipants) external{
        require(_noOfParticipants>= 2 && _noOfParticipants<=4, "ERR: ENTER PARTICIPANTS BETWEEN >=2 AND <=4 !");
        require(_endTime >= block.timestamp,"ENTER TIMESTAMP GREATER THAN CURRENT TIME");
        require(_startTime >= block.timestamp && _startTime < _endTime,"ENTER TIMESTAMP GREATER THAN CURRENT TIME");
        
        //require(msg.value == _reward,"ERR: SEND  EXACT REWARD VALUE TO CONTRACT WHILE CALLING THIS FUNCTION ");
        //Reward calculation.
        uint256 totalReward=_entryFee*(_noOfParticipants);
        uint256 rewardToAdmin = ( totalReward*5)/100;
        uint256 rewardToParticipant =totalReward-rewardToAdmin;
        
        tournament[idCntr]=tournamentInfo(
            _startTime,
            _endTime,
            _entryFee,
            rewardToParticipant,
            rewardToAdmin,
            msg.sender, //as a admin.
            address(0),
            _noOfParticipants,
            false
        );
        addressToTournament[msg.sender].push(idCntr);
        
        idCntr++;
        emit eventTournamentCreated(_startTime,_endTime,_entryFee,_noOfParticipants,rewardToAdmin,rewardToParticipant);
    }

    // Allows users to join tournament.
    function joinTournament(uint256 _id) external payable{
        require(block.timestamp>=tournament[_id].startTime,"ERR: CANT CALL BEFORE TOURNAMENT STARTS!");
        require(msg.sender!=tournament[_id].tournamentAdmin,"ERR: ADMIN CAN'T JOIN OWN TOURNAMENT");
        require(_id <= idCntr,"ERR: TOURNAMENT DON'T EXISTS!");
        require(tournamentJoined[_id][msg.sender] == false,"ERR: YOU HAVE ALREADY JOINED!");
        require(participantsAddress[_id].length< tournament[_id].noOfParticipants,"ERR: PARTICIPATION ALREADY ENDED!");
        require(block.timestamp <= tournament[_id].endTime,"ERR: TOURNAMENT TIME ENDED");
        require(msg.value == tournament[_id].entryFee,"ERR: SENT ETH VALUE IS NOT EQUAL TO ENTRY FEE");
        
        //participantsAddress[_id].participantsArr.push(msg.sender);
        participantsAddress[_id].push(msg.sender);
        tournamentJoined[_id][msg.sender]=true;
        emit eventTournamentJoined(_id,msg.value,msg.sender);
    }

    // Sends reward to winner address and sets it as a winner of that tournament.
    // Callable only by tournament owner.
    function sendReward(uint256 _id) external returns(bool,bool){
        require(block.timestamp>=tournament[_id].startTime,"ERR: CANT CALL BEFORE TOURNAMENT STARTS!");
        require(participantsAddress[_id].length == tournament[_id].noOfParticipants,"ERR: PARTICIPANTS ARE NOT ENOUGH!");
        require(msg.sender == tournament[_id].tournamentAdmin,"ERR: YOU ARE NOT TOURNAMENT ADMIN TO CALL THIS FUNCTION!");
        require(_id <= idCntr,"ERR: TOURNAMENT DON'T EXISTS!");
        require(tournament[_id].winnerAddress == address(0),"ERR: WINNER ALREADY ANNOUNCED AND TOURNAMENT IS OVER!");
        
        address winner=decideWinner(_id);
        
        //setting tournament is over.
        tournament[_id].endTime=block.timestamp;
        tournament[_id].winnerAddress=winner;
        
        (bool success1,)=payable(winner).call{value: tournament[_id].reward}("");
        (bool success2,)=payable(tournament[_id].tournamentAdmin).call{value: tournament[_id].rewardToAdmin}("");
        emit eventRewardSent(_id,winner,tournament[_id].reward,tournament[_id].rewardToAdmin);
        return (success1,success2);
    }
    
    // Predictable random number generation. Using only for testing purpose.
    function decideWinner(uint256 _id) view public returns(address){
        address[] memory arr=participantsAddress[_id];
        
        uint256 winner= uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, arr)))%(arr.length-1) ;
        
        return arr[winner];
    }


    // cancel tournament.
    function cancelTournament(uint256 _id) external {
        require(msg.sender == tournament[_id].tournamentAdmin,"ERR: YOU ARE NOT TOURNAMENT ADMIN TO CALL THIS FUNCTION!");
        // add mapping for status.
        tournament[_id].endTime=block.timestamp;
        tournament[_id].iscancelled= true;
        emit tournamentCancelled(_id);
    }
    
    
    // // Return fees to participated users in case there are no enough participants
    // // Callable only by tournament owner.
    // function returnFees(uint256 _id) external{
    //     require(msg.sender == tournament[_id].tournamentAdmin,"ERR: YOU ARE NOT TOURNAMENT ADMIN TO OF THIS TOURNAMENT!");
    //     require(block.timestamp <= tournament[_id].endTime,"ERR: TOURNAMENT ALREADY ENDED!");
    //     tournament[_id].endTime=block.timestamp;
    //     for (uint256 i = 0; i < participantsAddress[_id].length; i++) {
    //         payable(participantsAddress[_id][i]).call{value:tournament[_id].entryFee}("");
    //     }
        
    // }

    //claim tournament fee . only when tournament cancelled.
    function claimTournamentFee(uint256 _id) external returns(bool){
        // fee claimed or not
        require(!feeClaimed[_id][msg.sender],"ERR: ALREADY CLAIMED!");
        require(tournament[_id].iscancelled,"ERR: NOT CANCELLED YET!");
        //check if id exist
        require(_id <= idCntr,"ERR: TOURNAMENT DON'T EXISTS!");
        //check if tournament cancelled.
        require(block.timestamp >= tournament[_id].endTime,"ERR: TOURNAMENT NOT HAlTED BY ADMIN!");
        require(tournamentJoined[_id][msg.sender] == true,"ERR: YOU'RE NOT A PARTICIPANT");
        feeClaimed[_id][msg.sender]=true;
        payable(msg.sender).transfer(tournament[_id].entryFee);
        return true;
    }

    // Returns boolean value for tournament is active or not.
    function isTournamentActive(uint256 _id) view external returns(bool){
        if(tournament[_id].endTime <= block.timestamp){
            return false;
        }
        else if(tournament[_id].startTime <= block.timestamp){ 
            return true;
        }
        else{
            return false;
        }
        
    }
    
    // Returns list of participants.
    function getParticipantList(uint256 _id) view external returns(address[] memory){
        require(_id <= idCntr,"ERR: TOURNAMENT DON'T EXISTS!");
        return participantsAddress[_id];
    }

    // Returns balance of this contract.
    function contractBal() view external returns(uint256){
        return address(this).balance;
    }

    // Returns balance of msg.sender.
    function callerBal() view external returns(uint256){
        return msg.sender.balance;
    }
    
    // Returns msg.sender's tournament.
    function yourTournaments() view external returns(uint256[] memory){
        uint256[] memory arr=addressToTournament[msg.sender];
        return arr;
    }
    
    
}
