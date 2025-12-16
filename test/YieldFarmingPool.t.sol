// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {YieldFarmingPool} from "../src/YieldFarmingPool.sol";
import {MockToken} from "../src/MockToken.sol";
import {ABIEncoderDemo} from "../src/ABIEncoderDemo.sol";

contract YieldFarmingPoolTest is Test {
    YieldFarmingPool public yieldFarmingPool;
    MockToken public rewardToken;
    address public user1;
    address public user2;

    function setUp() public {
        rewardToken = new MockToken("Reward Token", "RT", 1000000000000000000000000);
        yieldFarmingPool = new YieldFarmingPool(address(rewardToken), new ABIEncoderDemo());
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
    }

    function testCreatePoolSuccess() public {
        uint256 rewardRate = 1e18;
        bytes32 poolId = yieldFarmingPool.createPool(address(rewardToken), rewardRate);

        assertEq(poolId, keccak256(abi.encodePacked(address(rewardToken), rewardRate, block.timestamp, block.chainid)));

        (
            address token,
            uint256 totalStaked,
            uint256 poolRewardRate,
            uint256 lastUpdate,
            uint256 rewardPerTokenStored,
            bool isActive
        ) = yieldFarmingPool.pools(poolId);

        assertEq(token, address(rewardToken));
        assertEq(poolRewardRate, rewardRate);
        assertEq(lastUpdate, block.timestamp);
        assertEq(rewardPerTokenStored, 0);
        assertEq(isActive, true);
        assertEq(totalStaked, 0);
    }

    function testCreatePoolFailureWhenTokenIsZeroAddress() public {
        uint256 rewardRate = 1e18;
        address zeroAddress = address(0);
        vm.expectRevert("Invalid token");
        yieldFarmingPool.createPool(zeroAddress, rewardRate);
    }

    function testCreatePoolFailureWhenRewardRateIsZero() public {
        uint256 rewardRate = 0;
        address token = address(rewardToken);
        vm.expectRevert("Invalid reward rate");
        yieldFarmingPool.createPool(token, rewardRate);
    }

    function testCreatePoolFailureWhenPoolAlreadyExists() public {
        uint256 rewardRate = 1e18;
        yieldFarmingPool.createPool(address(rewardToken), rewardRate);
        vm.expectRevert("Pool already exists");
        yieldFarmingPool.createPool(address(rewardToken), rewardRate);
    }
}
