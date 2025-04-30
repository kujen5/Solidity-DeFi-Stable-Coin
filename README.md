# Solidity DeFi Stable Coin

`Solidity DeFi Stable Coin` is a project that aims to familiarize you with Solidity and Smart Contract concepts. It consists of a Decentralized Stable Coin called KSC and that is pegged 1:1 with United States Dollar (USD). Users can deposit collateral coins (ETH or BTC) and get KSC (our stable coin) in return while always being 200% overcollateralized => meaning they'd get 50 KSC for every deposited 100$. If a user's health factor breaks (means if they become under-collateralized) either due to a market crash or any other reason, they would get liquidated by a liquidator and have their whole debt wiped clean and the liquidator would get the deposited collateral at a discount.



## Getting Started

### Requirements

- [foundry](https://getfoundry.sh/)
    - You will know your installation is successful if you can run `forge --version`

### Setup

Clone this repository:
```
git clone https://github.com/kujen5/Solidity-DeFi-Stable-Coin
```

Create and setup an account on https://etherscan.io/ to claim an Etherscan API key.

Create and setup and account on https://dashboard.alchemy.com/ to be able to create an application using Ethereum Sepolia and finally claim your Sepolia RPC Url.

Create an account on https://metamask.io/ and setup a wallet to be able to claim your private key. You can also add metamask as a plugin in your browser.

Go to your Metamask wallet => Show test networks => select Sepolia. We'll be needing it.

Create an `.env` file where you put your private keys and API keys like this:
```
DEFAULT_ANVIL_PRIVATE_KEY=<value>
ETHEREUM_SEPOLIA_PRIVATE_KEY=<value>
ETHERSCAN_API_KEY=<value>
ETHEREUM_SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<value>

ZKSYNC_SEPOLIA_API_KEY=<value>
ZKSYNC_SEPOLIA_PRIVATE_KEY=<value>
#ZKSYNC_SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<value>
DEFAULT_ZKSYNC_LOCAL_KEY=<value>

SENDER_ADDRESS=<value>
```
(ZkSync will be added in the future)

Finally, source your `.env` file: `source .env` or you could just use your Makefile command which will source it automatically.


## Usage
1. Setup your `anvil` chain by running this command in your terminal:
```bash
anvil
```

You will find an RPC URL (`http://127.0.0.1:8545` by default) and multiple accounts associated with their corresponding private keys. Choose a private key to work with. 


2. Compile your code:
Run:

```bash
forge compile
```

Or:

```bash
make compile
```

3. Deploying the contract to the Anvil local chain:

Run:

```bash
forge script script/DeployKSC.s.sol --rpc-url http://127.0.0.1:8545  --broadcast --private-key $DEFAULT_ANVIL_PRIVATE_KEY
```

Or: 
```bash
make deploy
```

4. Deploying the contract to the Ethereum Sepolia testnet:

Run:
```bash
forge script script/DeployKSC.s.sol:script/DeployKSC --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --private-key $ETHEREUM_SEPOLIA_PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv
```

Or:
```bash
make deploy ARGS="--network ethsepolia"
```
You can now interact with your contract on chain by grabbing your contract's address and putting it in https://sepolia.etherscan.io/

### Interacting with the Smart Contract

#### Depositing Collateral and Minting KSC 

First, we have to get our user some WETH (wrapped ETH).
We start by first retrieving the WETH contract address:
```bash
$ cast call 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82 "getCollateralTokens()" --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f -- --abi "function getCollateralTokens() public view returns (address[] memory)"
0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000008a791620dd6260079bf849dc5567adc3f2fdc318000000000000000000000000b7f8bc63bbcad18155201308c8f3540b07f84f5e
```

We can now decode this to get the addresses:
```bash
$ cast abi-decode "getCollateralTokens() returns (address[])" 0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000020000000000000000000000008a791620dd6260079bf849dc5567adc3f2fdc318000000000000000000000000b7f8bc63bbcad18155201308c8f3540b07f84f5e
[0x8A791620dd6260079BF849Dc5567aDC3F2FdC318, 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e]
```

The first address belongs to the WETH contract.
We can now mint our user some WETH:
```bash
$ cast send 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318 "mint(address,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 100000000000000000000 --rpc-url 127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

blockHash               0x252c49de812ec7e4145d12c168723e89eabca26033118f5796ef63f743e96b59
blockNumber             13
contractAddress
cumulativeGasUsed       34272
effectiveGasPrice       223329865
from                    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
gasUsed                 34272
logs                    [{"address":"0x8a791620dd6260079bf849dc5567adc3f2fdc318","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x0000000000000000000000000000000000000000000000000000000000000000","0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266"],"data":"0x0000000000000000000000000000000000000000000000056bc75e2d63100000","blockHash":"0x252c49de812ec7e4145d12c168723e89eabca26033118f5796ef63f743e96b59","blockNumber":"0xd","blockTimestamp":"0x68124417","transactionHash":"0xb0dd3fb25142ca779ae68f4cddc6efcedb1419c19add38b683217b86ff05bb69","transactionIndex":"0x0","logIndex":"0x0","removed":false}]
logsBloom               0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000020000000000000100000800000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000008000000000000000000000000000000000000000000002000000200000000000000000040000002000000000000000000020000000000000000000000000000000000000000000000000000000000000000000
root
status                  1 (success)
transactionHash         0xb0dd3fb25142ca779ae68f4cddc6efcedb1419c19add38b683217b86ff05bb69
transactionIndex        0
type                    2
blobGasPrice            1
blobGasUsed
authorizationList
to                      0x8A791620dd6260079BF849Dc5567aDC3F2FdC318
```

Now we must approve KSCEngine to spend our WETH:
```bash
$ cast send 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318 "approveInternally(address,address,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82 100000000000000000000 --rpc-url 127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

blockHash               0x557446477833add5d5b82338f4d7c60d954e5c8b31263d9927b3a74716c5a380
blockNumber             14
contractAddress
cumulativeGasUsed       26962
effectiveGasPrice       195477416
from                    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
gasUsed                 26962
logs                    [{"address":"0x8a791620dd6260079bf849dc5567adc3f2fdc318","topics":["0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925","0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266","0x0000000000000000000000000dcd1bf9a1b36ce34237eeafef220932846bcd82"],"data":"0x0000000000000000000000000000000000000000000000056bc75e2d63100000","blockHash":"0x557446477833add5d5b82338f4d7c60d954e5c8b31263d9927b3a74716c5a380","blockNumber":"0xe","blockTimestamp":"0x6812443f","transactionHash":"0xca759b9fc8791f46c73e90e202c5c987ca5070388240fd9a2cb9c9f883cd4518","transactionIndex":"0x0","logIndex":"0x0","removed":false}]
logsBloom               0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000100000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022000000000000000000000008000000000000000000000000000000000000000000000000000200000000000000000040000002000000000000000000000000010000000000000000000000000000000000000080000000000000000000000
root
status                  1 (success)
transactionHash         0xca759b9fc8791f46c73e90e202c5c987ca5070388240fd9a2cb9c9f883cd4518
transactionIndex        0
type                    2
blobGasPrice            1
blobGasUsed
authorizationList
to                      0x8A791620dd6260079BF849Dc5567aDC3F2FdC318
```

And finally we can go ahead and deposit some collateral:
```bash
$ cast send 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82 "depositCollateral(address,uint256)" 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318 100000000000000000000 --rpc-url 127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

blockHash               0x580a62572000f4b5c7660369cd3e7ad19982b3b0d28feaef5784240e6ab11cc9
blockNumber             16
contractAddress
cumulativeGasUsed       50248
effectiveGasPrice       149907388
from                    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
gasUsed                 50248
logs                    [{"address":"0x0dcd1bf9a1b36ce34237eeafef220932846bcd82","topics":["0xf1c0dd7e9b98bbff859029005ef89b127af049cd18df1a8d79f0b7e019911e56"],"data":"0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb922660000000000000000000000008a791620dd6260079bf849dc5567adc3f2fdc3180000000000000000000000000000000000000000000000056bc75e2d63100000","blockHash":"0x580a62572000f4b5c7660369cd3e7ad19982b3b0d28feaef5784240e6ab11cc9","blockNumber":"0x10","blockTimestamp":"0x681249ec","transactionHash":"0x86f638191cc8632a3e90b83a6eb02acec95dfa44f1eed300bb48ed4969e79e36","transactionIndex":"0x0","logIndex":"0x0","removed":false},{"address":"0x8a791620dd6260079bf849dc5567adc3f2fdc318","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266","0x0000000000000000000000000dcd1bf9a1b36ce34237eeafef220932846bcd82"],"data":"0x0000000000000000000000000000000000000000000000056bc75e2d63100000","blockHash":"0x580a62572000f4b5c7660369cd3e7ad19982b3b0d28feaef5784240e6ab11cc9","blockNumber":"0x10","blockTimestamp":"0x681249ec","transactionHash":"0x86f638191cc8632a3e90b83a6eb02acec95dfa44f1eed300bb48ed4969e79e36","transactionIndex":"0x0","logIndex":"0x1","removed":false}]
logsBloom               0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000100000000000004000000000000000000008000001000000080000000000000000000000100000000000000000000000000000000000000000000002000000000000000000000000000020000000000000000000000080000000000000000000000000000000000000000000020000002000000000000000000500000020000000800000000000000000000000000000000000000000000000000000000a0000000000000000000000
root
status                  1 (success)
transactionHash         0x86f638191cc8632a3e90b83a6eb02acec95dfa44f1eed300bb48ed4969e79e36
transactionIndex        0
type                    2
blobGasPrice            1
blobGasUsed
authorizationList
to                      0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82
```

First we can check out collateral balance:
```bash
$ cast call 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82 "getCollateralBalanceOfUser(address,address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318 --rpc-url 127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efca
e784d7bf4f2ff80
0x0000000000000000000000000000000000000000000000008ac7230489e80000
```

And we can verify the value and that it matches our initial deposited WETH:
```bash
$ cast --to-base 0x0000000000000000000000000000000000000000000000008ac7230489e80000 decimal
10000000000000000000
```

Now let's mint some KSC:
```bash
$ cast send 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82 "mintKSC(uint256)" 100 --rpc-url 127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

blockHash               0xce5a4471c2b4a8fcaa60987ae3a06008dfd8bd48c6fd6e8277583d2cdefc7671
blockNumber             15
contractAddress
cumulativeGasUsed       144881
effectiveGasPrice       171086660
from                    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
gasUsed                 144881
logs                    [{"address":"0xa51c1fc2f0d1a1b8494ed1fe312d7c3a78ed91c0","topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef","0x0000000000000000000000000000000000000000000000000000000000000000","0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266"],"data":"0x0000000000000000000000000000000000000000000000000000000000000064","blockHash":"0xce5a4471c2b4a8fcaa60987ae3a06008dfd8bd48c6fd6e8277583d2cdefc7671","blockNumber":"0xf","blockTimestamp":"0x681249d5","transactionHash":"0x2308fe52805e5cbf5ca5952485cb48ebb523ab7a096f89ea9ebf575bdd9c5f3f","transactionIndex":"0x0","logIndex":"0x0","removed":false}]
logsBloom               0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000020000000000000100000800000000000000000000000010000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000200000000000000000000000002000000000000000000020000000000000000000000000000002000000000000000000000000400000000000
root
status                  1 (success)
transactionHash         0x2308fe52805e5cbf5ca5952485cb48ebb523ab7a096f89ea9ebf575bdd9c5f3f
transactionIndex        0
type                    2
blobGasPrice            1
blobGasUsed
authorizationList
to                      0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82
```

Now we can check how much KSC we minted and our available collateral value in USD:
```bash
$ cast call 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82 "getAccountInfo(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url 127.0.0.1:8545 -- --abi "function getAccountInfo(address) view returns (uint256, uint256)"
0x0000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000002e963951560b51800000
```

Decrypting this:
```bash
$ cast abi-decode "getAccountInfo() returns (uint256,uint256)" 0x0000000000000000000000000000000000000000000000000000000000000064000000000000000000000000000000000000000000002e963951560b51800000
100
220000000000000000000000 [2.2e23]
```
And we can confirm that we have 100 KSC and 220,000USD in collateral.
(I deposited a bit more in the backstage haha)
 

## Test Coverage

The current test coverage is at ~85% with unit and fuzz tests with 49 tests and 500lines+ of testing in total, it's still not perfect but I will keep working on it in the future :

```
╭------------------------------------------------------------+------------------+------------------+----------------+-----------------╮
| File                                                       | % Lines          | % Statements     | % Branches     | % Funcs         |
+=====================================================================================================================================+
| script/DeployKSC.s.sol                                     | 100.00% (12/12)  | 100.00% (14/14)  | 100.00% (0/0)  | 100.00% (1/1)   |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| script/HelperConfig.s.sol                                  | 75.00% (12/16)   | 84.21% (16/19)   | 33.33% (1/3)   | 66.67% (2/3)    |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| src/KSCEngine.sol                                          | 97.52% (118/121) | 97.25% (106/109) | 80.00% (8/10)  | 100.00% (33/33) |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| src/KujenStableCoin.sol                                    | 100.00% (14/14)  | 100.00% (13/13)  | 100.00% (4/4)  | 100.00% (2/2)   |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| src/libraries/OracleLib.sol                                | 50.00% (10/20)   | 50.00% (12/24)   | 50.00% (2/4)   | 50.00% (2/4)    |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| test/fuzz/continue_on_revert/ContinueOnRevertHandler.t.sol | 90.70% (39/43)   | 92.31% (36/39)   | 100.00% (2/2)  | 90.00% (9/10)   |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| test/fuzz/fail_on_revert/FailOnRevertHandler.t.sol         | 86.54% (45/52)   | 84.62% (44/52)   | 100.00% (5/5)  | 100.00% (8/8)   |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| test/mocks/ERC20Mock.sol                                   | 40.00% (4/10)    | 40.00% (2/5)     | 100.00% (0/0)  | 40.00% (2/5)    |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| test/mocks/MockFailedMintKSC.sol                           | 35.71% (5/14)    | 30.77% (4/13)    | 0.00% (0/4)    | 50.00% (1/2)    |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| test/mocks/MockFailedTransfer.sol                          | 36.36% (4/11)    | 22.22% (2/9)     | 0.00% (0/2)    | 66.67% (2/3)    |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| test/mocks/MockFailedTransferFrom.sol                      | 36.36% (4/11)    | 22.22% (2/9)     | 0.00% (0/2)    | 66.67% (2/3)    |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| test/mocks/MockMoreDebtKSC.sol                             | 76.47% (13/17)   | 73.33% (11/15)   | 0.00% (0/4)    | 100.00% (3/3)   |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| test/mocks/MockV3Aggregator.sol                            | 67.39% (31/46)   | 70.59% (24/34)   | 100.00% (0/0)  | 58.33% (7/12)   |
|------------------------------------------------------------+------------------+------------------+----------------+-----------------|
| Total                                                      | 80.36% (311/387) | 80.56% (286/355) | 55.00% (22/40) | 83.15% (74/89)  |
╰------------------------------------------------------------+------------------+------------------+----------------+-----------------╯
```



## TODO

- [ ] Implement more tests (Fuzz Tests / Unit Tests / Mutations Tests) to better test our code.
- [ ] Implement Network Configurations for ZkSync Sepolia, Arbitrum Sepolia, and other networks.
- [ ] Add more features.

## Thank you!

This project has been made with love as a learning experience. The best is yet to come.
Please give the project a star if you like it!