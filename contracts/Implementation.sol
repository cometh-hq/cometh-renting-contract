// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.7.0;

/// @dev Simple contract that allows to access the implementation address pointed
/// to by a Proxy. It must be herited first
contract Implementation {
	address public implementation;

	event ImplementationChanged(address newImplementation);

	function updateImplementation(address newImplementation) internal {
		require(implementation != newImplementation, "Implementation already used");
		implementation = newImplementation;
		emit ImplementationChanged(newImplementation);
	}
}
