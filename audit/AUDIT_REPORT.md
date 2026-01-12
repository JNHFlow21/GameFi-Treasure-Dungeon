# Audit Report

## Executive Summary
- 审计范围：`src/EnterDungeon.sol`、`src/JackpotPool.sol`、`src/PriceConverter.sol`。
- 漏洞统计：Critical 0 / High 1 / Medium 3 / Low 0 / Informational 0。

## Detailed Findings

### 1) Jackpot 奖池使用总余额计算，未排除玩家已获奖励负债（High）
**Description:**
`EnterDungeon.getSnapshotofCurrentPlayersCountAndPoolBalance` 直接用合约总余额计算奖池锁仓金额，忽略了玩家已获得但未提现的奖励余额。这样会把本该属于玩家的可提现余额算入奖池，导致奖池后续派奖后出现资金缺口，玩家提现失败（资金不可用/DoS），甚至形成系统性不偿付。

**Location:**
- `src/EnterDungeon.sol:195`
- `src/EnterDungeon.sol:207`

**Remediation:**
- 增加 `s_totalPendingRewards` 追踪待支付奖励余额；
- 锁仓时使用 `freeBalance = balance - s_totalPendingRewards` 计算奖池；
- 在随机返现、派奖与提现时同步更新 `s_totalPendingRewards`。

### 2) 奖池在无玩家时会被锁死（Medium）
**Description:**
当锁仓时快照玩家数量为 0，`JackpotPool` 会进入 `LOCKED` 状态，但在抽奖阶段因 `s_snapshotPlayersCount > 0` 条件不满足而无法进入抽奖流程，导致状态永久停留在 `LOCKED`，系统无法继续下一轮。

**Location:**
- `src/JackpotPool.sol:98`

**Remediation:**
- 在锁仓步骤发现 `s_snapshotPlayersCount == 0` 时，直接将状态重置为 `OPEN` 并刷新下一轮时间。

### 3) 管理员可一次性提走全部资金（Medium）
**Description:**
`withdrawAll` 允许合约 owner 直接提走全部余额，包含玩家已获奖励与锁仓奖池，造成资金被管理员/被盗 key 直接抽走的风险。

**Location:**
- `src/EnterDungeon.sol:264`

**Remediation:**
- 仅允许提取“可用余额”（合约余额减去玩家待提现余额与锁仓奖池余额），避免影响玩家权益。

### 4) 预言机价格缺乏有效性校验（Medium）
**Description:**
`PriceConverter.getPrice` 未校验 `price > 0`、`updatedAt`、`answeredInRound` 等字段；如果喂价异常或过期，可能导致入场费计算错误（低价入场或直接 DoS）。

**Location:**
- `src/PriceConverter.sol:20`

**Remediation:**
- 增加价格为正、时间戳有效、轮次一致性校验；
- 统一按 `Aggregator.decimals()` 缩放到 1e18 精度。

## Tool Analysis
- 使用 Slither 进行静态分析（报告保存在 `audit/slither-report.txt`）。
- 人工审计覆盖玩家入场、随机返现、奖池锁仓/抽奖、提现及管理员权限路径。
