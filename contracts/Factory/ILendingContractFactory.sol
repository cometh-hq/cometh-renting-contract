// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface ILendingContractFactory is IERC721Receiver{
    struct Offer{
        uint256 id;
        uint256[] nftIds;
        address lender;
        uint256 duration;
        uint256 percentageForLender;
        uint256 fixedFee;
    }

    struct Lending{
        address id;
        uint256[] nftIds;
        address lender;
        address tenant;
        uint256 end;
        uint256 percentageForLender;
    }

    event OfferNew(uint256 offerId, address lender, uint256[] nftIds, uint256 percentageForLender, uint256 fixedFee);
    event OfferRemoved(uint256 offerId, address lender);
    event OfferAccepted(uint256 offerId, address lender, address tenant, address lendingContract);
    event LendingContractClosed(address lendingContract, address lender, address tenant);

    function makeOffer(uint256[] memory nftIds, uint256 duration, uint256 percentageForLender, uint256 fixedFee) external;
    function removeOffer(uint256 offerId) external;
    function acceptOffer(uint256 offerId) external;
    function closeLending() external;

    function offerAmount() external view returns (uint256);
    function offer(uint256 id) external view returns (Offer memory);
    function offerAt(uint256 index) external view returns (Offer memory);
    function offersPaginated(uint256 start, uint256 amount) external view returns (Offer[] memory);
    function offersOf(address lender) external view returns (Offer[] memory);

    function lendingAmount() external view returns (uint256);
    function lending(address id) external view returns (Lending memory);
    function lendingAt(uint256 index) external view returns (Lending memory);
    function lendingsPaginated(uint256 start, uint256 amount) external view returns (Lending[] memory);

    function lendingsGrantedOf(address lender) external view returns (Lending[] memory);
    function lendingsReceivedOf(address tenant) external view returns (Lending[] memory);
}
