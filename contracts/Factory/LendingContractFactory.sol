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

    Counters.Counter private _proposalIdTracker;

    mapping(uint256 => Proposal) public proposals;

    EnumerableSet.UintSet private _proposalsId;
    EnumerableSet.AddressSet private _lending;
    mapping(address => EnumerableSet.AddressSet) private _lendingGrantedOf;
    mapping(address => EnumerableSet.AddressSet) private _lendingReceivedOf;

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

        address lending = _newLending(
            proposal.lender,
            msg.sender,
            proposal.nftIds,
            block.timestamp + proposal.duration,
            proposal.percentageForLender
        );

        for(uint256 i = 0; i < proposal.nftIds.length; i++) {
            _transfertSpaceShips(
                address(this),
                lending,
                proposal.nftIds[i]
            );
        }
        _removeProposal(proposalId);
        emit ProposalAccepted(
            proposalId,
            proposal.lender,
            msg.sender,
            lending
        );
    }

    function closeLending() override external {
        require(_lending.contains(msg.sender), "unknown lending contract");
        LendingContract lending = LendingContract(msg.sender);
        _removeLendingContract(
            msg.sender,
            lending.lender(),
            lending.tenant()
        );
        emit LendingContractClosed(
            msg.sender,
            lending.lender(),
            lending.tenant()
        );
    }

    function proposalAmount() override external view returns (uint256) {
        return _proposalsId.length();
    }

    function lendingAmount() override external view returns (uint256) {
        return _lending.length();
    }

    function proposalAt(
        uint256 index
    ) override external view returns (Proposal memory) {
        return proposals[_proposalsId.at(index)];
    }

    function lendingAt(uint256 index) override external view returns (address) {
        address lending = _lending.at(index);
        return lending;
    }

    function lendingGrantedOf(
        address lender
    ) override external view returns (address[] memory) {
        address[] memory result =
            new address[](_lendingGrantedOf[lender].length());
        for (uint256 i = 0; i < _lendingGrantedOf[lender].length(); i++) {
            result[i] = _lendingGrantedOf[lender].at(i);
        }
        return result;
    }

    function lendingReceivedOf(
        address tenant
    ) override external view returns (address[] memory) {
        address[] memory result =
            new address[](_lendingReceivedOf[tenant].length());
        for (uint256 i = 0; i < _lendingReceivedOf[tenant].length(); i++) {
            result[i] = _lendingReceivedOf[tenant].at(i);
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

    function _newLending(
        address lender,
        address tenant,
        uint256[] memory nftIds,
        uint256 end,
        uint256 percentageForLender
    ) internal returns(address) {
        LendingContract lending = new LendingContract(
            must,
            spaceships,
            stakedSpaceShips,
            mustManager,
            lender,
            tenant,
            nftIds,
            end,
            percentageForLender
        );

        _lending.add(address(lending));
        _lendingGrantedOf[lender].add(address(lending));
        _lendingReceivedOf[tenant].add(address(lending));
        return address(lending);
    }

    function _removeLendingContract(
        address lending,
        address lender,
        address tenant
    ) internal {
        _lending.remove(lending);
        _lendingGrantedOf[lender].remove(lending);
        _lendingReceivedOf[tenant].remove(lending);
    }
}
