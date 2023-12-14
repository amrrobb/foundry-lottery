// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subId,
            uint32 callbackGasLimit,
            address link, // address link
            uint256 deployerKey
        ) = config.activeNetworkConfig();

        if (subId == 0) {
            // Create a new subscription
            CreateSubscription subscription = new CreateSubscription();
            subId = subscription.createSubscription(
                vrfCoordinator,
                deployerKey
            );

            // Fund the subscription
            FundSubscription fundSubscriptionContract = new FundSubscription();
            fundSubscriptionContract.fundSubscription(
                vrfCoordinator,
                subId,
                link,
                deployerKey
            );
        }
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumerContract = new AddConsumer();
        addConsumerContract.addConsumer(
            vrfCoordinator,
            subId,
            address(raffle),
            deployerKey
        );
        return (raffle, config);
    }
}
