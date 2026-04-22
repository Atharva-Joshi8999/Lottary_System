// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "lib/forge-std/src/Script.sol";
import {Lottery} from "../src/lottery_system.sol";

contract DeployLottery is Script {
    function run() external {
        // Chainlink VRF config
        address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
        uint64 subId = 0; //Valid Chainlink subscription for execution
        bytes32 keyHash = 0x474e34a077df58807dbe9c37a1c9b356c1b0b66f3f6b3f1f0a6e6c4d6c2e0c1a;

        uint32 callbackGasLimit = 200000;
        uint16 requestConfirmations = 3;

        vm.startBroadcast();

        new Lottery(vrfCoordinator, subId, keyHash, callbackGasLimit, requestConfirmations);

        vm.stopBroadcast();
    }
}
