-include .env

# Deploy
deploy 	:;	forge script script/Deploy.s.sol:DeployYieldNestNFT --rpc-url ${RPC_URL} --broadcast --etherscan-api-key ${ETHERSCAN_API_KEY} --verify
