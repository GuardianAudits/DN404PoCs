// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "../utils/forge-std/Test.sol";
import {StdInvariant} from "../utils/forge-std/StdInvariant.sol";
import {DN404} from "../../src/DN404.sol";
import {DN404Mirror} from "../../src/DN404Mirror.sol";
import {MockDN404CustomUnit} from "../utils/mocks/MockDN404CustomUnit.sol";
import {DN404Handler} from "./handlers/DN404Handler.sol";
import {BaseInvariantTest} from "./BaseInvariant.t.sol";

/// @dev Invariant tests that modify the unit throughout execution with `setUnit`.
/// @notice This will currently display reverts as the handler's nftsOwned must be adjusted for dynamic units.
contract VariableUnitInvariant is BaseInvariantTest {

    function setUp() public virtual override {
        BaseInvariantTest.setUp();

        // Selectors to target.
        // Currently excluding `mintNext`.
        bytes4[] memory selectors = new bytes4[](13);
        selectors[0] = DN404Handler.approve.selector;
        selectors[1] = DN404Handler.transfer.selector;
        selectors[2] = DN404Handler.transferFrom.selector;
        selectors[3] = DN404Handler.mint.selector;
        selectors[4] = DN404Handler.burn.selector;
        selectors[5] = DN404Handler.setSkipNFT.selector;
        selectors[6] = DN404Handler.approveNFT.selector;
        selectors[7] = DN404Handler.setApprovalForAll.selector;
        selectors[8] = DN404Handler.transferFromNFT.selector;
        selectors[9] = DN404Handler.setUseExistsLookup.selector;
        selectors[10] = DN404Handler.setUseDirectTransfersIfPossible.selector;
        selectors[11] = DN404Handler.setAddToBurnedPool.selector;
        selectors[12] = DN404Handler.setUnit.selector; // Allow for dynamic unit.
        targetSelector(FuzzSelector({addr: address(dn404Handler), selectors: selectors}));
    }

    // Sets the initial unit and then will be modified on the DN404 contract during the run.
    function _unit() internal override returns(uint256) {
        return 1e18;
    }

}
