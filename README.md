## Yield Farming Pool

The `YieldFarmingPool` contract is a yield farming protocol that allows users to stake tokens and earn rewards. It implements a multi-pool system where each pool can have different staking tokens and reward rates.

### Features

- **Multi-Pool Support**: Create multiple staking pools with different tokens and reward rates
- **Staking**: Users can stake tokens into active pools
- **Rewards**: Automatic reward calculation based on staked amount and time
- **Withdrawal**: Users can withdraw their staked tokens at any time
- **Reward Claiming**: Users can claim accumulated rewards separately from staking/withdrawal
- **Pool Management**: Owner can create pools, update reward rates, and perform emergency withdrawals

### Key Functions

#### For Users

- **`stake(bytes32 poolId, uint256 amount)`**: Stake tokens into a pool. Automatically claims pending rewards before staking.
- **`withdraw(bytes32 poolId, uint256 amount)`**: Withdraw staked tokens from a pool. Automatically claims pending rewards before withdrawal.
- **`claimRewards(bytes32 poolId)`**: Claim accumulated rewards without withdrawing staked tokens.
- **`pendingRewards(bytes32 poolId, address user)`**: View function to check pending rewards for a user.

#### For Owner

- **`createPool(address token_, uint256 rewardRate)`**: Create a new staking pool with a specific token and reward rate.
- **`updatePoolRewardRate(bytes32 poolId, uint256 newRewardRate)`**: Update the reward rate for an existing pool.
- **`emergencyWithdraw(address token, uint256 amount)`**: Emergency function to withdraw tokens from the contract.

#### View Functions

- **`getActivePools()`**: Get list of all active pool IDs.
- **`getActivePoolsCount()`**: Get the count of active pools.
- **`getPoolEncodedData(bytes32 poolId)`**: Get encoded pool data.
- **`getUserHash(bytes32 poolId, address user)`**: Get user hash for a specific pool.

### Security Features

- **ReentrancyGuard**: Protects against reentrancy attacks
- **Ownable**: Access control for owner-only functions
- **SafeERC20**: Safe token transfer operations
- **Reward Debt System**: Prevents reward manipulation using a reward debt tracking mechanism

### Pool Structure

Each pool contains:

- `token`: The ERC20 token address that can be staked
- `totalStaked`: Total amount of tokens staked in the pool
- `rewardRate`: Reward rate per second
- `lastUpdate`: Timestamp of last pool update
- `rewardPerTokenStored`: Accumulated rewards per token (scaled by 1e18)
- `isActive`: Whether the pool is currently active

### User Information

For each user in each pool, the contract tracks:

- `amount`: Amount of tokens staked by the user
- `rewardDebt`: Reward debt to prevent double-claiming
- `lastClaimTime`: Timestamp of last reward claim

### Events

- `PoolCreated`: Emitted when a new pool is created
- `Staked`: Emitted when a user stakes tokens
- `Withdrawn`: Emitted when a user withdraws tokens
- `RewardClaimed`: Emitted when rewards are claimed
- `PoolUpdated`: Emitted when a pool's reward rate is updated
