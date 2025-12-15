// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ABIEncoderDemo} from "./ABIEncoderDemo.sol";

contract YieldFarmingPool is Ownable, ReentrancyGuard {
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

    IERC20 public immutable token;

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
        token = IERC20(rewardToken_);
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
}
