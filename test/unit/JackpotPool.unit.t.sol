// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {JackpotPool} from "../../src/JackpotPool.sol";
import {DeployGame} from "../../script/DeployGame.s.sol";
import {HelperConfig, ChainConfig} from "../../script/HelperConfig.s.sol";
import {EnterDungeon} from "../../src/EnterDungeon.sol";

contract JackpotPoolTest is Test {
    EnterDungeon enterDungeon;
    JackpotPool jackpotPool;
    ChainConfig chainConfig;

    address public PLAYER1 = makeAddr("player1");
    address public PLAYER2 = makeAddr("player2");

    uint256 public constant ENTRY_FEE = 1 ether;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployGame deployGame = new DeployGame();
        (enterDungeon, jackpotPool, chainConfig) = deployGame.run();

        vm.deal(PLAYER1, STARTING_USER_BALANCE);
        vm.deal(PLAYER2, STARTING_USER_BALANCE);
    }
}
