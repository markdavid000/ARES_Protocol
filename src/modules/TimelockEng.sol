// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ITimeLockEng.sol";
import "../interfaces/IAresProtocol.sol";
import "../interfaces/IProposal.sol";
import "../libraries/AttackGaurd.sol";

contract TimelockEng is ITimelockEng {

    mapping(bytes32 => Timelocked) private _entries;

    IProposal private _proposal;
    address private _treasury;

    uint256 public constant TIMELOCK_DELAY = 24 hours;

    bool private _locked;

    AttackGuard.RateLimit private _rateLimit;

    modifier nonReentrant() {
        require(!_locked, "reentrant call");
        _locked = true;
        _;
        _locked = false;
    }


    constructor(
        address _proposalAddr,
        address _treasuryAddr,
        uint256 _dailyLimit
    ) {
        _proposal = IProposal(_proposalAddr);
        _treasury = _treasuryAddr;


        _rateLimit.dailyLimit = _dailyLimit;
        _rateLimit.windowStart = block.timestamp;
        _rateLimit.spentToday = 0;
    }

    function queue(bytes32 _proposalId) external {
        IProposal.Proposal memory proposal_ = _proposal.getProposalById(_proposalId);

        require(proposal_.time_created != 0, "proposal does not exist");

        require(
            proposal_.proposal_status == IProposal.ProposalState.QUEUED,
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
        Timelocked storage entry_ = _entries[_proposalId];

        require(entry_.startedAt != 0, "entry does not exist");
        require(entry_.timelockStatus == TimelockedState.QUEUED, "not queued");
        require(block.timestamp >= entry_.startedAt, "delay not passed");

        IProposal.Proposal memory proposal_ = _proposal.getProposalById(_proposalId);


        AttackGuard.applyDailyLimit(_rateLimit, proposal_.value);

        entry_.timelockStatus = TimelockedState.EXECUTED;

        IAresProtocol(_treasury).executeProposal(proposal_.target, proposal_.value, proposal_.data);

        emit TimelockedExecuted(_proposalId, TimelockedState.EXECUTED);
    }

    function cancel(bytes32 _proposalId) external {
        Timelocked storage entry_ = _entries[_proposalId];

        require(entry_.startedAt != 0, "entry does not exist");
        require(entry_.timelockStatus == TimelockedState.QUEUED, "not queued");

        entry_.timelockStatus = TimelockedState.CANCELED;

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

    function readyToExecute(bytes32 _proposalId) external view returns (bool) {
        Timelocked storage entry_ = _entries[_proposalId];
        return
            entry_.startedAt != 0 &&
            entry_.timelockStatus == TimelockedState.QUEUED &&
            block.timestamp >= entry_.startedAt;
    }
}