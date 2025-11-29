//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2PlusMock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2PlusMock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;
    //VRFCoordinatorV2_5Mock vrfMock;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event EnteredRaffle(address indexed player); // Event emitted when a player enters the raffle
    event WinnerPicked(address indexed winner); // Event emitted when a winner is picked

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        // vrfMock = VRFCoordinatorV2_5Mock(vrfCoordinator);

        // // Fund the subscription with LINK-wei so requestRandomWords won't revert
        // vrfMock.fundSubscription(subscriptionId, 1 ether);

        // // Make our raffle a consumer of that subscription
        // vrfMock.addConsumer(subscriptionId, address(raffle));

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenDontPayEnoughETH() public {
        //Arrange
        vm.prank(PLAYER);
        //Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        //Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); //for manipulating the block time stamp
        vm.roll(block.number + 1); //used to control block number during testing
        raffle.performUpkeep("");

        //Act /Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //<---------CheckUPKeep-------------->
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsntOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); //for manipulating the block time stamp
        vm.roll(block.number + 1); //used to control block number during testing
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    //Challenge
    // testCheckUpKeepReturnsFalseIfEnoughTimeHasPassed
    // testCheckUpKeepReturnsTrueWhenParametersAreGood

    /*////////////////////////////////////////////////////////////
                        PERFORM UPKEEP
    /////////////////////////////////////////////////////////////*/

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); //for manipulating the block time stamp
        vm.roll(block.number + 1); //used to control block number during testing

        //Act/Assert
        raffle.performUpkeep(""); //there is better way too
    }

    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        //Act /Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // what if we need to get data from emitted events in our tests?
    function testPerformUpKeepUpdatesRaffleStateAndEmitRequestId() public raffleEntered {
        //Act
        vm.recordLogs(); // cheatcode to record all the events inside an array
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs(); //cheat code to store the emitted event
        bytes32 requestId = entries[1].topics[1];

        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*////////////////////////////////////////////////////////
                FULFILLRANDOMWORDS
    ////////////////////////////////////////////////////////*/

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId //fuzz testing it will take 256 different random inputs and pass it into here
    )
        public
        raffleEntered
        skipFork
    {
        vm.expectRevert(bytes("nonexistent request"));
        VRFCoordinatorV2PlusMock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulFillRandomWordsPicksAWinnerResetAndSendsMoney() public raffleEntered skipFork {
        //Arrange
        uint256 additionalEntrants = 3; //4 total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i)); //address(i)
            hoax(newPlayer, 1 ether); //give player ETH + PRANK
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        //Act
        vm.recordLogs(); // cheatcode to record all the events inside an array
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs(); //cheat code to store the emitted event
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2PlusMock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        //Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
