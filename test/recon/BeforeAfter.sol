
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";

abstract contract BeforeAfter is Setup {

    struct Vars {
        uint256 tokenBalance;
    }

    Vars internal _before;
    Vars internal _after;

    function __before(address actor) internal {
        _before.tokenBalance = dn404.balanceOf(actor);
    }

    function __after(address actor) internal {
        _after.tokenBalance = dn404.balanceOf(actor);
    }
}
