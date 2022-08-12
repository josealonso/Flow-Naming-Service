This is a [Flow](http://onflow.org/) project scaffolded with [flow-app-scafold](https://github.com/onflow/flow-app-scaffold).

## Getting Started

1. [Install the Flow CLI](https://github.com/onflow/flow-cli).

2. Start the emulator.

```bash
flow emulator
```

### Creating a testnet account

```
flow keys generate
```

- Create an account on testnet with the generated keys.
https://testnet-faucet.onflow.org/?key=<PUBLIC_KEY>

- After a few seconds of loading, it should give you back an account address! It will also tell you that it airdropped 1000 Flow Tokens into that account!

- Type the command

```
flow config add acccount
```
A new account is added under the `accounts` property of the `flow.json` object.

## Add contract paths and aliases

```
flow config add contract
```
