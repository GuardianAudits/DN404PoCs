
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "./BeforeAfter.sol";
import {Properties} from "./Properties.sol";
import {vm} from "@chimera/Hevm.sol";

abstract contract TargetFunctions is BaseTargetFunctions, Properties, BeforeAfter {

    function mint(uint256 amount) public {
        amount = between(amount, 0, 100e18);
        __before(msg.sender);
        dn404.mint(msg.sender, amount);
        __after(msg.sender);

        t(_after.tokenBalance >_before.tokenBalance, "Balance did not increase");
    }


}
