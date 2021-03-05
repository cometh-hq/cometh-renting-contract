// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface IGame {
    function enter(uint256 tokenId) external;
    function leave(uint256 tokenId) external;
}
