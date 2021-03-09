const LendingContractFactory = artifacts.require("LendingContractFactory");

function requireEnv(name) {
  const v = process.env[name];
  assert(!!v, `env ${name} required`);
  return v;
}

module.exports = async function (deployer, network) {
  if (network != "production") {
    return
  }
  const mustAddress = requireEnv("MUST");
  const spaceshipsAddress = requireEnv("SPACESHIPS");
  const stakedSpaceShipsAddress = requireEnv("STAKED_SPACESHIPS");
  const mustManagerAddress = requireEnv("MUSTMANAGER");
  deployer.deploy(LendingContractFactory, mustAddress, spaceshipsAddress, stakedSpaceShipsAddress, mustManagerAddress);
};
