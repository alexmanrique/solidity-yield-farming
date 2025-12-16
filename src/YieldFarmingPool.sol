// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ABIEncoderDemo} from "./ABIEncoderDemo.sol";

contract YieldFarmingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Pool {
        address token;
        uint256 totalStaked;
        uint256 rewardRate;
        uint256 lastUpdate;
        uint256 rewardPerTokenStored;
        bool isActive;
    }

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastClaimTime;
    }

    IERC20 public immutable REWARD_TOKEN;

    mapping(bytes32 => Pool) public pools;

    bytes32[] public activePools;

    ABIEncoderDemo abiEncoderDemo;

    //Mapping of user information by pool and address
    mapping(bytes32 => mapping(address => UserInfo)) public userInfo;

    event PoolCreated(bytes32 indexed poolId, address token, uint256 rewardRate);
    event Staked(bytes32 indexed poolId, address indexed user, uint256 amount);
    event Withdrawn(bytes32 indexed poolId, address indexed user, uint256 amount);
    event RewardClaimed(bytes32 indexed poolId, address indexed user, uint256 amount);
    event PoolUpdated(bytes32 indexed poolId, address token, uint256 rewardRate);

    constructor(address rewardToken_, ABIEncoderDemo abiEncoderDemo_) Ownable(msg.sender) {
        require(rewardToken_ != address(0), "Invalid reward token");
        REWARD_TOKEN = IERC20(rewardToken_);
        abiEncoderDemo = abiEncoderDemo_;
    }

    function createPool(address token_, uint256 rewardRate) external onlyOwner returns (bytes32 poolId) {
        require(token_ != address(0), "Invalid token");
        require(rewardRate > 0, "Invalid reward rate");

        poolId = abiEncoderDemo.createPoolIdentifier(token_, rewardRate, block.timestamp, block.chainid);
        //Check if pool already exists
        require(pools[poolId].token == address(0), "Pool already exists");

        pools[poolId] = Pool({
            token: token_,
            totalStaked: 0,
            rewardRate: rewardRate,
            lastUpdate: block.timestamp,
            rewardPerTokenStored: 0,
            isActive: true
        });

        activePools.push(poolId);
        emit PoolCreated(poolId, token_, rewardRate);
        return poolId;
    }

    function stake(bytes32 poolId, uint256 amount) external nonReentrant {
        Pool storage pool = pools[poolId];
        require(pool.isActive, "Pool is not active");
        require(amount > 0, "Amount must be positive");

        _updatePool(poolId);
        UserInfo storage user = userInfo[poolId][msg.sender];
        if (user.amount > 0) {
            uint256 pending = _calculatePendingRewards(poolId, msg.sender);
            if (pending > 0) {
                _safeRewardsTransfer(msg.sender, pending);
                emit RewardClaimed(poolId, msg.sender, pending);
            }
        }

        bool success = IERC20(pool.token).transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        user.amount += amount;
        user.rewardDebt = user.amount * pool.rewardPerTokenStored / 1e18;
        user.lastClaimTime = block.timestamp;
        pool.totalStaked += amount;
        emit Staked(poolId, msg.sender, amount);
    }

    function withDraw(bytes32 poolId, uint256 amount) external nonReentrant {
        Pool storage pool = pools[poolId];
        UserInfo storage user = userInfo[poolId][msg.sender];

        require(user.amount > amount, "Insuficient staked amount");

        _updatePool(poolId);
        uint256 pending = _calculatePendingRewards(poolId, msg.sender);
        if (pending > 0) {
            _safeRewardsTransfer(msg.sender, pending);
            emit RewardClaimed(poolId, msg.sender, pending);
        }

        user.amount -= amount;
        user.rewardDebt = user.amount * pool.rewardPerTokenStored / 1e18;
        pool.totalStaked -= amount;
        IERC20(pool.token).safeTransfer(msg.sender, amount);
        emit Withdrawn(poolId, msg.sender, amount);
    }

    function claimRewards(bytes32 poolId) external nonReentrant {
        _updatePool(poolId);
        uint256 pending = _calculatePendingRewards(poolId, msg.sender);
        require(pending > 0, "no rewards to claim");

        UserInfo storage user = userInfo[poolId][msg.sender];
        user.rewardDebt = user.amount * pools[poolId].rewardPerTokenStored / 1e18;
        user.lastClaimTime = block.timestamp;
        _safeRewardsTransfer(msg.sender, pending);

        emit RewardClaimed(poolId, msg.sender, pending);
    }

       /**
     * @dev Calculate the pending rewards of a user
     * @param poolId Pool identifier
     * @param user User address
     * @return Amount of pending rewards
     */
    function pendingRewards(bytes32 poolId, address user) external view returns (uint256) {
        Pool storage pool = pools[poolId];
        UserInfo storage userInfoData = userInfo[poolId][user];
        
        uint256 rewardPerTokenStored = pool.rewardPerTokenStored;
        
        if (pool.totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - pool.lastUpdate;
            uint256 rewards = timeElapsed * pool.rewardRate;
            rewardPerTokenStored += rewards * 1e18 / pool.totalStaked;
        }
        
        return userInfoData.amount * rewardPerTokenStored / 1e18 - userInfoData.rewardDebt;
    }

    /**
     *
     */
    function updatePoolRewardRate(bytes32 poolId, uint256 newRewardRate) external onlyOwner {
        Pool storage pool = pools[poolId];
        require(pool.isActive, "Pool is not active");

        _updatePool(poolId);
        pool.rewardRate = newRewardRate;

        emit PoolUpdated(poolId, pool.token, newRewardRate);
    }

    function getPoolEncodedData(bytes32 poolId) external view returns (bytes memory encodedData) {
        Pool storage pool = pools[poolId];

        encodedData = abi.encodePacked(
            pool.token, pool.totalStaked, pool.rewardRate, pool.lastUpdate, pool.rewardPerTokenStored, pool.isActive
        );
    }

    function getUserHash(bytes32 poolId, address user) external pure returns (bytes32 userHash) {
        userHash = keccak256(abi.encodePacked(user, poolId, "YIELD_FARMING_USER"));
    }

    function getActivePoolsCount() external view returns (uint256) {
        return activePools.length;
    }

    function getActivePools() external view returns (bytes32[] memory) {
        return activePools;
    }

    function emergencyWithDraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }

    /**
     *
     */
    function _updatePool(bytes32 poolId) internal {
        Pool storage pool = pools[poolId];

        if (pool.totalStaked == 0) return;

        uint256 currentTime = block.timestamp;
        uint256 timeElapsed = currentTime - pool.lastUpdate;
        if (timeElapsed > 0) {
            uint256 reward = timeElapsed * pool.rewardRate;
            pool.rewardPerTokenStored += reward * 1e18 / pool.totalStaked;
        }
        pool.lastUpdate = block.timestamp;
    }

    /**
     *
     */
    function _safeRewardsTransfer(address to, uint256 amount) internal {
        uint256 rewardBalance = REWARD_TOKEN.balanceOf(address(this));
        if (amount > rewardBalance) {
            amount = rewardBalance;
        }
        if (amount > 0) {
            REWARD_TOKEN.safeTransfer(to, amount);
        }
    }

    function _calculatePendingRewards(bytes32 poolId, address user) internal view returns (uint256) {
        Pool storage pool = pools[poolId];
        UserInfo storage userInfoData = userInfo[poolId][user];

        uint256 rewardPerTokenStored = pool.rewardPerTokenStored;

        if (pool.totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - pool.lastUpdate;
            uint256 rewards = timeElapsed * pool.rewardRate;
            rewardPerTokenStored += rewards * 1e18 / pool.totalStaked;
        }

        return userInfoData.amount * rewardPerTokenStored / 1e18 - userInfoData.rewardDebt;
    }
}
