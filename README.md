## PPROBLEM 1

### Freeze Bypass

The freezing mechanism can be bypassed due to incomplete checks in the `transferFrom` function.

- Only checks if the spender (`msg.sender`) is frozen
- Doesn't check if the token owner (`from`) is frozen
- A frozen account's tokens can still be moved if they previously approved a non-frozen address

### The Fix

```solidity
function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
    require(!isFrozen[msg.sender] && !isFrozen[from], "account frozen");
    return super.transferFrom(from, to, amount);
}
```

### Unauthorized Burning

The `burn` function has no access controls, allowing anyone to burn anyone else's tokens.

- No permission checks
- Anyone can burn tokens from any address
- Catastrophic loss of funds possible

### The Fix

```solidity
function burn(address from, uint256 amount) public {
    require(msg.sender == from || msg.sender == owner(), "not authorized");
    _burn(from, amount);
}
```

Best Practices Learned

1. **Access Control**: Always implement proper access controls on sensitive functions
2. **Complete Checks**: When implementing freezing or blocking mechanisms, ensure all relevant parties are checked
3. **Token Safety**: For functions that can destroy tokens, ensure only authorized parties can execute them
4. **Permission Validation**: Double-check both spender and owner permissions in transfer-related functions

## PPROBLEM 2

### Issues with Deposit Implementation

- Uses raw `transferFrom` without checking actual tokens received
- Relies on input `amount` rather than actual transferred amount
- Doesn't account for tokens with fees or rebasing mechanics
- Wrong token allowance check (checks reward token instead of deposit token)

### Best Practice Implementation

```solidity
function deposit(uint256 amount) public {
    // Capture balance before transfer
    uint256 balanceBefore = depositToken.balanceOf(address(this));

    // Use safeTransferFrom for secure transfer
    depositToken.safeTransferFrom(msg.sender, address(this), amount);

    // Calculate actual received amount
    uint256 balanceAfter = depositToken.balanceOf(address(this));
    uint256 actualAmount = balanceAfter - balanceBefore;

    // Update user's balance with actual amount received
    internalBalances[msg.sender] += actualAmount;
    depositTime[msg.sender] = block.timestamp;

    emit Deposit(msg.sender, actualAmount);
}
```

1. **Fee Tokens**: Some tokens take a fee on transfer. Using `balanceAfter - balanceBefore` ensures we track actual received amount
2. **Rebasing Tokens**: Tokens that change balances automatically are handled correctly
3. **Safety**: `safeTransferFrom` ensures transfer success and handles non-standard ERC20 implementations
4. **Accuracy**: User's balance reflects actual tokens in contract, preventing accounting errors

#### Withdraw Function Issues

The withdraw function doesn't reduce internalBalances[msg.sender], allowing multiple withdrawals.

1. Use `<=` for balance checks

```solidity
require(amount <= internalBalances[msg.sender], "insufficient balance");
```

2. Update balances before transfer (CEI pattern)

```solidity
internalBalances[msg.sender] -= amount;
```

3. Use safe transfers

```solidity
depositToken.safeTransfer(msg.sender, amount);
```

4. Track rewards and deposits

```solidity
mapping(address => uint256) public depositAmount;    // Amount user has deposited
mapping(address => uint256) public depositTime;      // Time of deposit
mapping(address => uint256) public rewardDebt;       // Accumulated rewards
mapping(address => bool) public hasWithdrawn;        // If user has withdrawn
```

4. Track rewards properly in Withdraw

```solidity
function withdraw(uint256 amount) external {
    // Validations
    require(amount <= depositAmount[msg.sender], "insufficient balance");
    require(!hasWithdrawn[msg.sender], "already withdrawn");

    // Calculate rewards
    uint256 reward;
    if (block.timestamp >= depositTime[msg.sender] + 24 hours) {
        // Only give rewards if held for 24+ hours
        reward = amount;  // 1:1 reward ratio
    }

    // Update state
    depositAmount[msg.sender] -= amount;
    hasWithdrawn[msg.sender] = true;

    // Transfers (after state updates)
    if (reward > 0) {
        rewardToken.safeTransfer(msg.sender, reward);
    }
    depositToken.safeTransfer(msg.sender, amount);

    emit Withdrawn(msg.sender, amount, reward);
}
```

Uses `hasWithdrawn` flag to prevent multiple withdrawals of rewards
Only rewards tokens that were held for full duration
All state changes happen before transfers
