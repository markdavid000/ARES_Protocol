// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Proposal} from "../src/modules/Proposal.sol";
import {TimelockEng} from "../src/modules/TimelockEng.sol";
import {Distributor} from "../src/modules/Distributor.sol";
import {AresProtocol} from "../src/core/AresProtocol.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IDistributor} from "../src/interfaces/IDistributor.sol";
import {IProposal} from "../src/interfaces/IProposal.sol";
import {ITimelockEng} from "../src/interfaces/ITimelockEng.sol";

contract AresProtocolTest is Test {

    address constant USDC_ADDR = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IERC20 public usdcAddr;

    Proposal public proposal;
    TimelockEng public timelockEng;
    Distributor public distributor;
    AresProtocol public treasury;

    address public levi;
    address public mark;
    address public marvel;

    uint256 public signer1Key = 0x111;
    uint256 public signer2Key = 0x222;
    address public signer1;
    address public signer2;

    bytes32 public merkleRoot;
    uint256 public leviAmount = 100e6;

    function setUp() public {
        vm.createSelectFork("https://0xrpc.io/eth");

        usdcAddr = IERC20(USDC_ADDR);
        levi = makeAddr("levi");
        mark = makeAddr("mark");
        marvel = makeAddr("marvel");
        signer1 = vm.addr(signer1Key);
        signer2 = vm.addr(signer2Key);

        vm.startPrank(levi);

        address[] memory signers = new address[](2);
        signers[0] = signer1;
        signers[1] = signer2;

        proposal  = new Proposal(signers, 2);
        merkleRoot  = keccak256(abi.encodePacked(levi, leviAmount));
        treasury    = new AresProtocol(address(proposal), address(0), address(usdcAddr));
        timelockEng    = new TimelockEng(address(proposal), address(treasury), 10_000e6);
        distributor = new Distributor(address(usdcAddr), merkleRoot, address(treasury));

        treasury.setTimelock(address(timelockEng));
        vm.stopPrank();

        deal(address(usdcAddr), address(treasury), 500_000e6);
        deal(address(usdcAddr), address(distributor), 10_000e6);
        vm.deal(levi, 10 ether);
        vm.deal(mark, 10 ether);
    }

    function test_ProposalLifecycle() public {
        bytes32 proposalId = _createProposal("lifecycle test", 1000e6);

        assertEq(
            uint256(_getStatus(proposalId)),
            uint256(IProposal.ProposalState.PENDING)
        );

        vm.warp(block.timestamp + 1 hours + 1);
        _queueProposal(proposalId);

        assertEq(
            uint256(_getStatus(proposalId)),
            uint256(IProposal.ProposalState.QUEUED)
        );

        timelockEng.queue(proposalId);

        vm.warp(block.timestamp + 24 hours + 1);

        uint256 before = usdcAddr.balanceOf(levi);
        timelockEng.execute(proposalId);
        assertEq(usdcAddr.balanceOf(levi) - before, 1000e6);

        assertEq(
            uint256(timelockEng.getTimelockEntry(proposalId).timelockStatus),
            uint256(ITimelockEng.TimelockedState.EXECUTED)
        );
    }

    function test_SignatureVerification() public {
        bytes32 proposalId = _createProposal("sig test", 500e6);
        vm.warp(block.timestamp + 1 hours + 1);
        _queueProposal(proposalId);
        assertEq(
            uint256(_getStatus(proposalId)),
            uint256(IProposal.ProposalState.QUEUED)
        );
    }

    function test_TimelockExecution() public {
        bytes32 proposalId = _createAndQueueToTimelock();

        assertFalse(timelockEng.readyToExecute(proposalId));

        vm.warp(block.timestamp + 24 hours + 1);
        assertTrue(timelockEng.readyToExecute(proposalId));

        timelockEng.execute(proposalId);

        assertEq(
            uint256(timelockEng.getTimelockEntry(proposalId).timelockStatus),
            uint256(ITimelockEng.TimelockedState.EXECUTED)
        );
    }

    function test_RewardClaiming() public {
        bytes32[] memory proof = new bytes32[](0);
        uint256 before = usdcAddr.balanceOf(levi);

        vm.prank(levi);
        distributor.claimReward(levi, leviAmount, proof);

        assertEq(usdcAddr.balanceOf(levi) - before, leviAmount);
        assertTrue(distributor.hasClaimedReward(levi));
    }

    function test_RevertWhen_Reentrancy() public {
        bytes32 proposalId = _createAndQueueToTimelock();
        vm.warp(block.timestamp + 24 hours + 1);

        timelockEng.execute(proposalId);

        vm.expectRevert("not queued");
        timelockEng.execute(proposalId);
    }

    function test_RevertWhen_DoubleClaim() public {
        bytes32[] memory proof = new bytes32[](0);

        vm.prank(levi);
        distributor.claimReward(levi, leviAmount, proof);

        vm.prank(levi);
        vm.expectRevert("already claimed");
        distributor.claimReward(levi, leviAmount, proof);
    }

    function test_RevertWhen_InvalidSignature() public {
        bytes32 proposalId = _createProposal("invalid sig", 500e6);
        vm.warp(block.timestamp + 1 hours + 1);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 wrongKey = 0xDEAD;

        address[] memory signers    = new address[](2);
        bytes[]   memory signatures = new bytes[](2);
        uint256[] memory nonces     = new uint256[](2);

        signers[0]    = vm.addr(wrongKey);
        signers[1]    = vm.addr(wrongKey);
        signatures[0] = _signProposal(proposalId, wrongKey, signer1, 0, deadline);
        signatures[1] = _signProposal(proposalId, wrongKey, signer2, 0, deadline);

        vm.expectRevert("insufficient signatures");
        proposal.queueProposal(
            proposalId, signers, signatures, nonces, deadline
        );
    }

    function test_RevertWhen_PrematureExecution() public {
        bytes32 proposalId = _createAndQueueToTimelock();

        vm.expectRevert("delay not passed");
        timelockEng.execute(proposalId);
    }

    function test_RevertWhen_ProposalReplay() public {
        bytes32 proposalId = _createAndQueueToTimelock();
        vm.warp(block.timestamp + 24 hours + 1);

        timelockEng.execute(proposalId);

        vm.expectRevert("not queued");
        timelockEng.execute(proposalId);
    }

    function test_RevertWhen_PrematureQueue() public {
        bytes32 proposalId = _createProposal("premature queue", 500e6);

        uint256 deadline = block.timestamp + 1 hours;

        address[] memory signers    = new address[](2);
        bytes[]   memory signatures = new bytes[](2);
        uint256[] memory nonces     = new uint256[](2);

        signers[0]    = signer1;
        signers[1]    = signer2;
        signatures[0] = _signProposal(proposalId, signer1Key, signer1, 0, deadline);
        signatures[1] = _signProposal(proposalId, signer2Key, signer2, 0, deadline);

        vm.expectRevert("still in commit phase");
        proposal.queueProposal(
            proposalId, signers, signatures, nonces, deadline
        );
    }

    function test_RevertWhen_UnauthorizedCancel() public {
        bytes32 proposalId = _createProposal("cancel test", 500e6);

        vm.prank(marvel);
        vm.expectRevert("not authorized to cancel");
        proposal.cancelProposal(proposalId);
    }

    function test_RevertWhen_InvalidMerkleProof() public {
        bytes32[] memory proof = new bytes32[](0);

        vm.prank(levi);
        vm.expectRevert("invalid proof");
        distributor.claimReward(levi, leviAmount * 2, proof);
    }


    function _createProposal(
        string memory _desc,
        uint256 _amount
    ) internal returns (bytes32) {
        bytes memory data = abi.encodeWithSignature(
            "transfer(address,uint256)", levi, _amount
        );
        vm.prank(mark);
        return proposal.createProposal{value: 1 ether}(
            address(usdcAddr),
            data,
            0,
            _desc,
            IProposal.ProposalType.TRANSFER
        );
    }

    function _createAndQueueToTimelock() internal returns (bytes32) {
        bytes32 proposalId = _createProposal("timelock test", 1000e6);
        vm.warp(block.timestamp + 1 hours + 1);
        _queueProposal(proposalId);
        timelockEng.queue(proposalId);
        return proposalId;
    }

    function _queueProposal(bytes32 _proposalId) internal {
        uint256 deadline = block.timestamp + 1 hours;

        address[] memory signers    = new address[](2);
        bytes[]   memory signatures = new bytes[](2);
        uint256[] memory nonces     = new uint256[](2);

        signers[0]    = signer1;
        signers[1]    = signer2;
        signatures[0] = _signProposal(_proposalId, signer1Key, signer1, 0, deadline);
        signatures[1] = _signProposal(_proposalId, signer2Key, signer2, 0, deadline);

        proposal.queueProposal(_proposalId, signers, signatures, nonces, deadline);
    }

    function _getStatus(
        bytes32 _proposalId
    ) internal view returns (IProposal.ProposalState) {
        return proposal.getProposalById(_proposalId).proposal_status;
    }

    function _signProposal(
        bytes32 _proposalId,
        uint256 _privKey,
        address _signer,      // <-- add this
        uint256 _nonce,
        uint256 _deadline
    ) internal view returns (bytes memory) {

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint chainId,address verifyingContract)"),
                //                                              ^^^^ NOT uint256
                keccak256(bytes("ARES Protocol")),
                keccak256(bytes("1")),
                block.chainid,
                address(proposal)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Approval(bytes32 proposalId,address signer,uint nonce,uint deadline)"),
                //                                     ^^^^^^^^^^^^^^ added, and uint not uint256
                _proposalId,
                _signer,      // <-- added
                _nonce,
                _deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privKey, digest);
        return abi.encodePacked(r, s, v);
    }
}