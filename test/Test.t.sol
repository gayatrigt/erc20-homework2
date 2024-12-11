// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/StableCoin.sol";

contract StableCoinTest is Test {
    StableCoin public token;
    address owner;
    address alice;
    address bob;
    address mallory; // attacker

    function setUp() public {
        // Setup test addresses
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        mallory = makeAddr("mallory");

        // Deploy token
        token = new StableCoin();

        // Mint some tokens to alice
        token.mint(alice, 1000);
    }

    function test_FreezeBypass() public {
        // Initial setup - give approval before freeze
        vm.prank(alice);
        token.approve(mallory, 1000);

        // Owner freezes alice
        token.freeze(alice);

        // Verify alice is frozen
        assertTrue(token.isFrozen(alice));

        // But mallory can still transfer alice's tokens!
        vm.prank(mallory);
        bool success = token.transferFrom(alice, bob, 500);

        // Verify transfer worked despite freeze
        assertTrue(success);
        assertEq(token.balanceOf(bob), 500);
        assertEq(token.balanceOf(alice), 500);
    }

    function test_UnauthorizedBurn() public {
        // Verify initial balance
        assertEq(token.balanceOf(alice), 1000);

        // Mallory, who has no permission, can burn alice's tokens
        vm.prank(mallory);
        token.burn(alice, 1000);

        // Verify all of alice's tokens were burned
        assertEq(token.balanceOf(alice), 0);
    }
}
