// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

struct ChainConfig {
    // Deployer
    uint256 deployerPrivateKey;
    // Price Feed
    address priceFeed;
    // VRF
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    // Automation
    uint256 interval;
}

contract HelperConfig is Script {
    // Active Chain Config
    ChainConfig public activeChainConfig;

    // Environment Variables
    // RPC_URL
    string constant SEPOLIA_RPC_URL = "SEPOLIA_RPC_URL";
    string constant MAINNET_RPC_URL = "MAINNET_RPC_URL";
    string constant ANVIL_FORK_URL = "ANVIL_FORK_URL";
    // Private Key
    string constant SEPOLIA_PRIVATE_KEY = "SEPOLIA_PRIVATE_KEY";
    string constant MAINNET_PRIVATE_KEY = "MAINNET_PRIVATE_KEY";
    string constant ANVIL_PRIVATE_KEY = "ANVIL_PRIVATE_KEY";
    // VRF Subscription ID
    string constant SEPOLIA_VRF_SUBSCRIPTION_ID = "SEPOLIA_VRF_SUBSCRIPTION_ID";
    string constant MAINNET_VRF_SUBSCRIPTION_ID = "MAINNET_VRF_SUBSCRIPTION_ID";

    // VRF Mock Variables
    uint96 public constant MOCK_BASE_FEE = 0.1 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UINT_LINK = 1 ether; // LINK / ETH price
    uint32 public constant CALLBACK_GAS_LIMIT = 200_000;
    uint256 public constant FUND_LINK_AMOUNT = 100000000000000000000;

    // Price Feed Variables
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000e8; // 2000 USD

    // Automation Variables
    uint256 public constant AUTOMATION_INTERVAL = 10 minutes;

    constructor() {
        uint256 chainId = block.chainid;
        if (chainId == 31337 || chainId == 1337) {
            activeChainConfig = getOrCreateAnvilConfig();
        } else if (chainId == 11155111) {
            activeChainConfig = getSepoliaConfig();
        } else if (chainId == 1) {
            activeChainConfig = getMainnetConfig();
        } else {
            revert("Chain not supported");
        }
    }

    // 要想在部署脚本中可见，必须使用external
    function getActiveChainConfig() external view returns (ChainConfig memory) {
        return activeChainConfig;
    }

    function getOrCreateAnvilConfig() public returns (ChainConfig memory AnvilConfig) {
        // 部署mocks： vrf / link / mockV3Aggregator
        if (activeChainConfig.vrfCoordinator != address(0)) {
            return activeChainConfig;
        }

        console2.log(unicode"⚠️ You have deployed a mock conract!");
        console2.log("Make sure this was intentional");
        vm.startBroadcast();

        // 1. deploy vrfCoordinatorV2_5Mock and LinkToken
        // LinkToken link = new LinkToken();
        // MockV3Aggregator linkEthFeed = new MockV3Aggregator(18, 1 ether);

        // VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
        //     MOCK_BASE_FEE,
        //     MOCK_GAS_PRICE_LINK,
        //     MOCK_WEI_PER_UINT_LINK
        // );

        // 解决 OnlyCallableFromLink 问题
        // vrfCoordinatorV2_5Mock.setLINKAndLINKNativeFeed(address(link), address(linkEthFeed));

        // 2. create subscription
        // uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();
        // 3. fund subscription
        // vrfCoordinatorV2_5Mock.fundSubscription(subscriptionId, FUND_LINK_AMOUNT);   //
        // ① 先给自己铸一点 LINK（LinkToken 的构造函数默认把全部 supply 铸给 deployer）
        // uint256 FUND = 100 ether; // 100 LINK
        // ② 注意 payload 必须 encode _exactly_ 一个 uint64
        // bytes memory payload = abi.encode(subscriptionId);
        // 转账 + fund
        // link.transferAndCall(address(vrfCoordinatorV2_5Mock), FUND, payload);   // 不用再手动fund，因为transferAndCall (...) 已经把钱冲进订阅了
        // vrfCoordinatorV2_5Mock.fundSubscription(subscriptionId, 1 ether);   // 1 ETH == 1 LINK

        // 4. add consumer 部署了 enterDungeon才能执行
        // vrfCoordinatorV2_5Mock.addConsumer(subscriptionId, address(enterDungeon));

        // 5. deploy mockV3Aggregator
        MockV3Aggregator mockV3Aggregator = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        vm.stopBroadcast();

        AnvilConfig = ChainConfig({
            deployerPrivateKey: vm.envUint(ANVIL_PRIVATE_KEY),
            priceFeed: address(mockV3Aggregator),
            vrfCoordinator: address(0), // depoloy初始化
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0, // 只用修改这个
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            interval: AUTOMATION_INTERVAL
        });
        return AnvilConfig;
    }

    function getSepoliaConfig() public view returns (ChainConfig memory SepoliaConfig) {
        SepoliaConfig = ChainConfig({
            deployerPrivateKey: vm.envUint(SEPOLIA_PRIVATE_KEY),
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: vm.envUint(SEPOLIA_VRF_SUBSCRIPTION_ID),
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            interval: AUTOMATION_INTERVAL
        });
        return SepoliaConfig;
    }

    function getMainnetConfig() public pure returns (ChainConfig memory MainnetConfig) {
        return MainnetConfig;
    }
}
