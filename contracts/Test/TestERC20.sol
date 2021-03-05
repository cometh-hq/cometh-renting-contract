// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

contract TestERC20 is ERC20PresetMinterPauser {
    constructor() public ERC20PresetMinterPauser("TestERC20", "ERC20") {}
}
