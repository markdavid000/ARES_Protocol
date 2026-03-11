//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITimelockEng {
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

    function queue(bytes32 _proposalId) external;

    function execute(bytes32 _proposalId) external;

    function cancel(bytes32 _proposalId) external;

    function readyToExecute(bytes32 _proposalId) external view returns (bool);
}