// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/presets/ERC721PresetMinterPauserAutoId.sol";

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract TestERC721 is ERC721PresetMinterPauserAutoId {
    constructor()
        public ERC721PresetMinterPauserAutoId("TestERC721", "ERC721", "test") {}
}
