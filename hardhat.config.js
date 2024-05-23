require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("dotenv").config();

const { SEPOLIA_ARB_API_URL, PRIVATE_KEY } = process.env;

if (!SEPOLIA_ARB_API_URL || !PRIVATE_KEY) {
  throw new Error("Please set your SEPOLIA_ARB_API_URL and PRIVATE_KEY in a .env file");
}

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, // You can adjust this value to find the optimal balance between size and gas efficiency
      },
    },
  },
  defaultNetwork: "sepolia",
  networks: {
    hardhat: {},
    sepolia: {
      url: SEPOLIA_ARB_API_URL,
      accounts: [`0x${PRIVATE_KEY}`]
    },
    localhost: {
      url: "http://127.0.0.1:8545"
    }
  }
};
