// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {YieldFarmingPool} from "../src/YieldFarmingPool.sol";
import {MockToken} from "../src/MockToken.sol";
import {ABIEncoderDemo} from "../src/ABIEncoderDemo.sol";

contract YieldFarmingPoolTest is Test {
    YieldFarmingPool public yieldFarmingPool;
    MockToken public rewardToken;
    MockToken public stakingToken1;
    MockToken public stakingToken2;
    address public user1;
    address public user2;

    function setUp() public {
        rewardToken = new MockToken("Reward Token", "RT", 1000000000000000000000000);
        stakingToken1 = new MockToken("Staking Token 1", "ST1", 1000000000000000000000000);
        stakingToken2 = new MockToken("Staking Token 2", "ST2", 1000000000000000000000000);
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

    function testPoolIdUniqueness() public {
        uint256 rewardRate = 1e18;
        bytes32 poolId1 = yieldFarmingPool.createPool(address(rewardToken), rewardRate);
        bytes32 poolId2 = yieldFarmingPool.createPool(address(rewardToken), rewardRate * 2);
        assertTrue(poolId1 != poolId2);

        vm.warp(block.timestamp + 1);
        bytes32 poolId3 = yieldFarmingPool.createPool(address(rewardToken), rewardRate);

        assertTrue(poolId1 != poolId3);
    }

    function testStake() public {
        uint256 stakeAmount = 1000 * 10 ** 18;
        uint256 rewardRate = 1e18;

        bool success = stakingToken1.transfer(user1, 10000 * 10 ** 18);
        require(success, "Transfer failed");

        bytes32 poolId1 = yieldFarmingPool.createPool(address(stakingToken1), rewardRate);

        vm.startPrank(user1);
        stakingToken1.approve(address(yieldFarmingPool), type(uint256).max);
        stakingToken2.approve(address(yieldFarmingPool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user1);
        yieldFarmingPool.stake(poolId1, stakeAmount);
        vm.stopPrank();

        // Verificar que el stake se registró correctamente
        (uint256 amount,,) = yieldFarmingPool.userInfo(poolId1, user1);
        (, uint256 totalStaked,,,,) = yieldFarmingPool.pools(poolId1);

        assertEq(amount, stakeAmount);
        assertEq(totalStaked, stakeAmount);
    }

    function testStakeAndRewards() public {
        uint256 stakeAmount = 1000 * 10 ** 18;
        uint256 rewardRate = 1e18;
        bytes32 poolId1 = yieldFarmingPool.createPool(address(stakingToken1), rewardRate);

        bool success = stakingToken1.transfer(user1, 10000 * 10 ** 18);
        require(success, "Transfer failed");

        // Transferir tokens de recompensa al contrato para que pueda distribuirlos
        uint256 rewardAmount = 10000 * 10 ** 18; // Suficientes tokens para las recompensas
        success = rewardToken.transfer(address(yieldFarmingPool), rewardAmount);
        require(success, "Reward token transfer failed");

        vm.startPrank(user1);
        stakingToken1.approve(address(yieldFarmingPool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user1);
        yieldFarmingPool.stake(poolId1, stakeAmount);
        vm.stopPrank();

        // Avanzar tiempo para generar recompensas
        vm.warp(block.timestamp + 100);

        // Verificar recompensas pendientes
        uint256 pendingRewards = yieldFarmingPool.pendingRewards(poolId1, user1);
        assertGt(pendingRewards, 0);

        // Reclamar recompensas
        vm.startPrank(user1);
        yieldFarmingPool.claimRewards(poolId1);
        vm.stopPrank();

        // Verificar que las recompensas se transfirieron
        assertGt(rewardToken.balanceOf(user1), 0);
    }

    function testWithdraw() public {
        uint256 stakeAmount = 1000 * 10 ** 18;
        uint256 withdrawAmount = 500 * 10 ** 18;

        uint256 rewardRate = 1e18;

        bytes32 poolId1 = yieldFarmingPool.createPool(address(stakingToken1), rewardRate);

        // Aprobar transferencia de tokens al contrato desde el usuario
        vm.startPrank(user1);
        stakingToken1.approve(address(yieldFarmingPool), type(uint256).max);
        vm.stopPrank();

        // Transferir tokens de recompensa al contrato para que pueda distribuirlos
        uint256 rewardAmount = 10000 * 10 ** 18; // Suficientes tokens para las recompensas
        bool success = rewardToken.transfer(address(yieldFarmingPool), rewardAmount);
        require(success, "Reward token transfer failed");

        success = stakingToken1.transfer(user1, 10000 * 10 ** 18);
        require(success, "Transfer failed");

        vm.startPrank(user1);
        yieldFarmingPool.stake(poolId1, stakeAmount);

        // Avanzar tiempo para generar recompensas
        vm.warp(block.timestamp + 100);

        yieldFarmingPool.withdraw(poolId1, withdrawAmount);
        vm.stopPrank();

        // Verificar que el withdraw se procesó correctamente
        (uint256 amount,,) = yieldFarmingPool.userInfo(poolId1, user1);
        (, uint256 totalStaked,,,,) = yieldFarmingPool.pools(poolId1);

        assertEq(amount, stakeAmount - withdrawAmount);
        assertEq(totalStaked, stakeAmount - withdrawAmount);
        assertEq(stakingToken1.balanceOf(user1), 9000 * 10 ** 18 + withdrawAmount);
    }

    function testMultipleUsers() public {
        uint256 stakeAmount1 = 1000 * 10 ** 18;
        uint256 stakeAmount2 = 2000 * 10 ** 18;
        uint256 rewardRate = 1e18;
        bytes32 poolId1 = yieldFarmingPool.createPool(address(stakingToken1), rewardRate);

        bool success = stakingToken1.transfer(user1, 10000 * 10 ** 18);
        require(success, "Transfer failed");

        success = stakingToken1.transfer(user2, 10000 * 10 ** 18);
        require(success, "Transfer failed");

        vm.startPrank(user1);
        stakingToken1.approve(address(yieldFarmingPool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        stakingToken1.approve(address(yieldFarmingPool), type(uint256).max);
        vm.stopPrank();

        // User1 stake en pool1
        vm.startPrank(user1);
        stakingToken1.approve(address(yieldFarmingPool), type(uint256).max);
        yieldFarmingPool.stake(poolId1, stakeAmount1);
        vm.stopPrank();

        // User2 stake en pool1
        vm.startPrank(user2);
        stakingToken1.approve(address(yieldFarmingPool), type(uint256).max);
        yieldFarmingPool.stake(poolId1, stakeAmount2);
        vm.stopPrank();

        // Avanzar tiempo
        vm.warp(block.timestamp + 100);

        // Verificar que ambos usuarios tienen recompensas
        uint256 pending1 = yieldFarmingPool.pendingRewards(poolId1, user1);
        uint256 pending2 = yieldFarmingPool.pendingRewards(poolId1, user2);

        assertGt(pending1, 0);
        assertGt(pending2, 0);

        // User2 debería tener más recompensas por tener más tokens staked
        assertGt(pending2, pending1);
    }

    function testGetPoolEncodedData() public {
        uint256 rewardRate = 1e18;
        bytes32 poolId1 = yieldFarmingPool.createPool(address(stakingToken1), rewardRate);
        // Obtener datos codificados del pool
        bytes memory encodedData = yieldFarmingPool.getPoolEncodedData(poolId1);
        
        // Verificar que los datos están codificados
        assertGt(encodedData.length, 0);
        
        // Los datos codificados deberían contener información del pool
        // Como no podemos decodificar directamente, verificamos que no esté vacío
        assertTrue(encodedData.length > 0);
    }
}
