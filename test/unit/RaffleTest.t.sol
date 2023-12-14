// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig config;

    /** Network Config */
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant TOLERANCE = 0.001 ether;

    /** Events */
    event EnteredRaffle(address indexed player);
    // event PickedWinner(address indexed winner);
    event PickedWinners(address[] indexed winners);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, config) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = config.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleStates.OPEN);
    }

    /** Modifiers */
    modifier raffleEnteredAndTimePassed() {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    /*****************/
    /** Enter Raffle */
    /*****************/
    function testRaffleRevertWhenNotEnoughFee() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughFee.selector);
        raffle.enterRaffle();
    }

    function testRecordPlayerWhenEnterRaffle() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(PLAYER == playerRecorded);
    }

    function testEmitsEventWhenEnterRaffle() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, true, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterRaffleWhenCalculating()
        public
        raffleEnteredAndTimePassed
    {
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*****************/
    /** Check Upkeep */
    /*****************/
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen()
        public
        raffleEnteredAndTimePassed
    {
        // Act
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueIfParamatersAreMatched()
        public
        raffleEnteredAndTimePassed
    {
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /*******************/
    /** Perform Upkeep */
    /*******************/
    function testPerformUpkeepRunsOnlyIfCheckUpkeepIsTrue()
        public
        raffleEnteredAndTimePassed
    {
        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public skipFork {
        // Arrange
        uint256 balance = 0;
        uint256 players = 0;
        uint256 raffleState = 0;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                balance,
                players,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    // What if I need to test using output of an event?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // Act / Assert
        vm.recordLogs();
        raffle.performUpkeep(""); // emit request id

        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Order from topics
        // 0. emitted event
        // 1..n indexed parameters inputed in the event

        bytes32 emittedEvent = entries[1].topics[0];
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleStates rState = raffle.getRaffleState();
        assertEq(emittedEvent, keccak256("RequestedRaffleWinner(uint256)"));
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1); // Raffle state change into calculating
    }

    /*************************/
    /** Fulfill Random Words */
    /*************************/
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksWinnersResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        // Arrange
        uint256 additionalPlayers = 5;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < additionalPlayers + startingIndex;
            i++
        ) {
            address player = address(uint160(i)); // address of i
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 previousTimestamp = raffle.getLastTimestamp();
        uint256 totalPrize = entranceFee * (1 + additionalPlayers);

        // Pretend to be chainlink vrf to get random numbers & pick winners
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        uint256[] memory prizePercentages = raffle.getPrizePercentages();

        // Act
        // Assert
        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getTotalRecentWinners() == 3);
        assert(
            prizePercentages[0] == 50 &&
                prizePercentages[1] == 30 &&
                prizePercentages[2] == 20
        );
        assert(raffle.getRecentWinner(0) != address(0));
        assert(raffle.getTotalPlayers() == 0);
        assert(raffle.getLastTimestamp() > previousTimestamp);

        for (uint256 i = 0; i < prizePercentages.length; i++) {
            address winner = raffle.getRecentWinner(i);
            uint256 percentage = prizePercentages[i];
            uint256 expectedPrize = STARTING_BALANCE -
                entranceFee +
                ((totalPrize * percentage) / 100);

            // console.log("index:", i);
            // console.log(winner.balance);
            // console.log(expectedPrize);
            // assert(
            //     winner.balance >= expectedPrize - TOLERANCE &&
            //         winner.balance <= expectedPrize + TOLERANCE
            // );
            assert(winner.balance == expectedPrize);
        }
        // test emit picked winners
    }
}
