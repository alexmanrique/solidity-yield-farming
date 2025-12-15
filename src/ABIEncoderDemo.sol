// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title ABIEncoderDemo
 * @dev Contract that demonstrates different uses of abi.encodePacked in DeFi
 */
contract ABIEncoderDemo {
    // Events to demonstrate encoding
    event DataEncoded(bytes32 indexed hash, bytes encodedData);
    event PoolIdentifierCreated(bytes32 indexed poolId, address token, uint256 rate);
    event UserPositionEncoded(bytes32 indexed positionId, address user, uint256 amount);

    /**
     * @dev Demonstrates encoding of liquidity pool parameters
     * @param tokenA First token of the pool
     * @param tokenB Second token of the pool
     * @param fee Pool fee (in basis points)
     * @return poolId Unique identifier of the pool
     */
    function createPoolIdentifier(address tokenA, address tokenB, uint24 fee) external pure returns (bytes32 poolId) {
        // Sort tokens to ensure consistency
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        // USE OF ABI.ENCODEPACKED: Create a unique pool identifier
        // Similar to the method used by Uniswap V3
        poolId = keccak256(abi.encodePacked(token0, token1, fee));
    }

    function createPoolIdentifier(address token, uint256 rewardRate, uint256 timestamp, uint256 chainId)
        external
        pure
        returns (bytes32 poolId)
    {
        poolId = keccak256(abi.encodePacked(token, rewardRate, timestamp, chainId));
    }

    /**
     * @dev Encodes data for a trading position
     * @param user User address
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @param minAmountOut Minimum output amount
     * @return positionId Position identifier
     * @return encodedData Encoded position data
     */
    function encodeTradingPosition(
        address user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external view returns (bytes32 positionId, bytes memory encodedData) {
        // Encode the position data
        encodedData = abi.encodePacked(user, tokenIn, tokenOut, amountIn, minAmountOut, block.timestamp);

        // Create a unique identifier for the position
        positionId = keccak256(encodedData);
    }

    /**
     * @dev Encodes parameters for a swap on a DEX
     * @param path Array of tokens for the swap
     * @param amounts Array of amounts
     * @param deadline Transaction deadline
     * @return swapData Encoded swap data
     */
    function encodeSwapData(address[] calldata path, uint256[] calldata amounts, uint256 deadline)
        external
        pure
        returns (bytes memory swapData)
    {
        require(path.length == amounts.length, "Arrays length mismatch");

        // Encode the path
        bytes memory pathData;
        for (uint256 i = 0; i < path.length; i++) {
            pathData = abi.encodePacked(pathData, path[i]);
        }

        // Encode the amounts
        bytes memory amountsData;
        for (uint256 i = 0; i < amounts.length; i++) {
            amountsData = abi.encodePacked(amountsData, amounts[i]);
        }

        // Combine everything
        swapData = abi.encodePacked(pathData, amountsData, deadline);
    }

    /**
     * @dev Encodes data for a limit order
     * @param maker Maker address
     * @param taker Taker address
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @param amountOut Output amount
     * @param nonce Unique nonce
     * @return orderHash Order hash
     * @return orderData Encoded order data
     */
    function encodeLimitOrder(
        address maker,
        address taker,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 nonce
    ) external pure returns (bytes32 orderHash, bytes memory orderData) {
        // Encode the order data
        orderData = abi.encodePacked(maker, taker, tokenIn, tokenOut, amountIn, amountOut, nonce, "LIMIT_ORDER_V1");

        // Create the order hash
        orderHash = keccak256(orderData);
    }

    /**
     * @dev Encodes data for a yield farming position
     * @param user User address
     * @param poolId Pool identifier
     * @param amount Staked amount
     * @param startTime Start time
     * @return positionId Position identifier
     */
    function encodeYieldPosition(address user, bytes32 poolId, uint256 amount, uint256 startTime)
        external
        pure
        returns (bytes32 positionId)
    {
        // USE OF ABI.ENCODEPACKED: Create a unique position identifier
        positionId = keccak256(abi.encodePacked(user, poolId, amount, startTime, "YIELD_POSITION"));
    }

    /**
     * @dev Encodes data for a flash loan
     * @param token Flash loan token
     * @param amount Loan amount
     * @param callbackData Callback data
     * @return flashData Encoded flash loan data
     */
    function encodeFlashLoanData(address token, uint256 amount, bytes calldata callbackData)
        external
        pure
        returns (bytes memory flashData)
    {
        flashData = abi.encodePacked(token, amount, callbackData, "FLASH_LOAN_V1");
    }

    /**
     * @dev Encodes parameters for a staking pool
     * @param token Token address
     * @param rewardRate Reward rate
     * @param lockPeriod Lock period
     * @param maxStakers Maximum number of stakers
     * @return poolConfig Encoded configuration data
     */
    function encodeStakingPoolConfig(address token, uint256 rewardRate, uint256 lockPeriod, uint256 maxStakers)
        external
        view
        returns (bytes memory poolConfig)
    {
        poolConfig = abi.encodePacked(token, rewardRate, lockPeriod, maxStakers, block.timestamp);
    }

    /**
     * @dev Creates a unique hash for a user across multiple pools
     * @param user User address
     * @param poolIds Array of pool identifiers
     * @return userHash Unique user hash
     */
    function createUserMultiPoolHash(address user, bytes32[] calldata poolIds)
        external
        pure
        returns (bytes32 userHash)
    {
        bytes memory data = abi.encodePacked(user);

        for (uint256 i = 0; i < poolIds.length; i++) {
            data = abi.encodePacked(data, poolIds[i]);
        }

        data = abi.encodePacked(data, "MULTI_POOL_USER");
        userHash = keccak256(data);
    }

    /**
     * @dev Encodes data for a yield farming strategy
     * @param strategyName Name of the strategy
     * @param pools Array of involved pools
     * @param weights Array of weights for each pool
     * @return strategyData Encoded strategy data
     */
    function encodeYieldStrategy(string calldata strategyName, address[] calldata pools, uint256[] calldata weights)
        external
        pure
        returns (bytes memory strategyData)
    {
        require(pools.length == weights.length, "Arrays length mismatch");

        // Encode strategy name
        bytes memory nameData = abi.encodePacked(strategyName);

        // Encode pools
        bytes memory poolsData;
        for (uint256 i = 0; i < pools.length; i++) {
            poolsData = abi.encodePacked(poolsData, pools[i]);
        }

        // Encode weights
        bytes memory weightsData;
        for (uint256 i = 0; i < weights.length; i++) {
            weightsData = abi.encodePacked(weightsData, weights[i]);
        }

        // Combine everything
        strategyData = abi.encodePacked(nameData, poolsData, weightsData, "YIELD_STRATEGY_V1");
    }

    /**
     * @dev Demonstrates encoding data for a cross-chain bridge
     * @param sourceChain Source chain
     * @param targetChain Target chain
     * @param token Token to transfer
     * @param amount Amount
     * @param recipient Recipient
     * @return bridgeData Encoded bridge data
     */
    function encodeCrossChainBridgeData(
        uint256 sourceChain,
        uint256 targetChain,
        address token,
        uint256 amount,
        address recipient
    ) external pure returns (bytes memory bridgeData) {
        bridgeData = abi.encodePacked(sourceChain, targetChain, token, amount, recipient, "CROSS_CHAIN_BRIDGE");
    }

    /**
     * @dev Creates a unique identifier for a DeFi transaction
     * @param txType Transaction type
     * @param user User
     * @param timestamp Timestamp
     * @param nonce Unique nonce
     * @return txId Unique transaction identifier
     */
    function createDeFiTransactionId(string calldata txType, address user, uint256 timestamp, uint256 nonce)
        external
        pure
        returns (bytes32 txId)
    {
        txId = keccak256(abi.encodePacked(txType, user, timestamp, nonce, "DEFI_TX"));
    }

    /**
     * @dev Encodes data for a stop loss order
     * @param user User address
     * @param token Token to sell
     * @param amount Amount to sell
     * @param stopPrice Stop loss price
     * @param triggerPrice Trigger price
     * @return stopLossData Encoded order data
     */
    function encodeStopLossOrder(address user, address token, uint256 amount, uint256 stopPrice, uint256 triggerPrice)
        external
        pure
        returns (bytes memory stopLossData)
    {
        stopLossData = abi.encodePacked(user, token, amount, stopPrice, triggerPrice, "STOP_LOSS_ORDER");
    }

    /**
     * @dev Encodes data for a take profit order
     * @param user User address
     * @param token Token to sell
     * @param amount Amount to sell
     * @param takeProfitPrice Take profit price
     * @return takeProfitData Encoded order data
     */
    function encodeTakeProfitOrder(address user, address token, uint256 amount, uint256 takeProfitPrice)
        external
        pure
        returns (bytes memory takeProfitData)
    {
        takeProfitData = abi.encodePacked(user, token, amount, takeProfitPrice, "TAKE_PROFIT_ORDER");
    }

    /**
     * @dev Encodes data for a trailing stop order
     * @param user User address
     * @param token Token to sell
     * @param amount Amount to sell
     * @param trailingPercent Trailing percentage
     * @param activationPrice Activation price
     * @return trailingStopData Encoded order data
     */
    function encodeTrailingStopOrder(
        address user,
        address token,
        uint256 amount,
        uint256 trailingPercent,
        uint256 activationPrice
    ) external pure returns (bytes memory trailingStopData) {
        trailingStopData = abi.encodePacked(
            user, token, amount, trailingPercent, activationPrice, "TRAILING_STOP_ORDER"
        );
    }
}

