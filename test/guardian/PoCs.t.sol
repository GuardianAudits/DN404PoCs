// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../utils/SoladyTest.sol";
import {DN404Mirror} from "../../src/DN404Mirror.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {LibSort} from "solady/utils/LibSort.sol";
import {MintNextDN404} from "../../src/example/MintNextDN404.sol";
import "../utils/forge-std/console.sol";

library DN404MirrorTransferEmitter {
    event Transfer(address indexed from, address indexed to, uint256 indexed id);

    function emitTransfer(address from, address to, uint256 id) internal {
        emit Transfer(from, to, id);
    }
}

contract GuardianPoCs is SoladyTest {
    uint256 private constant _WAD = 1000000000000000000;

    address private constant _PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    MintNextDN404 dn;
    DN404Mirror mirror;

    address owner = address(111);
    address alice = address(222);
    address bob = address(333);
    address dummy = address(444);

    event SkipNFTSet(address indexed target, bool status);

    function setUp() public {
        vm.prank(owner);
        dn = new MintNextDN404("DN", "DN", 10e18, owner);
        mirror = new DN404Mirror(address(this));
    }

    function test_steal_reminted_nft() public {
        // Transfer from the owner to alice to mint initial NFTs
        vm.prank(owner);
        dn.transfer(alice, 10e18);

        // NFT supply should be now 10
        (bool success, bytes memory data) = address(dn).call(abi.encodeWithSelector(0xe2c79281)); // `totalNFTSupply()`.
        require(success);

        uint256 nftSupply = abi.decode(data, (uint256));

        assertTrue(nftSupply == 10);

        // burn some of the initial tokens, the burn pool is now populated
        vm.prank(owner);
        dn.burn(alice, 1e18);

        (uint256 head, uint256 tail) = dn.getBurnedPool();

        assertTrue(head == 0);
        assertTrue(tail == 1);

        // now mint next and mint nft ids that belong to the burn pool
        vm.prank(owner);
        dn.mintNext(bob, 1e18);

        // Bob owns token with id 10
        (success, data) = address(dn).call(abi.encodeWithSelector(0x6352211e, 10)); // `ownerOf(uint256)`.
        require(success);

        address ownerOfTen = abi.decode(data, (address));

        vm.assertTrue(ownerOfTen == bob);

        // now a normal mint will overwrite the owner of the previously minted nft
        // Bob's nft has been stolen
        vm.prank(owner);
        dn.mint(alice, 1e18);

        (success, data) = address(dn).call(abi.encodeWithSelector(0x6352211e, 10)); // `ownerOf(uint256)`.
        require(success);

        ownerOfTen = abi.decode(data, (address));

        vm.assertTrue(ownerOfTen == alice);
    }

}