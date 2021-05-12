// SPDX-License-Identifier: MIT

pragma solidity ^0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";


contract Modulable is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _modules;

    modifier onlyModule() {
        require(
            _modules.contains(msg.sender),
            "Manager: caller is not a module"
        );
        _;
    }

    constructor() public {}

    function updateModule(address newModule) onlyOwner external {
        _updateModule(newModule);
    }

    function updateModules(address[] memory newModules) onlyOwner external {
        for(uint256 i = 0; i < newModules.length; i++) {
            _updateModule(newModules[i]);
        }
    }

    function isModule(address module) public view returns (bool) {
        return _modules.contains(module);
    }

    function modules() external view returns (address[] memory) {
        address[] memory result = new address[](_modules.length());
        for (uint256 i = 0; i < _modules.length(); i++) {
            result[i] = _modules.at(i);
        }
        return result;
    }

    function _updateModule(address newModule) private {
        if(_modules.contains(newModule)) {
            _modules.remove(newModule);
        } else {
            _modules.add(newModule);
        }
    }
}
