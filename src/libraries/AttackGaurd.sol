// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AttackGuard {
    struct Snapshot {
        mapping(bytes32 => uint256) proposalBlockNumber;

        mapping(address => mapping(uint256 => uint256)) balanceAt;
    }

    struct RateLimit {
        uint256 windowStart;
        uint256 spentToday;
        uint256 dailyLimit;
    }

    function applyDailyLimit(
        RateLimit storage _self,
        uint256 _amount
    ) internal {
        if (block.timestamp > _self.windowStart + 1 days) {
            _self.windowStart = block.timestamp;
            _self.spentToday = 0;
        }

        require(
            _self.spentToday + _amount <= _self.dailyLimit,
            "daily limit exceeded"
        );

        _self.spentToday += _amount;
    }

    function isWithinDailyLimit(
        RateLimit storage _self,
        uint256 _amount
    ) internal view returns (bool) {
        if (block.timestamp > _self.windowStart + 1 days) {
            return _amount <= _self.dailyLimit;
        }
        return _self.spentToday + _amount <= _self.dailyLimit;
    }

    function logSnapshot(
        Snapshot storage _self,
        bytes32 _proposalId
    ) internal {
        _self.proposalBlockNumber[_proposalId] = block.number;
    }

    function logBalance(
        Snapshot storage _self,
        address _user,
        uint256 _balance
    ) internal {
        _self.balanceAt[_user][block.number] = _balance;
    }


    function getVotingPower(
        Snapshot storage _self,
        address _user,
        bytes32 _proposalId
    ) internal view returns (uint256) {
        uint256 snapshotBlock = _self.proposalBlockNumber[_proposalId];
        return _self.balanceAt[_user][snapshotBlock];
    }
}