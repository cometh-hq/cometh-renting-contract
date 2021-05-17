const RentalManager = artifacts.require("RentalManager")
const Rental = artifacts.require("Rental")
const StakedSpaceShips = artifacts.require("StakedSpaceShips");
const TestERC721 = artifacts.require("TestERC721")
const TestERC20 = artifacts.require("TestERC20")
const FakeGame = artifacts.require("FakeGame")
const ProxyFactory = artifacts.require("ProxyFactory")
const OfferStore = artifacts.require("OfferStore")
const RentalStore = artifacts.require("RentalStore")

const { assertRevertWith } = require('./utils');
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

contract('Rental', function(accounts) {
  const admin = accounts[0];
  const alice = accounts[1];
  const bob = accounts[2];

  let stakedSpaceShips;
  let game;
  let must;
  let offerStore;
  let rentalStore;

  const gameId = 1;
  const firstShip = 0
  const secondShip = 1
  const thirdShip = 2
  const fourthShip = 3
  const fithShip = 4
  const sixShip = 5

  const leaveFee = 1000000000000000;
  const minFee = 300000000000000;

  beforeEach(async () => {
    must = await TestERC20.new({ from: admin });
    must.mint(admin, '1000000000000000000000')
    spaceships = await TestERC721.new({ from: admin });

    stakedSpaceShips = await StakedSpaceShips.new("uri", spaceships.address, { from: admin });

    game = await FakeGame.new(must.address, stakedSpaceShips.address);
    await stakedSpaceShips.updateGames(gameId, game.address)

    await spaceships.mint(alice, { from: admin });
    await spaceships.mint(alice, { from: admin });
    await spaceships.mint(alice, { from: admin });

    const proxyFactory = await ProxyFactory.new()

    const impl = await Rental.new(
      must.address,
      spaceships.address,
      stakedSpaceShips.address,
      game.address,
      ZERO_ADDRESS,
      ZERO_ADDRESS,
      [],
      0,
      0
    )
    offerStore = await OfferStore.new()
    rentalStore = await RentalStore.new()
    factory = await RentalManager.new(
      must.address,
      spaceships.address,
      stakedSpaceShips.address,
      game.address,
      proxyFactory.address,
      impl.address,
      offerStore.address,
      rentalStore.address
    );

    await offerStore.updateModule(factory.address)
    await rentalStore.updateModule(factory.address)
    await must.transfer(bob, minFee, { from: admin });
  });

  describe('Rental', async () => {
    it("make offer over 5 ships", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await assertRevertWith(
        factory.makeOffer([firstShip, secondShip, thirdShip, fourthShip, fithShip, sixShip], 0, 50, minFee + 6 * leaveFee, ZERO_ADDRESS, { from: alice }),
        "more than 5 nft"
      )
    })

    it("make and acceptOffer", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip, secondShip, thirdShip], 0, 50, minFee + 3 * leaveFee, ZERO_ADDRESS, { from: alice });

      await must.transfer(bob,  3 * leaveFee, { from: admin });
      await must.approve(factory.address, 3 * leaveFee + minFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });

      const bobRentings = await factory.rentingsReceivedOf(bob);
      assert.equal(bobRentings.length, 1);

      const renting = await Rental.at(bobRentings[0].id);
      await renting.stake(firstShip, gameId, { from: bob })
      await renting.stake(secondShip, gameId, { from: bob })
      await renting.stake(thirdShip, gameId, { from: bob })

      assert.equal(await must.balanceOf(factory.address), 3 * leaveFee);
    })

    it("make and acceptOffer with fixed fee", async function() {
      await must.transfer(bob, 3 * leaveFee + 1, { from: admin });
      await must.approve(factory.address, 3 * leaveFee + minFee + 1, { from: bob });

      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip, secondShip, thirdShip], 0, 50, minFee + 1 + 3 * leaveFee, ZERO_ADDRESS, { from: alice });

      await factory.acceptOffer(0, { from: bob });

      const bobRentings = await factory.rentingsReceivedOf(bob);
      assert.equal(bobRentings.length, 1);
      assert.equal(await must.balanceOf(bob), 0);
      assert.equal(await must.balanceOf(alice), 1);
    })

    it("claim", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 0, 50, minFee + 1 * leaveFee, ZERO_ADDRESS, { from: alice });

      await must.transfer(bob,  1 * leaveFee, { from: admin });
      await must.approve(factory.address, 1 * leaveFee + minFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });
      const renting = await Rental.at((await factory.rentingsReceivedOf(bob))[0].id);

      // erc20
      const erc20Reward = await TestERC20.new({ from: admin });
      await erc20Reward.mint(renting.address, 100, { from: admin });
      await renting.claim(erc20Reward.address, { from: alice });
      assert.equal(await erc20Reward.balanceOf(alice), 50);
      assert.equal(await erc20Reward.balanceOf(bob), 50);

      // native
      await web3.eth.sendTransaction({from: admin, to: renting.address, value: 100});
      const bobBalance = await web3.eth.getBalance(bob);
      await renting.claim(ZERO_ADDRESS, { from: alice });
      const bobNewBalance = await web3.eth.getBalance(bob);
      assert.equal(bobNewBalance, (BigInt(bobBalance) + BigInt(50)).toString());

      // must
      await must.transfer(renting.address, 100, { from: admin });
      await renting.claim(must.address, { from: alice });
      assert.equal(await must.balanceOf(bob), 100);
    })

    it("claimBatch", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 0, 50, minFee + 1 * leaveFee, ZERO_ADDRESS, { from: alice });

      await must.transfer(bob,  1 * leaveFee, { from: admin });
      await must.approve(factory.address, 1 * leaveFee + minFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });
      const renting = await Rental.at((await factory.rentingsReceivedOf(bob))[0].id);

      // erc20
      const erc20Reward = await TestERC20.new({ from: admin });
      await erc20Reward.mint(renting.address, 100, { from: admin });

      // native
      await web3.eth.sendTransaction({from: admin, to: renting.address, value: 100});
      const bobBalance = await web3.eth.getBalance(bob);

      // must
      await must.transfer(renting.address, 100, { from: admin });

      await renting.claimBatch([ZERO_ADDRESS, erc20Reward.address, must.address], { from: alice });
      const bobNewBalance = await web3.eth.getBalance(bob);

      assert.equal(await must.balanceOf(bob), 100);
      assert.equal(await erc20Reward.balanceOf(alice), 50);
      assert.equal(await erc20Reward.balanceOf(bob), 50);
      assert.equal(bobNewBalance, (BigInt(bobBalance) + BigInt(50)).toString());
    })

    it("close", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip, secondShip, thirdShip], 0, 50, minFee + 3 * leaveFee, ZERO_ADDRESS, { from: alice });

      await must.transfer(bob,  3 * leaveFee, { from: admin });
      await must.approve(factory.address, 3 * leaveFee + minFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });

      const renting = await Rental.at((await factory.rentingsReceivedOf(bob))[0].id);

      await renting.stake(secondShip, gameId, { from: bob })
      await must.transfer(renting.address,  1 * leaveFee, { from: admin });
      await stakedSpaceShips.exit(secondShip, '0x', { from: bob })

      await renting.close({ from: alice });

      assert.equal(await spaceships.ownerOf(firstShip), alice);
      assert.equal(await spaceships.ownerOf(secondShip), alice);
      assert.equal(await spaceships.ownerOf(thirdShip), alice);
    })

    it("claimBatchAndClose", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 0, 50, minFee + 1 * leaveFee, ZERO_ADDRESS, { from: alice });

      await must.transfer(bob,  1 * leaveFee, { from: admin });
      await must.approve(factory.address, 1 * leaveFee + minFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });
      const renting = await Rental.at((await factory.rentingsReceivedOf(bob))[0].id);

      // erc20
      const erc20Reward = await TestERC20.new({ from: admin });
      await erc20Reward.mint(renting.address, 100, { from: admin });

      // native
      await web3.eth.sendTransaction({from: admin, to: renting.address, value: 100});
      const bobBalance = await web3.eth.getBalance(bob);

      // must
      await must.transfer(renting.address, 100, { from: admin });

      await renting.claimBatchAndClose([ZERO_ADDRESS, erc20Reward.address, must.address], { from: alice });
      assert.equal(await spaceships.ownerOf(firstShip), alice);
    })

    it("can exit and re stake", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 0, 50, minFee + 1 * leaveFee, ZERO_ADDRESS, { from: alice });

      await must.transfer(bob,  1 * leaveFee, { from: admin });
      await must.approve(factory.address, 1 * leaveFee + minFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });

      const renting = await Rental.at((await factory.rentingsReceivedOf(bob))[0].id);

      await renting.stake(firstShip, gameId, { from: bob })
      await must.transfer(renting.address,  1 * leaveFee, { from: admin });
      await stakedSpaceShips.exit(firstShip, '0x', { from: bob })
      assert.equal(await spaceships.ownerOf(firstShip), renting.address);

      await renting.stake(firstShip, gameId, { from: bob });
      assert.equal(await stakedSpaceShips.ownerOf(firstShip), renting.address);
    })

    it("can leave game and re enter", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 0, 50, minFee + 1 * leaveFee, ZERO_ADDRESS, { from: alice });

      await must.transfer(bob,  1 * leaveFee, { from: admin });
      await must.approve(factory.address, 1 * leaveFee + minFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });

      const renting = await Rental.at((await factory.rentingsReceivedOf(bob))[0].id);

      await renting.stake(firstShip, gameId, { from: bob })
      await must.transfer(renting.address,  1 * leaveFee, { from: admin });
      await stakedSpaceShips.leaveGame(firstShip, { from: bob })
      await stakedSpaceShips.enterGame(gameId, firstShip, { from: bob });
    })

    it("prematureStop", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 1000000, 50, minFee + 1 * leaveFee, ZERO_ADDRESS, { from: alice });

      await must.transfer(bob,  1 * leaveFee, { from: admin });
      await must.approve(factory.address, 1 * leaveFee + minFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });

      const renting = await Rental.at((await factory.rentingsReceivedOf(bob))[0].id);
      renting.prematureStop({ from: bob })
      renting.prematureStop({ from: alice })

      await renting.close({ from: alice });
    })

    it("privateFor", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 1000000, 50, minFee + 1 * leaveFee, admin, { from: alice });

      await assertRevertWith(
        factory.acceptOffer(0, { from: bob }),
        "invalid sender"
      )

      await must.approve(factory.address, 1 * leaveFee + minFee, { from: admin });
      await factory.acceptOffer(0, { from: admin })
    })
  })
})
