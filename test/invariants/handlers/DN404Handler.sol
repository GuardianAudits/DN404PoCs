// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../utils/SoladyTest.sol";
import {MockDN404} from "../../utils/mocks/MockDN404.sol";
import {MockDN404CustomUnit} from "../../utils/mocks/MockDN404CustomUnit.sol";
import {DN404Mirror} from "../../../src/DN404Mirror.sol";
import {DN404} from "../../../src/DN404.sol";
import "test/utils/forge-std/console.sol";

contract DN404Handler is SoladyTest {
    uint256 private constant _WAD = 1000000000000000000;
    uint256 private constant START_SLOT =
        0x0000000000000000000000000000000000000000000000a20d6e21d0e5255308;
    uint8 internal constant _ADDRESS_DATA_SKIP_NFT_FLAG = 1 << 1;

    MockDN404CustomUnit dn404;
    DN404Mirror mirror;

    address user0 = vm.addr(uint256(keccak256("User0")));
    address user1 = vm.addr(uint256(keccak256("User1")));
    address user2 = vm.addr(uint256(keccak256("User2")));
    address user3 = vm.addr(uint256(keccak256("User3")));
    address user4 = vm.addr(uint256(keccak256("User4")));
    address user5 = vm.addr(uint256(keccak256("User5")));

    address[6] actors;

    mapping(address => uint256) public nftsOwned;

    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    constructor(MockDN404CustomUnit _dn404) {
        dn404 = _dn404;
        mirror = DN404Mirror(payable(dn404.mirrorERC721()));

        actors[0] = user0;
        actors[1] = user1;
        actors[2] = user2;
        actors[3] = user3;
        actors[4] = user4;
        actors[5] = user5;

        vm.prank(user0);
        dn404.approve(user0, type(uint256).max);

        vm.prank(user1);
        dn404.approve(user1, type(uint256).max);

        vm.prank(user2);
        dn404.approve(user2, type(uint256).max);

        vm.prank(user3);
        dn404.approve(user3, type(uint256).max);

        vm.prank(user4);
        dn404.approve(user4, type(uint256).max);

        vm.prank(user5);
        dn404.approve(user5, type(uint256).max);
    }

    function randomAddress(uint256 seed) private view returns (address) {
        return actors[_bound(seed, 0, actors.length - 1)];
    }

    function approve(uint256 ownerIndexSeed, uint256 spenderIndexSeed, uint256 amount) external {
        // PRE-CONDITIONS
        address owner = randomAddress(ownerIndexSeed);
        address spender = randomAddress(spenderIndexSeed);

        if (owner == spender) return;

        // ACTION
        vm.startPrank(owner);
        dn404.approve(spender, amount);

        // POST-CONDITIONS
        assertEq(dn404.allowance(owner, spender), amount, "Allowance != Amount");
    }

    function transfer(uint256 fromIndexSeed, uint256 toIndexSeed, uint256 amount) external {
        // PRE-CONDITIONS
        address from = randomAddress(fromIndexSeed);
        address to = randomAddress(toIndexSeed);
        amount = _bound(amount, 0, dn404.balanceOf(from));
        vm.startPrank(from);

        uint256 fromBalanceBefore = dn404.balanceOf(from);
        uint256 toBalanceBefore = dn404.balanceOf(to);
        uint256 totalSupplyBefore = dn404.totalSupply();

        // ACTION
        dn404.transfer(to, amount);

        // POST-CONDITIONS
        uint256 fromNFTPreOwned = nftsOwned[from];

        nftsOwned[from] -= _zeroFloorSub(fromNFTPreOwned, (fromBalanceBefore - amount) / _WAD);
        if (!dn404.getSkipNFT(to)) {
            if (from == to) toBalanceBefore -= amount;
            nftsOwned[to] += _zeroFloorSub((toBalanceBefore + amount) / _WAD, nftsOwned[to]);
        }

        uint256 fromBalanceAfter = dn404.balanceOf(from);
        uint256 toBalanceAfter = dn404.balanceOf(to);
        uint256 totalSupplyAfter = dn404.totalSupply();

        // Assert balance updates between addresses are valid.
        if (from != to) {
            assertEq(fromBalanceAfter + amount, fromBalanceBefore, "balance after + amount != balance before");
            assertEq(toBalanceAfter, toBalanceBefore + amount, "balance After != balance Before + amount");
        }
        else {
            assertEq(fromBalanceAfter, fromBalanceBefore, "balance after != balance before");
        }
        
        // Assert totalSupply stays the same.
        assertEq(totalSupplyBefore, totalSupplyAfter, "total supply before != total supply after");
    }

    function transferFrom(
        uint256 senderIndexSeed,
        uint256 fromIndexSeed,
        uint256 toIndexSeed,
        uint256 amount
    ) external {
        // PRE-CONDITIONS
        address sender = randomAddress(senderIndexSeed);
        address from = randomAddress(fromIndexSeed);
        address to = randomAddress(toIndexSeed);
        amount = _bound(amount, 0, dn404.balanceOf(from));
        vm.startPrank(sender);

        uint256 fromBalanceBefore = dn404.balanceOf(from);
        uint256 toBalanceBefore = dn404.balanceOf(to);
        uint256 totalSupplyBefore = dn404.totalSupply();

        if (dn404.allowance(from, sender) < amount) {
            sender = from;
            vm.startPrank(sender);
        }

        // ACTION
        dn404.transferFrom(from, to, amount);

        // POST-CONDITIONS
        uint256 fromNFTPreOwned = nftsOwned[from];

        nftsOwned[from] -= _zeroFloorSub(fromNFTPreOwned, (fromBalanceBefore - amount) / _WAD);
        if (!dn404.getSkipNFT(to)) {
            if (from == to) toBalanceBefore -= amount;
            nftsOwned[to] += _zeroFloorSub((toBalanceBefore + amount) / _WAD, nftsOwned[to]);
        }

        uint256 fromBalanceAfter = dn404.balanceOf(from);
        uint256 toBalanceAfter = dn404.balanceOf(to);
        uint256 totalSupplyAfter = dn404.totalSupply();

        // Assert balance updates between addresses are valid.
        if (from != to) {
            assertEq(fromBalanceAfter + amount, fromBalanceBefore, "balance after + amount != balance before");
            assertEq(toBalanceAfter, toBalanceBefore + amount, "balance After != balance Before + amount");
        }
        else {
            assertEq(fromBalanceAfter, fromBalanceBefore, "balance after != balance before");
        }
        
        // Assert totalSupply stays the same.
        assertEq(totalSupplyBefore, totalSupplyAfter, "total supply before != total supply after");
    }

    function mint(uint256 toIndexSeed, uint256 amount) external {
        // PRE-CONDITIONS
        address to = randomAddress(toIndexSeed);
        amount = _bound(amount, 0, 100e18);

        uint256 toBalanceBefore = dn404.balanceOf(to);
         uint256 totalSupplyBefore = dn404.totalSupply();

        // ACTION
        dn404.mint(to, amount);

        // POST-CONDITIONS
        if (!dn404.getSkipNFT(to)) {
            nftsOwned[to] = (toBalanceBefore + amount) / _WAD;
            uint256[] memory tokensAfter = dn404.tokensOf(to);
            assertEq(tokensAfter.length, nftsOwned[to], "owned != len(tokensOf)");
        }

        uint256 toBalanceAfter = dn404.balanceOf(to);
        uint256 totalSupplyAfter = dn404.totalSupply();
        // Assert user balance increased by minted amount.
        assertEq(toBalanceAfter, toBalanceBefore + amount, "balance after != balance before + amount");
        // Assert totalSupply increased by minted amount.
        assertEq(totalSupplyBefore + amount, totalSupplyAfter, "supply after != supply before + amount");
    }

    function burn(uint256 fromIndexSeed, uint256 amount) external {
        address from = randomAddress(fromIndexSeed);
        vm.startPrank(from);
        amount = _bound(amount, 0, dn404.balanceOf(from));

        uint256 fromBalanceBefore = dn404.balanceOf(from);

        dn404.burn(from, amount);

        nftsOwned[from] -= _zeroFloorSub(nftsOwned[from], (fromBalanceBefore - amount) / _WAD);
    }

    function setSkipNFT(uint256 actorIndexSeed, bool status) external {
        vm.startPrank(randomAddress(actorIndexSeed));
        dn404.setSkipNFT(status);
    }

    function approveNFT(uint256 ownerIndexSeed, uint256 spenderIndexSeed, uint256 id) external {
        address owner = randomAddress(ownerIndexSeed);
        address spender = randomAddress(spenderIndexSeed);

        if (mirror.ownerAt(id) != address(0)) return;
        if (mirror.ownerAt(id) != owner) {
            owner = mirror.ownerAt(id);
        }

        vm.startPrank(owner);
        mirror.approve(spender, id);
    }

    function setApprovalForAll(uint256 ownerIndexSeed, uint256 spenderIndexSeed, uint256 id)
        external
    {
        address owner = randomAddress(ownerIndexSeed);
        address spender = randomAddress(spenderIndexSeed);

        if (mirror.ownerAt(id) != address(0)) return;
        if (mirror.ownerAt(id) != owner) {
            owner = mirror.ownerAt(id);
        }

        vm.startPrank(owner);
        mirror.approve(spender, id);
    }

    function transferFromNFT(
        uint256 senderIndexSeed,
        uint256 fromIndexSeed,
        uint256 toIndexSeed,
        uint32 id
    ) external {
        address sender = randomAddress(senderIndexSeed);
        address from = randomAddress(fromIndexSeed);
        address to = randomAddress(toIndexSeed);

        if (mirror.ownerAt(id) == address(0)) return;
        if (mirror.getApproved(id) != sender || mirror.isApprovedForAll(from, sender)) {
            sender = from;
        }
        if (mirror.ownerAt(id) != from) {
            from = mirror.ownerAt(id);
            sender = from;
        }

        vm.startPrank(sender);

        mirror.transferFrom(from, to, id);

        --nftsOwned[from];
        ++nftsOwned[to];
    }

    function _zeroFloorSub(uint256 x, uint256 y) private pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }
}
