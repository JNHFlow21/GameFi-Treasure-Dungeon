⸻

我使用的版本：chainlink-brownie-contracts version:1.3.0

⸻

1. Import 相关包
,,,
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2PLUS.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
,,,

⸻

2. 要使用的VRF功能的 contract 继承 VRFConsumerBaseV2Plus
,,,
contract EnterDungeon is VRFConsumerBaseV2Plus{}
,,,

⸻

3. 在contract中 声明下列VRF状态变量
,,,
    // Chainlink VRF Variables
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane; // keyHash
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    bool private s_enableNativePayment; // true:ETH, false:LINK
,,,

⸻

4. 重构你的 contract 的 constructor
,,,
    constructor(address _vrfCoordinator, uint256 _subscriptionId, bytes32 _gasLane, uint32 _callbackGasLimit) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_subscriptionId = _subscriptionId;
        i_gasLane = _gasLane;
        i_callbackGasLimit = _callbackGasLimit;
    }
,,,

⸻

5. 实现 requestRandomNumber()，用来封装随机数请求的逻辑
,,,
    /**
     * @notice requestRandomNumber
     * @dev 自己定义的一个函数，可以叫做任何名字，只是单独封装了VRF请求随机数的逻辑
     * @return requestId
     */
    function requestRandomNumber() public returns (uint256 requestId) {
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
,,,

⸻

6. 重写 fulfillRandomWords() 里面写你具体的业务逻辑
,,,
    /**
     * @notice fulfillRandomWords
     * @dev 当VRF请求随机数成功后，会调用这个函数，里面是拿到随机数后的具体处理逻辑
     *      调用者是 VRF Coordinator，要使用requestId映射playerAddress
     * @param  requestId 请求ID
     * @param randomWords 随机数
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // TODO:
    }
,,,

⸻

7. 本地 Mock 测试

7.1 导入 Mock 合约
,,,
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
,,,

7.2 部署 Mock 合约
,,,
        // 1. deploy vrfCoordinatorV2_5Mock
        vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );

        // 2. create subscription
        uint256 subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();

        // 3. fund subscription
        vrfCoordinatorV2_5Mock.fundSubscription(subscriptionId, FUND_LINK_AMOUNT); 
        // FUND_LINK_AMOUNT = 100000000000000000000 = 100 LINK

        // 4. add consumer
        vrfCoordinatorV2_5Mock.addConsumer(chainConfig.subscriptionId, address(consumer_addr));
,,,


7.3 常见报错 & 解决

报错信息	原因	解决办法
Arithmetic underflow in createSubscription()	mock 里用 blockhash(block.number - 1)，而本地链把前一区块 hash 置 0	把内部实现改成 blockhash(block.number)（已在下方补丁）

补丁示例：

// SubscriptionApi.sol 片段
subId = uint256(
  keccak256(
    abi.encodePacked(
      msg.sender,
      blockhash(block.number), // ← 修改
      address(this),
      s_currentSubNonce
    )
  )
);


⸻

🔗 线上部署别忘记

在 [Chainlink-VRF-UI](https://vrf.chain.link/) 手动 Add Consumer，否则主网请求将被拒绝。

⸻