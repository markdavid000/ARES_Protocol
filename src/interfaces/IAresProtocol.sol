// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./IProposal.sol";

interface IAresProtocol {
    function executeProposal(
        address _target,
        uint256 _value,
        bytes calldata _data,
        IProposal.ProposalType _proposalType
    ) external returns (bool);
}