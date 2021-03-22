// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IRentingContractFactory is IERC721Receiver{
    struct Offer{
        uint256 id;
        uint256[] nftIds;
        address lender;
        uint256 duration;
        uint256 percentageForLender;
        uint256 fee;
    }

    struct Renting{
        address id;
        uint256[] nftIds;
        address lender;
        address tenant;
        uint256 start;
        uint256 end;
        uint256 percentageForLender;
    }

    event OfferNew(uint256 offerId, address lender, uint256[] nftIds, uint256 percentageForLender, uint256 fee);
    event OfferRemoved(uint256 offerId, address lender);
    event OfferAccepted(uint256 offerId, address lender, address tenant, address rentingContract);
    event RentingContractClosed(address rentingContract, address lender, address tenant);

    function makeOffer(uint256[] memory nftIds, uint256 duration, uint256 percentageForLender, uint256 fee) external returns (uint256);
    function removeOffer(uint256 offerId) external;
    function acceptOffer(uint256 offerId) external returns (address);
    function closeRenting() external;

    function updateLeaveFee(uint256 newFee) external;

    function offerAmount() external view returns (uint256);
    function offer(uint256 id) external view returns (Offer memory);
    function offersPaginated(uint256 start, uint256 amount) external view returns (Offer[] memory);
    function offersOf(address lender) external view returns (Offer[] memory);

    function rentingAmount() external view returns (uint256);
    function renting(address id) external view returns (Renting memory);
    function rentingsPaginated(uint256 start, uint256 amount) external view returns (Renting[] memory);

    function rentingsGrantedOf(address lender) external view returns (Renting[] memory);
    function rentingsReceivedOf(address tenant) external view returns (Renting[] memory);
}
