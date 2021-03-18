const LendingContractFactory = artifacts.require("LendingContractFactory")
const LendingContract = artifacts.require("LendingContract")
const StakedSpaceShips = artifacts.require("StakedSpaceShips");
const TestERC721 = artifacts.require("TestERC721")
const TestERC20 = artifacts.require("TestERC20")
const FakeGame = artifacts.require("FakeGame")

contract('LendingContract', function(accounts) {
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

  const leaveFee = 1000000000000000;

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

    factory = await LendingContractFactory.new(must.address, spaceships.address, stakedSpaceShips.address, game.address);
  });

  describe('LendingContract', async () => {
    it("make and acceptOffer", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip, secondShip, thirdShip], 0, 50, 0, { from: alice });

      await must.transfer(bob,  3 * leaveFee, { from: admin });
      await must.approve(factory.address, 3 * leaveFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });

      const bobLendings = await factory.lendingsReceivedOf(bob);
      assert.equal(bobLendings.length, 1);

      const lending = await LendingContract.at(bobLendings[0].id);
      await lending.stake(firstShip, gameId, { from: bob })
      await lending.stake(secondShip, gameId, { from: bob })
      await lending.stake(thirdShip, gameId, { from: bob })

      assert.equal(await must.balanceOf(factory.address), 3 * leaveFee);
    })

    it("make and acceptOffer with fixed fee", async function() {
      await must.transfer(bob, 3 * leaveFee + 1, { from: admin });
      await must.approve(factory.address, 3 * leaveFee + 1, { from: bob });

      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip, secondShip, thirdShip], 0, 50, 1, { from: alice });

      await factory.acceptOffer(0, { from: bob });

      const bobLendings = await factory.lendingsReceivedOf(bob);
      assert.equal(bobLendings.length, 1);
      assert.equal(await must.balanceOf(bob), 0);
      assert.equal(await must.balanceOf(alice), 1);
    })

    it("claim", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 0, 50, 0, { from: alice });

      await must.transfer(bob,  1 * leaveFee, { from: admin });
      await must.approve(factory.address, 1 * leaveFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });
      const lending = await LendingContract.at((await factory.lendingsReceivedOf(bob))[0].id);

      // erc20
      const erc20Reward = await TestERC20.new({ from: admin });
      await erc20Reward.mint(lending.address, 100, { from: admin });
      await lending.claim(erc20Reward.address, { from: alice });
      assert.equal(await erc20Reward.balanceOf(alice), 50);
      assert.equal(await erc20Reward.balanceOf(bob), 50);

      // native
      await web3.eth.sendTransaction({from: admin, to: lending.address, value: 100});
      const bobBalance = await web3.eth.getBalance(bob);
      await lending.claim('0x0000000000000000000000000000000000000000', { from: alice });
      const bobNewBalance = await web3.eth.getBalance(bob);
      assert.equal(bobNewBalance, (BigInt(bobBalance) + BigInt(50)).toString());

      // must
      await must.transfer(lending.address, 100, { from: admin });
      await lending.claim(must.address, { from: alice });
      assert.equal(await must.balanceOf(bob), 100);
    })

    it("claimBatch", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 0, 50, 0, { from: alice });

      await must.transfer(bob,  1 * leaveFee, { from: admin });
      await must.approve(factory.address, 1 * leaveFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });
      const lending = await LendingContract.at((await factory.lendingsReceivedOf(bob))[0].id);

      // erc20
      const erc20Reward = await TestERC20.new({ from: admin });
      await erc20Reward.mint(lending.address, 100, { from: admin });

      // native
      await web3.eth.sendTransaction({from: admin, to: lending.address, value: 100});
      const bobBalance = await web3.eth.getBalance(bob);

      // must
      await must.transfer(lending.address, 100, { from: admin });

      await lending.claimBatch(['0x0000000000000000000000000000000000000000', erc20Reward.address, must.address], { from: alice });
      const bobNewBalance = await web3.eth.getBalance(bob);

      assert.equal(await must.balanceOf(bob), 100);
      assert.equal(await erc20Reward.balanceOf(alice), 50);
      assert.equal(await erc20Reward.balanceOf(bob), 50);
      assert.equal(bobNewBalance, (BigInt(bobBalance) + BigInt(50)).toString());
    })

    it("close", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip, secondShip, thirdShip], 0, 50, 0, { from: alice });

      await must.transfer(bob,  3 * leaveFee, { from: admin });
      await must.approve(factory.address, 3 * leaveFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });

      const lending = await LendingContract.at((await factory.lendingsReceivedOf(bob))[0].id);

      await lending.stake(secondShip, gameId, { from: bob })
      await must.transfer(lending.address,  1 * leaveFee, { from: admin });
      await stakedSpaceShips.exit(secondShip, '0x', { from: bob })

      await lending.close({ from: alice });

      assert.equal(await spaceships.ownerOf(firstShip), alice);
      assert.equal(await spaceships.ownerOf(secondShip), alice);
      assert.equal(await spaceships.ownerOf(thirdShip), alice);
    })

    it("claimBatchAndClose", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 0, 50, 0, { from: alice });

      await must.transfer(bob,  1 * leaveFee, { from: admin });
      await must.approve(factory.address, 1 * leaveFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });
      const lending = await LendingContract.at((await factory.lendingsReceivedOf(bob))[0].id);

      // erc20
      const erc20Reward = await TestERC20.new({ from: admin });
      await erc20Reward.mint(lending.address, 100, { from: admin });

      // native
      await web3.eth.sendTransaction({from: admin, to: lending.address, value: 100});
      const bobBalance = await web3.eth.getBalance(bob);

      // must
      await must.transfer(lending.address, 100, { from: admin });

      await lending.claimBatchAndClose(['0x0000000000000000000000000000000000000000', erc20Reward.address, must.address], { from: alice });
      assert.equal(await spaceships.ownerOf(firstShip), alice);
    })

    it("can exit and re stake", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 0, 50, 0, { from: alice });

      await must.transfer(bob,  1 * leaveFee, { from: admin });
      await must.approve(factory.address, 1 * leaveFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });

      const lending = await LendingContract.at((await factory.lendingsReceivedOf(bob))[0].id);

      await lending.stake(firstShip, gameId, { from: bob })
      await must.transfer(lending.address,  1 * leaveFee, { from: admin });
      await stakedSpaceShips.exit(firstShip, '0x', { from: bob })
      assert.equal(await spaceships.ownerOf(firstShip), lending.address);

      await lending.stake(firstShip, gameId, { from: bob });
      assert.equal(await stakedSpaceShips.ownerOf(firstShip), lending.address);
    })

    it("can leave game and re enter", async function() {
      await spaceships.setApprovalForAll(factory.address, true, { from: alice });
      await factory.makeOffer([firstShip], 0, 50, 0, { from: alice });

      await must.transfer(bob,  1 * leaveFee, { from: admin });
      await must.approve(factory.address, 1 * leaveFee, { from: bob });

      await factory.acceptOffer(0, { from: bob });

      const lending = await LendingContract.at((await factory.lendingsReceivedOf(bob))[0].id);

      await lending.stake(firstShip, gameId, { from: bob })
      await must.transfer(lending.address,  1 * leaveFee, { from: admin });
      await stakedSpaceShips.leaveGame(firstShip, { from: bob })
      await stakedSpaceShips.enterGame(gameId, firstShip, { from: bob });
    })
  })
})
