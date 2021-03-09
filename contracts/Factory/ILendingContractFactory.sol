// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface ILendingContractFactory is IERC721Receiver{
    struct Proposal{
        uint256[] nftIds;
        address lender;
        uint256 duration;
        uint256 percentageForLender;
        uint256 fixedFee;
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
    function lendingAmount() external view returns (uint256);
    function proposalAt(uint256 index) external view returns (Proposal memory);
    function lendingAt(uint256 index) external view returns (address);
    function lendingGrantedOf(address lender) external view returns (address[] memory);
    function lendingReceivedOf(address tenant) external view returns (address[] memory);
}
