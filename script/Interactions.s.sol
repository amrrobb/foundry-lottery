// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingHelperConfig() public returns (uint64) {
        HelperConfig config = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerKey) = config
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64 subId) {
        console.log("Creating subscription on Chainid: ", block.chainid);
        vm.startBroadcast(deployerKey);
        subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        console.log("Your Sub Id: ", subId);
        console.log("Updating Sub Id from  HelperConfig ");
        vm.stopBroadcast();
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingHelperConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingHelperConfig() public {
        HelperConfig config = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address link,
            uint256 deployerKey
        ) = config.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On Chainid: ", block.chainid);

        vm.startBroadcast(deployerKey);
        if (block.chainid == 31337) {
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
        } else {
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
        }
        vm.stopBroadcast();
    }

    function run() external {
        fundSubscriptionUsingHelperConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingHelperConfig(address raffle) public {
        HelperConfig config = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            ,
            uint256 deployerKey
        ) = config.activeNetworkConfig();
        return addConsumer(vrfCoordinator, subId, raffle, deployerKey);
    }

    function addConsumer(
        address vrfCoordinator,
        uint64 subId,
        address raffle,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer contract: ", raffle);
        console.log("Subscription id : ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On Chainid: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingHelperConfig(raffle);
    }
}
