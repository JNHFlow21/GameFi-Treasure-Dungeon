# INTERVIEW PREP (Bybit 审计岗)

## Project Walkthrough
- **入场（EnterDungeon）**：玩家支付约 10 美元等值的 ETH，进入地牢并触发 Chainlink VRF 随机返现；玩家状态与余额记录在 `s_totalPlayers`。
- **随机返现（VRF）**：`fulfillRandomWords` 根据随机数给玩家记账返现（余额可提现），同时维护在线玩家数组。
- **Jackpot 抽奖**：`JackpotPool` 通过 Automation 在锁仓窗口快照在线玩家与奖池金额，并在开奖时调用 VRF 随机选择胜者，调用 `payWinnerByIndex` 记账派奖。
- **提现/退出**：玩家调用 `withdraw` 提取余额；`exitDungeon` 将玩家从在线列表移除。
- **定价**：`PriceConverter` 使用 Chainlink ETH/USD 预言机进行入场费判断。

## Bug Deep Dive

### 漏洞 1：奖池计算包含玩家已获奖励，导致系统性欠付
**原理解析：**
奖池锁仓金额以合约总余额的 80% 计算，但合约余额里包含玩家尚未提现的奖励余额。这会把“已欠玩家的资产”再次拿来做奖池派奖，导致后续提现失败、出现实际资金缺口。

**修复思路：**
引入 `s_totalPendingRewards` 跟踪待支付奖励金额，计算奖池时用 `freeBalance = balance - pendingRewards`，派奖/提现时同步更新 pending。

**面试官问答脚本：**
- Q：你是如何发现奖池会挤占玩家余额的？
- A：我发现奖池金额直接从 `address(this).balance` 计算，而玩家返现只是记账余额并未即时转出，这意味着合约余额包含玩家权益。如果再按 80% 锁仓，会把玩家余额当作奖池资金，后续提现就可能失败。
- Q：你的修复方案是什么？
- A：我增加了 `s_totalPendingRewards` 记录全体玩家待提现余额，锁仓时只使用 `balance - pendingRewards` 作为奖池基数，并在返现、派奖、提现时同步更新该值，保证资产与负债一致。

### 漏洞 2：无人参与时奖池锁死（DoS）
**原理解析：**
锁仓时如果快照玩家数量为 0，会进入 `LOCKED` 状态；而抽奖步骤要求 `s_snapshotPlayersCount > 0`，导致无法进入抽奖流程，状态永久卡死在 `LOCKED`，整个系统无法继续下一轮。

**修复思路：**
在锁仓阶段检测到 0 玩家时，立即恢复到 `OPEN` 并刷新下一轮时间，避免系统停摆。

**面试官问答脚本：**
- Q：这个 DoS 是怎么产生的？
- A：`performUpkeep` 在锁仓时无条件进入 `LOCKED`，但抽奖阶段又需要玩家数量 > 0。0 人时不会进入抽奖也不会回到 OPEN，导致状态永久锁死。
- Q：你如何修复？
- A：在锁仓阶段检测到 0 玩家时直接回滚为 `OPEN`，并更新 `nextDrawTime`，保证下一个周期仍可进行。
