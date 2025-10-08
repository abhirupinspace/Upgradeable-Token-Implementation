// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {UpgradeableToken} from "../src/UpgradeableToken.sol";
import {UpgradeableTokenV2} from "../src/UpgradeableTokenV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract UpgradeableTokenUpgradeTest is Test {
    UpgradeableToken public implementation;
    UpgradeableTokenV2 public implementationV2;
    ERC1967Proxy public proxy;
    UpgradeableToken public token;
    UpgradeableTokenV2 public tokenV2;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    string public constant NAME = "UpgradeableToken";
    string public constant SYMBOL = "UGT";
    uint256 public constant MAX_SUPPLY = 1_000_000 * 10 ** 18;
    uint256 public constant INITIAL_MINT = 100_000 * 10 ** 18;
    uint256 public constant REWARD_RATE = 500; // 5% APR
    uint256 public constant MIN_STAKING_DURATION = 1 days;

    event Upgraded(address indexed implementation);
    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 amount);

    function setUp() public {
        // Deploy V1 implementation
        implementation = new UpgradeableToken();

        // Deploy proxy with V1
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

        // Setup initial state
        vm.startPrank(owner);
        token.mint(alice, INITIAL_MINT);
        token.mint(bob, INITIAL_MINT);
        vm.stopPrank();
    }

    function test_UpgradeToV2() public {
        // Record state before upgrade
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 totalSupplyBefore = token.totalSupply();
        uint256 maxSupplyBefore = token.maxSupply();
        address ownerBefore = token.owner();

        // Deploy V2 implementation
        implementationV2 = new UpgradeableTokenV2();

        // Perform upgrade
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, false);
        emit Upgraded(address(implementationV2));

        token.upgradeToAndCall(address(implementationV2), "");

        // Reinitialize as V2
        tokenV2 = UpgradeableTokenV2(address(proxy));
        tokenV2.initializeV2(REWARD_RATE, MIN_STAKING_DURATION);

        vm.stopPrank();

        // Verify state preservation
        assertEq(tokenV2.balanceOf(alice), aliceBalanceBefore);
        assertEq(tokenV2.balanceOf(bob), bobBalanceBefore);
        assertEq(tokenV2.totalSupply(), totalSupplyBefore);
        assertEq(tokenV2.maxSupply(), maxSupplyBefore);
        assertEq(tokenV2.owner(), ownerBefore);
        assertEq(tokenV2.name(), NAME);
        assertEq(tokenV2.symbol(), SYMBOL);
        assertEq(tokenV2.version(), 2);

        // Verify new functionality
        assertEq(tokenV2.rewardRate(), REWARD_RATE);
        assertEq(tokenV2.minStakingDuration(), MIN_STAKING_DURATION);
        assertEq(tokenV2.totalStaked(), 0);
    }

    function test_StakingFunctionalityAfterUpgrade() public {
        // Upgrade to V2
        implementationV2 = new UpgradeableTokenV2();

        vm.startPrank(owner);
        token.upgradeToAndCall(address(implementationV2), "");
        tokenV2 = UpgradeableTokenV2(address(proxy));
        tokenV2.initializeV2(REWARD_RATE, MIN_STAKING_DURATION);
        vm.stopPrank();

        // Test staking
        uint256 stakeAmount = 10_000 * 10 ** 18;
        uint256 aliceBalanceBefore = tokenV2.balanceOf(alice);

        vm.startPrank(alice);

        // Approve and stake
        vm.expectEmit(true, false, false, true);
        emit TokensStaked(alice, stakeAmount);

        tokenV2.stake(stakeAmount);

        assertEq(tokenV2.balanceOf(alice), aliceBalanceBefore - stakeAmount);
        assertEq(tokenV2.stakedBalanceOf(alice), stakeAmount);
        assertEq(tokenV2.totalStaked(), stakeAmount);

        vm.stopPrank();
    }

    function test_UnstakingWithRewardsAfterUpgrade() public {
        // Upgrade to V2
        implementationV2 = new UpgradeableTokenV2();

        vm.startPrank(owner);
        token.upgradeToAndCall(address(implementationV2), "");
        tokenV2 = UpgradeableTokenV2(address(proxy));
        tokenV2.initializeV2(REWARD_RATE, MIN_STAKING_DURATION);
        vm.stopPrank();

        uint256 stakeAmount = 10_000 * 10 ** 18;

        // Alice stakes
        vm.prank(alice);
        tokenV2.stake(stakeAmount);

        // Fast forward time
        vm.warp(block.timestamp + MIN_STAKING_DURATION + 1);

        // Calculate expected rewards
        uint256 expectedRewards = tokenV2.calculateRewards(alice);
        assertTrue(expectedRewards > 0);

        // Unstake
        vm.prank(alice);
        tokenV2.unstake(stakeAmount);

        assertEq(tokenV2.stakedBalanceOf(alice), 0);
        assertEq(tokenV2.totalStaked(), 0);
        // Alice should have original balance plus rewards
        assertTrue(tokenV2.balanceOf(alice) > INITIAL_MINT);
    }

    function test_RevertWhen_UnstakeBeforeMinDuration() public {
        // Upgrade to V2
        implementationV2 = new UpgradeableTokenV2();

        vm.startPrank(owner);
        token.upgradeToAndCall(address(implementationV2), "");
        tokenV2 = UpgradeableTokenV2(address(proxy));
        tokenV2.initializeV2(REWARD_RATE, MIN_STAKING_DURATION);
        vm.stopPrank();

        uint256 stakeAmount = 10_000 * 10 ** 18;

        // Alice stakes
        vm.prank(alice);
        tokenV2.stake(stakeAmount);

        // Try to unstake immediately
        vm.prank(alice);
        vm.expectRevert(UpgradeableTokenV2.StakingDurationNotMet.selector);
        tokenV2.unstake(stakeAmount);
    }

    function test_ClaimRewardsWithoutUnstaking() public {
        // Upgrade to V2
        implementationV2 = new UpgradeableTokenV2();

        vm.startPrank(owner);
        token.upgradeToAndCall(address(implementationV2), "");
        tokenV2 = UpgradeableTokenV2(address(proxy));
        tokenV2.initializeV2(REWARD_RATE, MIN_STAKING_DURATION);
        vm.stopPrank();

        uint256 stakeAmount = 10_000 * 10 ** 18;

        // Alice stakes
        vm.prank(alice);
        tokenV2.stake(stakeAmount);

        uint256 balanceBeforeClaim = tokenV2.balanceOf(alice);

        // Fast forward time
        vm.warp(block.timestamp + 30 days);

        // Claim rewards
        uint256 expectedRewards = tokenV2.calculateRewards(alice);

        vm.expectEmit(true, false, false, true);
        emit RewardsClaimed(alice, expectedRewards);

        vm.prank(alice);
        tokenV2.claimRewards();

        // Staked balance should remain the same
        assertEq(tokenV2.stakedBalanceOf(alice), stakeAmount);
        // Balance should increase by rewards
        assertEq(tokenV2.balanceOf(alice), balanceBeforeClaim + expectedRewards);
    }

    function test_RevertWhen_NonOwnerUpgrades() public {
        implementationV2 = new UpgradeableTokenV2();

        vm.prank(alice);
        vm.expectRevert();
        token.upgradeToAndCall(address(implementationV2), "");
    }

    function test_OldFunctionalityWorksAfterUpgrade() public {
        // Upgrade to V2
        implementationV2 = new UpgradeableTokenV2();

        vm.startPrank(owner);
        token.upgradeToAndCall(address(implementationV2), "");
        tokenV2 = UpgradeableTokenV2(address(proxy));
        tokenV2.initializeV2(REWARD_RATE, MIN_STAKING_DURATION);

        // Test old functionality: minting
        tokenV2.mint(alice, 1000 * 10 ** 18);

        // Test old functionality: add minter
        tokenV2.addMinter(bob);
        assertTrue(tokenV2.isMinter(bob));

        // Test old functionality: pause
        tokenV2.pause();
        assertTrue(tokenV2.paused());

        tokenV2.unpause();
        assertFalse(tokenV2.paused());

        vm.stopPrank();

        // Test old functionality: transfer
        uint256 transferAmount = 500 * 10 ** 18;
        vm.prank(alice);
        tokenV2.transfer(bob, transferAmount);
    }

    function testFuzz_StakingRewards(uint256 stakeAmount, uint256 stakeDuration) public {
        stakeAmount = bound(stakeAmount, 1000, INITIAL_MINT);
        stakeDuration = bound(stakeDuration, MIN_STAKING_DURATION, 365 days);

        // Upgrade to V2
        implementationV2 = new UpgradeableTokenV2();

        vm.startPrank(owner);
        token.upgradeToAndCall(address(implementationV2), "");
        tokenV2 = UpgradeableTokenV2(address(proxy));
        tokenV2.initializeV2(REWARD_RATE, MIN_STAKING_DURATION);
        vm.stopPrank();

        // Stake
        vm.prank(alice);
        tokenV2.stake(stakeAmount);

        // Fast forward
        vm.warp(block.timestamp + stakeDuration);

        // Calculate and verify rewards
        uint256 rewards = tokenV2.calculateRewards(alice);
        uint256 expectedRewards = (stakeAmount * REWARD_RATE * stakeDuration) / (10000 * 365 days);

        // Allow small rounding difference
        assertApproxEqAbs(rewards, expectedRewards, 1000);

        // Unstake and verify
        vm.prank(alice);
        tokenV2.unstake(stakeAmount);

        assertEq(tokenV2.stakedBalanceOf(alice), 0);
    }

    function test_MultipleUsersStaking() public {
        // Upgrade to V2
        implementationV2 = new UpgradeableTokenV2();

        vm.startPrank(owner);
        token.upgradeToAndCall(address(implementationV2), "");
        tokenV2 = UpgradeableTokenV2(address(proxy));
        tokenV2.initializeV2(REWARD_RATE, MIN_STAKING_DURATION);
        vm.stopPrank();

        uint256 aliceStake = 10_000 * 10 ** 18;
        uint256 bobStake = 20_000 * 10 ** 18;

        // Both users stake
        vm.prank(alice);
        tokenV2.stake(aliceStake);

        vm.prank(bob);
        tokenV2.stake(bobStake);

        assertEq(tokenV2.totalStaked(), aliceStake + bobStake);
        assertEq(tokenV2.stakedBalanceOf(alice), aliceStake);
        assertEq(tokenV2.stakedBalanceOf(bob), bobStake);

        // Fast forward and check rewards
        vm.warp(block.timestamp + 30 days);

        uint256 aliceRewards = tokenV2.calculateRewards(alice);
        uint256 bobRewards = tokenV2.calculateRewards(bob);

        // Bob should have approximately 2x Alice's rewards
        assertApproxEqRel(bobRewards, aliceRewards * 2, 0.01e18);
    }
}