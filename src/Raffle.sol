// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

// import {console} from "forge-std/Test.sol";
// import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

/// @title A title that should describe the contract/interface
/// @author The name of the author
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details

contract Raffle is VRFConsumerBaseV2 {
    /** Errors */
    error Raffle__NotEnoughFee();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    /** Tyoe Declarations  */
    enum RaffleStates {
        OPEN, // 0
        CALLCULATING // 1
    }

    /** State Variables */
    uint32 constant NUM_WORDS = 3; // 3 for 3 winners;
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    address payable[] private s_players;
    uint256 private immutable i_entranceFee;
    /// @dev Duration of the lottery in seconds
    uint256 private immutable i_interval;
    /// @dev The owner of the lottery
    address private immutable i_owner;
    /// @dev the coordinator address contract
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_lastTimestamp;
    // address private s_recentWinner; // Top 3 winners
    address[] private s_recentWinners;
    //  = new address[](3); // Top 3 winners

    /// @dev current raffle state
    RaffleStates private s_raffleState;

    /** Events */
    event EnteredRaffle(address indexed player);
    // event PickedWinner(address indexed winner);
    event PickedWinners(address[] indexed winners); // for 3 winners
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_owner = msg.sender;
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        s_lastTimestamp = block.timestamp;
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleStates.OPEN;
    }

    modifier validRaffle() {
        // require(s_raffleState == RaffleStates.OPEN);
        if (s_raffleState != RaffleStates.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        _;
    }

    function enterRaffle() external payable validRaffle {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughFee();
        }
        s_players.push(payable(msg.sender));
        // 1. makes migration easier
        // 2. makes indexing "front end" easier
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This function utilize Chainlink Automation to see if it's time to perform upkeep
     * This following should be true for this to return true:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle state should be OPEN
     * 3. The contract has players (funded with ETH)
     * 4. (Implicit) The contract needs LINK for subscription
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimestamp) >= i_interval;
        bool isOpen = s_raffleState == RaffleStates.OPEN;
        bool havePlayers = s_players.length > 0;
        bool haveBalance = address(this).balance > 0;
        upkeepNeeded = timeHasPassed && havePlayers && haveBalance && isOpen;
        return (upkeepNeeded, "0x0");
    }

    // 1. Get random number
    // 2. Use random number to pick a player
    // 3. Be called automatically
    // pickWinners
    function performUpkeep(bytes calldata /* checkData */) external {
        // check to see if enough time has passed
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded)
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );

        s_raffleState = RaffleStates.CALLCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        // Quiz: is it redundant with vrfCoordinator emitted event?
        emit RequestedRaffleWinner(requestId);
    }

    /**  
    This feature is for picking 1 winners randomly
    */

    // function fulfillRandomWords(
    //     uint256 /** requestId */
    //     uint256[] memory randomWords
    // ) internal override {
    //     // RNG modulo players length
    //     uint256 winnerIndex = randomWords[0] % s_players.length;
    //     address payable winner = s_players[winnerIndex];
    //     s_recentWinner = winner;

    //     s_raffleState = RaffleStates.OPEN;
    //     s_players = new address payable[](0);

    //     (bool success, ) = winner.call{value: address(this).balance}("");
    //     if (!success) revert Raffle__TransferFailed();

    //     emit PickedWinner(s_recentWinner);
    // }

    /**  
    This feature is for picking 3 winners randomly
    */

    // CEI: Checks, Effects and Interactions
    // Checks -> verification
    // Effects -> Our own contracts
    // Interactions -> Outside our contracts

    // Pick 3 winners from players with prize conditions
    // 1st winner gets 50% of pool
    // 2nd winner gets 30% of pool
    // 3rd winner gets 20% of pool

    // If only 1 winner -> get all prize
    // If only 2 winner -> 3rd winner prize divided evenly and distribute to 1st and 2nd winner
    function fulfillRandomWords(
        uint256 /** requestId */,
        uint256[] memory randomWords
    ) internal override {
        // RNG modulo players length
        uint256 maxIndex = s_players.length < 3 ? s_players.length : 3;
        uint256[] memory winnerIndexes = new uint256[](maxIndex);
        for (uint256 i = 0; i < maxIndex; i++) {
            uint256 totalPlayers = s_players.length;
            uint256 winnerIndex = randomWords[i] % totalPlayers;
            while (validateWinnerIndex(winnerIndexes, winnerIndex) == false) {
                totalPlayers -= 1;
                winnerIndex = randomWords[i] % totalPlayers;
            }
            winnerIndexes[i] = winnerIndex;
            address payable winner = s_players[winnerIndex];
            s_recentWinners.push(winner);
        }
        s_raffleState = RaffleStates.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        sendPrizeToWinners();
    }

    function validateWinnerIndex(
        uint256[] memory winnerIndexes,
        uint256 winnerIndex
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < winnerIndexes.length; i++) {
            if (winnerIndexes[i] == winnerIndex) return false;
        }
        return true;
    }

    function sendPrizeToWinners() internal {
        if (s_recentWinners.length > 0) {
            uint256 totalPrize = address(this).balance;
            uint256[] memory prizePercentages = getPrizePercentages();

            emit PickedWinners(s_recentWinners);
            for (uint256 i = 0; i < prizePercentages.length; i++) {
                address winner = s_recentWinners[i];
                (bool success, ) = winner.call{
                    value: (totalPrize * prizePercentages[i]) / 100
                }("");
                if (!success) revert Raffle__TransferFailed();
            }
        }
    }

    // this function returns array of percentage
    // ex. 60% and 40% will return [70, 30]
    function getPrizePercentages()
        public
        view
        returns (uint256[] memory _prizePercentages)
    {
        // Initialize the dynamic array based on the length condition
        uint256 maxLength = s_recentWinners.length < 3
            ? s_recentWinners.length
            : 3;
        _prizePercentages = new uint256[](maxLength);
        if (s_recentWinners.length == 1) {
            _prizePercentages[0] = 100;
        } else if (s_recentWinners.length == 2) {
            _prizePercentages[0] = 60;
            _prizePercentages[1] = 40;
        } else {
            _prizePercentages[0] = 50;
            _prizePercentages[1] = 30;
            _prizePercentages[2] = 20;
        }
    }

    /** Getter Functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleStates) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) public view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getTotalPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getTotalRecentWinners() public view returns (uint256) {
        return s_recentWinners.length;
    }

    function getRecentWinner(
        uint256 indexOfWinner
    ) public view returns (address) {
        return s_recentWinners[indexOfWinner];
    }

    function getLastTimestamp() public view returns (uint256) {
        return s_lastTimestamp;
    }
}
