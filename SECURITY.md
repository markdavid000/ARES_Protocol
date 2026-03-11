## Security Analysis

### Key Attack Surfaces & How They’re Mitigated

#### 1. Flash Loan Attack

A common governance exploit involves borrowing a large amount of tokens through a flash loan to temporarily gain voting power and influence a proposal within a single transaction.

this is prevents by using a snapshot mechanism that records token balances at the moment a proposal is created. Because the snapshot captures balances before the flash-loan transaction finishes, temporarily borrowed tokens are not counted toward governance power.

```solidity
AttackGuards.recordSnapshot(_snapshot, proposalId);
```

#### 2. Signature Replay

An attacker might try to reuse a previously valid signature to approve another proposal.

To prevent this, every signer has an associated nonce. Once a signature is used, the nonce increments automatically, making the old signature permanently invalid.

```solidity
_nonces[_signers[i]]++;
```

#### 3. Cross-Chain Replay

A signature generated on one network (for example Ethereum mainnet) could potentially be reused on another chain.

ARES protects against this by including both the **chain ID** and the **contract address** in the EIP-712 domain separator. If either of these values changes, the signature becomes invalid.

```solidity
block.chainid,
address(this)
```

#### 4. Reentrancy

A malicious contract might attempt to call execute() repeatedly during execution to trigger multiple transfers.

Two protections are used here:

A `nonReentrant` modifier prevents nested calls.

The proposal status is updated to `EXECUTED` before the external call is made.

This ensures the proposal cannot be executed more than once.

```solidity
entry.status = TimeLockStatus.EXECUTED;
IAresProtocol(_treasury).executeProposal(...);
```

#### 5. Treasury Drain

An attacker might try to pass a proposal that withdraws the entire treasury in one execution.

To reduce this risk, the protocol implements a daily withdrawal limit. Even if a proposal is approved, the total amount withdrawn within a 24-hour window cannot exceed a predefined threshold.

```solidity
require(_self.spentToday + _amount <= _self.maxDailyLimit, "daily limit exceeded");
```

#### 6. Proposal Griefing

Without restrictions, an attacker could spam the system with useless proposals to slow down governance.

To discourage this behavior, submitting a proposal requires a 1 ETH deposit. Governance can slash the deposit if the proposal is deemed malicious or abusive.

#### 7. Double Claim

A contributor might attempt to claim their reward multiple times.

This is prevented by tracking claims in a `_claimed` mapping. Once a claim is processed, the recipient is permanently marked as claimed.

```solidity
require(!_claimed[_recipient], "already claimed");
_claimed[_recipient] = true;
```

#### 8. Premature Execution

Someone might attempt to execute a proposal before the required timelock delay has passed.

The protocol enforces this strictly using the `executableAt` timestamp.

```solidity
require(block.timestamp >= entry.executableAt, "delay not passed");
```
