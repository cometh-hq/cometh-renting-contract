// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../RentingContract.sol";
import "./IRentingContractFactory.sol";

contract RentingContractFactory is IRentingContractFactory {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;

    Counters.Counter private _offerIdTracker;
    EnumerableSet.UintSet private _offersId;
    mapping(uint256 => Offer) private _offers;
    mapping(address => EnumerableSet.UintSet) private _offersOf;

    EnumerableSet.AddressSet private _rentings;
    mapping(address => EnumerableSet.AddressSet) private _rentingsGrantedOf;
    mapping(address => EnumerableSet.AddressSet) private _rentingsReceivedOf;

    uint256 private _leaveFee = 1000000000000000;
    address private _owner;

    address public spaceships;
    address public stakedSpaceShips;
    address public must;
    address public mustManager;

    address public feeReceiver;
    uint256 public serviceFeePercentage = 5;
    uint256 public serviceFeeMin = 300000000000000;

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
        feeReceiver = msg.sender;
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
        require(percentageForLender <= 100, "percentage over 100%");
        require(lenderTax >= serviceFeeMin, "fee too low");
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

        uint256 serviceFee = (offer.fee - leaveFee) * serviceFeePercentage / 100;
        if (serviceFee < serviceFeeMin) {
            serviceFee = serviceFeeMin;
        }
        _transferMust(msg.sender, feeReceiver, serviceFee);
        _transferMust(msg.sender, offer.lender, offer.fee - leaveFee - serviceFee);

        address rentingContract = _newRenting(
            offer.lender,
            msg.sender,
            offer.nftIds,
            block.timestamp + offer.duration,
            offer.percentageForLender
        );

        for(uint256 i = 0; i < offer.nftIds.length; i++) {
            _transferSpaceShips(
                address(this),
                rentingContract,
                offer.nftIds[i]
            );
        }
        _removeOffer(offerId, offer.lender);
        emit OfferAccepted(
            offerId,
            offer.lender,
            msg.sender,
            rentingContract
        );

        return address(rentingContract);
    }

    function closeRenting() override external {
        require(_rentings.contains(msg.sender), "unknown renting");
        RentingContract rentingContract = RentingContract(msg.sender);
        IERC20(must).transfer(
            address(rentingContract),
            rentingContract.nftIds().length * _leaveFee
        );
        _removeRenting(
            msg.sender,
            rentingContract.lender(),
            rentingContract.tenant()
        );
        emit RentingContractClosed(
            msg.sender,
            rentingContract.lender(),
            rentingContract.tenant()
        );
    }

    function updateLeaveFee(uint256 newFee) override external {
        require(msg.sender == _owner);
        _leaveFee = newFee;
    }

    function updateServiceFee(address newFeeReceiver, uint256 newFeePercentage, uint256 newMinFee) override external {
        require(msg.sender == _owner);
        if(newFeeReceiver != address(0)) {
            feeReceiver = newFeeReceiver;
        }
        require(newFeePercentage < 100);
        serviceFeePercentage = newFeePercentage;
        serviceFeeMin = newMinFee;
    }

    function offerAmount() override external view returns (uint256) {
        return _offersId.length();
    }

    function rentingAmount() override external view returns (uint256) {
        return _rentings.length();
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

    function renting(address id) override public view returns (Renting memory) {
        require(_rentings.contains(id), "unknown renting");
        RentingContract rentingContract = RentingContract(payable(id));
        return Renting({
            id: id,
            nftIds: rentingContract.nftIds(),
            lender: rentingContract.lender(),
            tenant: rentingContract.tenant(),
            start: rentingContract.start(),
            end: rentingContract.end(),
            percentageForLender: rentingContract.percentageForLender()
        });
    }

    function rentingsGrantedOf(
        address lender
    ) override external view returns (Renting[] memory) {
        Renting[] memory result =
            new Renting[](_rentingsGrantedOf[lender].length());
        for (uint256 i = 0; i < _rentingsGrantedOf[lender].length(); i++) {
            result[i] = renting(_rentingsGrantedOf[lender].at(i));
        }
        return result;
    }

    function rentingsReceivedOf(
        address tenant
    ) override external view returns (Renting[] memory) {
        Renting[] memory result =
            new Renting[](_rentingsReceivedOf[tenant].length());
        for (uint256 i = 0; i < _rentingsReceivedOf[tenant].length(); i++) {
            result[i] = renting(_rentingsReceivedOf[tenant].at(i));
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

    function rentingsPaginated(
        uint256 start,
        uint256 amount
     ) override external view returns (Renting[] memory) {
        Renting[] memory result = new Renting[](amount);
        for (uint256 i = 0; i < amount; i++) {
            result[i] = renting(_rentings.at(start + i));
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

    function _newRenting(
        address lender,
        address tenant,
        uint256[] memory nftIds,
        uint256 end,
        uint256 percentageForLender
    ) internal returns(address) {
        address rentingContract = address(new RentingContract(
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

        _rentings.add(rentingContract);
        _rentingsGrantedOf[lender].add(rentingContract);
        _rentingsReceivedOf[tenant].add(rentingContract);
        return rentingContract;
    }

    function _removeRenting(
        address rentingContract,
        address lender,
        address tenant
    ) internal {
        _rentings.remove(rentingContract);
        _rentingsGrantedOf[lender].remove(rentingContract);
        _rentingsReceivedOf[tenant].remove(rentingContract);
    }
}
