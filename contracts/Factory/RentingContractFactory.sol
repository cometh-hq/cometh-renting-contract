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

    Counters.Counter private _proposalIdTracker;

    mapping(uint256 => Proposal) public proposals;

    EnumerableSet.UintSet private _proposalsId;
    EnumerableSet.AddressSet private _rentContracts;
    mapping(address => EnumerableSet.AddressSet) private _rentContractsOf;

    address public spaceships;
    address public stakedSpaceShips;
    address public must;

    constructor(
        address mustAddress,
        address spaceshipsAddress,
        address stakedSpaceShipsAddress
    ) public {
        must = mustAddress;
        spaceships = spaceshipsAddress;
        stakedSpaceShips = stakedSpaceShipsAddress;
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

    function makeProposal(
        uint256[] memory nftIds,
        uint256 duration,
        uint256 percentageForLender,
        uint256 fixedFee
    ) override external {
        _addProposal(nftIds, duration, percentageForLender, fixedFee);
        for(uint256 i = 0; i < nftIds.length; i++) {
            _transfertSpaceShips(
                msg.sender,
                address(this),
                nftIds[i]
            );
        }
    }

    function removeProposal(uint256 proposalId) override external {
        require(_proposalsId.contains(proposalId), "unknow proposal");
        Proposal memory proposal = proposals[proposalId];
        for(uint256 i = 0; i < proposal.nftIds.length; i++) {
            _transfertSpaceShips(
                address(this),
                proposal.lender,
                proposal.nftIds[i]
            );
        }
        _removeProposal(proposalId);
        emit RemovedProposal(proposalId);
    }

    function acceptProposal(uint256 proposalId) override external {
        require(_proposalsId.contains(proposalId), "unknow proposal");
        Proposal memory proposal = proposals[proposalId];

        _payFixedFee(proposal.lender, proposal.fixedFee);

        address rentingContract = _newRentingContract(
            proposal.lender,
            msg.sender,
            block.timestamp + proposal.duration,
            proposal.percentageForLender
        );

        for(uint256 i = 0; i < proposal.nftIds.length; i++) {
            _transfertSpaceShips(
                address(this),
                rentingContract,
                proposal.nftIds[i]
            );
        }
        _removeProposal(proposalId);
        emit ProposalAccepted(
            proposalId,
            proposal.lender,
            msg.sender,
            rentingContract
        );
    }

    function closeRentingContract() override external {
        require(_rentContracts.contains(msg.sender), "unknown rent contract");
        RentingContract rentingContract = RentingContract(msg.sender);
        _removeRentingContract(msg.sender, rentingContract.tenant());
        emit RentingContractClosed(
            msg.sender,
            rentingContract.lender(),
            rentingContract.tenant()
        );
    }

    function proposalAmount() override external view returns (uint256) {
        return _proposalsId.length();
    }

    function rentAmount() override external view returns (uint256) {
        return _rentContracts.length();
    }

    function proposalAt(
        uint256 index
    ) override external view returns (Proposal memory) {
        return proposals[_proposalsId.at(index)];
    }

    function rentAt(uint256 index) override external view returns (address) {
        address rentContract = _rentContracts.at(index);
        return rentContract;
    }

    function rentOf(
        address tenant
    ) override external view returns (address[] memory) {
        address[] memory result =
            new address[](_rentContractsOf[tenant].length());
        for (uint256 i = 0; i < _rentContractsOf[tenant].length(); i++) {
            result[i] = _rentContractsOf[tenant].at(i);
        }
        return result;
    }

    function _addProposal(
        uint256[] memory nftIds,
        uint256 duration,
        uint256 percentageForLender,
        uint256 fixedFee
    ) internal {
        proposals[_proposalIdTracker.current()] = Proposal({
            nftIds: nftIds,
            lender: msg.sender,
            duration: duration,
            percentageForLender: percentageForLender,
            fixedFee: fixedFee
        });
        _proposalsId.add(_proposalIdTracker.current());
        emit NewProposal(
            _proposalIdTracker.current(),
            msg.sender,
            nftIds,
            percentageForLender,
            fixedFee
        );
        _proposalIdTracker.increment();
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

    function _removeProposal(uint256 proposalId) internal {
        _proposalsId.remove(proposalId);
        delete proposals[proposalId];
    }

    function _newRentingContract(
        address lender,
        address tenant,
        uint256 end,
        uint256 percentageForLender
    ) internal returns(address) {
        RentingContract rentingContract = new RentingContract(
            must,
            spaceships,
            stakedSpaceShips,
            lender,
            tenant,
            end,
            percentageForLender
        );

        _rentContracts.add(address(rentingContract));
        _rentContractsOf[tenant].add(address(rentingContract));
        return address(rentingContract);
    }

    function _removeRentingContract(
        address rentingContract,
        address tenant
    ) internal {
        _rentContracts.remove(rentingContract);
        _rentContractsOf[tenant].remove(rentingContract);
    }
}
