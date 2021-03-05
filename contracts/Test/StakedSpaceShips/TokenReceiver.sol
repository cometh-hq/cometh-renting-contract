// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../interface/IGame.sol";
import "./GamesGateway.sol";

interface ITokenReceiver {
    function stake(address token, uint256 tokenId, uint256 gameId) external;
    function unstake(uint256 tokenId, bytes calldata data) external;
    function exit(uint256 tokenId, bytes calldata data) external;

    function updateSource(address newSource) external;

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

abstract contract TokenReceiver is ERC721, Ownable, GamesGateway, ITokenReceiver {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;

    mapping(address => mapping(uint256 => uint256)) private erc1155Accepetd;
    mapping(uint256 => address) private modelIdToERC1155Contract;
    mapping(uint256 => uint256) private modelIdToERC1155TokenId;
    mapping(uint256 => Counters.Counter) private _tokenIdTrackers;
    mapping(uint256 => EnumerableSet.UintSet) private _freeSerials;

    EnumerableSet.AddressSet private _allowedSources;
    mapping(uint256 => address) private _sourceOf;

    uint32 public constant ID_TO_MODEL = 1000000;

    constructor() public {}

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) override external returns (bytes4) {
        require(_allowedSources.contains(msg.sender), "StakedSpaceShips: unknown source");

        _mint(from, tokenId);
        _sourceOf[tokenId] = msg.sender;

        if(data.length != 0) {
            require(data.length == 32, "StakedSpaceShips: must contains game id");
            uint256 gameId;
            uint256 _index = msg.data.length - 32;
            assembly {gameId := calldataload(_index)}

            if(gameId != 0) {
                _enterGame(gameId, tokenId);
            }
        }

        return this.onERC721Received.selector;
    }

    function stake(address token, uint256 tokenId, uint256 gameId) override external {
        bytes memory data = "";
        if(gameId != 0) {
            data = abi.encodePacked(gameId);
        }
        IERC721(token).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            abi.encode(gameId)
        );
    }

    function unstake(uint256 tokenId, bytes calldata data) override external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "StakedSpaceShips: require owner or approved");
        require(inGame[tokenId] == 0, "StakedSpaceShips: token is in a game");
        _unstake(tokenId, data);
    }

    function exit(uint256 tokenId, bytes calldata data) override external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "StakedSpaceShips: require owner or approved");
        if(inGame[tokenId] != 0) {
            _leaveGame(tokenId);
        }
        _unstake(tokenId, data);
    }

    function updateSource(address source) onlyOwner override public {
        if(_allowedSources.contains(source)) {
            _allowedSources.remove(source);
        } else {
            _allowedSources.add(source);
        }
    }

    function _unstake(uint256 tokenId, bytes calldata data) internal {
        address tokenOwner = ownerOf(tokenId);
        _burn(tokenId);

        address source = _sourceOf[tokenId];
        IERC721(source).safeTransferFrom(
            address(this),
            tokenOwner,
            tokenId,
            data
        );
    }

    function _idToModel(uint256 id) internal pure returns (uint256) {
        return id / ID_TO_MODEL;
    }

    function _idToSerial(uint256 id) internal pure returns (uint256) {
        return id % ID_TO_MODEL;
    }
}
