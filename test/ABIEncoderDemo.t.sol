// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../lib/forge-std/src/Test.sol";
import "../src/ABIEncoderDemo.sol";

/// @title ABIEncoderDemoTest
/// @notice Comprehensive tests targeting 100% coverage for ABIEncoderDemo
/// @dev All comments are in English as requested
contract ABIEncoderDemoTest is Test {
    ABIEncoderDemo private demo;

    /// @dev Deploy a fresh contract before each test
    function setUp() external {
        demo = new ABIEncoderDemo();
    }

    /// @dev Pool id must be invariant to token ordering (tokens are sorted internally)
    function test_createPoolIdentifier_SameForBothTokenOrders() external view {
        address tokenA = address(0x1000);
        address tokenB = address(0x2000);
        uint24 fee = 3000;

        bytes32 idAB = demo.createPoolIdentifier(tokenA, tokenB, fee);
        bytes32 idBA = demo.createPoolIdentifier(tokenB, tokenA, fee);
        assertEq(idAB, idBA, "pool id should be identical regardless of token order");
    }

    /// @dev Different fees must produce different pool ids
    function test_createPoolIdentifier_DifferentFeeDifferentId() external {
        address tokenA = address(0x1000);
        address tokenB = address(0x2000);

        bytes32 idLow = demo.createPoolIdentifier(tokenA, tokenB, 500);
        bytes32 idHigh = demo.createPoolIdentifier(tokenA, tokenB, 3000);
        assertTrue(idLow != idHigh, "different fees must yield different ids");
    }

    /// @dev Function returns encoded bytes and keccak hash including current timestamp
    function test_encodeTradingPosition_ReturnsExpectedDataAndHash() external {
        address user = address(0x1234);
        address tokenIn = address(0xA1);
        address tokenOut = address(0xB2);
        uint256 amountIn = 1 ether;
        uint256 minAmountOut = 2 ether;

        // Freeze block timestamp to a known value
        uint256 fixedTs = 1_700_000_000;
        vm.warp(fixedTs);

        (bytes32 positionId, bytes memory encodedData) =
            demo.encodeTradingPosition(user, tokenIn, tokenOut, amountIn, minAmountOut);

        bytes memory expected = abi.encodePacked(user, tokenIn, tokenOut, amountIn, minAmountOut, fixedTs);

        assertEq(encodedData, expected, "encoded trading position mismatch");
        assertEq(positionId, keccak256(expected), "position id must be keccak of encoded data");
    }

    /// @dev Happy-path encoding for swap data (path + amounts + deadline)
    function test_encodeSwapData_EncodesPathAmountsDeadline() external {
        address[] memory path = new address[](3);
        path[0] = address(0x1);
        path[1] = address(0x2);
        path[2] = address(0x3);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 10;
        amounts[1] = 20;
        amounts[2] = 30;

        uint256 deadline = 999;

        bytes memory actual = demo.encodeSwapData(path, amounts, deadline);

        // Build expected packed bytes exactly as the contract does
        bytes memory pathData;
        for (uint256 i = 0; i < path.length; i++) {
            pathData = abi.encodePacked(pathData, path[i]);
        }

        bytes memory amountsData;
        for (uint256 j = 0; j < amounts.length; j++) {
            amountsData = abi.encodePacked(amountsData, amounts[j]);
        }

        bytes memory expected = abi.encodePacked(pathData, amountsData, deadline);
        assertEq(actual, expected, "swap data encoding mismatch");
    }

    /// @dev Mismatched array lengths must revert with the exact message
    function test_encodeSwapData_RevertsOnLengthMismatch() external {
        address[] memory path = new address[](2);
        path[0] = address(0x1);
        path[1] = address(0x2);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;

        vm.expectRevert(abi.encodeWithSignature("Error(string)", "Arrays length mismatch"));
        demo.encodeSwapData(path, amounts, 123);
    }

    /// @dev Returns order data and its hash; includes the string discriminator
    function test_encodeLimitOrder_ReturnsExpectedDataAndHash() external {
        address maker = address(0x11);
        address taker = address(0x22);
        address tokenIn = address(0x33);
        address tokenOut = address(0x44);
        uint256 amountIn = 100;
        uint256 amountOut = 200;
        uint256 nonce = 7;

        (bytes32 orderHash, bytes memory orderData) =
            demo.encodeLimitOrder(maker, taker, tokenIn, tokenOut, amountIn, amountOut, nonce);

        bytes memory expected =
            abi.encodePacked(maker, taker, tokenIn, tokenOut, amountIn, amountOut, nonce, "LIMIT_ORDER_V1");

        assertEq(orderData, expected, "limit order data encoding mismatch");
        assertEq(orderHash, keccak256(expected), "limit order hash mismatch");
    }

    /// @dev Yield position id is keccak of its packed fields plus discriminator
    function test_encodeYieldPosition_ReturnsExpectedId() external {
        address user = address(0xAA);
        bytes32 poolId = keccak256(abi.encodePacked("POOL"));
        uint256 amount = 12345;
        uint256 startTime = 42;

        bytes32 actual = demo.encodeYieldPosition(user, poolId, amount, startTime);

        bytes memory packed = abi.encodePacked(user, poolId, amount, startTime, "YIELD_POSITION");
        bytes32 expected = keccak256(packed);
        assertEq(actual, expected, "yield position id mismatch");
    }

    /// @dev Flash loan data concatenates token, amount, callbackData and discriminator
    function test_encodeFlashLoanData() external {
        address token = address(0xDEAD);
        uint256 amount = 321;
        bytes memory callbackData = hex"aabbcc";

        bytes memory actual = demo.encodeFlashLoanData(token, amount, callbackData);
        bytes memory expected = abi.encodePacked(token, amount, callbackData, "FLASH_LOAN_V1");

        assertEq(actual, expected, "flash loan data encoding mismatch");
    }

    /// @dev Staking pool config includes current timestamp; freeze it for determinism
    function test_encodeStakingPoolConfig_UsesCurrentTimestamp() external {
        address token = address(0x55);
        uint256 rewardRate = 9999;
        uint256 lockPeriod = 30 days;
        uint256 maxStakers = 50;

        uint256 fixedTs = 1_800_000_000;
        vm.warp(fixedTs);

        bytes memory actual = demo.encodeStakingPoolConfig(token, rewardRate, lockPeriod, maxStakers);
        bytes memory expected = abi.encodePacked(token, rewardRate, lockPeriod, maxStakers, fixedTs);

        assertEq(actual, expected, "staking pool config encoding mismatch");
    }

    /// @dev Multi-pool user hash is keccak of user + all pool ids + discriminator
    function test_createUserMultiPoolHash() external {
        address user = address(0xCafe);

        bytes32[] memory pools = new bytes32[](3);
        pools[0] = keccak256(abi.encodePacked("P0"));
        pools[1] = keccak256(abi.encodePacked("P1"));
        pools[2] = keccak256(abi.encodePacked("P2"));

        bytes memory data = abi.encodePacked(user);
        for (uint256 i = 0; i < pools.length; i++) {
            data = abi.encodePacked(data, pools[i]);
        }
        data = abi.encodePacked(data, "MULTI_POOL_USER");

        bytes32 expected = keccak256(data);
        bytes32 actual = demo.createUserMultiPoolHash(user, pools);
        assertEq(actual, expected, "multi pool user hash mismatch");
    }

    /// @dev Yield strategy requires equal-length arrays and returns packed bytes with discriminator
    function test_encodeYieldStrategy_HappyPath() external {
        string memory name = "StratAlpha";

        address[] memory pools = new address[](2);
        pools[0] = address(0x10);
        pools[1] = address(0x20);

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 40;

        bytes memory actual = demo.encodeYieldStrategy(name, pools, weights);

        bytes memory nameData = abi.encodePacked(name);
        bytes memory poolsData;
        for (uint256 i = 0; i < pools.length; i++) {
            poolsData = abi.encodePacked(poolsData, pools[i]);
        }
        bytes memory weightsData;
        for (uint256 j = 0; j < weights.length; j++) {
            weightsData = abi.encodePacked(weightsData, weights[j]);
        }

        bytes memory expected = abi.encodePacked(nameData, poolsData, weightsData, "YIELD_STRATEGY_V1");

        assertEq(actual, expected, "yield strategy encoding mismatch");
    }

    /// @dev Mismatched pools/weights must revert with the exact message
    function test_encodeYieldStrategy_RevertsOnLengthMismatch() external {
        string memory name = "Broken";

        address[] memory pools = new address[](2);
        pools[0] = address(0x10);
        pools[1] = address(0x20);

        uint256[] memory weights = new uint256[](1);
        weights[0] = 100;

        vm.expectRevert(abi.encodeWithSignature("Error(string)", "Arrays length mismatch"));
        demo.encodeYieldStrategy(name, pools, weights);
    }

    /// @dev Cross-chain bridge data is a simple packed concatenation with discriminator
    function test_encodeCrossChainBridgeData() external {
        uint256 sourceChain = 1;
        uint256 targetChain = 137;
        address token = address(0xFEED);
        uint256 amount = 777;
        address recipient = address(0xBEEF);

        bytes memory actual = demo.encodeCrossChainBridgeData(sourceChain, targetChain, token, amount, recipient);

        bytes memory expected =
            abi.encodePacked(sourceChain, targetChain, token, amount, recipient, "CROSS_CHAIN_BRIDGE");

        assertEq(actual, expected, "bridge data encoding mismatch");
    }

    /// @dev Transaction id is keccak of packed fields plus discriminator
    function test_createDeFiTransactionId() external {
        string memory txType = "SWAP";
        address user = address(0xABCD);
        uint256 timestamp = 123456789;
        uint256 nonce = 9;

        bytes32 actual = demo.createDeFiTransactionId(txType, user, timestamp, nonce);

        bytes32 expected = keccak256(abi.encodePacked(txType, user, timestamp, nonce, "DEFI_TX"));

        assertEq(actual, expected, "defi transaction id mismatch");
    }

    /// @dev Stop loss order data must match packed encoding with discriminator
    function test_encodeStopLossOrder() external {
        address user = address(0x01);
        address token = address(0x02);
        uint256 amount = 1_000;
        uint256 stopPrice = 95;
        uint256 triggerPrice = 90;

        bytes memory actual = demo.encodeStopLossOrder(user, token, amount, stopPrice, triggerPrice);
        bytes memory expected = abi.encodePacked(user, token, amount, stopPrice, triggerPrice, "STOP_LOSS_ORDER");

        assertEq(actual, expected, "stop loss order encoding mismatch");
    }

    /// @dev Take profit order data must match packed encoding with discriminator
    function test_encodeTakeProfitOrder() external {
        address user = address(0x03);
        address token = address(0x04);
        uint256 amount = 2_000;
        uint256 takeProfitPrice = 120;

        bytes memory actual = demo.encodeTakeProfitOrder(user, token, amount, takeProfitPrice);
        bytes memory expected = abi.encodePacked(user, token, amount, takeProfitPrice, "TAKE_PROFIT_ORDER");

        assertEq(actual, expected, "take profit order encoding mismatch");
    }

    /// @dev Trailing stop order data must match packed encoding with discriminator
    function test_encodeTrailingStopOrder() external {
        address user = address(0x05);
        address token = address(0x06);
        uint256 amount = 3_000;
        uint256 trailingPercent = 5; // 5%
        uint256 activationPrice = 110;

        bytes memory actual = demo.encodeTrailingStopOrder(user, token, amount, trailingPercent, activationPrice);
        bytes memory expected =
            abi.encodePacked(user, token, amount, trailingPercent, activationPrice, "TRAILING_STOP_ORDER");

        assertEq(actual, expected, "trailing stop order encoding mismatch");
    }
}

