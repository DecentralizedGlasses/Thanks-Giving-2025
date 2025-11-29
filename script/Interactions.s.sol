// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2PlusMock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2PlusMock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script, CodeConstants {
    function createSubscriptionUsingConfig() public returns (uint256, address, uint256) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator; //instead of returning whole different variable it just returns vrfCoordinator
        uint256 deployerKey = helperConfig.getConfig().deployerKey;
        (uint256 subId,) = createSubscription(vrfCoordinator, deployerKey); //using create subscription function and passing that vrfCoordinator value
        //create a subscription(put it in its own function so itll be little bit easier to access)

        return (subId, vrfCoordinator, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns (uint256, address) {
        console.log("Creating Subscription on chain ID:", block.chainid);
        vm.startBroadcast(deployerKey);
        uint256 subId = VRFCoordinatorV2PlusMock(vrfCoordinator).createSubscription();

        vm.stopBroadcast();

        console.log("your subscription Id:", subId);
        console.log("please update the subscriptionId in your HelperConfig.s.sol");

        return (subId, vrfCoordinator);
    }

    function run() external {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; //3 LINK

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator; //instrad of returning whole different variable it just returns vrfCoordinator
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        uint256 deployerKey = helperConfig.getConfig().deployerKey;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, uint256 deployerKey)
        public
    {
        console.log("Funding subscription:", subscriptionId);
        console.log("Using vrfCoordinator:", vrfCoordinator);
        console.log("on chainID :", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2PlusMock(vrfCoordinator).fundSubscription(subscriptionId, uint96(FUND_AMOUNT));
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

//raffle == contractToAddToVrf
contract AddConsumer is Script {
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, uint256 deployerKey)
        public
    {
        console.log("Adding consumer to vrfCoordinator:", contractToAddToVrf);
        console.log("To vrfCoordinator:", vrfCoordinator);
        console.log("on chain Id:", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2PlusMock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    //here mostRecentlyDeployed == raffle in patrciks code
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        // (
        //     address vrfCoordinator,
        //     uint256 subId,
        //     uint256 deployerKey
        // ) = helperConfig.getConfig(); // this is same as below
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 deployerKey = helperConfig.getConfig().deployerKey;
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId, deployerKey);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
