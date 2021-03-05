// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableMap.sol";
import "../interface/IGame.sol";

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

abstract contract GamesGateway is Ownable, IGamesGateway {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    EnumerableMap.UintToAddressMap private _games;

    mapping(uint256 => uint256) override public inGame;

    constructor() public {}

    function enterGame(uint256 gameId, uint256 tokenId) virtual override public {
        _enterGame(gameId, tokenId);
    }

    function leaveGame(uint256 tokenId) virtual override public {
        _leaveGame(tokenId);
    }

    function updateGames(uint256 gameId, address gameAddress) onlyOwner override external {
        require(gameId != 0, "cannot use game 0");
        _games.set(gameId, gameAddress);
    }

    function games() override view external returns (address[] memory) {
        address[] memory result = new address[](_games.length());
        for(uint256 i = 0; i < _games.length(); i++) {
            (, result[i]) = _games.at(i);
        }
        return result;
    }

    function gamesIds() override view external returns (uint256[] memory) {
        uint256[] memory result = new uint256[](_games.length());
        for(uint256 i = 0; i < _games.length(); i++) {
            (result[i],) = _games.at(i);
        }
        return result;
    }

    function _enterGame(uint256 gameId, uint256 tokenId) internal {
        require(_games.contains(gameId), "StakedSpaceShips: unknow game");
        require(inGame[tokenId] == 0, "StakedSpaceShips: token already in a game");
        IGame(_games.get(gameId)).enter(tokenId);
        inGame[tokenId] = gameId;
        EnterGame(gameId, tokenId);
    }

    function _leaveGame(uint256 tokenId) internal {
        uint256 gameId = inGame[tokenId];
        require(gameId != 0, "StakedSpaceShips: token is not in a game");
        IGame(_games.get(gameId)).leave(tokenId);
        inGame[tokenId] = 0;
        LeaveGame(gameId, tokenId);
    }
}
