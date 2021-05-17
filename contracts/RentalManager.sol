// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IRental.sol";
import "./IRentalManager.sol";
import "./ProxyFactory.sol";
import "./OfferStore.sol";
import "./RentalStore.sol";

contract RentalManager is IRentalManager, Ownable {
    ProxyFactory public proxyFactory;
    address public rentalImplementation;

    uint256 private _leaveFee = 1000000000000000;
    address private _owner;

    address public spaceships;
    address public stakedSpaceShips;
    address public must;
    address public mustManager;

    address public feeReceiver;
    uint256 public serviceFeePercentage = 5;
    uint256 public serviceFeeMin = 300000000000000;

    IOfferStore public offerStore;
    IRentalStore public rentalStore;

    constructor(
        address mustAddress,
        address spaceshipsAddress,
        address stakedSpaceShipsAddress,
        address mustManagerAddress,
        ProxyFactory newProxyFactory,
        address newRentalImplementation,
        IOfferStore newOfferStore,
        IRentalStore newRentalStore
    ) public {
        proxyFactory = newProxyFactory;
        rentalImplementation = newRentalImplementation;
        _owner = msg.sender;
        must = mustAddress;
        spaceships = spaceshipsAddress;
        stakedSpaceShips = stakedSpaceShipsAddress;
        mustManager = mustManagerAddress;
        feeReceiver = msg.sender;
        updateOfferStore(newOfferStore);
        updateRentalStore(newRentalStore);
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
        uint256 fee,
        address privateFor
    ) override external returns(uint256 id){
        require(percentageForLender <= 100, "percentage over 100%");
        require(nftIds.length <= 5, "more than 5 nft");
        uint256 leaveFeeEscrow = nftIds.length * _leaveFee;
        require(fee >= serviceFeeMin + leaveFeeEscrow, "fee too low");
        id = _addOffer(nftIds, duration, percentageForLender, fee, privateFor);
        for(uint256 i = 0; i < nftIds.length; i++) {
            _transferSpaceShips(
                msg.sender,
                address(this),
                nftIds[i]
            );
        }
    }

    function removeOffer(uint256 offerId) override external {
        require(offerStore.contains(offerId), "unknown offer");
        address lender = offerStore.lender(offerId);
        require(msg.sender == lender, "caller is not lender");

        uint256[] memory nftIds = offerStore.nftIds(offerId);
        for(uint256 i = 0; i < nftIds.length; i++) {
            _transferSpaceShips(
                address(this),
                lender,
                nftIds[i]
            );
        }
        _removeOffer(offerId);
        emit OfferRemoved(offerId, lender);
    }

    function acceptOffer(uint256 offerId) override external returns(address) {
        require(offerStore.contains(offerId), "unknown offer");
        Offer memory offer = offer(offerId);
        require(offer.privateFor == address(0) || offer.privateFor == msg.sender, "invalid sender");

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
        _removeOffer(offerId);
        emit OfferAccepted(
            offerId,
            offer.lender,
            msg.sender,
            rentingContract
        );

        return rentingContract;
    }

    function closeRenting() override external {
        require(rentalStore.contains(msg.sender), "unknown renting");
        IRental rentingContract = IRental(msg.sender);
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

    function updateLeaveFee(uint256 newFee) override external onlyOwner {
        _leaveFee = newFee;
    }

    function updateServiceFee(address newFeeReceiver, uint256 newFeePercentage, uint256 newMinFee) override external onlyOwner {
        require(msg.sender == _owner);
        if(newFeeReceiver != address(0)) {
            feeReceiver = newFeeReceiver;
        }
        require(newFeePercentage < 100);
        serviceFeePercentage = newFeePercentage;
        serviceFeeMin = newMinFee;
    }

    function updateOfferStore(IOfferStore newStore)
        public
        onlyOwner
    {
        offerStore = newStore;
    }

    function updateRentalStore(IRentalStore newStore)
        public
        onlyOwner
    {
        rentalStore = newStore;
    }

    function offerAmount() override external view returns (uint256) {
        return offerStore.length();
    }

    function rentingAmount() override external view returns (uint256) {
        return rentalStore.length();
    }

    function offer(
        uint256 id
    ) override public view returns (Offer memory) {
        require(offerStore.contains(id), "unknown offer id");
        return Offer({
            id: id,
            nftIds: offerStore.nftIds(id),
            lender: offerStore.lender(id),
            duration: offerStore.duration(id),
            percentageForLender: offerStore.percentageForLender(id),
            fee: offerStore.fee(id),
            privateFor: offerStore.privateFor(id)
        });
    }

    function offersOf(
        address lender
    ) override external view returns (Offer[] memory) {
        uint256[] memory ids = offerStore.offersIdsOf(lender);
        Offer[] memory result = new Offer[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = offer(ids[i]);
        }
        return result;
    }

    function renting(address id) override public view returns (Renting memory) {
        require(rentalStore.contains(id), "unknown renting");
        IRental rentingContract = IRental(payable(id));
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
        address[] memory ids = rentalStore.rentalsIdsGrantedOf(lender);
        Renting[] memory result = new Renting[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = renting(ids[i]);
        }
        return result;
    }

    function rentingsReceivedOf(
        address tenant
    ) override external view returns (Renting[] memory) {
        address[] memory ids = rentalStore.rentalsIdsReceivedOf(tenant);
        Renting[] memory result = new Renting[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = renting(ids[i]);
        }
        return result;
    }

    function offersPaginated(
        uint256 start,
        uint256 amount
    ) override external view returns (Offer[] memory) {
        Offer[] memory result = new Offer[](amount);
        for (uint256 i = 0; i < amount; i++) {
            result[i] = offer(offerStore.idAt(start + i));
        }
        return result;
    }

    function rentingsPaginated(
        uint256 start,
        uint256 amount
    ) override external view returns (Renting[] memory) {
        Renting[] memory result = new Renting[](amount);
        for (uint256 i = 0; i < amount; i++) {
            result[i] = renting(rentalStore.idAt(start + i));
        }
        return result;
    }

    function _addOffer(
        uint256[] memory nftIds,
        uint256 duration,
        uint256 percentageForLender,
        uint256 fee,
        address privateFor
    ) internal returns(uint256 id) {
        id = offerStore.add(
            nftIds,
            msg.sender,
            duration,
            percentageForLender,
            fee,
            privateFor
        );
        emit OfferNew(
            id,
            msg.sender,
            nftIds,
            percentageForLender,
            fee,
            privateFor
        );
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

    function _removeOffer(uint256 offerId) internal {
        offerStore.remove(offerId);
    }

    function _newRenting(
        address lender,
        address tenant,
        uint256[] memory nftIds,
        uint256 end,
        uint256 percentageForLender
    ) internal returns(address) {
        bytes memory data = abi.encodeWithSelector(
            0x26f8a3e1,
            must,
            spaceships,
            stakedSpaceShips,
            mustManager,
            lender,
            tenant,
            nftIds,
            end,
            percentageForLender,
            address(this)
        );
        address rentingContract = address(proxyFactory.createProxy(rentalImplementation, data));
        rentalStore.add(rentingContract, lender, tenant);
        return rentingContract;
    }

    function _removeRenting(
        address rentingContract,
        address lender,
        address tenant
    ) internal {
        rentalStore.remove(rentingContract, lender, tenant);
    }
}
