// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IGamesGateway {
    event EnterGame(
        uint256 indexed gameId,
        uint256 indexed tokenId
    );

    event LeaveGame(
        uint256 indexed gameId,
        uint256 indexed tokenId
    );

    function updateGames(uint256 gameId, address gameAddress) external;
    function enterGame(uint256 gameId, uint256 tokenId) external;
    function leaveGame(uint256 tokenId) external;

    function games() view external returns (address[] memory);
    function gamesIds() view external returns (uint256[] memory);
    function inGame(uint256 tokenId) view external returns (uint256);
}

interface ITokenReceiver {
    function stake(address token, uint256 tokenId, uint256 gameId) external;
    function unstake(uint256 tokenId, bytes calldata data) external;
    function exit(uint256 tokenId, bytes calldata data) external;

    function updateSource(address newSource) external;

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

interface IStakedSpaceShips is IGamesGateway, ITokenReceiver {
    function tokensOfOwner(address owner) external view returns (uint256[] memory);
}
