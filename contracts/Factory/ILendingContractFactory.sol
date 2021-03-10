// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface ILendingContractFactory is IERC721Receiver{
    struct Proposal{
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

    event NewProposal(uint256 proposalId, address lender, uint256[] nftIds, uint256 percentageForLender, uint256 fixedFee);
    event RemovedProposal(uint256 proposalId);
    event ProposalAccepted(uint256 proposalId, address lender, address tenant, address lendingContract);
    event LendingContractClosed(address lendingContract, address lender, address tenant);

    function makeProposal(uint256[] memory nftIds, uint256 duration, uint256 percentageForLender, uint256 fixedFee) external;
    function removeProposal(uint256 proposalId) external;
    function acceptProposal(uint256 proposalId) external;
    function closeLending() external;

    function proposalAmount() external view returns (uint256);
    function proposal(uint256 id) external view returns (Proposal memory);
    function proposalAt(uint256 index) external view returns (Proposal memory);
    function proposalsPaginated(uint256 start, uint256 amount) external view returns (Proposal[] memory);

    function lendingAmount() external view returns (uint256);
    function lending(address id) external view returns (Lending memory);
    function lendingAt(uint256 index) external view returns (Lending memory);
    function lendingsPaginated(uint256 start, uint256 amount) external view returns (Lending[] memory);

    function lendingsGrantedOf(address lender) external view returns (Lending[] memory);
    function lendingsReceivedOf(address tenant) external view returns (Lending[] memory);
}
