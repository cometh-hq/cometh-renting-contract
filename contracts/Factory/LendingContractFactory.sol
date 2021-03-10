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
    EnumerableSet.UintSet private _proposalsId;
    mapping(uint256 => Proposal) private _proposals;

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
        require(_proposalsId.contains(proposalId), "unknown proposal");
        Proposal memory proposal = _proposals[proposalId];
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
        require(_proposalsId.contains(proposalId), "unknown proposal");
        Proposal memory proposal = _proposals[proposalId];

        _payFixedFee(proposal.lender, proposal.fixedFee);

        address lendingContract = _newLending(
            proposal.lender,
            msg.sender,
            proposal.nftIds,
            block.timestamp + proposal.duration,
            proposal.percentageForLender
        );

        for(uint256 i = 0; i < proposal.nftIds.length; i++) {
            _transfertSpaceShips(
                address(this),
                lendingContract,
                proposal.nftIds[i]
            );
        }
        _removeProposal(proposalId);
        emit ProposalAccepted(
            proposalId,
            proposal.lender,
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

    function proposalAmount() override external view returns (uint256) {
        return _proposalsId.length();
    }

    function lendingAmount() override external view returns (uint256) {
        return _lendings.length();
    }

    function proposalAt(
        uint256 index
    ) override external view returns (Proposal memory) {
        return _proposals[_proposalsId.at(index)];
    }

    function proposal(
        uint256 id
    ) override external view returns (Proposal memory) {
        require(_proposalsId.contains(id), "unknown proposal id");
        return _proposals[id];
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

    function proposalsPaginated(
        uint256 start,
        uint256 amount
    ) override external view returns (Proposal[] memory) {
        Proposal[] memory result = new Proposal[](amount);
        for (uint256 i = 0; i < amount; i++) {
            result[i] = _proposals[_proposalsId.at(start + i)];
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

    function _addProposal(
        uint256[] memory nftIds,
        uint256 duration,
        uint256 percentageForLender,
        uint256 fixedFee
    ) internal {
        _proposals[_proposalIdTracker.current()] = Proposal({
            id: _proposalIdTracker.current(),
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
        delete _proposals[proposalId];
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
