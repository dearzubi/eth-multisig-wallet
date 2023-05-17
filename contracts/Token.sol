// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ZZKT is ERC20 {
    
    constructor(uint _initSupply) ERC20("ZZKT", "ZZKT") {
        _mint(msg.sender, _initSupply * 10 ** uint(decimals()));
    }
}
