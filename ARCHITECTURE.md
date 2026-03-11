### System Architecture

Ares protocol is designed as a treasury system where no funds can move without passing through a strict execution pipeline. Every treasury action begins as a proposal and progresses through several validation stages before it can be executed.

```
USER
   ↓
Proposal Manager
   (stores proposals, enforces commit phase)
   ↓
Signature Authorization
   (verifies that M-of-N signers approve)
   ↓
Timelock
   (48-hour delay + rate-limit checks)
   ↓
AresProtocol
   (treasury vault that executes the call)
   ↓
Target Contract
   (receives the treasury action)

```

Each stage acts as a safeguard, ensuring that proposals cannot bypass validation. A proposal must successfully pass through every layer before any treasury action is executed.

In this flow, no step can be skipped.

### Module Seperation

**Proposal:** manages the lifecycle of treasury proposals. It stores proposal data, enforces the one-hour commit phase, verifies signer approvals, and tracks proposal status from `PENDING` to `QUEUED`.  
This module does not hold funds and cannot execute transactions.

**Timelock:** enforces the mandatory 24-hour delay before execution. Once a proposal has been queued, the timelock starts a countdown and only allows execution after the delay has elapsed. It reads proposal information from the Proposal module but does not store proposal data itself. The timelock also does not move funds directly — instead, it calls the treasury contract to execute actions

**Distributor:** manages contributor rewards independently of the governance system. It verifies Merkle proofs and distributes tokens to eligible claimants. This module operates separately from the proposal system.

**AresProtocol:** acts as the treasury vault. It holds all protocol funds and is the only contract capable of making external calls.  
The contract does not handle proposals or signature verification — it simply ensures that the caller is the authorized timelock before executing a transaction.

**SignatureAuth:** responsible for verifying EIP-712 signatures. It contains no storage and is used by the Proposal module to validate signer approvals.

**AttackGaurd:** provides rate-limiting and snapshot functionality. While the library contains the logic, the state is stored by the contracts that integrate it.

### Security Boundaries

The following rules define how authority is distributed across the system.

```
Who can create a proposal?
Anyone, provided they submit the required 1 ETH deposit.

Who can authorize a proposal?
Only registered governance signers.

Who can queue a proposal?
Anyone, but only after the commit phase has ended and valid signatures are provided.

Who can execute a proposal?
Anyone, but only after the timelock delay has passed.

Who can cancel a proposal?
The original proposer or an authorized signer.

Who can call AresProtocol.executeProposal?
Only the registered Timelock contract (enforced by onlyTimelock).

Who can update the Merkle root?
Only the AresProtocol treasury contract.

Who can set the timelock address?
Only the deployer, and only once (enforced by onlyOwner and the `_timelockSet` flag).
```

#### Trust Assumptions

Signer keys are secure: Authorized signers are responsible for protecting their private keys. If a signer’s key is compromised, an attacker could approve malicious proposals. The rate limiter reduces potential damage but cannot completely prevent actions approved by valid signers.

Deployer is honest: The deployer sets the timelock address during initialization. A malicious deployer could configure a fake timelock contract. However, once the timelock is set via setTimelock, it cannot be modified.

block.timestamp is approximately accurate: Both the commit phase and the timelock delay rely on block.timestamp. While miners can manipulate timestamps slightly (typically within ~15 seconds), this is insignificant compared to the one-hour commit phase and the 24-hour timelock delay.

USDC behaves normally: The treasury currently holds USDC, which is centrally controlled by Circle. In extreme situations, Circle could pause transfers or blacklist addresses. This behavior is outside the protocol’s control.
