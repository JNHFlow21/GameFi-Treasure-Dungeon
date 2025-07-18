// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, ChainConfig} from "./HelperConfig.s.sol";
import {EnterDungeon} from "../src/EnterDungeon.sol";
import {JackpotPool} from "../src/JackpotPool.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract DeployGame is Script {
    // VRF Mock Variables
    uint96 public constant MOCK_BASE_FEE = 0.1 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UINT_LINK = 1 ether; // LINK / ETH price
    uint256 public constant FUND_LINK_AMOUNT = 100000000000000000000;
    VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock;
    EnterDungeon enterDungeon;
    JackpotPool jackpotPool;

    function run() public returns (EnterDungeon, JackpotPool, ChainConfig memory) {
        HelperConfig helperConfig = new HelperConfig();
        ChainConfig memory chainConfig = helperConfig.getActiveChainConfig();

        if (chainConfig.vrfCoordinator == address(0)) {
            // 1. deploy vrfCoordinatorV2_5Mock
            vrfCoordinatorV2_5Mock =
                new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
            // 2. create subscription
            uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();
            // 3. fund subscription
            vrfCoordinatorV2_5Mock.fundSubscription(subscriptionId, FUND_LINK_AMOUNT);
            // set chainConfig
            chainConfig.vrfCoordinator = address(vrfCoordinatorV2_5Mock);
            chainConfig.subscriptionId = subscriptionId;
        }

        vm.startBroadcast(chainConfig.deployerPrivateKey);

        // 部署 enterDungeon
        /**
         * address _priceFeed,
         *     address _vrfCoordinator,
         *     uint256 _subscriptionId,
         *     bytes32 _gasLane,
         *     uint32 _callbackGasLimit
         */
        enterDungeon = new EnterDungeon(
            chainConfig.priceFeed,
            chainConfig.vrfCoordinator,
            chainConfig.subscriptionId,
            chainConfig.gasLane,
            chainConfig.callbackGasLimit
        );

        // 部署 Jackpotpool
        /**
         * address _enterDungeon,
         *     uint256 _interval,
         *     address _vrfCoordinator,
         *     uint256 _subscriptionId,
         *     bytes32 _gasLane,
         *     uint32 _callbackGasLimit
         */
        jackpotPool = new JackpotPool(
            address(enterDungeon),
            chainConfig.interval,
            chainConfig.vrfCoordinator,
            chainConfig.subscriptionId,
            chainConfig.gasLane,
            chainConfig.callbackGasLimit
        );

        // 设置 enterDungeon 的 jackpotPool
        console2.log("EnterDungeon address: %s", address(enterDungeon));
        console2.log("Setting JackpotPool address: %s", address(jackpotPool));
        enterDungeon.setJackpotPool(address(jackpotPool));

        vm.stopBroadcast();

        // 如果是anvil 就添加 consumer
        if (block.chainid == 31337 || block.chainid == 1337) {
            vrfCoordinatorV2_5Mock.addConsumer(chainConfig.subscriptionId, address(jackpotPool));
            vrfCoordinatorV2_5Mock.addConsumer(chainConfig.subscriptionId, address(enterDungeon));
        }

        // 输出部署信息
        console2.log("===============Deployment Info===============");
        console2.log("Chain ID: %s", block.chainid);
        console2.log("DungeonEntrance address: %s", address(enterDungeon));
        console2.log("JackpotPool address: %s", address(jackpotPool));
        console2.log("PriceFeed address: %s", chainConfig.priceFeed);
        console2.log("VRF Subscription ID: %s", chainConfig.subscriptionId);
        console2.log("VrfCoordinator address: %s", chainConfig.vrfCoordinator);
        console2.log("CallbackGasLimit: %s", chainConfig.callbackGasLimit);
        console2.log("Interval: %s", chainConfig.interval);
        console2.log("=========================================");

        return (enterDungeon, jackpotPool, chainConfig);
    }
}
