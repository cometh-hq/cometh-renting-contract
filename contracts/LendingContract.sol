// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./Interface/IStakedSpaceShips.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Factory/ILendingContractFactory.sol";
import "./ILendingContract.sol";

contract LendingContract is ILendingContract, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;

    address public override lender;
    address public override tenant;
    uint256 public override start;
    uint256 public override end;
    uint256 public override percentageForLender;

    address public factory;
    address public spaceships;
    address public stakedSpaceShips;
    address public must;

    mapping(address => uint256) private _claimed;

    EnumerableSet.UintSet private _nftIds;

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
        uint256[] memory newNFTIds,
        uint256 newEnd,
        uint256 newPercentageForLender
    ) public {
        must = mustAddress;
        spaceships = spaceshipsAddress;
        stakedSpaceShips = stakedSpaceShipsAddress;
        factory = msg.sender;
        for(uint256 i = 0; i < newNFTIds.length; i++) {
            _nftIds.add(newNFTIds[i]);
        }
        lender = newLender;
        tenant = newTenant;
        start = block.timestamp;
        end = newEnd;
        percentageForLender = newPercentageForLender;
        IERC721Enumerable(stakedSpaceShips).setApprovalForAll(tenant, true);
        IERC20(must).approve(mustManagerAddress, 10000000 ether);
    }

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata) override external returns(bytes4) {
        require(msg.sender == spaceships || msg.sender == stakedSpaceShips, "invalid token");
        if((msg.sender == spaceships) && (from == factory)) {
            require(_nftIds.contains(tokenId), "invalid token id");
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

    function claim(address token) override external nonReentrant lenderOrTenant {
        _claim(token);
    }

    function claimBatch(address[] memory tokens) override public nonReentrant lenderOrTenant {
        for(uint256 i = 0; i < tokens.length; i++) {
            _claim(tokens[i]);
        }
    }

    function claimBatchAndClose(address[] memory tokens) override external nonReentrant lenderOrTenant {
        _claimBatch(tokens);
        close();
    }

    function close() override public lenderOrTenant {
        require(block.timestamp >= end, "contract unfinished");
        ILendingContractFactory(factory).closeLending();

        uint256 amountStaked = IERC721Enumerable(stakedSpaceShips).balanceOf(address(this));
        for(uint256 i = 0; i < amountStaked; i++) {
            uint256 tokenId = IERC721Enumerable(stakedSpaceShips).tokenOfOwnerByIndex(address(this), 0);
            IStakedSpaceShips(stakedSpaceShips).exit(tokenId, '');
        }

        for(uint256 i = 0; i < _nftIds.length(); i++) {
            IERC721Enumerable(spaceships).safeTransferFrom(address(this), lender, _nftIds.at(i));
        }
    }

    function nftIds() override external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](_nftIds.length());
        for (uint256 i = 0; i < _nftIds.length(); i++) {
            result[i] = _nftIds.at(i);
        }
        return result;
    }

    function alreadyClaimed(address[] memory tokens) override external view returns(uint256[] memory) {
        uint256[] memory result = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            result[i] = _claimed[tokens[i]];
        }
        return result;
    }

    function _retrieveMust() private returns(uint256 amount) {
        amount = IERC20(must).balanceOf(address(this));
        if(amount == 0) return amount;
        IERC20(must).transfer(tenant, amount);
    }

    function _retrieveNativeGains() private returns(uint256 amount) {
        amount = address(this).balance;
        if(amount == 0) return amount;
        payable(lender).transfer(address(this).balance * percentageForLender / 100);
        payable(tenant).transfer(address(this).balance);
    }

    function _retrieveERC20Gains(address token) private returns(uint256 amount) {
        amount = IERC20(token).balanceOf(address(this));
        if(amount == 0) return amount;
        uint256 amountForLender = amount * percentageForLender / 100;
        IERC20(token).transfer(lender, amountForLender);
        IERC20(token).transfer(tenant, amount - amountForLender);
    }

    function _claim(address token) private {
        uint256 amount;
        if(token == address(0)) {
            amount = _retrieveNativeGains();
        } else if(token == must) {
            amount = _retrieveMust();
        } else {
            amount = _retrieveERC20Gains(token);
        }
        _claimed[token] += amount;
    }

    function _claimBatch(address[] memory tokens) private {
        for(uint256 i = 0; i < tokens.length; i++) {
            _claim(tokens[i]);
        }
    }

    receive() external payable {}
}
