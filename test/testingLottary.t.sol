// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "lib/forge-std/src/Test.sol";
import {Lottery} from "../src/lottery_system.sol";

contract LotteryTest is Test {
    Lottery lottery;

    function setUp() public {
        lottery = new Lottery(
            address(1), // mock coordinator
            0,
            bytes32(0),
            200000,
            3
        );
    }

    function testPlaceBet() public {
        uint8[6] memory guesses = [uint8(1), 2, 3, 4, 5, 6];

        lottery.placeBet{value: 1 ether}(guesses);

        assertEq(lottery.betId(), 1);
    }

    function testRevertIfZeroETH() public {
        uint8[6] memory guesses = [uint8(1), 2, 3, 4, 5, 6];

        vm.expectRevert();
        lottery.placeBet(guesses);
    }
}
