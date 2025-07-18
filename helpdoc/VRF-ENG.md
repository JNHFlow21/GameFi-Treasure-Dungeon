chainlink-brownie-contracts/version:1.3.0
⸻

1. Import
,,,
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2PLUS.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
,,,

⸻

2. Inherit VRFConsumerBaseV2Plus
,,,
contract EnterDungeon is VRFConsumerBaseV2Plus{}
,,,

⸻

3. State Variables
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

4. Constructor Parameters
,,,
    constructor(address _vrfCoordinator, uint256 _subscriptionId, bytes32 _gasLane, uint32 _callbackGasLimit) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_subscriptionId = _subscriptionId;
        i_gasLane = _gasLane;
        i_callbackGasLimit = _callbackGasLimit;
    }
,,,

⸻

5. Custom Function requestRandomNumber() – Encapsulate the Randomness Request
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

6. Override Function fulfillRandomWords() – Handle the Randomness Response
,,,
    /**
     * @notice fulfillRandomWords
     * @dev 当VRF请求随机数成功后，会调用这个函数，里面是拿到随机数后的具体处理逻辑
     *      调用者是 VRF Coordinator，要使用requestId映射playerAddress
     * @param  requestId 请求ID
     * @param randomWords 随机数
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // 获取玩家地址
        address playerAddress = s_requestIdToPlayerAddress[requestId];

        // TODO:
    }
,,,

⸻

⚠️⚠️⚠️ : At last, don't forget add consumer(your contract address) [Chainlink-VRF-UI](https://vrf.chain.link/)

7. Test locally with mock

7.1 Import
,,,
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
,,,

7.2 Do these steps at your HelperConfig.s.sol or Deploy.s.sol
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

7.3 Solve the Error : Arithmetic Underflow in createSubscription
While attempting to create a subId using the createSubscription function in SubscriptionApi.sol, I encountered an arithmetic underflow error. The function is responsible for generating unique subscription ID by hashing several parameters, including block.number - 1.
solution is:
,,,
  /**
   * @inheritdoc IVRFSubscriptionV2Plus
   */
  function createSubscription() external override nonReentrant returns (uint256 subId) {
    // Generate a subscription id that is globally unique.
    uint64 currentSubNonce = s_currentSubNonce;
    subId = uint256(
    // block.number - 1 --> block.number
      keccak256(abi.encodePacked(msg.sender, blockhash(block.number), address(this), currentSubNonce))
    );
,,,

