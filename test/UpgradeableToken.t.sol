// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {UpgradeableToken} from "../src/UpgradeableToken.sol";
import {UpgradeableTokenV2} from "../src/UpgradeableTokenV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeableTokenTest is Test {
    UpgradeableToken public implementation;
    ERC1967Proxy public proxy;
    UpgradeableToken public token;
    UpgradeableTokenV2 public tokenV2;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    string public constant NAME = "UpgradeableToken";
    string public constant SYMBOL = "UGT";
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10 ** 18;
    uint256 public constant INITIAL_MINT = 100_000 * 10 ** 18;

    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        // Deploy implementation
        implementation = new UpgradeableToken();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(
            UpgradeableToken.initialize.selector,
            NAME,
            SYMBOL,
            MAX_SUPPLY,
            owner
        );
        proxy = new ERC1967Proxy(address(implementation), initData);

        // Cast proxy to token interface
        token = UpgradeableToken(address(proxy));

        // Fund accounts
        vm.deal(owner, 10 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    function test_Initialization() public view {
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.maxSupply(), MAX_SUPPLY);
        assertEq(token.owner(), owner);
        assertTrue(token.isMinter(owner));
        assertEq(token.version(), 1);
        assertEq(token.totalSupply(), 0);
    }

    function test_RevertWhen_InitializedTwice() public {
        vm.expectRevert();
        token.initialize(NAME, SYMBOL, MAX_SUPPLY, owner);
    }

    function test_MintTokens() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), alice, INITIAL_MINT);

        token.mint(alice, INITIAL_MINT);

        assertEq(token.balanceOf(alice), INITIAL_MINT);
        assertEq(token.totalSupply(), INITIAL_MINT);

        vm.stopPrank();
    }

    function test_RevertWhen_NonMinterMints() public {
        vm.prank(alice);
        vm.expectRevert(UpgradeableToken.NotMinter.selector);
        token.mint(bob, 1000 * 10 ** 18);
    }

    function test_RevertWhen_MintExceedsMaxSupply() public {
        vm.prank(owner);
        vm.expectRevert(UpgradeableToken.MaxSupplyExceeded.selector);
        token.mint(alice, MAX_SUPPLY + 1);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(UpgradeableToken.InvalidAddress.selector);
        token.mint(address(0), 1000 * 10 ** 18);
    }

    function test_RevertWhen_MintZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(UpgradeableToken.InvalidAmount.selector);
        token.mint(alice, 0);
    }

    function test_AddMinter() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, false);
        emit MinterAdded(alice);

        token.addMinter(alice);
        assertTrue(token.isMinter(alice));

        vm.stopPrank();

        // Alice should now be able to mint
        vm.prank(alice);
        token.mint(bob, 1000 * 10 ** 18);
        assertEq(token.balanceOf(bob), 1000 * 10 ** 18);
    }

    function test_RemoveMinter() public {
        vm.startPrank(owner);

        token.addMinter(alice);
        assertTrue(token.isMinter(alice));

        vm.expectEmit(true, false, false, false);
        emit MinterRemoved(alice);

        token.removeMinter(alice);
        assertFalse(token.isMinter(alice));

        vm.stopPrank();

        // Alice should no longer be able to mint
        vm.prank(alice);
        vm.expectRevert(UpgradeableToken.NotMinter.selector);
        token.mint(bob, 1000 * 10 ** 18);
    }

    function test_RevertWhen_NonOwnerAddsMinter() public {
        vm.prank(alice);
        vm.expectRevert();
        token.addMinter(bob);
    }

    function test_UpdateMaxSupply() public {
        uint256 newMaxSupply = 2_000_000 * 10 ** 18;

        vm.startPrank(owner);

        vm.expectEmit(false, false, false, true);
        emit MaxSupplyUpdated(MAX_SUPPLY, newMaxSupply);

        token.updateMaxSupply(newMaxSupply);
        assertEq(token.maxSupply(), newMaxSupply);

        vm.stopPrank();
    }

    function test_RevertWhen_MaxSupplyBelowTotalSupply() public {
        vm.startPrank(owner);

        token.mint(alice, 500_000 * 10 ** 18);

        vm.expectRevert(UpgradeableToken.InvalidAmount.selector);
        token.updateMaxSupply(100_000 * 10 ** 18);

        vm.stopPrank();
    }

    function test_BurnTokens() public {
        vm.prank(owner);
        token.mint(alice, INITIAL_MINT);

        uint256 burnAmount = 10_000 * 10 ** 18;

        vm.prank(alice);
        token.burn(burnAmount);

        assertEq(token.balanceOf(alice), INITIAL_MINT - burnAmount);
        assertEq(token.totalSupply(), INITIAL_MINT - burnAmount);
    }

    function test_PauseAndUnpause() public {
        vm.startPrank(owner);

        token.mint(alice, INITIAL_MINT);

        vm.expectEmit(false, false, false, true);
        emit Paused(owner);
        token.pause();

        assertTrue(token.paused());

        vm.stopPrank();

        // Transfers should fail when paused
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1000 * 10 ** 18);

        // Unpause
        vm.startPrank(owner);

        vm.expectEmit(false, false, false, true);
        emit Unpaused(owner);
        token.unpause();

        assertFalse(token.paused());

        vm.stopPrank();

        // Transfers should work after unpause
        vm.prank(alice);
        token.transfer(bob, 1000 * 10 ** 18);
        assertEq(token.balanceOf(bob), 1000 * 10 ** 18);
    }

    function test_RevertWhen_NonOwnerPauses() public {
        vm.prank(alice);
        vm.expectRevert();
        token.pause();
    }

    function testFuzz_MintWithinMaxSupply(uint256 amount) public {
        amount = bound(amount, 1, MAX_SUPPLY);

        vm.prank(owner);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzz_Transfer(uint256 mintAmount, uint256 transferAmount, address recipient) public {
        vm.assume(recipient != address(0) && recipient != alice);
        mintAmount = bound(mintAmount, 1, MAX_SUPPLY);
        transferAmount = bound(transferAmount, 1, mintAmount);

        vm.prank(owner);
        token.mint(alice, mintAmount);

        vm.prank(alice);
        token.transfer(recipient, transferAmount);

        assertEq(token.balanceOf(alice), mintAmount - transferAmount);
        assertEq(token.balanceOf(recipient), transferAmount);
    }

    function testFuzz_BurnTokens(uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 1, MAX_SUPPLY);
        burnAmount = bound(burnAmount, 0, mintAmount);

        vm.prank(owner);
        token.mint(alice, mintAmount);

        vm.prank(alice);
        token.burn(burnAmount);

        assertEq(token.balanceOf(alice), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    function testFuzz_MultipleMinters(uint8 numMinters, uint256 mintAmount) public {
        numMinters = uint8(bound(numMinters, 1, 10));
        mintAmount = bound(mintAmount, 1, MAX_SUPPLY / numMinters);

        address[] memory minters = new address[](numMinters);

        vm.startPrank(owner);

        for (uint8 i = 0; i < numMinters; i++) {
            minters[i] = makeAddr(string(abi.encode("minter", i)));
            token.addMinter(minters[i]);
        }

        vm.stopPrank();

        for (uint8 i = 0; i < numMinters; i++) {
            vm.prank(minters[i]);
            token.mint(makeAddr(string(abi.encode("recipient", i))), mintAmount);
        }

        assertEq(token.totalSupply(), uint256(numMinters) * mintAmount);
    }
}