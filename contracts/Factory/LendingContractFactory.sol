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

    uint256 private _leaveFee = 1000000000000000;
    address private _owner;

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
        _owner = msg.sender;
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
        uint256[] calldata nftIds,
        uint256 duration,
        uint256 percentageForLender,
        uint256 lenderTax
    ) override external returns(uint256 id){
        require(percentageForLender <= 100, "percentage value over 100%");
        uint256 fee = lenderTax + nftIds.length * _leaveFee;
        id = _addOffer(nftIds, duration, percentageForLender, fee);
        for(uint256 i = 0; i < nftIds.length; i++) {
            _transferSpaceShips(
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
            _transferSpaceShips(
                address(this),
                offer.lender,
                offer.nftIds[i]
            );
        }
        _removeOffer(offerId, offer.lender);
        emit OfferRemoved(offerId, offer.lender);
    }

    function acceptOffer(uint256 offerId) override external returns(address) {
        require(_offersId.contains(offerId), "unknown offer");
        Offer memory offer = _offers[offerId];

        uint256 leaveFee = offer.nftIds.length * _leaveFee;
        _transferMust(msg.sender, address(this), leaveFee);
        _transferMust(msg.sender, offer.lender, offer.fee - leaveFee);

        address lendingContract = _newLending(
            offer.lender,
            msg.sender,
            offer.nftIds,
            block.timestamp + offer.duration,
            offer.percentageForLender
        );

        for(uint256 i = 0; i < offer.nftIds.length; i++) {
            _transferSpaceShips(
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

        return address(lendingContract);
    }

    function closeLending() override external {
        require(_lendings.contains(msg.sender), "unknown lending contract");
        LendingContract lendingContract = LendingContract(msg.sender);
        IERC20(must).transfer(
            address(lendingContract),
            lendingContract.nftIds().length * _leaveFee
        );
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

    function updateLeaveFee(uint256 newFee) external override {
        require(msg.sender == _owner);
        _leaveFee = newFee;
    }

    function offerAmount() override external view returns (uint256) {
        return _offersId.length();
    }

    function lendingAmount() override external view returns (uint256) {
        return _lendings.length();
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

    function lending(address id) override public view returns (Lending memory) {
        require(_lendings.contains(id), "unknown lending contract");
        LendingContract lendingContract = LendingContract(payable(id));
        return Lending({
            id: id,
            nftIds: lendingContract.nftIds(),
            lender: lendingContract.lender(),
            tenant: lendingContract.tenant(),
            start: lendingContract.start(),
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
        uint256 fee
    ) internal returns(uint256 id) {
        id = _offerIdTracker.current();
        _offers[id] = Offer({
            id: id,
            nftIds: nftIds,
            lender: msg.sender,
            duration: duration,
            percentageForLender: percentageForLender,
            fee: fee
        });
        _offersId.add(id);
        emit OfferNew(
            id,
            msg.sender,
            nftIds,
            percentageForLender,
            fee
        );
        _offersOf[msg.sender].add(id);
        _offerIdTracker.increment();
    }

    function _transferMust(address from, address to, uint256 amount) internal {
        IERC20(must).transferFrom(
            from,
            to,
            amount
        );
    }

    function _transferSpaceShips(
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
