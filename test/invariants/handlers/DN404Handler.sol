// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../utils/SoladyTest.sol";
import {MockDN404} from "../../utils/mocks/MockDN404.sol";
import {MockDN404CustomUnit} from "../../utils/mocks/MockDN404CustomUnit.sol";
import {DN404Mirror} from "../../../src/DN404Mirror.sol";
import {DN404} from "../../../src/DN404.sol";

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

    // Avoid stack-to-deep errors.
    struct BeforeAfter {
        uint256 fromBalanceBefore;
        uint256 toBalanceBefore;
        uint256 totalSupplyBefore;
        uint256 totalNFTSupplyBefore;
        uint256 fromNFTBalanceBefore;
        uint256 toNFTBalanceBefore;
        uint88 fromAuxBefore;
        uint88 toAuxBefore;
        uint256 fromBalanceAfter;
        uint256 toBalanceAfter;
        uint256 totalSupplyAfter;
        uint256 totalNFTSupplyAfter;
        uint256 fromNFTBalanceAfter;
        uint256 toNFTBalanceAfter;
        uint88 fromAuxAfter;
        uint88 toAuxAfter;
    }

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

    function approve(uint256 ownerIndexSeed, uint256 spenderIndexSeed, uint256 amount) public {
        // PRE-CONDITIONS
        address owner = randomAddress(ownerIndexSeed);
        address spender = randomAddress(spenderIndexSeed);
        uint88 ownerAuxBefore = dn404.getAux(owner);
        uint88 spenderAuxBefore = dn404.getAux(spender);

        if (owner == spender) return;

        // ACTION
        vm.startPrank(owner);
        dn404.approve(spender, amount);

        // POST-CONDITIONS
        uint88 ownerAuxAfter = dn404.getAux(owner);
        uint88 spenderAuxAfter = dn404.getAux(spender);

        assertEq(dn404.allowance(owner, spender), amount, "Allowance != Amount");
        // Assert auxiliary data is unchanged.
        assertEq(ownerAuxBefore, ownerAuxAfter, "owner auxiliary data has changed");
        assertEq(spenderAuxBefore, spenderAuxAfter, "spender auxiliary data has changed");
    }

    function transfer(uint256 fromIndexSeed, uint256 toIndexSeed, uint256 amount) public {
        // PRE-CONDITIONS
        address from = randomAddress(fromIndexSeed);
        address to = randomAddress(toIndexSeed);
        amount = _bound(amount, 0, dn404.balanceOf(from));
        vm.startPrank(from);

        BeforeAfter memory beforeAfter;
        beforeAfter.fromBalanceBefore = dn404.balanceOf(from);
        beforeAfter.toBalanceBefore = dn404.balanceOf(to);
        beforeAfter.totalSupplyBefore = dn404.totalSupply();
        beforeAfter.toAuxBefore = dn404.getAux(to);

        uint256 numNFTBurns = _zeroFloorSub(mirror.balanceOf(from), (beforeAfter.fromBalanceBefore - amount) / dn404.unit());
        uint256 numNFTMints = _zeroFloorSub((beforeAfter.toBalanceBefore + amount) / dn404.unit(), mirror.balanceOf(to));
        uint256 n = _min(mirror.balanceOf(from), _min(numNFTBurns, numNFTMints));
        uint256[] memory burnedIds = dn404.burnedPool();

        // ACTION
        vm.recordLogs();
        (bool success, ) = address(dn404).call(abi.encodeWithSelector(DN404.transfer.selector, to, amount));

        // POST-CONDITIONS
        if (success) {
            Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 id;
            for (uint256 i = 0; i < logs.length; i++) {
                if (i < logs.length && logs[i].topics[0] == keccak256("Transfer(address,address,uint256)")) {
                    // Grab minted ID from logs.
                    if (logs[i].topics.length > 3) id = uint256(logs[i].topics[3]);
                    if (n > 0 && from != to) {
                        for (uint j = 0; j < burnedIds.length; j++) {
                            // Assert direct transfers do not overlap with burned pool.
                            if (dn404.useDirectTransfersIfPossible() && i < n) assertNotEq(burnedIds[j], id, "transfer direct went over burned ids");
                        }
                    }
                    // Assert approval for id has been reset during transfer.
                    if(mirror.ownerAt(id) != address(0)) assertEq(mirror.getApproved(id), address(0));
                }
            }
        
            nftsOwned[from] -= _zeroFloorSub(nftsOwned[from], (beforeAfter.fromBalanceBefore - amount) / dn404.unit());
            if (!dn404.getSkipNFT(to)) {
                if (from == to) beforeAfter.toBalanceBefore -= amount;
                nftsOwned[to] += _zeroFloorSub((beforeAfter.toBalanceBefore + amount) / dn404.unit(), nftsOwned[to]);
            }

            beforeAfter.fromBalanceAfter = dn404.balanceOf(from);
            beforeAfter.toBalanceAfter = dn404.balanceOf(to);
            beforeAfter.totalSupplyAfter = dn404.totalSupply();
            beforeAfter.toAuxAfter = dn404.getAux(to);

            // Assert balance updates between addresses are valid.
            if (from != to) {
                assertEq(beforeAfter.fromBalanceAfter + amount, beforeAfter.fromBalanceBefore, "balance after + amount != balance before");
                assertEq(beforeAfter.toBalanceAfter, beforeAfter.toBalanceBefore + amount, "balance after != balance before + amount");
            }
            else {
                assertEq(beforeAfter.fromBalanceAfter, beforeAfter.fromBalanceBefore, "balance after != balance before");
            }
            
            // Assert totalSupply stays the same.
            assertEq(beforeAfter.totalSupplyBefore, beforeAfter.totalSupplyAfter, "total supply before != total supply after");
            // Assert auxiliary data is unchanged.
            assertEq(beforeAfter.toAuxBefore, beforeAfter.toAuxAfter, "auxiliary data has changed");
        }
    }

    function transferFrom(
        uint256 senderIndexSeed,
        uint256 fromIndexSeed,
        uint256 toIndexSeed,
        uint256 amount
    ) public {
        // PRE-CONDITIONS
        address sender = randomAddress(senderIndexSeed);
        address from = randomAddress(fromIndexSeed);
        address to = randomAddress(toIndexSeed);
        amount = _bound(amount, 0, dn404.balanceOf(from));
        vm.startPrank(sender);

        BeforeAfter memory beforeAfter;
        beforeAfter.fromBalanceBefore = dn404.balanceOf(from);
        beforeAfter.toBalanceBefore = dn404.balanceOf(to);
        beforeAfter.totalSupplyBefore = dn404.totalSupply();
        beforeAfter.toAuxBefore = dn404.getAux(to);

        uint256 numNFTBurns = _zeroFloorSub(mirror.balanceOf(from), (beforeAfter.fromBalanceBefore - amount) / dn404.unit());
        uint256 numNFTMints = _zeroFloorSub((beforeAfter.toBalanceBefore + amount) / dn404.unit(), mirror.balanceOf(to));
        uint256 n = _min(mirror.balanceOf(from), _min(numNFTBurns, numNFTMints));
        uint256[] memory burnedIds = dn404.burnedPool();

        if (dn404.allowance(from, sender) < amount) {
            sender = from;
            vm.startPrank(sender);
        }

        // ACTION
        vm.recordLogs();
        (bool success, ) = address(dn404).call(abi.encodeWithSelector(DN404.transferFrom.selector, from, to, amount));

        // POST-CONDITIONS
        if (success) {
            Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 id;
            for (uint256 i = 0; i < logs.length; i++) {
                if (i < logs.length && logs[i].topics[0] == keccak256("Transfer(address,address,uint256)")) {
                    // Grab minted ID from logs.
                    if (logs[i].topics.length > 3) id = uint256(logs[i].topics[3]);
                    if (n > 0 && from != to) {
                        for (uint j = 0; j < burnedIds.length; j++) {
                            // Assert direct transfers not overlap with burned pool.
                            if (dn404.useDirectTransfersIfPossible() && i < n) assertNotEq(burnedIds[j], id, "transfer direct went over burned ids");
                        }
                    }
                    // Assert approval for id has been reset during transfer.
                    if(mirror.ownerAt(id) != address(0)) assertEq(mirror.getApproved(id), address(0));
                }
            }

            nftsOwned[from] -= _zeroFloorSub(nftsOwned[from], (beforeAfter.fromBalanceBefore - amount) / dn404.unit());
            if (!dn404.getSkipNFT(to)) {
                if (from == to) beforeAfter.toBalanceBefore -= amount;
                nftsOwned[to] += _zeroFloorSub((beforeAfter.toBalanceBefore + amount) / dn404.unit(), nftsOwned[to]);
            }

            beforeAfter.fromBalanceAfter = dn404.balanceOf(from);
            beforeAfter.toBalanceAfter = dn404.balanceOf(to);
            beforeAfter.totalSupplyAfter = dn404.totalSupply();
            beforeAfter.toAuxAfter = dn404.getAux(to);

            // Assert balance updates between addresses are valid.
            if (from != to) {
                assertEq(beforeAfter.fromBalanceAfter + amount, beforeAfter.fromBalanceBefore, "balance after + amount != balance before");
                assertEq(dn404.balanceOf(to), beforeAfter.toBalanceBefore + amount, "balance after != balance before + amount");
            }
            else {
                assertEq(beforeAfter.fromBalanceAfter, beforeAfter.fromBalanceBefore, "balance after != balance before");
            }
            
            // Assert totalSupply stays the same.
            assertEq(beforeAfter.totalSupplyBefore, dn404.totalSupply(), "total supply before != total supply after");
            // Assert auxiliary data is unchanged.
            assertEq(beforeAfter.toAuxBefore, beforeAfter.toAuxAfter, "auxiliary data has changed");
        }
    }

    function mint(uint256 toIndexSeed, uint256 amount) public {
        // PRE-CONDITIONS
        address to = randomAddress(toIndexSeed);
        amount = _bound(amount, 0, 100e18);

        BeforeAfter memory beforeAfter;
        beforeAfter.toBalanceBefore = dn404.balanceOf(to);
        beforeAfter.totalSupplyBefore = dn404.totalSupply();
        beforeAfter.totalNFTSupplyBefore = mirror.totalSupply();
        beforeAfter.toNFTBalanceBefore = dn404.balanceOfNFT(to);
        beforeAfter.toAuxBefore = dn404.getAux(to);

        // ACTION
        vm.recordLogs();
        (bool success, ) = address(dn404).call(abi.encodeWithSelector(MockDN404.mint.selector, to, amount)); // mint(to, amount);

        // POST-CONDITIONS
        if (success) {
            beforeAfter.toBalanceAfter = dn404.balanceOf(to);
            beforeAfter.totalSupplyAfter = dn404.totalSupply();
            beforeAfter.totalNFTSupplyAfter = mirror.totalSupply();
            beforeAfter.toAuxAfter = dn404.getAux(to);

            Vm.Log[] memory logs = vm.getRecordedLogs();
            uint256 transferCounter;
            for (uint256 i = 0; i < logs.length; i++) {
                    if (i < logs.length && logs[i].topics[0] == keccak256("Transfer(address,address,uint256)")) {
                        transferCounter += 1;
                        assertEq(address(uint160(uint256(logs[i].topics[1]))), address(0), "from address does not match event");
                        assertEq(address(uint160(uint256(logs[i].topics[2]))), to, "to address does not match event");
                        if (logs[i].topics.length > 3) assertEq(mirror.ownerAt(uint256(logs[i].topics[3])), to, "to address does not own minted id");
                    }
            }
        
            if (!dn404.getSkipNFT(to)) {
                nftsOwned[to] = (beforeAfter.toBalanceBefore + amount) / dn404.unit();
                uint256[] memory tokensAfter = dn404.tokensOf(to);
                assertEq(tokensAfter.length, nftsOwned[to], "owned != len(tokensOf)");
                // Assert that number of (Transfer events - 1) should match the loop iterations to mint an NFT in `mint`.
                // Subtract by 1 because one of the Transfer events is for the ERC20 transfer.
                assertEq(transferCounter - 1, _zeroFloorSub((beforeAfter.toBalanceAfter / dn404.unit()), beforeAfter.toNFTBalanceBefore), "# of times transfer emitted != mint loop iterations");
            }   

            // Assert user balance increased by minted amount.
            assertEq(beforeAfter.toBalanceAfter, beforeAfter.toBalanceBefore + amount, "balance after != balance before + amount");
            // Assert totalSupply increased by minted amount.
            assertEq(beforeAfter.totalSupplyBefore + amount, beforeAfter.totalSupplyAfter, "supply after != supply before + amount");
            // Assert totalNFTSupply is at least equal to prior state before mint.
            assertGe(beforeAfter.totalNFTSupplyAfter, beforeAfter.totalNFTSupplyBefore, "nft supply after < nft supply before");
            // Assert auxiliary data is unchanged.
            assertEq(beforeAfter.toAuxBefore, beforeAfter.toAuxAfter, "auxiliary data has changed");
        }
    }

    function mintNext(uint256 toIndexSeed, uint256 amount) public {
        // PRE-CONDITIONS
        address to = randomAddress(toIndexSeed);
        amount = _bound(amount, 0, 100e18);

        BeforeAfter memory beforeAfter;
        beforeAfter.toBalanceBefore = dn404.balanceOf(to);
        beforeAfter.totalSupplyBefore = dn404.totalSupply();
        beforeAfter.totalNFTSupplyBefore = mirror.totalSupply();
        beforeAfter.toNFTBalanceBefore = dn404.balanceOfNFT(to);
        beforeAfter.toAuxBefore = dn404.getAux(to);

        // ACTION
        vm.recordLogs();
        dn404.mintNext(to, amount);
        
        // POST-CONDITIONS
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 transferCounter;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Transfer(address,address,uint256)")) {
                transferCounter += 1;
                assertEq(address(uint160(uint256(logs[i].topics[1]))), address(0), "from address does not match event");
                assertEq(address(uint160(uint256(logs[i].topics[2]))), to, "to address does not match event");
                if (logs[i].topics.length > 3) assertEq(mirror.ownerAt(uint256(logs[i].topics[3])), to, "to address does not own minted id");
            }
        }

        beforeAfter.toBalanceAfter = dn404.balanceOf(to);
        beforeAfter.totalSupplyAfter = dn404.totalSupply();
        beforeAfter.totalNFTSupplyAfter = mirror.totalSupply();
        beforeAfter.toAuxAfter = dn404.getAux(to);

        if (!dn404.getSkipNFT(to)) {
            nftsOwned[to] = (beforeAfter.toBalanceBefore + amount) / dn404.unit();
            uint256[] memory tokensAfter = dn404.tokensOf(to);
            assertEq(tokensAfter.length, nftsOwned[to], "owned != len(tokensOf)");
            assertEq(transferCounter - 1, _zeroFloorSub((beforeAfter.toBalanceAfter / dn404.unit()), beforeAfter.toNFTBalanceBefore), "# of times transfer emitted != mint loop iterations");
        }
        // If NFT was minted, ensure burned pool head and tail are 0.
        if (transferCounter > 1) {
            (uint256 head, uint256 tail) = dn404.burnedPoolHeadTail();
            assertTrue(head == 0 && tail == 0, "Head or Tail != 0");
        }

        // Assert user balance increased by minted amount.
        assertEq(beforeAfter.toBalanceAfter, beforeAfter.toBalanceBefore + amount, "balance after != balance before + amount");
        // Assert totalSupply increased by minted amount.
        assertEq(beforeAfter.totalSupplyBefore + amount, beforeAfter.totalSupplyAfter, "supply before +amount != supply after");
        // Assert totalNFTSupply is at least equal to prior state before mint.
        assertGe(beforeAfter.totalNFTSupplyAfter, beforeAfter.totalNFTSupplyBefore, "nft supply after < nft supply before");
        // Assert auxiliary data is unchanged.
        assertEq(beforeAfter.toAuxBefore, beforeAfter.toAuxAfter, "auxiliary data has changed");
    }

    function burn(uint256 fromIndexSeed, uint256 amount) public {
        // PRE-CONDITIONS
        address from = randomAddress(fromIndexSeed);
        vm.startPrank(from);
        amount = _bound(amount, 0, dn404.balanceOf(from));

        uint256 fromBalanceBefore = dn404.balanceOf(from);
        uint256 totalSupplyBefore = dn404.totalSupply();
        uint256 fromNFTBalanceBefore = mirror.balanceOf(from);
        uint256 totalNFTSupplyBefore = mirror.totalSupply();
        uint256 fromAuxBefore = dn404.getAux(from);

        // ACTION
        dn404.burn(from, amount);

        // POST-CONDITIONS
        uint256 numToBurn = _zeroFloorSub(nftsOwned[from], (fromBalanceBefore - amount) / dn404.unit());
        nftsOwned[from] -= numToBurn;

        uint256[] memory tokensAfter = dn404.tokensOf(from);
        uint256 totalSupplyAfter = dn404.totalSupply();
        uint256 fromNFTBalanceAfter = mirror.balanceOf(from);
        uint256 totalNFTSupplyAfter = mirror.totalSupply();
        uint256 fromAuxAfter = dn404.getAux(from);
        // Assert user tokensOf was reduced by numToBurn.
        assertEq(tokensAfter.length, nftsOwned[from], "owned != len(tokensOf)");
        // Assert totalSupply decreased by burned amount.
        assertEq(totalSupplyBefore, totalSupplyAfter + amount, "supply before != supply after + amount");
        // Assert NFT balance decreased by numToBurn.
        assertEq(fromNFTBalanceBefore, fromNFTBalanceAfter + numToBurn, "NFT balance did not decrease appropriately");
        // Assert totalNFTSupply is at most equal to prior state before mint.
        assertLe(totalNFTSupplyAfter, totalNFTSupplyBefore, "nft supply after > nft supply before");
        // Assert auxiliary data is unchanged.
        assertEq(fromAuxBefore, fromAuxAfter, "auxiliary data has changed");
    }

    function setSkipNFT(uint256 actorIndexSeed, bool status) public {
        // PRE-CONDITIONS
        address actor = randomAddress(actorIndexSeed);
        uint256 actorAuxBefore = dn404.getAux(actor);

        // ACTION
        vm.startPrank(actor);
        dn404.setSkipNFT(status);

        // POST-CONDITIONS
        bool isSkipNFT = dn404.getSkipNFT(actor);
        uint256 actorAuxAfter = dn404.getAux(actor);
        // Assert skipNFT status is appropriately set.
        assertEq(isSkipNFT, status, "isSKipNFT != status");
        // Assert auxiliary data is unchanged.
        assertEq(actorAuxBefore, actorAuxAfter, "auxiliary data has changed");
    }

    function approveNFT(uint256 ownerIndexSeed, uint256 spenderIndexSeed, uint256 id) public {
        // PRE-CONDITIONS
        address owner = randomAddress(ownerIndexSeed);
        address spender = randomAddress(spenderIndexSeed);

        if (mirror.ownerAt(id) == address(0)) return;
        if (mirror.ownerAt(id) != owner) {
            owner = mirror.ownerAt(id);
        }
        uint256 ownerAuxBefore = dn404.getAux(owner);
        uint256 spenderAuxBefore = dn404.getAux(spender);

        // ACTION
        vm.startPrank(owner);
        mirror.approve(spender, id);

        // POST-CONDITIONS
        address approvedSpenderMirror = mirror.getApproved(id);
        address approvedSpenderDN = dn404.getApproved(id);
        address ownerAfter = mirror.ownerAt(id);
        uint256 ownerAuxAfter = dn404.getAux(owner);
        uint256 spenderAuxAfter = dn404.getAux(spender);
        // Assert approved spender is requested spender.
        assertEq(approvedSpenderMirror, spender, "spender != approved spender mirror");
        assertEq(approvedSpenderDN, spender, "spender != approved spender DN");
        // Assert that owner of ID did not change.
        assertEq(owner, ownerAfter, "owner changed on approval");
        // Assert auxiliary data is unchanged.
        assertEq(ownerAuxBefore, ownerAuxAfter, "owner auxiliary data has changed");
        assertEq(spenderAuxBefore, spenderAuxAfter, "spender auxiliary data has changed");
    }

    function setApprovalForAll(uint256 ownerIndexSeed, uint256 spenderIndexSeed, uint256 id, bool approval)
        public
    {
        // PRE-CONDITIONS
        address owner = randomAddress(ownerIndexSeed);
        address spender = randomAddress(spenderIndexSeed);
        uint256 ownerAuxBefore = dn404.getAux(owner);
        uint256 spenderAuxBefore = dn404.getAux(spender);

        // ACTION
        vm.startPrank(owner);
        mirror.setApprovalForAll(spender, approval);

        // POST-CONDITIONS
        bool approvedForAll = mirror.isApprovedForAll(owner, spender);
        uint256 ownerAuxAfter = dn404.getAux(owner);
        uint256 spenderAuxAfter = dn404.getAux(spender);
        // Assert approval status is updated correctly.
        assertEq(approvedForAll, approval, "approved for all != approval");
        // Assert auxiliary data is unchanged.
        assertEq(ownerAuxBefore, ownerAuxAfter, "owner auxiliary data has changed");
        assertEq(spenderAuxBefore, spenderAuxAfter, "spender auxiliary data has changed");

    }

    function transferFromNFT(
        uint256 senderIndexSeed,
        uint256 fromIndexSeed,
        uint256 toIndexSeed,
        uint32 id
    ) public {
        // PRE-CONDITIONS
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

        BeforeAfter memory beforeAfter;
        beforeAfter.fromBalanceBefore = dn404.balanceOf(from);
        beforeAfter.toBalanceBefore = dn404.balanceOf(to);
        beforeAfter.totalNFTSupplyBefore = mirror.totalSupply();
        beforeAfter.fromAuxBefore = dn404.getAux(from);
        beforeAfter.toAuxBefore = dn404.getAux(to);

        // ACTION
        vm.startPrank(sender);
        mirror.transferFrom(from, to, id);

        // POST-CONDITIONS
        --nftsOwned[from];
        ++nftsOwned[to];

        uint256[] memory tokensFromAfter = dn404.tokensOf(from);
        uint256[] memory tokensToAfter = dn404.tokensOf(to);
        beforeAfter.fromBalanceAfter = dn404.balanceOf(from);
        beforeAfter.toBalanceAfter = dn404.balanceOf(to);
        beforeAfter.totalNFTSupplyAfter = mirror.totalSupply();
        beforeAfter.fromAuxAfter = dn404.getAux(from);
        beforeAfter.toAuxAfter = dn404.getAux(to);

        // Assert length matches internal tracking.
        assertEq(tokensFromAfter.length, nftsOwned[from], "Owned != len(tokensOfFrom)");
        assertEq(tokensToAfter.length, nftsOwned[to], "Owned != len(tokensOfTo)");
        // Assert token balances for `from` and `to` was updated.
        if (from != to) {
            assertEq(beforeAfter.fromBalanceBefore, beforeAfter.fromBalanceAfter + dn404.unit(), "before != after + unit");
            assertEq(beforeAfter.toBalanceAfter, beforeAfter.toBalanceBefore + dn404.unit(), "after != before + unit");
        }
        else {
            assertEq(beforeAfter.fromBalanceBefore, beforeAfter.fromBalanceAfter, "before != after");
            assertEq(beforeAfter.toBalanceAfter, beforeAfter.toBalanceBefore, "after != before");
        }
        // Assert `to` address owns the transferred NFT.
        assertEq(mirror.ownerAt(id), to, "to != ownerOf");
        // Assert totalNFTSupply is unchanged.
        assertEq(beforeAfter.totalNFTSupplyBefore, beforeAfter.totalNFTSupplyAfter, "total supply before != total supply after");
        // Assert that approval is reset on transfer.
        assertEq(mirror.getApproved(id), address(0));
        // Assert auxiliary data is unchanged.
        assertEq(beforeAfter.fromAuxBefore, beforeAfter.fromAuxAfter, "from auxiliary data has changed");
        assertEq(beforeAfter.toAuxBefore, beforeAfter.toAuxAfter, "to auxiliary data has changed");
    }

    function _zeroFloorSub(uint256 x, uint256 y) private pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }

    /// @dev Returns `x < y ? x : y`.
    function _min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            z := xor(x, mul(xor(x, y), lt(y, x)))
        }
    }

    function setUseExistsLookup(bool value) public {
       dn404.setUseExistsLookup(value);
    }

     function setUseDirectTransfersIfPossible(bool value) public {
        dn404.setUseDirectTransfersIfPossible(value);
    }

    function setAddToBurnedPool(bool value) public {
        dn404.setAddToBurnedPool(value);
    }

    function setUnit(uint256 value) public {
        value = _bound(value, 1e16, 1e20);
        dn404.setUnit(value);
    }

    function setAux(address target, uint88 value) public {
        dn404.setAux(target, value);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     POCS
    //////////////////////////////////////////////////////////////////////////*/

    function poc_mintnext_overlap_burned_ids_without_burn() internal {
        //  [FAIL. Reason: mint next went over burned ids: 13 == 13]
        // 	[Sequence]
        // 	sender=0x6c04248eEAd24C0a5327Da4857e085D599CADCbf addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=mint(uint256,uint256) args=[115792089237316195423570985008687907853269984665640564039457584007913129639934 [1.157e77], 15708559942556327919058285537 [1.57e28]]
        mint(115792089237316195423570985008687907853269984665640564039457584007913129639934, 42556327918744114339);
        // 	sender=0x000000c600000000000000000000000100000003 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=setAddToBurnedPool(bool) args=[true]
        setAddToBurnedPool(true);
        // 	sender=0x0000000000000000000000019689C70d4e933Ed5 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=transfer(uint256,uint256,uint256) args=[3613691728762 [3.613e12], 97416 [9.741e4], 48535295050378615425577907356361192661480127285716589363808434126849 [4.853e67]]
        transfer(3613691728762 , 97416 , 48535295050378615425577907356361192661480127285716589363808434126849);
        // 	sender=0x0000000000000000000000000000000000018158 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=mintNext(uint256,uint256) args=[109965082468 [1.099e11], 22859867009474803402833385750641289444944960863979897771692941901824 [2.285e67]]
        mintNext(109965082468, 22859867009474803402833385750641289444944960863979897771692941901824);
        //  invariantMirrorAndBaseRemainImmutable() (runs: 10315, calls: 103146, reverts: 1) 
    }

    function poc_owned_index_not_index() internal {
        //  [FAIL. Reason: revert: ownedIndex != i]
        //  [Sequence]
        //  sender=0x0000001A0000000200fffFfffffFFfFffffFFfff addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=mintNext(uint256,uint256) args=[811048 [8.11e5], 723531000577036798685916213594008081532211033450479617 [7.235e53]]
        mintNext(811048, 723531000577036798685916213594008081532211033450479617);
        //  sender=0x9f0A6745f074AccA55be333e1baa4c15C343335e addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=setAddToBurnedPool(bool) args=[true]
        setAddToBurnedPool(true);
        //  sender=0x0000000000000000000000000000000000083704 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=mint(uint256,uint256) args=[115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77], 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77]]
        mint(115792089237316195423570985008687907853269984665640564039457584007913129639935, 115792089237316195423570985008687907853269984665640564039457584007913129639935);
        //  sender=0x000000000000000000000000000000000000C304 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=burn(uint256,uint256) args=[930361141132617696600007231793931638960177866343637659138896228481 [9.303e65], 3092605490865279355099875312615797476301765343180589804646345 [3.092e60]]
        burn(930361141132617696600007231793931638960177866343637659138896228481, 3092605490865279355099875312615797476301765343180589804646345);
        //  sender=0x3C624f73Dac70934296cAB18f41303a8C29BFffb addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=approveNFT(uint256,uint256,uint256) args=[3, 37595224438518972901097519449128827215179 [3.759e40], 0]
        approveNFT(3, 37595224438518972901097519449128827215179, 0);
        //  sender=0x0000000000000000010000000000000000000001 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=mintNext(uint256,uint256) args=[224591879611914513246196655613176644196566470039175167 [2.245e53], 203305108264189912242559986334148991836622876980543488 [2.033e53]]
        mintNext(224591879611914513246196655613176644196566470039175167, 203305108264189912242559986334148991836622876980543488);
        //  sender=0xEAc0d0B96d4f8790F187439aBBCb80255a6aE2e7 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=mintNext(uint256,uint256) args=[1, 64760335289823728000213847395181035399356028 [6.476e43]]
        mintNext(1, 64760335289823728000213847395181035399356028);
        //  sender=0x0000000000000000000000000000000100000001 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=transferFrom(uint256,uint256,uint256,uint256) args=[91353182317495452320 [9.135e19], 3792478065 [3.792e9], 317868 [3.178e5], 1084136 [1.084e6]]
        transferFrom(91353182317495452320, 3792478065, 317868, 1084136);
        //  sender=0x000000000000000000000000000000000005b310 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=approveNFT(uint256,uint256,uint256) args=[1272559165939207953607506622486397 [1.272e33], 4557583612253692448658464381713338480089709506295375190769 [4.557e57], 115792089237316195423570985008687907853269984665640564039457584007913129639933 [1.157e77]]
        approveNFT(1272559165939207953607506622486397, 4557583612253692448658464381713338480089709506295375190769, 115792089237316195423570985008687907853269984665640564039457584007913129639933);
        //  sender=0x000000240000000102FfFffFFFFFffFFffFFFFFf addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=transferFromNFT(uint256,uint256,uint256,uint32) args=[115792089237316195423570985008687907853269984665640564039457584007913129639932 [1.157e77], 2, 0, 52063735 [5.206e7]]
        transferFromNFT(115792089237316195423570985008687907853269984665640564039457584007913129639932, 2, 0, 52063735);
        //  sender=0x0000000000000000000000000000000002b1bcAB addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=setApprovalForAll(uint256,uint256,uint256,bool) args=[8115095003376306228240655166834959053640252303729303656098547341719190957 [8.115e72], 49865171109948960495674332398227415025634 [4.986e40], 36911260965954574392165138108743385200777 [3.691e40], true]
        setApprovalForAll(8115095003376306228240655166834959053640252303729303656098547341719190957, 49865171109948960495674332398227415025634, 36911260965954574392165138108743385200777, true);
        //  sender=0x675c75301517D3832Cb0c2DcfDB3A46aFB54d80f addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=setUseExistsLookup(bool) args=[false]
        setUseExistsLookup(false);
        //  sender=0x00000000000000000000000000000000000139c4 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=mint(uint256,uint256) args=[3, 131816594966788261336111922731059090399600923988487938664410896425 [1.318e65]]
        mint(3, 131816594966788261336111922731059090399600923988487938664410896425);
        // invariantMirrorAndBaseRemainImmutable() (runs: 7441, calls: 111613, reverts: 1)
    }

    function poc_owned_does_not_match_internal() public {
//         [FAIL. Reason: owned != len(tokensOf): 22 != 0]
// 	[Sequence]
// 		sender=0x0000132500001324000013230000132200001322 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=mint(uint256,uint256) args=[1438766629005650134975100455840736710673155212971179553265908 [1.438e60], 381945484183744263816296001795312878460488748070619161957 [3.819e56]]
        mint(1438766629005650134975100455840736710673155212971179553265908, 381945484183744263816296001795312878460488748070619161957);
// 		sender=0x0000000100001561000000010000156000000001 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=setUnit(uint256) args=[1329]
        setUnit(1329);
// 		sender=0x0000000100000665000000010000066400000001 addr=[test/invariants/handlers/DN404Handler.sol:DN404Handler]0xF62849F9A0B5Bf2913b396098F7c7019b51A820a calldata=mint(uint256,uint256) args=[2, 35738316395000506422827 [3.573e22]]
        mint(2, 35738316395000506422827);
//  invariantDN404BalanceSum() (runs: 577, calls: 1731, reverts: 1)
    }
}
