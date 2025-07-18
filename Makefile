-include .env
export

.PHONY: all test clean build update format anvil help deploy-anvil deploy-sepolia deploy-mainnet

# ========== 通用命令 ==========
all: clean install update build

clean:
	forge clean

install:
	forge install foundry-rs/forge-std
	forge install smartcontractkit/chainlink-brownie-contracts@1.3.0
	forge install transmissions11/solmate@v6

update:
	forge update

build:
	forge build

# ========== 测试相关命令 ==========
test:
	@echo "🧪 Running Tests..."
	forge test -vvv

snapshot:
	forge snapshot

format:
	forge fmt

# ========== 网络命令 ==========
anvil:
	@echo "🚀 Starting local Anvil chain..."
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 12

# ========== 部署命令 ==========
deploy-anvil:
	@echo "🚀 Deploying to local Anvil..."
	@forge script script/DeployGame.s.sol:DeployGame --rpc-url $(ANVIL_FORK_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vvv

deploy-sepolia:
	@echo "🚀 Deploying to Sepolia..."
	@forge script script/DeployGame.s.sol:DeployGame --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvv

deploy-mainnet:
	@echo "🚀 Deploying to Mainnet..."
	@forge script script/DeployGame.s.sol:DeployGame --rpc-url $(MAINNET_RPC_URL) --private-key $(MAINNET_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvv

# ========== 实用工具 ==========
check-balance:
	@echo "🔍 Checking wallet balance..."
	@ADDRESS=$$(cast wallet address --private-key $(SEPOLIA_PRIVATE_KEY)) && \
	echo "📮 Wallet address: $$ADDRESS" && \
	echo "💰 ETH Balance: " && \
	cast balance $$ADDRESS --rpc-url $(SEPOLIA_RPC_URL)

pk-to-address:
	@echo "🔍 Search private key to address..."
	@echo "🔍 Your wallet address:"
	@cast wallet address $(SEPOLIA_PRIVATE_KEY)

# ========== 帮助信息 ==========
help:
	@echo "✅ Makefile Command Guide:"
	@echo "make install                # Install dependencies"
	@echo "make build                  # Build project"
	@echo "make test                   # Run tests"
	@echo "make format                 # Format code"
	@echo "make anvil                  # Start local Anvil chain"
	@echo "make deploy-anvil           # Deploy to local Anvil chain"
	@echo "make deploy-sepolia         # Deploy to Sepolia testnet"
	@echo "make check-balance          # Check wallet ETH balance"
	@echo "make pk-to-address          # Search private key to address"
