// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IRental.sol";
import "./ProxyFactory.sol";
import "./OfferStore.sol";
import "./RentalStore.sol";
import "./Modulable.sol";

contract Escrow is Modulable {
    address public must;
    address public spaceships;

    constructor(
        address mustAddress,
        address spaceshipsAddress
    ) public {
        spaceships = spaceshipsAddress;
        must = mustAddress;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external view returns(bytes4) {
        require(msg.sender == spaceships, "invalid nft");
        return this.onERC721Received.selector;
    }

    function transferMust(address to, uint256 amount) external onlyModule {
        IERC20(must).transfer(
            to,
            amount
        );
    }

    function transferSpaceShips(
        address to,
        uint256[] memory tokenIds
    ) external onlyModule {
        for(uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(spaceships).safeTransferFrom(
                address(this),
                to,
                tokenIds[i]
            );
        }
    }
}
