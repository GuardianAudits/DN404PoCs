
// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseSetup} from "@chimera/BaseSetup.sol";
import {DN404} from "../../src/DN404.sol";
import {DN404Mirror} from "../../src/DN404Mirror.sol";
import {MockDN404CustomUnit} from "../utils/mocks/MockDN404CustomUnit.sol";
import {DN404Handler} from "../invariants/handlers/DN404Handler.sol";

abstract contract Setup is BaseSetup {

    MockDN404CustomUnit dn404;
    DN404Mirror dn404Mirror;
    DN404Handler dn404Handler;

    function setup() internal virtual override {

        dn404 = new MockDN404CustomUnit();
        dn404.setUnit(1e18);
        dn404Mirror = new DN404Mirror(address(this));
        dn404.initializeDN404(0, address(0), address(dn404Mirror));

        dn404Handler = new DN404Handler(dn404);

    }
}
