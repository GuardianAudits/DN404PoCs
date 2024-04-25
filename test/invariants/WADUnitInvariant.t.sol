// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "../utils/forge-std/Test.sol";
import {StdInvariant} from "../utils/forge-std/StdInvariant.sol";
import {DN404} from "../../src/DN404.sol";
import {DN404Mirror} from "../../src/DN404Mirror.sol";
import {MockDN404CustomUnit} from "../utils/mocks/MockDN404CustomUnit.sol";
import {DN404Handler} from "./handlers/DN404Handler.sol";
import {BaseInvariantTest} from "./BaseInvariant.t.sol";

// forgefmt: disable-start
/**************************************************************************************************************************************/
/*** Invariant Tests                                                                                                                ***/
/***************************************************************************************************************************************

    * NFT total supply * WAD must always be less than or equal to the ERC20 total supply
    * NFT balance of a user * WAD must be less than or equal to the ERC20 balance of that user
    * NFT balance of all users summed up must be equal to the NFT total supply
    * ERC20 balance of all users summed up must be equal to the ERC20 total supply
    * Mirror contract known to the base and the base contract known to the mirror never change after initialization

/**************************************************************************************************************************************/
/*** Vault Invariants                                                                                                               ***/
/**************************************************************************************************************************************/
// forgefmt: disable-end
contract WADUnitInvariant is BaseInvariantTest {

    function invariantTotalReflectionIsValid() external {
        assertLe(
            dn404Mirror.totalSupply() * _WAD,
            dn404.totalSupply(),
            "NFT total supply * wad is greater than ERC20 total supply"
        );
    }

    function invariantUserReflectionIsValid() external {
        assertLe(
            dn404Mirror.balanceOf(user0) * _WAD,
            dn404.balanceOf(user0),
            "NFT balanceOf user 0 * wad is greater its ERC20 balanceOf"
        );
        assertLe(
            dn404Mirror.balanceOf(user1) * _WAD,
            dn404.balanceOf(user1),
            "NFT balanceOf user 1 * wad is greater its ERC20 balanceOf"
        );
        assertLe(
            dn404Mirror.balanceOf(user2) * _WAD,
            dn404.balanceOf(user2),
            "NFT balanceOf user 2 * wad is greater its ERC20 balanceOf"
        );
        assertLe(
            dn404Mirror.balanceOf(user3) * _WAD,
            dn404.balanceOf(user3),
            "NFT balanceOf user 3 * wad is greater its ERC20 balanceOf"
        );
        assertLe(
            dn404Mirror.balanceOf(user4) * _WAD,
            dn404.balanceOf(user4),
            "NFT balanceOf user 4 * wad is greater its ERC20 balanceOf"
        );
        assertLe(
            dn404Mirror.balanceOf(user5) * _WAD,
            dn404.balanceOf(user5),
            "NFT balanceOf user 5 * wad is greater its ERC20 balanceOf"
        );
    }
}
