[![CI](https://github.com/Semios-Protocol/SemiOS-contract/actions/workflows/ci.yml/badge.svg)][gh-ci]
[![License](https://img.shields.io/badge/License-MIT-orange.svg)][mit-license]
[![Chat][tg-badge]][tg-url]

[mit-license]: https://opensource.org/license/mit/
[gh-ci]: https://github.com/Semios-Protocol/SemiOS-contract/actions/workflows/main.yml
[tg-url]:  https://t.me/c/2070866902/1
[tg-badge]: https://img.shields.io/badge/chat-telegram-blue
## Getting Started

```sh
git clone git@github.com:Semios-Protocol/SemiOS-contract.git
cd SemiOS-contract
pnpm install # install Solhint, Prettier, and other Node.js deps
```

## Usage

This is a list of the most frequently needed commands.

### install package

Build the contracts:

```sh
$ npm install
```

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge build
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Deploy

Deploy to Anvil:

```sh
$ ENV=<your env> forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

For this script to work, you need to have a `MNEMONIC` environment variable set to a valid
[BIP39 mnemonic](https://iancoleman.io/bip39/), or providing the private key by adding --private-key=<your private key>

It is also required that the path deployed-contract-info/<your env>-d4a.json exsits and neccessary keys for contract
names are prepared. You can see deployed-contract-info/test-d4a.json as an example and run

```sh
$ ENV=test forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
```

After deploying, all contracts' addresses are recorded in deployed-contract-info/<your env>-d4a.json. Make sure that the
environment name in your deploy commond is consistent with the contract address file name prefix before "-d4a.json"

For instructions on how to deploy to a testnet or mainnet, check out the
[Solidity Scripting](https://book.getfoundry.sh/tutorials/solidity-scripting.html) tutorial.

### Generate abi and selectors

```sh
$ bash updateAbiANDSelector.sh
```

Files are generated in path deployed-contract-info

### Format

Format the contracts:

```sh
$ forge fmt
```

### Gas Usage

Get a gas report:

```sh
$ forge test --gas-report
```

### Lint

Lint the contracts:

```sh
$ pnpm lint
```

### Test

Run the tests:

```sh
$ forge test
```

auto test on push is specified in .github/workflows/main.yml

## Notes

1. Foundry uses [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) to manage dependencies. For
   detailed instructions on working with dependencies, please refer to the
   [guide](https://book.getfoundry.sh/projects/dependencies.html) in the book
2. You don't have to create a `.env` file, but filling in the environment variables may be useful when debugging and
   testing against a fork.

## Related Efforts

- [abigger87/femplate](https://github.com/abigger87/femplate)
- [cleanunicorn/ethereum-smartcontract-template](https://github.com/cleanunicorn/ethereum-smartcontract-template)
- [foundry-rs/forge-template](https://github.com/foundry-rs/forge-template)
- [FrankieIsLost/forge-template](https://github.com/FrankieIsLost/forge-template)

## License

This project is licensed under MIT.
