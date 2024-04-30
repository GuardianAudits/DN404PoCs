// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "../utils/forge-std/Test.sol";
import {StdInvariant} from "../utils/forge-std/StdInvariant.sol";
import {DN404} from "../../src/DN404.sol";
import {DN404Mirror} from "../../src/DN404Mirror.sol";
import {MockDN404CustomUnit} from "../utils/mocks/MockDN404CustomUnit.sol";
import {DN404Handler} from "./handlers/DN404Handler.sol";
import {StaticUnitInvariant} from "./StaticUnitInvariant.t.sol";

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
contract WADUnitInvariant is StaticUnitInvariant {

    function setUp() public virtual override {
        StaticUnitInvariant.setUp();
    }

    function _unit() internal override returns(uint256) {
        return 1e18;
    }

}
