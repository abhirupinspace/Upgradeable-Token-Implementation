// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {UpgradeableToken} from "../src/UpgradeableToken.sol";
import {UpgradeableTokenV2} from "../src/UpgradeableTokenV2.sol";

contract InteractScript is Script {
    function mint(address proxy, address to, uint256 amount) public {
        console.log("Minting", amount / 10 ** 18, "tokens to", to);

        vm.startBroadcast();

        UpgradeableToken token = UpgradeableToken(proxy);
        token.mint(to, amount);

        vm.stopBroadcast();

        console.log("New balance:", token.balanceOf(to) / 10 ** 18);
        console.log("Total supply:", token.totalSupply() / 10 ** 18);
    }

    function addMinter(address proxy, address minter) public {
        console.log("Adding minter:", minter);

        vm.startBroadcast();

        UpgradeableToken token = UpgradeableToken(proxy);
        token.addMinter(minter);

        vm.stopBroadcast();

        console.log("Minter added successfully");
    }

    function stake(address proxy, uint256 amount) public {
        console.log("Staking", amount / 10 ** 18, "tokens");

        vm.startBroadcast();

        UpgradeableTokenV2 token = UpgradeableTokenV2(proxy);
        token.stake(amount);

        vm.stopBroadcast();

        console.log("Staked balance:", token.stakedBalanceOf(msg.sender) / 10 ** 18);
        console.log("Total staked:", token.totalStaked() / 10 ** 18);
    }

    function unstake(address proxy, uint256 amount) public {
        vm.startBroadcast();

        UpgradeableTokenV2 token = UpgradeableTokenV2(proxy);

        uint256 rewards = token.calculateRewards(msg.sender);
        console.log("Unstaking", amount / 10 ** 18, "tokens");
        console.log("Expected rewards:", rewards / 10 ** 18);

        token.unstake(amount);

        vm.stopBroadcast();

        console.log("New balance:", token.balanceOf(msg.sender) / 10 ** 18);
        console.log("Remaining staked:", token.stakedBalanceOf(msg.sender) / 10 ** 18);
    }

    function claimRewards(address proxy) public {
        vm.startBroadcast();

        UpgradeableTokenV2 token = UpgradeableTokenV2(proxy);

        uint256 rewards = token.calculateRewards(msg.sender);
        console.log("Claiming rewards:", rewards / 10 ** 18, "tokens");

        token.claimRewards();

        vm.stopBroadcast();

        console.log("New balance:", token.balanceOf(msg.sender) / 10 ** 18);
    }

    function getInfo(address proxy) public view {
        UpgradeableToken token = UpgradeableToken(proxy);

        console.log("========================================");
        console.log("Token Information");
        console.log("========================================");
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());
        console.log("Version:", token.version());
        console.log("Total Supply:", token.totalSupply() / 10 ** 18);
        console.log("Max Supply:", token.maxSupply() / 10 ** 18);
        console.log("Owner:", token.owner());
        console.log("Paused:", token.paused());

        // Try to get V2 info if available
        try UpgradeableTokenV2(proxy).rewardRate() returns (uint256 rate) {
            UpgradeableTokenV2 tokenV2 = UpgradeableTokenV2(proxy);
            console.log("========================================");
            console.log("V2 Staking Information");
            console.log("========================================");
            console.log("Reward Rate:", rate, "basis points");
            console.log("Min Staking Duration:", tokenV2.minStakingDuration() / 3600, "hours");
            console.log("Total Staked:", tokenV2.totalStaked() / 10 ** 18);
        } catch {
            console.log("(V2 features not available)");
        }
        console.log("========================================");
    }

    function checkBalance(address proxy, address account) public view {
        UpgradeableToken token = UpgradeableToken(proxy);

        console.log("========================================");
        console.log("Account:", account);
        console.log("Balance:", token.balanceOf(account) / 10 ** 18, token.symbol());

        // Try to get staking info if V2
        try UpgradeableTokenV2(proxy).stakedBalanceOf(account) returns (uint256 staked) {
            UpgradeableTokenV2 tokenV2 = UpgradeableTokenV2(proxy);
            console.log("Staked:", staked / 10 ** 18, token.symbol());
            console.log("Pending Rewards:", tokenV2.calculateRewards(account) / 10 ** 18, token.symbol());
        } catch {}
        console.log("========================================");
    }
}