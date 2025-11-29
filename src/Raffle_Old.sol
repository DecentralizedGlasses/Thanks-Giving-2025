// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract

// Inside Contract:
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
// view & pure functions

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {
    VRFConsumerBaseV2Plus
} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {
    VRFV2PlusClient
} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {
    AutomationCompatibleInterface
} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A sample Raffle contract
 * @author Sivaji(Decentralized_Glasses)
 * @notice This contract is for creating a simple raffle
 * @dev  Implements chainlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /**Custom Errors */
    error Raffle__NotEnoughETHSent(); // Custom error for not enough ETH sent to enter the raffle (good Practice to save gas)
    error Raffle__TransferFailed(); // Custom error for transfer failure
    error Raffle__RaffleNotOpen(); // Custom error for raffle not open
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    ); // Custom error for upkeep not needed

    /*Type Declarations */
    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    /*State Variables */
    uint32 private constant NUM_WORDS = 1; // Number of random words to request
    uint256 private immutable i_entranceFee; // Entrance fee to enter the raffle as immutable and private so we can get to define at constructor level
    // @dev Duration of lottery in seconds
    uint256 private immutable i_interval; // Time interval for the raffle as immutable and private so we can get to define at constructor level
    bytes32 private immutable i_keyHash; // Gas lane key hash
    address payable[] private s_players; // Dynamic array to store the players addresses as private state variable
    uint256 private immutable i_subscriptionId; // subscription ID
    uint32 private immutable i_callbackGasLimit; // callback gas limit
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // default value

    uint256 private s_lastTimeStamp; // Last timestamp when the lottery was drawn
    address private s_recentWinner; // recent winner address
    RaffleState private s_raffleState; // Raffle state
    //uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

    /*Events */
    event RaffleEnter(address indexed player); // Event emitted when a player enters the raffle
    event WinnerPicked(address indexed winner); // Event emitted when a winner is picked
    event RequestedRaffleWinner(uint256 indexed requestId); //event to emit request ID

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        // Constructor to initialize the entrance fee
        i_entranceFee = entranceFee;
        // constructor to initialize the interval
        i_interval = interval;
        i_keyHash = gasLane; // initialize keyHash
        i_subscriptionId = subscriptionId; // initialize subscription ID
        i_callbackGasLimit = callbackGasLimit; // initialize callback gas limit

        s_raffleState = RaffleState.OPEN; // initialize raffle state to OPEN
        // constructor to initialize the last timestamp
        s_lastTimeStamp = block.timestamp; // Initialize the last timestamp to the current block timestamp
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH to enter Raffle"); // not much gas efficient coz it stores the string in memory
        // require(msg.value >= i_entranceFee, Raffle_NotEnoughETHSent()); // I dunno abou this one will learn later
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHSent(); //more gas efficient way using custom errors
        }
        if (s_raffleState != RaffleState.OPEN) revert Raffle__RaffleNotOpen(); // check if the raffle is open if not open don't enter
        s_players.push(payable(msg.sender)); // Add the player to the players array
        // 1. makes migration easier
        //2. makes front-end "indexing" easier
        emit RaffleEnter(msg.sender); // Emit the RaffleEnter event
    }

    /**
    @dev This is the function that chainlink nodes keeper call
    the lookk for 'upKeepNeeded' to return the value
    following should be true to return the value
    1. The lottery is open
    2. time interval has passed to between raffle runs
    3. the contract has ETH(balance)
    4. The contract has players(registered)
    5. implicitly your function is funded with LINK token
     */

    // function checkUpkeep(
    //     bytes memory /*checkData*/ //if you see this parameter is not used so we can comment it out
    // )
    //     external
    //     view
    //     override
    //     returns (bool upKeepNeeded, bytes memory /*performData*/)
    // {
    //     bool isOpen = s_raffleState == RaffleState.OPEN; // check if the raffle is open
    //     bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval); //check ifthe time interval passed
    //     bool hasPlayers = s_players.length > 0; // check if there are players
    //     bool hasBalance = address(this).balance > 0; // check if the contract has balance
    //     upKeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance); // return true if all conditions are met
    //     return (upKeepNeeded, "0x0"); // return false if any condition is not met
    // }

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        return (upkeepNeeded, "");
    }

    // 1. get a random Number
    // 2. use random number to pick a player
    //3. Be automatically called
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep(""); // calling checkUpkeep function
        //require(upkeepNeeded, "Upkeep not needed");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        } // check if upkeep is needed
        // if (block.timestamp - s_lastTimeStamp < i_interval) revert(); // check if the time interval has passed
        s_raffleState = RaffleState.CALCULATING; // Set the raffle state to CALCULATING

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        //checks

        //Effects: used to update state variables
        uint256 indexOfWinner = randomWords[0] % s_players.length; // Get the index of the winner
        address payable recentWinner = s_players[indexOfWinner]; // Get the address of the winner
        s_recentWinner = recentWinner; // Set the recent winner

        s_raffleState = RaffleState.OPEN; // Set the raffle state to OPEN
        s_players = new address payable[](0); // Reset the players array
        s_lastTimeStamp = block.timestamp; // Reset the last timestamp

        //Interactions: used to interact with other contracts or send ether
        (bool success, ) = recentWinner.call{value: address(this).balance}(""); // Transfer the balance to the winner
        if (!success) {
            revert Raffle__TransferFailed(); // Revert if the transfer fails
        }
        emit WinnerPicked(recentWinner); // Emit the WinnerPicked event
    }

    /**
    Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        // Getter function to get the entrance fee
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
