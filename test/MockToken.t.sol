// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "../lib/forge-std/src/Test.sol";
import {MockToken} from "../src/MockToken.sol";

contract MockTokenTest is Test {
    MockToken public mockToken;
    address public user1;
    uint256 amount = 1000000000000000000000000;

    function setUp() public {
        mockToken = new MockToken("Mock Token", "MT", 1000000000000000000000000);
        user1 = makeAddr("user1");
    }

    function testMint() public {
        mockToken.mint(user1, amount);
        assertEq(mockToken.balanceOf(user1), amount);
    }

    function testBurn() public {
        mockToken.mint(user1, amount);
        vm.startPrank(user1);
        mockToken.burn(amount);
        vm.stopPrank();
        assertEq(mockToken.balanceOf(user1), 0);
    }
}
