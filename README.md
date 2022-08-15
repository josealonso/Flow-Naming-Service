## Flow Name Service

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

### Add contract paths and aliases

```
flow config add contract
```

Added three different contracts: `FungibleToken.cdc`, `NonFungibleToken.cdc` and `Domains.cdc`

### Configure the deployment

```
flow config add deployment
```

- Choose `testnet` network, `testnet` account and `Domains` contract.

- After all the process ---> `Deployment added to the configuration.`

- Notice the `deployments` property has been added to the JSON object.

### Actually deploy

```
flow project deploy --network=testnet
```




