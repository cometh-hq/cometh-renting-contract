const assert = require("assert");
const RentingContractFactory = artifacts.require("RentingContractFactory");

function requireEnv(name) {
  const v = process.env[name];
  assert(!!v, `env ${name} required`);
  return v;
}

module.exports = async function (deployer, network) {
  if (network != "matic") {
    return
  }
  const mustAddress = requireEnv("MUST");
  const spaceshipsAddress = requireEnv("SPACESHIPS");
  const stakedSpaceShipsAddress = requireEnv("STAKED_SPACESHIPS");
  const mustManagerAddress = requireEnv("MUSTMANAGER");
  deployer.deploy(RentingContractFactory, mustAddress, spaceshipsAddress, stakedSpaceShipsAddress, mustManagerAddress);
};
