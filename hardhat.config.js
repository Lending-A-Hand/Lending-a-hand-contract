/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require('hardhat-spdx-license-identifier')
require("@nomiclabs/hardhat-ethers")
require("@nomiclabs/hardhat-etherscan")

const mnemonic = process.env.MNEMONIC || 'test test test test test test test test test test test junk'

module.exports = {
   networks: {
    bscTestnet: {
      url: 'https://data-seed-prebsc-2-s1.binance.org:8545',
      chainId: 97,
      gasPrice: 10000000000,
      // accounts: {
      //   mnemonic: mnemonic,
      //   path: 'm/44\'/60\'/0\'/0',
      // }
    },
    bscMainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 5000000000,
    }
  },
  solidity: {
    version: '0.8.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000
      }
    }
  },
  etherscan: {
    apiKey: "FFZ7W524USQ2MX3Q5SQH3D4ZAPH4NS613D",
  },
  spdxLicenseIdentifier: {
    overwrite: true,
    runOnCompile: false,
  },
};
