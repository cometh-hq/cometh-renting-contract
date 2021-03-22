// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./Interface/IStakedSpaceShips.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Factory/IRentingContractFactory.sol";
import "./IRentingContract.sol";

contract RentingContract is IRentingContract, ReentrancyGuard {
    address public override lender;
    address public override tenant;
    uint256 public override start;
    uint256 public override end;
    uint256 public override percentageForLender;

    address public factory;
    address public spaceships;
    address public stakedSpaceShips;
    IERC20 public must;

    uint256[] private _nftIds;

    bool public lenderStop;
    bool public tenantStop;

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
        must = IERC20(mustAddress);
        spaceships = spaceshipsAddress;
        stakedSpaceShips = stakedSpaceShipsAddress;
        factory = msg.sender;
        _nftIds = newNFTIds;
        lender = newLender;
        tenant = newTenant;
        start = block.timestamp;
        end = newEnd;
        percentageForLender = newPercentageForLender;
        IERC721Enumerable(stakedSpaceShips).setApprovalForAll(tenant, true);
        must.approve(mustManagerAddress, 10000000 ether);
    }

    function onERC721Received(address, address from, uint256, bytes calldata) override external returns(bytes4) {
        require(msg.sender == spaceships || msg.sender == stakedSpaceShips, "invalid token");
        if(msg.sender == spaceships) {
            require (from == factory || from == stakedSpaceShips, "invalid from");
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
        require(block.timestamp >= end, "unfinished");
        IRentingContractFactory(factory).closeRenting();

        uint256 amountStaked = IERC721Enumerable(stakedSpaceShips).balanceOf(address(this));
        for(uint256 i = 0; i < amountStaked; i++) {
            uint256 tokenId = IERC721Enumerable(stakedSpaceShips).tokenOfOwnerByIndex(address(this), 0);
            IStakedSpaceShips(stakedSpaceShips).exit(tokenId, '');
        }

        for(uint256 i = 0; i < _nftIds.length; i++) {
            IERC721Enumerable(spaceships).safeTransferFrom(address(this), lender, _nftIds[i]);
        }
    }

    function prematureStop() override external {
        if(msg.sender == tenant) tenantStop = !tenantStop;
        if(msg.sender == lender) lenderStop = !lenderStop;
        if(tenantStop && lenderStop) end = block.timestamp;
    }

    function nftIds() override external view returns (uint256[] memory) {
        return _nftIds;
    }

    function _retrieveNativeGains() private returns(uint256 amount) {
        amount = address(this).balance;
        if(amount == 0) return amount;
        payable(lender).transfer(address(this).balance * percentageForLender / 100);
        payable(tenant).transfer(address(this).balance);
    }

    function _retrieveERC20Gains(IERC20 token) private returns(uint256 amount) {
        amount = token.balanceOf(address(this));
        if(amount == 0) return amount;
        if(address(token) != address(must)) {
            uint256 amountForLender = amount * percentageForLender / 100;
            token.transfer(lender, amountForLender);
            amount = amount - amountForLender;
        }
        token.transfer(tenant, amount);
    }

    function _claim(address token) private {
        uint256 amount;
        if(token == address(0)) {
            amount = _retrieveNativeGains();
        } else {
            amount = _retrieveERC20Gains(IERC20(token));
        }
    }

    function _claimBatch(address[] memory tokens) private {
        for(uint256 i = 0; i < tokens.length; i++) {
            _claim(tokens[i]);
        }
    }

    receive() external payable {}
}
