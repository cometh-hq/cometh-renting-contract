// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./Interface/IStakedSpaceShips.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Factory/IRentingContractFactory.sol";
import "./IRentingContract.sol";

contract RentingContract is IRentingContract, ReentrancyGuard {
    uint256[] public override nftIds;
    address public override lender;
    address public override tenant;
    uint256 public override end;
    uint256 public override percentageForLender;

    address public factory;
    address public spaceships;
    address public stakedSpaceShips;
    address public must;

    modifier lenderOrTenant() {
        require(msg.sender == lender || msg.sender == tenant, "invalid caller");
        _;
    }

    constructor(
        address mustAddress,
        address spaceshipsAddress,
        address stakedSpaceShipsAddress,
        address mustManagerAddress,
        address newLender,
        address newTenant,
        uint256 newEnd,
        uint256 newPercentageForLender
    ) public {
        must = mustAddress;
        spaceships = spaceshipsAddress;
        stakedSpaceShips = stakedSpaceShipsAddress;
        factory = msg.sender;
        lender = newLender;
        tenant = newTenant;
        end = newEnd;
        percentageForLender = newPercentageForLender;
        IERC721Enumerable(stakedSpaceShips).setApprovalForAll(tenant, true);
        IERC20(must).approve(mustManagerAddress, 10000000 ether);
    }

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata) override external returns(bytes4) {
        require(msg.sender == spaceships || msg.sender == stakedSpaceShips, "invalid nft");
        if((msg.sender == spaceships) && (from == factory)) {
            nftIds.push(tokenId);
        }
        return this.onERC721Received.selector;
    }

    function stake(uint256 tokenId, uint256 gameId) override public {
        IERC721Enumerable(spaceships).safeTransferFrom(
            address(this),
            stakedSpaceShips,
            tokenId,
            abi.encode(gameId)
        );
    }

    function retrieveGains(address token) override external nonReentrant lenderOrTenant {
        if(token == address(0)) {
            _retrieveNativeGains();
            return;
        }
        if(token == must) {
            _retrieveMust();
            return;
        }
        _retrieveERC20Gains(token);
    }

    function endContract() override external lenderOrTenant {
        require(block.timestamp >= end, "contract unfinished");
        uint256 amountStaked = IERC721Enumerable(stakedSpaceShips).balanceOf(address(this));
        for(uint256 i = 0; i < amountStaked; i++) {
            uint256 tokenId = IERC721Enumerable(stakedSpaceShips).tokenOfOwnerByIndex(address(this), 0);
            IStakedSpaceShips(stakedSpaceShips).exit(tokenId, '');
        }

        for(uint256 i = 0; i < nftIds.length; i++) {
            IERC721Enumerable(spaceships).safeTransferFrom(address(this), lender, nftIds[i]);
        }

        IRentingContractFactory(factory).closeRentingContract();
    }

    function _retrieveMust() private {
        IERC20(must).transfer(tenant, IERC20(must).balanceOf(address(this)));
    }

    function _retrieveNativeGains() private {
        payable(lender).transfer(address(this).balance * percentageForLender / 100);
        payable(tenant).transfer(address(this).balance);
    }

    function _retrieveERC20Gains(address token) private {
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 amountForLender = balance * percentageForLender / 100;
        IERC20(token).transfer(lender, amountForLender);
        IERC20(token).transfer(tenant, balance - amountForLender);
    }

    receive() external payable {}
}
