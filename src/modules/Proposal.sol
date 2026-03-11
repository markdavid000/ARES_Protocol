//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IProposal.sol";
import "../libraries/SignatureAuth.sol";
import "../libraries/AttackGaurd.sol";

contract Proposal is IProposal {
    AttackGuard.Snapshot private _snapshot;

    mapping(bytes32 => Proposal) private _proposals;
    mapping(address => uint) private _nonces;
    mapping(address => bool) private _authorizedSigners;
    mapping(bytes32 => uint) private _deposits;

    uint private _quorum;

    uint private constant COMMIT_DELAY = 1 hours;

    uint private constant PROPOSAL_DEPOSIT = 1 ether;

    constructor(address[] memory _signers, uint256 _thresh) {
        require(_thresh > 0, "quorum cannot be zero");
        require(_thresh <= _signers.length, "quorum exceeds signers");

        for (uint256 i = 0; i < _signers.length; i++) {
            _authorizedSigners[_signers[i]] = true;
        }
        _quorum = _thresh;
    }

    function createProposal(
        address _target,
        bytes calldata _data,
        uint256 _value,
        string calldata _description,
        IProposal.ProposalType _proposalType
    ) external payable returns (bytes32) {
        require(msg.value >= PROPOSAL_DEPOSIT, "insufficient deposit");

        bytes32 proposalId = keccak256(abi.encodePacked(
            msg.sender,
            block.timestamp,
            _target,
            _data,
            _value,
            _description,
            _proposalType
        ));

        require(_proposals[proposalId].time_created == 0, "proposal already exists");

        _deposits[proposalId] = msg.value;

        _proposals[proposalId] = Proposal({
            proposalId: proposalId,
            target: _target,
            data: _data,
            value: _value,
            proposer: msg.sender,
            time_created: block.timestamp,
            desc: _description,
            proposal_status: ProposalState.PENDING,
            proposal_type: _proposalType
        });

         AttackGuard.logSnapshot(_snapshot, proposalId);

        emit ProposalCreated(
            proposalId,
            _proposalType,
            ProposalState.PENDING
        );

        return proposalId;
    }

    function queueProposal(bytes32 _proposalId, address[] calldata _signers,
        bytes[] calldata _signatures,
        uint256[] calldata _signerNonces,
        uint256 _deadline) external {
        require(_proposals[_proposalId].time_created != 0, "proposal does not exist");

        Proposal storage proposal_ = _proposals[_proposalId];

        require(proposal_.proposal_status == ProposalState.PENDING, "proposal is not pending");

        require(
            block.timestamp >= proposal_.time_created + COMMIT_DELAY,
            "still in commit phase"
        );

        for (uint256 i = 0; i < _signers.length; i++) {
            require(
                _authorizedSigners[_signers[i]],
                "insufficient signatures"  
            );
        }

        require(
            SignatureAuth.verifyThreshold(_proposalId, _signers, _signatures, _signerNonces, _deadline, _quorum),
            "insufficient signatures"
        );

        for (uint256 i = 0; i < _signers.length; i++) {
            _nonces[_signers[i]]++;
        }

        proposal_.proposal_status = ProposalState.QUEUED;

        emit ProposalQueued(_proposalId, proposal_.proposal_status);
    }

    function cancelProposal(bytes32 _proposalId) external {
        require(_proposals[_proposalId].time_created != 0, "proposal does not exist");

        Proposal storage proposal_ = _proposals[_proposalId];

        require(
            proposal_.proposal_status == ProposalState.PENDING ||
            proposal_.proposal_status == ProposalState.QUEUED,
            "proposal cannot be cancelled"
        );

        require(
            proposal_.proposer == msg.sender || _authorizedSigners[msg.sender],
            "not authorized to cancel"
        );

        proposal_.proposal_status = ProposalState.CANCELED;

        uint256 deposit_ = _deposits[_proposalId];
        delete _deposits[_proposalId];
        (bool success, ) = payable(proposal_.proposer).call{value: deposit_}("");
        require(success, "refund failed");

        emit ProposalCanceled(_proposalId, proposal_.proposal_status);
    }

    function getProposalById(bytes32 _proposalId) 
        external 
        view 
        returns (Proposal memory) 
    {
        require(_proposals[_proposalId].time_created != 0, "proposal does not exist");
        return _proposals[_proposalId];
    }

    function readyToQueue(bytes32 _proposalId) external view returns (bool) {
        Proposal storage proposal_ = _proposals[_proposalId];
        require(proposal_.time_created != 0, "proposal does not exist");
        return block.timestamp >= proposal_.time_created + COMMIT_DELAY;
    }
}