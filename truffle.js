var Web3 = require('web3')

module.exports = {
  networks: {
    development: {
      provider: new Web3('ws://localhost:8545'),
      network_id: "*", // Match any network id
      gasPrice: 10 ** 9,
      gas: 6000000
    },
    coverage: {
      host: "localhost",
      network_id: "1337",
      port: 8555,
      gas: 0xfffffffffff,
      gasPrice: 0x01
    },
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 500
    }
  }
};
