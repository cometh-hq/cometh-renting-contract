const RentingContractFactory = artifacts.require("RentingContractFactory")
const RentingContract = artifacts.require("RentingContract")
const StakedSpaceShips = artifacts.require("StakedSpaceShips");
const TestERC721 = artifacts.require("TestERC721")
const TestERC20 = artifacts.require("TestERC20")
const FakeGame = artifacts.require("FakeGame")

contract('RentingContract', function(accounts) {
  const admin = accounts[0];
  const alice = accounts[1];
  const bob = accounts[2];

  let stakedSpaceShips;
  let game;
  let must;

  const gameId = 1;
  const firstShip = 0
  const secondShip = 1
  const thirdShip = 2

  beforeEach(async () => {
    must = await TestERC20.new({ from: admin });
    must.mint(admin, 100000)
    spaceships = await TestERC721.new({ from: admin });

    stakedSpaceShips = await StakedSpaceShips.new("uri", spaceships.address, { from: admin });

    game = await FakeGame.new();

    await stakedSpaceShips.updateGames(gameId, game.address)

    await spaceships.mint(alice, { from: admin });
    await spaceships.mint(alice, { from: admin });
    await spaceships.mint(alice, { from: admin });

    factory = await RentingContractFactory.new(must.address, spaceships.address, stakedSpaceShips.address);
  });

  describe.only('RentingContract', async () => {
    it("make and acceptProposal", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeProposal([firstShip, secondShip, thirdShip], 0, 50, 0, { from: alice });

      await factory.acceptProposal(0, { from: bob });

      const bobRents = await factory.rentOf(bob);
      assert.equal(bobRents.length, 1);

      await stakedSpaceShips.enterGame(gameId, firstShip, { from: bob })
      await stakedSpaceShips.enterGame(gameId, secondShip, { from: bob })
      await stakedSpaceShips.enterGame(gameId, thirdShip, { from: bob })
    })

    it("make and acceptProposal with fixed fee", async function() {
      await must.transfer(bob, 1, { from: admin });
      await must.approve(factory.address, 10, { from: bob });

      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeProposal([firstShip, secondShip, thirdShip], 0, 50, 1, { from: alice });

      await factory.acceptProposal(0, { from: bob });

      const bobRents = await factory.rentOf(bob);
      assert.equal(bobRents.length, 1);
      assert.equal(await must.balanceOf(bob), 0);
      assert.equal(await must.balanceOf(alice), 1);
    })

    it("retrieveGains", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeProposal([firstShip], 0, 50, 0, { from: alice });
      await factory.acceptProposal(0, { from: bob });
      const rentingContract = await RentingContract.at((await factory.rentOf(bob))[0]);

      // erc20
      const erc20Reward = await TestERC20.new({ from: admin });
      await erc20Reward.mint(rentingContract.address, 100, { from: admin });
      await rentingContract.retrieveGains(erc20Reward.address, { from: alice });
      assert.equal(await erc20Reward.balanceOf(alice), 50);
      assert.equal(await erc20Reward.balanceOf(bob), 50);

      // native
      await web3.eth.sendTransaction({from: admin, to: rentingContract.address, value: 100});
      const bobBalance = await web3.eth.getBalance(bob);
      await rentingContract.retrieveGains('0x0000000000000000000000000000000000000000', { from: alice });
      const bobNewBalance = await web3.eth.getBalance(bob);
      assert.equal(bobNewBalance, (BigInt(bobBalance) + BigInt(50)).toString());

      // must
      await must.transfer(rentingContract.address, 100, { from: admin });
      await rentingContract.retrieveGains(must.address, { from: alice });
      assert.equal(await must.balanceOf(bob), 100);
    })

    it("endContract", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeProposal([firstShip, secondShip, thirdShip], 0, 50, 0, { from: alice });
      await factory.acceptProposal(0, { from: bob });

      const rentingContract = await RentingContract.at((await factory.rentOf(bob))[0]);

      await stakedSpaceShips.enterGame(gameId, secondShip, { from: bob })
      await stakedSpaceShips.exit(secondShip, '0x', { from: bob })

      await rentingContract.endContract({ from: alice });

      assert.equal(await spaceships.ownerOf(firstShip), alice);
      assert.equal(await spaceships.ownerOf(secondShip), alice);
      assert.equal(await spaceships.ownerOf(thirdShip), alice);
    })

    it("can exit and re stake", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeProposal([firstShip], 0, 50, 0, { from: alice });
      await factory.acceptProposal(0, { from: bob });

      const rentingContract = await RentingContract.at((await factory.rentOf(bob))[0]);

      await stakedSpaceShips.enterGame(gameId, firstShip, { from: bob })
      await stakedSpaceShips.exit(firstShip, '0x', { from: bob })
      assert.equal(await spaceships.ownerOf(firstShip), rentingContract.address);

      await rentingContract.stake(firstShip, gameId, { from: bob });
      assert.equal(await stakedSpaceShips.ownerOf(firstShip), rentingContract.address);
    })
  })
})
