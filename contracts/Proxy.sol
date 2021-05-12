// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.7.0;

/// @dev Proxy implementation based on https://blog.openzeppelin.com/proxy-patterns/
contract Proxy {
    address public implementation;

    constructor(address _implementation) payable public {
        implementation = _implementation;
    }

    fallback() external payable {
        address _impl = implementation;

        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    receive() external payable {}
}
