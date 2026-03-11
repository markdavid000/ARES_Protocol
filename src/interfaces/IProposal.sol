//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IProposal {
    enum ProposalType {
        TRANSFER,
        CALL,
        UPGRADE
    }

    enum ProposalState {
        PENDING,
        QUEUED,
        EXECUTED,
        CANCELED
    }

    struct Proposal {
        bytes32 proposalId;
        address target;
        bytes data;
        uint value;
        address proposer;
        uint time_created;
        string desc;
        ProposalType proposal_type;
        ProposalState proposal_status;
    }

    event ProposalCreated(bytes32 indexed proposalId, ProposalType indexed proposal_type, ProposalState indexed proposal_status);
    event ProposalExecuted(bytes32 indexed proposalId, ProposalState indexed proposal_status);
    event ProposalQueued(bytes32 indexed proposalId, ProposalState indexed proposal_status);
    event ProposalCanceled(bytes32 indexed proposalId, ProposalState indexed proposal_status);

    function createProposal(address _target, bytes calldata _data, uint _value, string memory _desc, ProposalType proposal_type) external payable returns (bytes32);

    function getProposalById(bytes32 _proposalId) external returns (Proposal memory);

    function queueProposal(
        bytes32 _proposalId,
        address[] calldata _signers,
        bytes[] calldata _signatures,
        uint256[] calldata _signerNonces,
        uint256 _deadline
    ) external;

    function cancelProposal(bytes32 _proposalId) external;

    function readyToQueue(bytes32 _proposalId) external view returns (bool);
}