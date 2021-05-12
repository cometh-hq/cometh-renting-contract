// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.7.0;

import "./Proxy.sol";

contract ProxyFactory {

    event ProxyCreation(Proxy proxy);

    /// @dev Forwards a meta transaction to a destination contract
    /// @param implementation Address of the contract to proxy
    /// @param data Payload for message call sent to new proxy contract.
    function createProxy(address implementation, bytes memory data)
        external
        payable
        returns (Proxy proxy)
    {
        proxy = new Proxy{value:msg.value}(implementation);
        if (data.length > 0) {
            (bool success,) = address(proxy).call(data);
            require(success, "Failing call after deployment");
        }

        emit ProxyCreation(proxy);
    }

    /// @dev Forwards a meta transaction to a destination contract
    /// @param implementation Address of the contract to proxy
    /// @param data Payload for message call sent to new proxy contract.
    /// @param saltNonce Nonce that will be used to generate the salt to calculate the address of the new proxy contract.
    function createProxyWithNonce(address implementation, bytes memory data, bytes32 saltNonce)
        external
        payable
        returns (Proxy proxy)
    {
        bytes32 salt = keccak256(abi.encode(keccak256(data), saltNonce));
        bytes memory deploymentData = abi.encodePacked(type(Proxy).creationCode, abi.encode(implementation));
        uint256 amount = msg.value;

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            proxy := create2(amount, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        require(address(proxy) != address(0), "Create2 call failed");

        if (data.length > 0) {
            (bool success,) = address(proxy).call(data);
            require(success, "Failing call after deployment");
        }

        emit ProxyCreation(proxy);
    }
}
