// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {UpgradeableToken} from "../src/UpgradeableToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() public returns (address proxy, address implementation) {
        // Load deployment parameters from environment
        address owner = vm.envOr("OWNER", msg.sender);
        string memory name = vm.envOr("TOKEN_NAME", string("UpgradeableToken"));
        string memory symbol = vm.envOr("TOKEN_SYMBOL", string("UGT"));
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", uint256(1_000_000 * 10 ** 18));

        console.log("========================================");
        console.log("Deploying UpgradeableToken");
        console.log("========================================");
        console.log("Owner:", owner);
        console.log("Name:", name);
        console.log("Symbol:", symbol);
        console.log("Max Supply:", maxSupply / 10 ** 18, "tokens");
        console.log("========================================");

        vm.startBroadcast();

        // Deploy implementation
        implementation = address(new UpgradeableToken());
        console.log("Implementation deployed to:", implementation);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            UpgradeableToken.initialize.selector,
            name,
            symbol,
            maxSupply,
            owner
        );

        // Deploy proxy
        proxy = address(new ERC1967Proxy(implementation, initData));
        console.log("Proxy deployed to:", proxy);

        // Cast to token interface for verification
        UpgradeableToken token = UpgradeableToken(proxy);

        // Verify deployment
        require(
            keccak256(bytes(token.name())) == keccak256(bytes(name)),
            "Name mismatch"
        );
        require(
            keccak256(bytes(token.symbol())) == keccak256(bytes(symbol)),
            "Symbol mismatch"
        );
        require(token.maxSupply() == maxSupply, "Max supply mismatch");
        require(token.owner() == owner, "Owner mismatch");
        require(token.isMinter(owner), "Owner is not minter");
        require(token.version() == 1, "Version mismatch");

        console.log("========================================");
        console.log("Deployment Successful!");
        console.log("Token Address (Proxy):", proxy);
        console.log("Implementation Address:", implementation);
        console.log("========================================");

        vm.stopBroadcast();

        // Save deployment addresses for upgrade script
        string memory deploymentData = string(
            abi.encodePacked(
                '{\n  "proxy": "',
                vm.toString(proxy),
                '",\n  "implementation": "',
                vm.toString(implementation),
                '",\n  "owner": "',
                vm.toString(owner),
                '",\n  "maxSupply": ',
                vm.toString(maxSupply),
                ',\n  "name": "',
                name,
                '",\n  "symbol": "',
                symbol,
                '"\n}'
            )
        );

        vm.writeFile("deployment.json", deploymentData);
        console.log("Deployment data saved to deployment.json");
    }
}