//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IDistributor {
    event RewardClaimed(address indexed recipient, uint amount);
    event RootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);

    function updateRoot(bytes32 _newRoot) external;

    function claimReward(bytes32 _proposalId) external;

    function hasClaimedReward(address _recipient) external view returns (bool);

    function getMerkleRoot() external view returns (bytes32);
}