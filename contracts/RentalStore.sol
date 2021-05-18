// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./Modulable.sol";

interface IRentalStore {
    function add(
        address rentalId,
        address lender,
        address tenant
    ) external;

    function remove(address rentalId, address lender, address tenant) external;

    function length() external view returns (uint256);

    function idAt(uint256 index) external view returns (address);

    function ids() external view returns (address[] memory);

    function contains(address rentalId) external view returns (bool);

    function rentalsIdsGrantedOf(address account) external view returns (address[] memory);

    function rentalsIdsReceivedOf(address account) external view returns (address[] memory);
}

contract RentalStore is IRentalStore, Modulable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal _ids;
    mapping(address => EnumerableSet.AddressSet) internal _idsGrantedOf;
    mapping(address => EnumerableSet.AddressSet) internal _idsReceivedOf;

    constructor() public {}

    function add(
        address rentalId,
        address lender,
        address tenant
    ) external override onlyModule {
        require(_ids.add(rentalId), "Store: already exist");
        _ids.add(rentalId);
        _idsGrantedOf[lender].add(rentalId);
        _idsReceivedOf[tenant].add(rentalId);
    }

    function remove(address rentalId, address lender, address tenant) external override onlyModule {
        require(_ids.remove(rentalId), "Store: unknow");
        require(_idsGrantedOf[lender].remove(rentalId), "Store: did not granted");
        require(_idsReceivedOf[tenant].remove(rentalId), "Store: did not receive");
    }

    function length() external view override returns (uint256) {
        return _ids.length();
    }

    function idAt(uint256 index) external view override returns (address) {
        return _ids.at(index);
    }

    function ids() external view override returns (address[] memory) {
        address[] memory result = new address[](_ids.length());
        for (uint256 i = 0; i < _ids.length(); i++) {
            result[i] = _ids.at(i);
        }
        return result;
    }

    function contains(address rentalId) external view override returns (bool) {
        return _ids.contains(rentalId);
    }

    function rentalsIdsGrantedOf(address account)
        external
        view
        override
        returns (address[] memory)
    {
        address[] memory result = new address[](_idsGrantedOf[account].length());
        for (uint256 i = 0; i < _idsGrantedOf[account].length(); i++) {
            result[i] = _idsGrantedOf[account].at(i);
        }
        return result;
    }

    function rentalsIdsReceivedOf(address account)
        external
        view
        override
        returns (address[] memory)
    {
        address[] memory result = new address[](_idsReceivedOf[account].length());
        for (uint256 i = 0; i < _idsReceivedOf[account].length(); i++) {
            result[i] = _idsReceivedOf[account].at(i);
        }
        return result;
    }
}
