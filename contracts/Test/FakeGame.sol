// SPDX-License-Identifier: MIT
import "./interface/IGame.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract FakeGame is IGame {
    mapping(uint256 => bool) private inGame;
    IERC20 _must;
    IERC721 _staked;
    uint256 _leaveFee = 1000000000000000;

    constructor(address must, address staked) public {
        _must = IERC20(must);
        _staked = IERC721(staked);
    }

    function enter(uint256 tokenId) override external {
        require(!inGame[tokenId]);
        inGame[tokenId] = true;
    }

    function leave(uint256 tokenId) override external {
        require(inGame[tokenId]);
        inGame[tokenId] = false;
        _must.transferFrom(
            _staked.ownerOf(tokenId),
            address(this),
            _leaveFee
        );
    }
}
