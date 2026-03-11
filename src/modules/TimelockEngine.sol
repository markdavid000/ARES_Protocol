// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "../interfaces/ITimeLockEngine.sol";
import "../interfaces/IProposal.sol";
import "../libraries/AttackGaurd.sol";

abstract contract TimelockEngine is ITimelockEngine {

    mapping(bytes32 => Timelocked) private _entries;

    IProposal private _proposal;
    address private _treasury;

    uint256 public constant TIMELOCK_DELAY = 48 hours;

    bool private _locked;

    AttackGuard.RateLimit private _rateLimit;

    modifier nonReentrant() {
        require(!_locked, "reentrant call");
        _locked = true;
        _;
        _locked = false;
    }


    constructor(
        address _proposalMgAddr,
        address _treasuryAddr,
        uint256 _maxDailyLimit
    ) {
        _proposal = IProposal(_proposalMgAddr);
        _treasury = _treasuryAddr;


        _rateLimit.dailyLimit = _maxDailyLimit;
        _rateLimit.windowStart = block.timestamp;
        _rateLimit.spentToday = 0;
    }

    function queue(bytes32 _proposalId) external {
        IProposal.Proposal memory proposal = _proposal.getProposalById(_proposalId);

        require(proposal.time_created != 0, "proposal does not exist");

        require(
            proposal.proposal_status == IProposal.ProposalState.QUEUED,
            "proposal not queued"
        );

        require(_entries[_proposalId].startedAt == 0, "already in timelock");

        _entries[_proposalId] = Timelocked({
            proposalId: _proposalId,
            startedAt: block.timestamp + TIMELOCK_DELAY, 
            timelockStatus: TimelockedState.QUEUED
        });

        emit TimelockedQueued(_proposalId, TimelockedState.QUEUED);
    }


    function execute(bytes32 _proposalId) external nonReentrant {
        Timelocked storage entry = _entries[_proposalId];

        require(entry.startedAt != 0, "entry does not exist");
        require(entry.timelockStatus == TimelockedState.QUEUED, "not queued");
        require(block.timestamp >= entry.startedAt, "delay not passed");

        IProposal.Proposal memory proposal = _proposal.getProposalById(_proposalId);


        AttackGuard.applyDailyLimit(_rateLimit, proposal.value);

        entry.timelockStatus = TimelockedState.EXECUTED;

        (bool success, ) = _treasury.call{value: proposal.value}(proposal.data);
        require(success, "execution failed");

        emit TimelockedExecuted(_proposalId, TimelockedState.EXECUTED);
    }

    function cancel(bytes32 _proposalId) external {
        Timelocked storage entry = _entries[_proposalId];

        require(entry.startedAt != 0, "entry does not exist");
        require(entry.timelockStatus == TimelockedState.QUEUED, "not queued");

        entry.timelockStatus = TimelockedState.CANCELED;

        emit TimelockedCanceled(_proposalId, TimelockedState.CANCELED);
    }

    function getTimelockEntry(bytes32 _proposalId)
        external
        view
        returns (Timelocked memory)
    {
        require(_entries[_proposalId].startedAt != 0, "entry does not exist");
        return _entries[_proposalId];
    }

    function isReadyToExecute(bytes32 _proposalId) external view returns (bool) {
        Timelocked storage entry = _entries[_proposalId];
        return
            entry.startedAt != 0 &&
            entry.timelockStatus == TimelockedState.QUEUED &&
            block.timestamp >= entry.startedAt;
    }
}