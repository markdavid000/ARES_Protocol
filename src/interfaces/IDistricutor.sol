//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDistributor {
    event RewardClaimed(address indexed recipient, uint amount);
    event RootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);

    function updateRoot(bytes32 _newRoot) external;

    function claimReward(address _receiver, uint _amount, bytes32[] calldata _proof) external;

    function hasClaimedReward(address _recipient) external view returns (bool);

    function getMerkleRoot() external view returns (bytes32);
}