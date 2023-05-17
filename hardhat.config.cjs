require('dotenv').config({path: './.env'})
require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-etherscan")
require('hardhat-contract-sizer')
require("hardhat-watcher")
require('hardhat-abi-exporter')

module.exports = {
  abiExporter: {
    path: "./abis",
    clear: true,
    flat: true
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true
    },
    // testnet: {
    //   url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
    //   chainId: 5,
    //   accounts: [`${process.env.PRIVATE_KEY}`]
    // },
    // mainnet: {
    //   url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    //   chainId: 1,
    //   accounts: [`${process.env.PRIVATE_KEY}`]
    // },
  },
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  mocha: {
    timeout: 360000
  },
  // etherscan: {
  //   apiKey: process.env.ETHERSCAN_API_KEY || "",
  // },
  watcher: {
    compile: {
      tasks: ["compile"],
      files: ["./contracts"],
      verbose: true,
    }
  }
}
