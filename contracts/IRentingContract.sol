// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IRentingContract is IERC721Receiver {
    function stake(uint256 tokenId, uint256 gameId) external;
    function retrieveGains(address token) external;
    function endContract() external;

    function nftIds(uint256 index) external view returns(uint256);
    function lender() external view returns(address);
    function tenant() external view returns(address);
    function end() external view returns(uint256);
    function percentageForLender() external view returns(uint256);
}
