const HDWalletProvider = require("@truffle/hdwallet-provider");
const path = require("path");

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!


  contracts_build_directory: path.join(__dirname, "build"),
  networks: {
    develop: { // default with truffle unbox is 7545, but we can use develop to test changes, ex. truffle migrate --network develop
      host: "127.0.0.1",
      port: 8545,
      network_id: "*"
    },
    rinkeby: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, `https://rinkeby.infura.io/v3/${process.env.INFURA_ID}`),
      network_id: '4',
      skipDryRun: true
    },
    kovan: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, `https://kovan.infura.io/v3/${process.env.INFURA_ID}`),
      network_id: '42',
      skipDryRun: true
    },
    ganache: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, "http://localhost:7545"),
      network_id: '1337',
      skipDryRun: true
    },
    matic_goerli: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, "https://rpc-mumbai.matic.today"),
      network_id: '80001',
      gasPrice: '1000000000',
      confirmations: 1,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    matic: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, 'https://rpc-mainnet.matic.network'),
      network_id: 137,
      gasPrice: '1000000000',
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    goerli: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, `https://goerli.infura.io/v3/${process.env.INFURA_ID}`),
      network_id: '5',
      gasPrice: '1000000000',
      skipDryRun: true
    }


  },
  compilers: {
    solc: {
      version: "0.6.12",
      settings: {
        enabled: true
      }
    }
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    etherscan: '9D4R76MXHKZ9EUKUUZ5PVICKCTSEI3K69I'
  }
};
