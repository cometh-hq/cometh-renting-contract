// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ITokenIdConverter.sol";

contract ERC1155Converter is ITokenIdConverter, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;

    address public converter;
    uint32 public constant ID_TO_MODEL = 1000000;

    mapping(address => mapping(uint256 => uint256)) private erc1155Accepetd;
    mapping(uint256 => address) private modelIdToERC1155Contract;
    mapping(uint256 => uint256) private modelIdToERC1155TokenId;
    mapping(uint256 => Counters.Counter) private _tokenIdTrackers;
    mapping(uint256 => EnumerableSet.UintSet) private _freeSerials;

    constructor(address newConverter) public {
        converter = newConverter;
    }

    function acceptNewERC1155(address newERC1155, uint256 id, uint256 modelId) onlyOwner external {
        require(erc1155Accepetd[newERC1155][id] == 0, "StakedSpaceShips: already supported contract");
        require(modelIdToERC1155Contract[modelId] == address(0), "StakedSpaceShips: model id already used");

        erc1155Accepetd[newERC1155][id] = modelId;
        modelIdToERC1155Contract[modelId] = newERC1155;
        modelIdToERC1155TokenId[modelId] = id;
    }

    function convertTokenId(address token, uint256 id) override external returns(uint256) {
        require(msg.sender == converter, "ERC1155Converter: invalid caller");
        require(erc1155Accepetd[token][id] != 0, "ERC1155Converter: unsupported contract or token id");

        uint256 modelId = erc1155Accepetd[token][id];
        uint256 serial;
        if(_freeSerials[modelId].length() == 0) {
            serial = _tokenIdTrackers[modelId].current();
            _tokenIdTrackers[modelId].increment();
        } else {
            serial = _freeSerials[modelId].at(0);
            _freeSerials[modelId].remove(serial);
        }
        require(serial != ID_TO_MODEL, "ERC1155Converter: max token capacity reached");
        uint256 newTokenId = modelId * ID_TO_MODEL + serial;
        return newTokenId;
    }

    function rollback(address token, uint256 tokenId) override external returns(uint256) {
        require(msg.sender == converter, "ERC1155Converter: invalid caller");
        uint256 modelId = _idToModel(tokenId);
        require(token == modelIdToERC1155Contract[modelId], "ERC1155Converter: invalid token");

        _freeSerials[modelId].add(_idToSerial(tokenId));

        return modelIdToERC1155TokenId[modelId];
    }

    function modelIdFor(address token, uint256 tokenId) override external view returns(uint256) {
        return erc1155Accepetd[token][tokenId];
    }

    function _idToModel(uint256 id) internal pure returns (uint256) {
        return id / ID_TO_MODEL;
    }

    function _idToSerial(uint256 id) internal pure returns (uint256) {
        return id % ID_TO_MODEL;
    }
}
