// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AutomationCompatibleInterface} from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2PLUS.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

error JackpotPool__InvalidRequestId();
error JackpotPool__InvalidState();

interface IEnterDungeon {
    function getSnapshotofCurrentPlayersCountAndPoolBalance() external returns (uint256, uint256); // 获取当前在线玩家数量和锁仓奖池金额
    function payWinnerByIndex(uint256 index) external returns (address); // 给玩家增加余额
}

contract JackpotPool is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* Type Declarations */
    enum State {
        OPEN, // 开放状态，可以参与抽奖
        LOCKED, // 锁定状态，不能参与抽奖
        DRAWING // 抽奖状态，正在抽奖

    }

    /* State Variables */
    IEnterDungeon public immutable i_enterDungeon;

    // Jackpot Pool Variables
    State public s_state = State.OPEN;
    uint256 public s_nextDrawTime;
    uint256 public constant LOCK_OFFSET = 5 minutes; // 5分钟锁仓时间
    uint256 public s_winnings;
    address public s_recentWinner;
    uint256 public s_snapshotPlayersCount;
    bytes1 private constant STEP_LOCK = 0x01;
    bytes1 private constant STEP_DRAW = 0x02;
    uint256 private s_lastRequestId;

    // Chainlink Automation Variables
    uint256 public immutable i_interval;
    uint256 public s_lastTimeStamp;

    // Chainlink VRF Variables
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane; // keyHash
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    bool private s_enableNativePayment; // true:ETH, false:LINK

    constructor(
        address _enterDungeon,
        uint256 _interval,
        address _vrfCoordinator,
        uint256 _subscriptionId,
        bytes32 _gasLane,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_enterDungeon = IEnterDungeon(_enterDungeon);
        i_subscriptionId = _subscriptionId;
        i_gasLane = _gasLane;
        i_callbackGasLimit = _callbackGasLimit;
        i_interval = _interval;
        s_lastTimeStamp = block.timestamp;
        s_nextDrawTime = block.timestamp + i_interval;
    }

    /**
     * @notice checkUpkeep
     * @dev 检查是否需要执行 upkeep，注意是view，一定不能修改数据，否则会直接失败
     * @param  检查数据
     * @return upkeepNeeded 是否需要执行 upkeep
     * @return performData 执行数据，这里是奖池状态
     */
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        if (
            s_state == State.OPEN && block.timestamp >= s_nextDrawTime - LOCK_OFFSET && block.timestamp < s_nextDrawTime
        ) {
            // 开始锁仓，不能参与抽奖
            // 此时 s_state = State.OPEN == 0;
            return (true, abi.encode(STEP_LOCK));
        } else if (s_state == State.LOCKED && block.timestamp >= s_nextDrawTime) {
            // 开始抽奖
            // 此时 s_state = State.LOCKED == 1;
            return (true, abi.encode(STEP_DRAW));
        } else {
            // 其他状态，不需要执行 upkeep
            return (false, "0x0");
        }
    }

    /**
     * @notice performUpkeep
     * @dev 执行 upkeep
     * @param performData 执行数据，这里是奖池状态
     */
    function performUpkeep(bytes calldata performData) external override {
        bytes1 step = abi.decode(performData, (bytes1));
        if (
            step == STEP_LOCK && s_state == State.OPEN && block.timestamp >= s_nextDrawTime - LOCK_OFFSET
                && block.timestamp < s_nextDrawTime
        ) {
            s_state = State.LOCKED;
            // 锁仓
            (s_snapshotPlayersCount, s_winnings) = i_enterDungeon.getSnapshotofCurrentPlayersCountAndPoolBalance();
        } else if (
            step == STEP_DRAW && s_state == State.LOCKED && block.timestamp >= s_nextDrawTime
                && s_snapshotPlayersCount > 0
        ) {
            s_state = State.DRAWING;
            // 请求随机数
            s_lastRequestId = requestRandomNumber();
            s_lastTimeStamp = block.timestamp;
        }
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
    }

    /**
     * @notice fulfillRandomWords
     * @dev 当VRF请求随机数成功后，会调用这个函数，里面是拿到随机数后的具体处理逻辑
     *      调用者是 VRF Coordinator，要使用requestId映射playerAddress
     * @param  requestId 请求ID
     * @param randomWords 随机数
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // Checks
        if (s_lastRequestId != requestId) revert JackpotPool__InvalidRequestId();
        if (s_state != State.DRAWING) revert JackpotPool__InvalidState();

        // Effects
        uint256 winnerIndex = randomWords[0] % s_snapshotPlayersCount;

        s_state = State.OPEN;
        s_lastTimeStamp = block.timestamp;
        s_nextDrawTime = block.timestamp + i_interval;

        // Interactions
        // 给玩家增加余额
        s_recentWinner = i_enterDungeon.payWinnerByIndex(winnerIndex);
    }
}
