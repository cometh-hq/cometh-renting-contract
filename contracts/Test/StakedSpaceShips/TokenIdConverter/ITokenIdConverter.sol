// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface ITokenIdConverter {
    function convertTokenId(address token, uint256 tokenId) external returns(uint256 newTokenId);
    function rollback(address token, uint256 newTokenId) external returns(uint256 tokenId);

    function modelIdFor(address token, uint256 tokenId) external view returns(uint256);
}
