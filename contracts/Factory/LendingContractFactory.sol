// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../LendingContract.sol";
import "./ILendingContractFactory.sol";

contract LendingContractFactory is ILendingContractFactory {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;

    Counters.Counter private _offerIdTracker;
    EnumerableSet.UintSet private _offersId;
    mapping(uint256 => Offer) private _offers;
    mapping(address => EnumerableSet.UintSet) private _offersOf;

    EnumerableSet.AddressSet private _lendings;
    mapping(address => EnumerableSet.AddressSet) private _lendingsGrantedOf;
    mapping(address => EnumerableSet.AddressSet) private _lendingsReceivedOf;

    address public spaceships;
    address public stakedSpaceShips;
    address public must;
    address public mustManager;

    constructor(
        address mustAddress,
        address spaceshipsAddress,
        address stakedSpaceShipsAddress,
        address mustManagerAddress
    ) public {
        must = mustAddress;
        spaceships = spaceshipsAddress;
        stakedSpaceShips = stakedSpaceShipsAddress;
        mustManager = mustManagerAddress;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) override external returns(bytes4) {
        require(msg.sender == spaceships, "invalid nft");
        return this.onERC721Received.selector;
    }

    function makeOffer(
        uint256[] memory nftIds,
        uint256 duration,
        uint256 percentageForLender,
        uint256 fixedFee
    ) override external {
        _addOffer(nftIds, duration, percentageForLender, fixedFee);
        for(uint256 i = 0; i < nftIds.length; i++) {
            _transfertSpaceShips(
                msg.sender,
                address(this),
                nftIds[i]
            );
        }
    }

    function removeOffer(uint256 offerId) override external {
        require(_offersId.contains(offerId), "unknown offer");
        Offer memory offer = _offers[offerId];
        for(uint256 i = 0; i < offer.nftIds.length; i++) {
            _transfertSpaceShips(
                address(this),
                offer.lender,
                offer.nftIds[i]
            );
        }
        _removeOffer(offerId, offer.lender);
        emit OfferRemoved(offerId, offer.lender);
    }

    function acceptOffer(uint256 offerId) override external {
        require(_offersId.contains(offerId), "unknown offer");
        Offer memory offer = _offers[offerId];

        _payFixedFee(offer.lender, offer.fixedFee);

        address lendingContract = _newLending(
            offer.lender,
            msg.sender,
            offer.nftIds,
            block.timestamp + offer.duration,
            offer.percentageForLender
        );

        for(uint256 i = 0; i < offer.nftIds.length; i++) {
            _transfertSpaceShips(
                address(this),
                lendingContract,
                offer.nftIds[i]
            );
        }
        _removeOffer(offerId, offer.lender);
        emit OfferAccepted(
            offerId,
            offer.lender,
            msg.sender,
            lendingContract
        );
    }

    function closeLending() override external {
        require(_lendings.contains(msg.sender), "unknown lending contract");
        LendingContract lendingContract = LendingContract(msg.sender);
        _removeLending(
            msg.sender,
            lendingContract.lender(),
            lendingContract.tenant()
        );
        emit LendingContractClosed(
            msg.sender,
            lendingContract.lender(),
            lendingContract.tenant()
        );
    }

    function offerAmount() override external view returns (uint256) {
        return _offersId.length();
    }

    function lendingAmount() override external view returns (uint256) {
        return _lendings.length();
    }

    function offerAt(
        uint256 index
    ) override external view returns (Offer memory) {
        return _offers[_offersId.at(index)];
    }

    function offer(
        uint256 id
    ) override external view returns (Offer memory) {
        require(_offersId.contains(id), "unknown offer id");
        return _offers[id];
    }

    function offersOf(
        address lender
    ) override external view returns (Offer[] memory) {
        Offer[] memory result = new Offer[](_offersOf[lender].length());
        for (uint256 i = 0; i < _offersOf[lender].length(); i++) {
            result[i] = _offers[_offersOf[lender].at(i)];
        }
        return result;
    }

    function lendingAt(
        uint256 index
    ) override external view returns (Lending memory) {
        address payable id = payable(_lendings.at(index));
        return lending(id);
    }

    function lending(address id) override public view returns (Lending memory) {
        require(_lendings.contains(id), "unknown lending contract");
        LendingContract lendingContract = LendingContract(payable(id));
        return Lending({
            id: id,
            nftIds: lendingContract.nftIds(),
            lender: lendingContract.lender(),
            tenant: lendingContract.tenant(),
            end: lendingContract.end(),
            percentageForLender: lendingContract.percentageForLender()
        });
    }

    function lendingsGrantedOf(
        address lender
    ) override external view returns (Lending[] memory) {
        Lending[] memory result =
            new Lending[](_lendingsGrantedOf[lender].length());
        for (uint256 i = 0; i < _lendingsGrantedOf[lender].length(); i++) {
            result[i] = lending(_lendingsGrantedOf[lender].at(i));
        }
        return result;
    }

    function lendingsReceivedOf(
        address tenant
    ) override external view returns (Lending[] memory) {
        Lending[] memory result =
            new Lending[](_lendingsReceivedOf[tenant].length());
        for (uint256 i = 0; i < _lendingsReceivedOf[tenant].length(); i++) {
            result[i] = lending(_lendingsReceivedOf[tenant].at(i));
        }
        return result;
    }

    function offersPaginated(
        uint256 start,
        uint256 amount
    ) override external view returns (Offer[] memory) {
        Offer[] memory result = new Offer[](amount);
        for (uint256 i = 0; i < amount; i++) {
            result[i] = _offers[_offersId.at(start + i)];
        }
        return result;
    }

    function lendingsPaginated(
        uint256 start,
        uint256 amount
     ) override external view returns (Lending[] memory) {
        Lending[] memory result = new Lending[](amount);
        for (uint256 i = 0; i < amount; i++) {
            result[i] = lending(_lendings.at(start + i));
        }
        return result;
    }

    function _addOffer(
        uint256[] memory nftIds,
        uint256 duration,
        uint256 percentageForLender,
        uint256 fixedFee
    ) internal {
        _offers[_offerIdTracker.current()] = Offer({
            id: _offerIdTracker.current(),
            nftIds: nftIds,
            lender: msg.sender,
            duration: duration,
            percentageForLender: percentageForLender,
            fixedFee: fixedFee
        });
        _offersId.add(_offerIdTracker.current());
        emit OfferNew(
            _offerIdTracker.current(),
            msg.sender,
            nftIds,
            percentageForLender,
            fixedFee
        );
        _offersOf[msg.sender].add(_offerIdTracker.current());
        _offerIdTracker.increment();
    }

    function _payFixedFee(address to, uint256 amount) internal {
        IERC20(must).transferFrom(
            msg.sender,
            to,
            amount
        );
    }

    function _transfertSpaceShips(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        IERC721(spaceships).safeTransferFrom(
            from,
            to,
            tokenId
        );
    }

    function _removeOffer(uint256 offerId, address lender) internal {
        _offersId.remove(offerId);
        _offersOf[lender].remove(offerId);
        delete _offers[offerId];
    }

    function _newLending(
        address lender,
        address tenant,
        uint256[] memory nftIds,
        uint256 end,
        uint256 percentageForLender
    ) internal returns(address) {
        address lendingContract = address(new LendingContract(
            must,
            spaceships,
            stakedSpaceShips,
            mustManager,
            lender,
            tenant,
            nftIds,
            end,
            percentageForLender
        ));

        _lendings.add(lendingContract);
        _lendingsGrantedOf[lender].add(lendingContract);
        _lendingsReceivedOf[tenant].add(lendingContract);
        return lendingContract;
    }

    function _removeLending(
        address lendingContract,
        address lender,
        address tenant
    ) internal {
        _lendings.remove(lendingContract);
        _lendingsGrantedOf[lender].remove(lendingContract);
        _lendingsReceivedOf[tenant].remove(lendingContract);
    }
}
