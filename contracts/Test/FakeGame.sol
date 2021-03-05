// SPDX-License-Identifier: MIT
import "./interface/IGame.sol";

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract FakeGame is IGame {
    mapping(uint256 => bool) private inGame;

    function enter(uint256 tokenId) override external {
        require(!inGame[tokenId]);
        inGame[tokenId] = true;
    }

    function leave(uint256 tokenId) override external {
        require(inGame[tokenId]);
        inGame[tokenId] = false;
    }
}
