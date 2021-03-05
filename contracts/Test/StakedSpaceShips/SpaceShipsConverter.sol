// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./TokenIdConverter/ITokenIdConverter.sol";

interface ISpaceShipsConverter {
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata data) external returns(bytes4);
    function onERC1155Received(address, address from, uint256 id, uint256 value, bytes calldata data) external returns(bytes4);

    function convertERC721(address token, uint256 tokenId) external;
    function convertERC1155(address token, uint256 tokenId) external;

    function acceptNewERC721(address newERC1155, ITokenIdConverter converter) external;
    function acceptNewERC1155(address newERC1155, ITokenIdConverter tokenIdConverter) external;

    function burn(uint256 tokenId) external;

    function modelIdFor(address token, uint256 tokenId) external view returns(uint256);
}

contract SpaceShipsConverter is ISpaceShipsConverter, ERC721, Ownable {
    mapping(address => ITokenIdConverter) private erc1155converters;
    mapping(address => ITokenIdConverter) private erc721converters;

    mapping(uint256 => address) private _convertedFrom;

    address private _stakedSpaceShips;

    constructor(address stakedSpaceShips) public ERC721("converted spaceships", "CSHIP") {
        _stakedSpaceShips = stakedSpaceShips;
    }

    function acceptNewERC721(address newERC1155, ITokenIdConverter tokenIdConverter) onlyOwner override external {
        require(address(erc721converters[newERC1155]) == address(0), "SpaceShipsConverter: already supported contract");
        erc721converters[newERC1155] = tokenIdConverter;
    }

    function acceptNewERC1155(address newERC1155, ITokenIdConverter tokenIdConverter) onlyOwner override external {
        require(address(erc1155converters[newERC1155]) == address(0), "SpaceShipsConverter: already supported contract");
        erc1155converters[newERC1155] = tokenIdConverter;
    }

    function convertERC721(address token, uint256 tokenId) override external {
        IERC721(token).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            ''
        );
    }

    function convertERC1155(address token, uint256 tokenId) override external {
        IERC1155(token).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            1,
            ''
        );
    }

    function onERC1155Received(address, address from, uint256 id, uint256 value, bytes calldata data) override external returns(bytes4) {
        ITokenIdConverter converter = erc1155converters[msg.sender];
        require(address(converter) != address(0), "SpaceShipsConverter: unsupported contract or token id");

        require(value == 1, "SpaceShipsConverter: value greater than 1 not supported");

        uint256 newTokenId = converter.convertTokenId(msg.sender, id);
        _convertedFrom[newTokenId] = msg.sender;
        _mint(from, newTokenId);

        if(data.length != 0) {
            _safeTransfer(
                from,
                _stakedSpaceShips,
                newTokenId,
                data
            );
        }

        return this.onERC1155Received.selector;
    }

    function onERC721Received(address, address from, uint256 id, bytes calldata data) override external returns(bytes4) {
        ITokenIdConverter converter = erc721converters[msg.sender];
        require(address(converter) != address(0), "SpaceShipsConverter: unsupported contract or token id");

        uint256 newTokenId = converter.convertTokenId(msg.sender, id);
        _convertedFrom[newTokenId] = msg.sender;
        _mint(from, newTokenId);

        if(data.length != 0) {
            _safeTransfer(
                from,
                _stakedSpaceShips,
                newTokenId,
                data
            );
        }

        return this.onERC721Received.selector;
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal override {
        super._safeTransfer(from, to, tokenId, data);
        if (from == _stakedSpaceShips && data.length != 0) {
            require(data.length == 32, "SpaceShipsConverter: must contains boolean");
            bool burn;
            uint256 _index = msg.data.length - 32;
            assembly {burn := calldataload(_index)}

            if(burn) {
                _burn(tokenId);
            }
        }
    }

    function burn(uint256 newTokenId) override external {
        require(_isApprovedOrOwner(_msgSender(), newTokenId), "SpaceShipsConverter: caller is not owner nor approved");
        _burn(newTokenId);
    }

    function modelIdFor(address token, uint256 tokenId) override external view returns(uint256) {
        ITokenIdConverter converter = erc1155converters[token];
        if(address(converter) == address(0)) {
            converter = erc721converters[token];
        }
        require(address(converter) != address(0), "SpaceShipsConverter: unsupported contract or token id");

        return converter.modelIdFor(token, tokenId);
    }

    function _burn(uint256 newTokenId) override internal {
        address tokenOwner = ownerOf(newTokenId);
        address token = _convertedFrom[newTokenId];

        super._burn(newTokenId);

        ITokenIdConverter converter = erc1155converters[token];
        if(address(converter) != address(0)) {
            uint256 tokenId = converter.rollback(token, newTokenId);
            IERC1155(token).safeTransferFrom(
                address(this),
                tokenOwner,
                tokenId,
                1,
                ''
            );
        } else {
            converter = erc721converters[token];
            uint256 tokenId = converter.rollback(token, newTokenId);
            IERC721(token).safeTransferFrom(
                address(this),
                tokenOwner,
                tokenId,
                ''
            );
        }
    }
}
