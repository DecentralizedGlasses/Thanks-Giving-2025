-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo " make deploy [ARGS=...]"

build:
	forge build


install:
	forge install Cyfrin/foundry-devops@0.1.0 &&\
	forge install smartcontractkit/chainlink@42c74fcd30969bca26a9aadc07463d1c2f473b8c &&
	forge install foundry-rs/forge-std@v1.7.0 &&\
	forge install transmissions11/solmate@v6 &&\

deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) \
	--private-key $(SEPOLIA_PRIVATE_KEY) \
	--broadcast --verify \
	--etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

test:
	forge test

anvil :
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1


NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

# if --network sepolia is used, then use sepolia stuff, otherwise anvil stuff
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) --legacy -vvvvv
endif


deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)