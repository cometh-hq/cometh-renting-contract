const RentingContractFactory = artifacts.require("RentingContractFactory");

function requireEnv(name) {
  const v = process.env[name];
  assert(!!v, `env ${name} required`);
  return v;
}

module.exports = function (deployer, network) {
  if (network != "production") {
    return
  }
  const mustAddress = requireEnv("MUST");
  const spaceshipsAddress = requireEnv("SPACESHIPS");
  const stakedSpaceShipsAddress = requireEnv("STAKED_SPACESHIPS");
  deployer.deploy(RentingContractFactory, mustAddress, spaceshipsAddress, stakedSpaceShipsAddress);
};
