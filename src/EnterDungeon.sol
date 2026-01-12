// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PriceConverter} from "./PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2PLUS.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console2} from "forge-std/console2.sol";

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
error EnterDungeon__ZeroAddress();
error EnterDungeon__NoAvailableBalance();

contract EnterDungeon is VRFConsumerBaseV2Plus {
    /* Type Declarations */
    struct Player {
        address playerAddress;
        uint256 enterFee; // ETH
        uint256 balance; // ETH
        uint256 lastUpdateTime;
        bool isInDungeon;
    }

    using PriceConverter for uint256;

    uint256 public constant ENTRY_FEE = 10e18; // 10usd

    /* State Variables */
    // Dungeon Variables
    uint256 private s_requestId;
    address public immutable s_priceFeed;
    mapping(address => Player) public s_totalPlayers;
    mapping(uint256 => address) public s_requestIdToPlayerAddress;
    mapping(address => bool) private s_requestPending;
    // Array + Mapping 双线维护 在线玩家
    address[] public s_currentPlayersAddress;
    mapping(address => uint256) public s_currentPlayersIndex;
    // 锁仓玩家列表
    address[] public s_snapshotPlayersAddress;
    uint256 private s_snapshotPoolBalance; // 锁仓奖池金额
    uint256 private s_totalPendingRewards;
    // Jackpot Pool Variables
    address public jackpotPoolAddress;

    // Chainlink VRF Variables
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane; // keyHash
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    bool private s_enableNativePayment = false; // true:ETH, false:LINK

    event JackpotPoolSet(address indexed pool);

    // 继承自 ConfirmedOwner 的 onlyOwner 修饰符可直接使用，无需再次声明
    modifier onlyJackpotPool() {
        if (msg.sender != jackpotPoolAddress) {
            revert EnterDungeon__NotJackpotPool();
        }
        _;
    }

    constructor(
        address _priceFeed,
        address _vrfCoordinator,
        uint256 _subscriptionId,
        bytes32 _gasLane,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        if (_priceFeed == address(0) || _vrfCoordinator == address(0)) {
            revert EnterDungeon__ZeroAddress();
        }
        s_priceFeed = _priceFeed;
        i_subscriptionId = _subscriptionId;
        i_gasLane = _gasLane;
        i_callbackGasLimit = _callbackGasLimit;
    }

    function setJackpotPool(address _pool) external onlyOwner {
        require(jackpotPoolAddress == address(0), "already set");
        if (_pool == address(0)) {
            revert EnterDungeon__ZeroAddress();
        }
        jackpotPoolAddress = _pool;
        emit JackpotPoolSet(_pool);
    }

    function enterDungeon() public payable {
        // 1、检查入场费是否足够
        uint256 enterFee = msg.value.getUsdValue(s_priceFeed);
        if (enterFee < ENTRY_FEE) {
            revert EnterDungeon__NotEnoughEthSent();
        }

        // 2、检查是否已经进入地下城
        if (s_totalPlayers[msg.sender].isInDungeon) {
            revert EnterDungeon__AlreadyEntered();
        }

        // 3.1 检查是否已有未完成随机请求
        if (s_requestPending[msg.sender]) {
            revert EnterDungeon__RequestPending();
        }

        // 3、更新玩家状态，并请求随机数
        // 写入主表
        s_totalPlayers[msg.sender] = Player({
            playerAddress: msg.sender,
            enterFee: msg.value,
            balance: 0,
            lastUpdateTime: block.timestamp,
            isInDungeon: true
        });
        // 维护在线数组 + 索引
        s_currentPlayersIndex[msg.sender] = s_currentPlayersAddress.length;
        s_currentPlayersAddress.push(msg.sender);

        // 4、请求随机数，触发随机返现
        uint256 requestId = requestRandomNumber();
        s_requestId = requestId;
        console2.log("requestId", requestId);
        s_requestIdToPlayerAddress[requestId] = msg.sender;
        s_requestPending[msg.sender] = true;
    }

    /**
     * @notice requestRandomNumber
     * @dev 自己定义的一个函数，可以叫做任何名字，只是单独封装了VRF请求随机数的逻辑
     * @return requestId
     */
    function requestRandomNumber() internal returns (uint256 requestId) {
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: s_enableNativePayment}))
            })
        );
        return requestId;
    }

    /**
     * @notice fulfillRandomWords
     * @dev 当VRF请求随机数成功后，会调用这个函数，里面是拿到随机数后的具体处理逻辑
     *      调用者是 VRF Coordinator，要使用requestId映射playerAddress
     * @param  requestId 请求ID
     * @param randomWords 随机数
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // 1、获取玩家地址
        address playerAddress = s_requestIdToPlayerAddress[requestId];

        // 2、根据随机数计算返现金额
        uint256 randomNumber = randomWords[0] % 100;
        uint256 reward;
        if (randomNumber < 50) {
            // 50% 概率获得 0.3倍的返现
            reward = s_totalPlayers[playerAddress].enterFee * 3 / 10;
        } else if (randomNumber < 80) {
            // 30% 概率获得 0.5倍的返现
            reward = s_totalPlayers[playerAddress].enterFee * 5 / 10;
        } else if (randomNumber < 90) {
            // 10% 概率获得 0.8倍的返现
            reward = s_totalPlayers[playerAddress].enterFee * 8 / 10;
        } else {
            // 10% 概率获得 0.1 倍的返现
            reward = s_totalPlayers[playerAddress].enterFee * 1 / 10;
        }
        s_totalPlayers[playerAddress].balance += reward;
        s_totalPendingRewards += reward;

        // 更新玩家状态 & 清除 pending 标记
        s_totalPlayers[playerAddress].lastUpdateTime = block.timestamp;
        s_requestPending[playerAddress] = false;
    }

    /**
     * @notice getCurrentPlayersCountAndSnapshotPoolBalance
     * @dev 获取当前在线玩家数量和锁仓奖池金额
     * @return 当前在线玩家数量
     */
    function getSnapshotofCurrentPlayersCountAndPoolBalance() public onlyJackpotPool returns (uint256, uint256) {
        // 快照此时的在线玩家列表
        s_snapshotPlayersAddress = s_currentPlayersAddress;
        uint256 contractBalance = address(this).balance;
        if (contractBalance < s_totalPendingRewards) {
            revert EnterDungeon__NotEnoughBalance();
        }
        uint256 freeBalance = contractBalance - s_totalPendingRewards;
        s_snapshotPoolBalance = (freeBalance * 80) / 100;
        return (s_snapshotPlayersAddress.length, s_snapshotPoolBalance);
    }

    function payWinnerByIndex(uint256 index) public onlyJackpotPool returns (address) {
        address winnerAddress = s_snapshotPlayersAddress[index];
        s_totalPlayers[winnerAddress].balance += s_snapshotPoolBalance;
        s_totalPendingRewards += s_snapshotPoolBalance;

        // 清空锁仓玩家列表和余额
        s_snapshotPlayersAddress = new address[](0);
        s_snapshotPoolBalance = 0;

        return winnerAddress;
    }

    function exitDungeon() public {
        // Checks
        // 检查是否在地下城
        if (!s_totalPlayers[msg.sender].isInDungeon) {
            revert EnterDungeon__NotInDungeon();
        }

        // Effects
        // 删除在线玩家 : 核心思路就是将最后一个玩家移动到要删除的位置，然后删除最后一个玩家
        uint256 deleteIndex = s_currentPlayersIndex[msg.sender]; // 使用mapping根据要删除的地址获取索引
        uint256 lastPlayerIndex = s_currentPlayersAddress.length - 1; // 取出最后一个玩家索引
        address lastPlayerAddress = s_currentPlayersAddress[lastPlayerIndex]; // 取出最后一个玩家地址

        s_currentPlayersAddress[deleteIndex] = lastPlayerAddress; // 将最后一个玩家移动到要删除的位置
        s_currentPlayersIndex[lastPlayerAddress] = deleteIndex; // 更新最后一个玩家的索引

        s_currentPlayersAddress.pop(); // 删除最后一个玩家
        delete s_currentPlayersIndex[msg.sender]; // 删除要删除的地址的索引

        s_totalPlayers[msg.sender].isInDungeon = false;
        s_totalPlayers[msg.sender].lastUpdateTime = block.timestamp;

        // Interactions
    }

    function withdraw() external payable {
        // Checks
        uint256 balance = s_totalPlayers[msg.sender].balance;
        if (balance <= 0) {
            revert EnterDungeon__NoBalance();
        }
        if (address(this).balance < balance) {
            revert EnterDungeon__NotEnoughBalance();
        }
        // Effects
        s_totalPlayers[msg.sender].balance = 0;
        s_totalPendingRewards -= balance;

        // Interactions
        (bool success,) = payable(msg.sender).call{value: balance}("");
        if (!success) {
            revert EnterDungeon__TransferFailed();
        }
    }

    function withdrawAll() external onlyOwner {
        uint256 balance = address(this).balance;
        uint256 reservedBalance = s_totalPendingRewards + s_snapshotPoolBalance;
        if (balance <= reservedBalance) {
            revert EnterDungeon__NoAvailableBalance();
        }
        uint256 availableBalance = balance - reservedBalance;
        (bool success,) = payable(msg.sender).call{value: availableBalance}("");
        if (!success) {
            revert EnterDungeon__AllTransferFailed();
        }
    }

    // getter
    function getPlayer(address _player) public view returns (Player memory) {
        return s_totalPlayers[_player];
    }

    function getCurrentPlayersCount() public view returns (uint256) {
        return s_currentPlayersAddress.length;
    }

    function getCurrentPlayersAddress() public view returns (address[] memory) {
        return s_currentPlayersAddress;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getJackpotPoolBalance() public view returns (uint256) {
        return s_snapshotPoolBalance;
    }

    function getRequestId() public view returns (uint256) {
        return s_requestId;
    }
}
