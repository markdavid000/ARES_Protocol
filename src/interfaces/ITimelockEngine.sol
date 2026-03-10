//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITimelockEngine {
    enum TimelockedState {
        PENDING,
        QUEUED,
        EXECUTED,
        CANCELED
    }

    struct Timelocked {
        bytes32 proposalId;
        uint startedAt;
        TimelockedState timelockStatus;
    }

    event TimelockedQueued(bytes32 indexed proposalId, TimelockedState timelockState);
    event TimelockedExecuted(bytes32 indexed proposalId, TimelockedState timelockState);
    event TimelockedCanceled(bytes32 indexed proposalId, TimelockedState timelockState);

    function getTimestamp(bytes32 _proposalId) external view returns (uint);

    function queueProposal(bytes32 _proposalId) external;

    function executeProposal(bytes32 _proposalId) external;

    function cancelProposal(bytes32 _proposalId) external;

    function getTimelockStatus(bytes32 _proposalId) external;

    function readyToExecute(bytes32 _proposalId) external view returns (bool);
}