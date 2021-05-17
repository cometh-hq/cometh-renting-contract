const assert = require("assert");
const RentalManager = artifacts.require("RentalManager");
const ProxyFactory = artifacts.require("ProxyFactory");
const OfferStore = artifacts.require("OfferStore");
const RentalStore = artifacts.require("RentalStore");
const Rental = artifacts.require("Rental");

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

  const proxyFactory = await deployer.deploy(ProxyFactory)
  const implementation = await deployer.deploy(Rental)

  const offerStore = await deployer.deploy(OfferStore)
  const rentalStore = await deployer.deploy(RentalStore)

  const rentalManager = await deployer.deploy(RentalManager, mustAddress, spaceshipsAddress, stakedSpaceShipsAddress, mustManagerAddress,
    proxyFactory.address, implementation.address, offerStore.address, rentalStore.address);

  await offerStore.updateModule(rentalManager.address)
  await rentalStore.updateModule(rentalManager.address)
};
