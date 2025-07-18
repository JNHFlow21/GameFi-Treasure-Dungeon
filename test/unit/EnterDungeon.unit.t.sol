// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {EnterDungeon} from "../../src/EnterDungeon.sol";
import {DeployGame} from "../../script/DeployGame.s.sol";
import {HelperConfig, ChainConfig} from "../../script/HelperConfig.s.sol";
import {JackpotPool} from "../../src/JackpotPool.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/* Errors */
error EnterDungeon__NotEnoughEthSent();
error EnterDungeon__AlreadyEntered();
error EnterDungeon__NotEnoughTimePassed();
error EnterDungeon__NotInDungeon();
error EnterDungeon__NoBalance();
error EnterDungeon__NotEnoughBalance();
error EnterDungeon__TransferFailed();
error EnterDungeon__RequestPending();
error EnterDungeon__NotJackpotPool();
error EnterDungeon__AllTransferFailed();

contract EnterDungeonTest is Test {
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

    function test_EnterDungeon_Success() public {
        vm.prank(PLAYER1);
        enterDungeon.enterDungeon{value: ENTRY_FEE}();

        assertEq(enterDungeon.getPlayer(PLAYER1).isInDungeon, true);
        assertEq(enterDungeon.getPlayer(PLAYER1).enterFee, ENTRY_FEE);
        assertEq(enterDungeon.getPlayer(PLAYER1).lastUpdateTime, block.timestamp);

        assertEq(enterDungeon.getCurrentPlayersCount(), 1);
        assertEq(enterDungeon.getCurrentPlayersAddress()[0], PLAYER1);
    }

    function test_EnterDungeon_Fail_NotEnoughEthSent() public {
        vm.prank(PLAYER1);
        vm.expectRevert(EnterDungeon__NotEnoughEthSent.selector);
        enterDungeon.enterDungeon{value: 0.00001 ether}();

        assertEq(enterDungeon.getPlayer(PLAYER1).isInDungeon, false);
        assertEq(enterDungeon.getCurrentPlayersCount(), 0);
    }

    function test_EnterDungeon_Fail_AlreadyEntered() public {
        vm.prank(PLAYER1);
        enterDungeon.enterDungeon{value: ENTRY_FEE}();

        vm.prank(PLAYER1);
        vm.expectRevert(EnterDungeon__AlreadyEntered.selector);
        enterDungeon.enterDungeon{value: ENTRY_FEE}();
    }

    function test_ExitDungeon_Success() public {
        vm.prank(PLAYER1);
        enterDungeon.enterDungeon{value: ENTRY_FEE}();

        vm.prank(PLAYER1);
        enterDungeon.exitDungeon();
        assertEq(enterDungeon.getPlayer(PLAYER1).isInDungeon, false);
        assertEq(enterDungeon.getCurrentPlayersCount(), 0);
        assertEq(enterDungeon.getCurrentPlayersAddress().length, 0);
    }

    function test_VRF() public {
        vm.recordLogs();
        vm.prank(PLAYER1);
        enterDungeon.enterDungeon{value: ENTRY_FEE}();

        uint256 requestId = enterDungeon.getRequestId();

        // mock 不会自动调用 fulfillRandomWords，所以需要手动调用
        VRFCoordinatorV2_5Mock(chainConfig.vrfCoordinator).fulfillRandomWords(uint256(requestId), address(enterDungeon));

        assert(enterDungeon.getPlayer(PLAYER1).balance > 0);
    }

    function test_Withdraw_Success() public {
        vm.prank(PLAYER1);
        enterDungeon.enterDungeon{value: ENTRY_FEE}();

        uint256 requestId = enterDungeon.getRequestId();
        VRFCoordinatorV2_5Mock(chainConfig.vrfCoordinator).fulfillRandomWords(uint256(requestId), address(enterDungeon));
        assert(enterDungeon.getPlayer(PLAYER1).balance > 0);

        vm.prank(PLAYER1);
        enterDungeon.withdraw();
        assertEq(enterDungeon.getPlayer(PLAYER1).balance, 0);
    }
}
