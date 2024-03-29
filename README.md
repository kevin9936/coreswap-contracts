# coreBTC protocol v1

This repository contains the smart contracts for the coreBTC protocol. The repository uses Hardhat as a development environment for compilation, testing, and deployment tasks. The project is forked from the https://github.com/TeleportDAO/teleswap-contracts project.

## What is coreBTC?

coreBTC is a fully decentralized protocol for bridging BTC between Bitcoin and Core chain securely.

## Audits
- [Halborn report](https://www.halborn.com/audits/coredao/corebtc) (Mar 2024)

## Community
- Follow us on [Twitter](https://twitter.com/Coredao_Org).
- Join our [discord channel](https://discord.com/invite/coredaoofficial).

## Install dependencies

To start, clone the codes and install the required packages using:

`yarn`

## Compile contracts

To compile the codes, use the below command:

`yarn clean` & `yarn build`

## Run tests

You can run the entire test suite with the following command:

`yarn test`

## Deploy contracts

You can deploy contracts on supported networks (testnet or mainnet) with the following command:

`NETWORK= yarn deploy`

## Config contracts

After deployment, some variables need to be set using the following commands:

`NETWORK= yarn init_config`

Run the below command with a different private key to config upgradable contracts:

`NETWORK= yarn config_upgradables`
