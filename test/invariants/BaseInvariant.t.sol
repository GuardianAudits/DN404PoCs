// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "../utils/forge-std/Test.sol";
import {StdInvariant} from "../utils/forge-std/StdInvariant.sol";
import {DN404} from "../../src/DN404.sol";
import {DN404Mirror} from "../../src/DN404Mirror.sol";
import {MockDN404CustomUnit} from "../utils/mocks/MockDN404CustomUnit.sol";
import {DN404Handler} from "./handlers/DN404Handler.sol";

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
contract BaseInvariantTest is Test, StdInvariant {
    address user0 = vm.addr(uint256(keccak256("User0")));
    address user1 = vm.addr(uint256(keccak256("User1")));
    address user2 = vm.addr(uint256(keccak256("User2")));
    address user3 = vm.addr(uint256(keccak256("User3")));
    address user4 = vm.addr(uint256(keccak256("User4")));
    address user5 = vm.addr(uint256(keccak256("User5")));
    address[] users = [user0, user1, user2, user3, user4, user5];

    uint256 internal constant _WAD = 1000000000000000000;

    MockDN404CustomUnit dn404;
    DN404Mirror dn404Mirror;
    DN404Handler dn404Handler;

    function setUp() public virtual {
        dn404 = new MockDN404CustomUnit();
        dn404.setUnit(10 ** 18);
        dn404Mirror = new DN404Mirror(address(this));
        dn404.initializeDN404(0, address(0), address(dn404Mirror));

        dn404Handler = new DN404Handler(dn404);

        vm.label(address(dn404), "dn404");
        vm.label(address(dn404Mirror), "dn404Mirror");
        vm.label(address(dn404Handler), "dn404Handler");

        // target handlers
        targetContract(address(dn404Handler));
    }

    function invariantMirror721BalanceSum() external {
        uint256 total = dn404Handler.nftsOwned(user0) + dn404Handler.nftsOwned(user1)
            + dn404Handler.nftsOwned(user2) + dn404Handler.nftsOwned(user3)
            + dn404Handler.nftsOwned(user4) + dn404Handler.nftsOwned(user5);
        assertEq(total, dn404Mirror.totalSupply(), "all users nfts owned exceed nft total supply");
    }

    function invariantDN404BalanceSum() external {
        uint256 total = dn404.balanceOf(user0) + dn404.balanceOf(user1) + dn404.balanceOf(user2)
            + dn404.balanceOf(user3) + dn404.balanceOf(user4) + dn404.balanceOf(user5);
        assertEq(dn404.totalSupply(), total, "all users erc20 balance exceed erc20 total supply");
    }

    function invariantMirrorAndBaseRemainImmutable() external {
        assertEq(
            dn404.mirrorERC721(), address(dn404Mirror), "mirror 721 changed after initialization"
        );
        assertEq(dn404Mirror.baseERC20(), address(dn404), "base erc20 changed after initialization");
    }

    function invariantBurnedPoolLengthIsTailMinusHead() external {
        (uint256 burnedHead, uint256 burnedTail) = dn404.burnedPoolHeadTail();
        uint256[] memory burnedIds = dn404.burnedPoolIds();
        assertEq(burnedIds.length, burnedTail - burnedHead, "burned ids length != burned tail - burned head");
    }
}
