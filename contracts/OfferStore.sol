// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./Modulable.sol";

interface IOfferStore {
    function add(
        uint256[] memory nftIds,
        address lender,
        uint256 duration,
        uint256 percentageForLender,
        uint256 fee
    ) external returns (uint256);

    function remove(uint256 cometId) external;

    function length() external view returns (uint256);

    function idAt(uint256 index) external view returns (uint256);

    function ids() external view returns (uint256[] memory);

    function contains(uint256 cometId) external view returns (bool);

    function lender(uint256 offerId) external view returns (address);

    function duration(uint256 offerId) external view returns (uint256);

    function nftIds(uint256 offerId) external view returns (uint256[] memory);

    function percentageForLender(uint256 offerId) external view returns (uint256);

    function fee(uint256 offerId) external view returns (uint256);

    function offersIdsOf(address account) external view returns (uint256[] memory);
}

contract OfferStore is IOfferStore, Modulable {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 internal currentId;
    EnumerableSet.UintSet internal _offerIds;

    mapping(uint256 => uint256[]) internal _nftIds;
    mapping(uint256 => address) internal _lenders;
    mapping(uint256 => uint256) internal _durations;
    mapping(uint256 => uint256) internal _percentageForLenders;
    mapping(uint256 => uint256) internal _fees;

    mapping(address => EnumerableSet.UintSet) internal _offersIdsOf;

    constructor() public {}

    function add(
        uint256[] memory nftIds,
        address lender,
        uint256 duration,
        uint256 percentageForLender,
        uint256 fee
    ) external override onlyModule returns (uint256) {
        uint256 id = currentId;
        require(_offerIds.add(id), "Store: already exist");
        _nftIds[id] = nftIds;
        _lenders[id] = lender;
        _durations[id] = duration;
        _percentageForLenders[id] = percentageForLender;
        _fees[id] = fee;
        _offersIdsOf[lender].add(id);
        currentId++;
        return id;
    }

    function remove(uint256 offerId) external override onlyModule {
        require(_offerIds.remove(offerId), "Store: unknow");
        _offersIdsOf[_lenders[offerId]].remove(offerId);
        delete _nftIds[offerId];
        _lenders[offerId] = address(0);
        _durations[offerId] = 0;
        _percentageForLenders[offerId] = 0;
        _fees[offerId] = 0;
    }

    function length() external view override returns (uint256) {
        return _offerIds.length();
    }

    function idAt(uint256 index) external view override returns (uint256) {
        return _offerIds.at(index);
    }

    function ids() external view override returns (uint256[] memory) {
        uint256[] memory result = new uint256[](_offerIds.length());
        for (uint256 i = 0; i < _offerIds.length(); i++) {
            result[i] = _offerIds.at(i);
        }
        return result;
    }

    function contains(uint256 offerId) external view override returns (bool) {
        return _offerIds.contains(offerId);
    }

    function nftIds(uint256 offerId)
        external
        view
        override
        returns (uint256[] memory)
    {
        return _nftIds[offerId];
    }

    function lender(uint256 offerId)
        external
        view
        override
        returns (address)
    {
        return _lenders[offerId];
    }

    function duration(uint256 offerId)
        external
        view
        override
        returns (uint256)
    {
        return _durations[offerId];
    }

    function percentageForLender(uint256 offerId)
        external
        view
        override
        returns (uint256)
    {
        return _percentageForLenders[offerId];
    }

    function fee(uint256 offerId)
        external
        view
        override
        returns (uint256)
    {
        return _fees[offerId];
    }

    function offersIdsOf(address account)
        external
        view
        override
        returns (uint256[] memory)
    {
        uint256[] memory result = new uint256[](_offersIdsOf[account].length());
        for (uint256 i = 0; i < _offersIdsOf[account].length(); i++) {
            result[i] = _offersIdsOf[account].at(i);
        }
        return result;
    }
}
