
# GameFi Treasure Dungeon

GameFi Treasure Dungeon 是一个基于 Solidity & Foundry 构建的链上小游戏。玩家支付固定门票（约 10 美元等值的 ETH）进入地牢探险：

1. 进入地牢 (`EnterDungeon`) 后会立即通过 **Chainlink VRF V2.5** 进行随机返现；
2. 部分 ETH 会锁仓到 **Jackpot 奖池**；
3. **Chainlink Automation** 定期触发抽奖，再次调用 VRF 随机选出一名在线玩家赢取整池奖励；
4. 支持提现、退出等完整的游戏闭环。

## 功能亮点

| 合约 | 作用 |
|------|------|
| `EnterDungeon` | 玩家入口，管理玩家状态、随机返现、提现等 |
| `JackpotPool`  | Jackpot 奖池，负责锁仓、定时抽奖与派奖 |
| `PriceConverter` | ETH/USD 价格转换库（基于 Chainlink 预言机） |

- **去中心化随机数**：Chainlink VRF V2.5
- **自动化执行**：Chainlink Automation (Keepers)
- **实时价格**：Chainlink ETH/USD 预言机
- **极速开发**：Foundry (Forge/Cast/Anvil)

## 目录结构

```text
├── src/                # 核心合约
├── script/             # 部署脚本 (Forge Script)
├── test/               # 单元测试
├── broadcast/          # Forge 脚本执行输出
├── Makefile            # 常用命令封装
└── foundry.toml        # Foundry 配置
```

## 快速开始（Quickstart）

> 以下所有命令均已写入 `Makefile`，可直接 `make <target>` 执行。

1. 克隆仓库并进入目录

```bash
git clone https://github.com/JNHFlow21/GameFi-Treasure-Dungeon.git
cd GameFi-Treasure-Dungeon
```

2. 安装依赖

```bash
make install        # 安装 Forge 子模块依赖
```

3. 编译合约

```bash
make build
```

4. 运行测试

```bash
make test
```

5. 本地启动链并部署

```bash
make anvil          # 启动本地 Anvil 链（已预置测试助记词）
# 另开终端窗口
make deploy-anvil   # 部署合约到本地链
```

6. 测试网 / 主网部署

在根目录创建按照`.env.example` 创建 `.env` 文件并填写以下变量：

```ini
# 示例 .env
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<ALCHEMY_KEY>
SEPOLIA_PRIVATE_KEY=0x<PRIVATE_KEY>
SEPOLIA_VRF_SUBSCRIPTION_ID=<SUB_ID>

MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/<ALCHEMY_KEY>
MAINNET_PRIVATE_KEY=0x<PRIVATE_KEY>
MAINNET_VRF_SUBSCRIPTION_ID=<SUB_ID>
```

然后执行：

```bash
make deploy-sepolia   # 部署到 Sepolia
```

7. 其他实用命令

```bash
make snapshot         # 生成 Gas 快照
make format           # 格式化代码
make check-balance    # 查询钱包余额
make pk-to-address    # 私钥转地址
make help             # 查看全部可用命令
```

## 依赖与参考

- [Foundry](https://github.com/foundry-rs/foundry)
- [Chainlink Contracts](https://github.com/smartcontractkit/chainlink-brownie-contracts)
- [solmate](https://github.com/transmissions11/solmate)

---
