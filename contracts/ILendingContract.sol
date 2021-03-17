// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface ILendingContract is IERC721Receiver {
    function stake(uint256 tokenId, uint256 gameId) external;
    function claim(address token) external;
    function claimBatch(address[] memory tokens) external;
    function claimBatchAndClose(address[] memory tokens) external;
    function close() external;

    function nftIds() external view returns(uint256[] memory);
    function lender() external view returns(address);
    function tenant() external view returns(address);
    function start() external view returns(uint256);
    function end() external view returns(uint256);
    function percentageForLender() external view returns(uint256);
    function alreadyClaimed(address[] memory tokens) external view returns(uint256[] memory);
}
