// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "../utils/forge-std/Test.sol";
import {StdInvariant} from "../utils/forge-std/StdInvariant.sol";
import {DN404} from "../../src/DN404.sol";
import {DN404Mirror} from "../../src/DN404Mirror.sol";
import {MockDN404CustomUnit} from "../utils/mocks/MockDN404CustomUnit.sol";
import {DN404Handler} from "./handlers/DN404Handler.sol";
import {BaseInvariantTest} from "./BaseInvariant.t.sol";

/// @notice Common invariant test setup for invariants that do not modify the unit post-initialization.
abstract contract StaticUnitInvariant is BaseInvariantTest {

    function setUp() public virtual override {
        BaseInvariantTest.setUp();

        // Selectors to target.
        // Currently excluding `mintNext` and `setUnit`.
        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = DN404Handler.approve.selector;
        selectors[1] = DN404Handler.transfer.selector;
        selectors[2] = DN404Handler.transferFrom.selector;
        selectors[3] = DN404Handler.mint.selector;
        selectors[4] = DN404Handler.burn.selector;
        selectors[5] = DN404Handler.setSkipNFT.selector;
        selectors[6] = DN404Handler.approveNFT.selector;
        selectors[7] = DN404Handler.setApprovalForAll.selector;
        selectors[8] = DN404Handler.transferFromNFT.selector;
        selectors[9] = DN404Handler.setUseDirectTransfersIfPossible.selector;
        selectors[10] = DN404Handler.setAddToBurnedPool.selector;
        selectors[11] = DN404Handler.setAux.selector;
        targetSelector(FuzzSelector({addr: address(dn404Handler), selectors: selectors}));
    }

}
