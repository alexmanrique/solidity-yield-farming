// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";


contract MockToken is ERC20, Ownable {

   constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply*10**decimals());
   }

   function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
   }

   function burn(uint256 amount) external {
        _burn(msg.sender, amount);
   }

}