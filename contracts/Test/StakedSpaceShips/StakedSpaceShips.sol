// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GamesGateway.sol";
import "./TokenReceiver.sol";

interface IStakedSpaceShips is IGamesGateway, ITokenReceiver {
    function tokensOfOwner(address owner) external view returns (uint256[] memory);
}

contract StakedSpaceShips is GamesGateway, TokenReceiver, IStakedSpaceShips {

    constructor(string memory uri, address spaceshipsContract) public ERC721("staked spaceships", "XSHIP") {
        _setBaseURI(uri);
        updateSource(spaceshipsContract);
    }

    function tokensOfOwner(address owner) override external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](balanceOf(owner));
        for(uint256 i = 0; i < balanceOf(owner); i++) {
            result[i] = tokenOfOwnerByIndex(owner, i);
        }
        return result;
    }

    function enterGame(uint256 gameId, uint256 tokenId) override(GamesGateway, IGamesGateway) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "StakedSpaceShips: require owner or approved");
        super.enterGame(gameId, tokenId);
    }

    function leaveGame(uint256 tokenId) override(GamesGateway, IGamesGateway) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "StakedSpaceShips: require owner or approved");
        super.leaveGame(tokenId);
    }

    function _transfer(address, address, uint256) internal override {
        revert("StakedSpaceShips: cannot transfer miners");
    }
}
