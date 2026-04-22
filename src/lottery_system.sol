// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Lottery
 * @author Atharva Joshi
 * @notice A decentralized lottery using Chainlink VRF for secure randomness
 * @dev Demonstrates secure randomness, gas optimization, and best practices
 */
import {VRFConsumerBaseV2} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract Lottery is VRFConsumerBaseV2 {
    // errors
    error InvalidBet();
    error AlreadyResolved();
    error RandomnessAlreadyRequested();
    error BetAmountTooLarge();
    error NotBetOwner();
    error InsufficientContractBalance(uint256 requested, uint256 available);

    // events
    event BetPlaced(uint256 indexed betId, address indexed player, uint256 amount);
    event RandomnessRequested(uint256 indexed requestId, uint256 indexed betId);
    event BetResolved(uint256 indexed betId, uint256 reward, uint256 matches);

    // bet struct
    struct Bet {
        address player;
        uint96 amount;
        uint40 blockNumber;
        bool resolved;
        bool randomnessRequested;
        uint8[6] guesses;
    }

    // storage
    uint256 public betId;
    mapping(uint256 => Bet) public bets;

    VRFCoordinatorV2Interface private immutable COORDINATOR;

    uint64 private immutable subscriptionId;
    bytes32 private immutable keyHash;
    uint32 private immutable callbackGasLimit;
    uint16 private immutable requestConfirmations;

    mapping(uint256 => uint256) public requestToBet;

    // constructor
    constructor(
        address vrfCoordinator,
        uint64 _subId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        subscriptionId = _subId;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
    }

    // place bet
    function placeBet(uint8[6] calldata _guesses) external payable {
        if (msg.value == 0) revert InvalidBet();
        if (msg.value > type(uint96).max) revert BetAmountTooLarge();

        uint256 _betId = betId;

        bets[_betId] = Bet({
            player: msg.sender,
            amount: uint96(msg.value),
            blockNumber: uint40(block.number),
            resolved: false,
            randomnessRequested: false,
            guesses: _guesses
        });

        emit BetPlaced(_betId, msg.sender, msg.value);

        unchecked {
            betId++;
        }
    }

    // request randomness
    function requestRandomness(uint256 _betId) external {
        Bet storage bet = bets[_betId];

        if (bet.player == address(0)) revert InvalidBet();
        if (bet.player != msg.sender) revert NotBetOwner();
        if (bet.resolved) revert AlreadyResolved();
        if (bet.randomnessRequested) revert RandomnessAlreadyRequested();

        bet.randomnessRequested = true;

        uint256 requestId =
            COORDINATOR.requestRandomWords(keyHash, subscriptionId, requestConfirmations, callbackGasLimit, 1);

        requestToBet[requestId] = _betId;

        emit RandomnessRequested(requestId, _betId);
    }

    // chainlink callback
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 _betId = requestToBet[requestId];
        delete requestToBet[requestId];

        Bet storage bet = bets[_betId];

        if (bet.resolved) return;

        bet.resolved = true;

        uint8[6] memory result = _getLast6Hex(bytes32(randomWords[0]));
        uint256 matches = _countMatches(bet.guesses, result);

        uint256 reward = _calculateReward(bet.amount, matches);

        if (reward > address(this).balance) {
            revert InsufficientContractBalance(reward, address(this).balance);
        }

        if (reward != 0) {
            (bool success,) = bet.player.call{value: reward}("");
            require(success, "Transfer failed");
        }

        emit BetResolved(_betId, reward, matches);
    }

    // extract hex
    function _getLast6Hex(bytes32 _hash) internal pure returns (uint8[6] memory result) {
        for (uint256 i; i < 6;) {
            result[i] = uint8(uint256(_hash >> (i * 4)) & 0xF);
            unchecked {
                ++i;
            }
        }
    }

    // count matches
    function _countMatches(uint8[6] memory guesses, uint8[6] memory result) internal pure returns (uint256 matches) {
        for (uint256 i; i < 6;) {
            if (guesses[i] == result[i]) {
                unchecked {
                    matches++;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    // reward logic
    function _calculateReward(uint256 amount, uint256 matches) internal pure returns (uint256) {
        if (matches == 0) return 0;
        if (matches == 1) return amount * 2;
        if (matches == 2) return amount * 3;
        if (matches == 3) return amount * 5;
        if (matches == 4) return amount * 10;
        if (matches == 5) return amount * 20;
        return amount * 50; // 6 matches
    }

    // receive eth
    receive() external payable {}
}
