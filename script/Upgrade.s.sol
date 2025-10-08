// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {UpgradeableToken} from "../src/UpgradeableToken.sol";
import {UpgradeableTokenV2} from "../src/UpgradeableTokenV2.sol";

contract UpgradeScript is Script {
    function run() public returns (address newImplementation) {
        // Load proxy address from environment or deployment file
        address proxy = vm.envAddress("PROXY_ADDRESS");
        uint256 rewardRate = vm.envOr("REWARD_RATE", uint256(500)); // 5% APR default
        uint256 minStakingDuration = vm.envOr("MIN_STAKING_DURATION", uint256(1 days));

        console.log("========================================");
        console.log("Upgrading UpgradeableToken to V2");
        console.log("========================================");
        console.log("Proxy Address:", proxy);
        console.log("Reward Rate:", rewardRate, "basis points");
        console.log("Min Staking Duration:", minStakingDuration / 3600, "hours");
        console.log("========================================");

        // Cast proxy to current token interface
        UpgradeableToken tokenV1 = UpgradeableToken(proxy);

        // Verify we're the owner
        require(
            tokenV1.owner() == msg.sender,
            "Only owner can upgrade"
        );

        // Record state before upgrade
        uint256 totalSupplyBefore = tokenV1.totalSupply();
        uint256 maxSupplyBefore = tokenV1.maxSupply();
        uint256 versionBefore = tokenV1.version();
        string memory nameBefore = tokenV1.name();
        string memory symbolBefore = tokenV1.symbol();

        console.log("Current State:");
        console.log("  Version:", versionBefore);
        console.log("  Total Supply:", totalSupplyBefore / 10 ** 18, "tokens");
        console.log("  Max Supply:", maxSupplyBefore / 10 ** 18, "tokens");

        vm.startBroadcast();

        // Deploy new implementation
        newImplementation = address(new UpgradeableTokenV2());
        console.log("New implementation deployed to:", newImplementation);

        // Perform upgrade
        tokenV1.upgradeToAndCall(newImplementation, "");
        console.log("Proxy upgraded to new implementation");

        // Cast to V2 interface
        UpgradeableTokenV2 tokenV2 = UpgradeableTokenV2(proxy);

        // Initialize V2 features
        tokenV2.initializeV2(rewardRate, minStakingDuration);
        console.log("V2 features initialized");

        // Verify upgrade
        require(tokenV2.version() == 2, "Version not updated");
        require(tokenV2.totalSupply() == totalSupplyBefore, "Total supply changed");
        require(tokenV2.maxSupply() == maxSupplyBefore, "Max supply changed");
        require(
            keccak256(bytes(tokenV2.name())) == keccak256(bytes(nameBefore)),
            "Name changed"
        );
        require(
            keccak256(bytes(tokenV2.symbol())) == keccak256(bytes(symbolBefore)),
            "Symbol changed"
        );
        require(tokenV2.rewardRate() == rewardRate, "Reward rate not set");
        require(
            tokenV2.minStakingDuration() == minStakingDuration,
            "Min staking duration not set"
        );

        vm.stopBroadcast();

        console.log("========================================");
        console.log("Upgrade Successful!");
        console.log("New Implementation:", newImplementation);
        console.log("New Version:", tokenV2.version());
        console.log("Staking Features Enabled:");
        console.log("  Reward Rate:", tokenV2.rewardRate(), "basis points");
        console.log("  Min Staking Duration:", tokenV2.minStakingDuration() / 3600, "hours");
        console.log("========================================");

        // Save upgrade data
        string memory upgradeData = string(
            abi.encodePacked(
                '{\n  "proxy": "',
                vm.toString(proxy),
                '",\n  "implementationV1": "',
                vm.toString(address(0)), // Would need to read from previous deployment
                '",\n  "implementationV2": "',
                vm.toString(newImplementation),
                '",\n  "version": 2,\n  "rewardRate": ',
                vm.toString(rewardRate),
                ',\n  "minStakingDuration": ',
                vm.toString(minStakingDuration),
                '\n}'
            )
        );

        vm.writeFile("upgrade-v2.json", upgradeData);
        console.log("Upgrade data saved to upgrade-v2.json");
    }
}