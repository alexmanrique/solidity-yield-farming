// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {SafeERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";


contract YieldFarmingPool is Ownable, ReentrancyGuard {

    constructor() {
       
    }

}