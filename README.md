<<<<<<< HEAD
<<<<<<< HEAD
# foundry-lottery
Learn to build smart contract for lottery with foundry
=======
## Foundry
=======
 ## Foundry
>>>>>>> 9568a79 (Initial commit)

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
<<<<<<< HEAD
>>>>>>> 9ca6a61 (chore: forge init)
=======

## What we want it to do?
1.  Users can enter by paying for a ticket 
    1.  The ticket fees are going to go to the winner during the draw
2.  After X period of time, the lottery will automatically draw a winner
    1.  And this will be done programatically
3.  Using Chainlink VRF & Chainlink Automation
    1.  Chainlink VRF → Randomness
    2.  Chainlink Automation → Time based trigger

## Tests!
1. Write some deploy scipts
2. Write testings for: 
   1. Local chain
   2. Forked Testnet
   3. Forked Mainnet


<!-- 3:25:00 -->
<!-- 4:00:00 -->
<!-- 5:05:05 -->
<!-- 5:10:05 -->
<!-- 5:26:05 -->
>>>>>>> 9568a79 (Initial commit)
