# Upgradeable Token - Foundry Implementation
By Abhirup Banerjee

A comprehensive implementation of an upgradeable ERC20 token using the UUPS (Universal Upgradeable Proxy Standard) pattern, built with Foundry and OpenZeppelin contracts.

## Features

### V1 - Base Token
- **ERC20 Standard**: Full ERC20 implementation with mint, burn, and transfer
- **Access Control**: Owner-based access control with minter role management
- **Pausable**: Emergency pause functionality for all token operations
- **Supply Management**: Configurable maximum supply with mint restrictions
- **Burnable**: Token holders can burn their tokens

### V2 - Staking Features
- **Token Staking**: Stake tokens to earn rewards
- **Reward System**: Configurable APR-based reward distribution
- **Flexible Unstaking**: Unstake with automatic reward claiming
- **Reward Claims**: Claim rewards without unstaking
- **Time-based Restrictions**: Minimum staking duration enforcement

## Architecture

```
┌─────────────────┐         ┌──────────────────────┐
│                 │         │                      │
│   ERC1967Proxy  │────────▶│  UpgradeableToken    │
│                 │         │    (Implementation)  │
└─────────────────┘         └──────────────────────┘
        │                            │
        │                            │ upgrade
        │                            ▼
        │                   ┌──────────────────────┐
        └──────────────────▶│  UpgradeableTokenV2  │
                            │    (Implementation)  │
                            └──────────────────────┘
```

## Project Structure

```
upgradeable-token-foundry/
├── src/
│   ├── UpgradeableToken.sol      # V1 implementation
│   └── UpgradeableTokenV2.sol    # V2 implementation with staking
├── test/
│   ├── UpgradeableToken.t.sol    # V1 comprehensive tests
│   └── UpgradeableTokenUpgrade.t.sol # Upgrade and V2 tests
├── script/
│   ├── Deploy.s.sol               # Initial deployment script
│   ├── Upgrade.s.sol              # Upgrade to V2 script
│   └── Interact.s.sol            # Interaction utilities
├── foundry.toml                   # Foundry configuration
└── README.md                      # This file
```

## Installation

### Prerequisites
- [Foundry](https://getfoundry.sh/) installed
- Git

### Setup

1. Clone the repository:
```bash
git clone <your-repo-url>
cd upgradeable-token-foundry
```

2. Install dependencies:
```bash
forge install --no-git
```

3. Build the project:
```bash
forge build --no-git
```

## Testing

Run all tests:
```bash
forge test --no-git
```

Run tests with gas reporting:
```bash
forge test --gas-report --no-git
```

Run tests with coverage:
```bash
forge coverage --no-git
```

Run specific test files:
```bash
# Test V1 functionality
forge test --match-path test/UpgradeableToken.t.sol -vvv --no-git

# Test upgrade and V2 functionality
forge test --match-path test/UpgradeableTokenUpgrade.t.sol -vvv --no-git
```

Run fuzz tests with more runs:
```bash
forge test --fuzz-runs 10000 --no-git
```

## Deployment

### Local Development (Anvil)

1. Start local node:
```bash
anvil
```

2. Deploy in another terminal:
```bash
forge script script/Deploy.s.sol --rpc-url localhost --broadcast --no-git
```

### Testnet Deployment (Sepolia)

1. Set up environment variables:
```bash
export PRIVATE_KEY=<your-private-key>
export SEPOLIA_RPC_URL=<your-sepolia-rpc-url>
export ETHERSCAN_API_KEY=<your-etherscan-api-key>
export OWNER=<owner-address>
export TOKEN_NAME="MyToken"
export TOKEN_SYMBOL="MTK"
export MAX_SUPPLY=1000000000000000000000000  # 1M tokens
```

2. Deploy:
```bash
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv \
  --no-git
```

### Mainnet Deployment

Similar to testnet, but with extra caution:
```bash
forge script script/Deploy.s.sol \
  --rpc-url mainnet \
  --broadcast \
  --verify \
  --gas-estimate-multiplier 120 \
  --interactives 1 \
  --no-git
```

## Upgrading

### Upgrade to V2

1. Set proxy address:
```bash
export PROXY_ADDRESS=<deployed-proxy-address>
export REWARD_RATE=500  # 5% APR in basis points
export MIN_STAKING_DURATION=86400  # 1 day in seconds
```

2. Run upgrade script:
```bash
forge script script/Upgrade.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv \
  --no-git
```

## Interaction

### Using Cast Commands

Get token info:
```bash
cast call $PROXY_ADDRESS "name()" --rpc-url $RPC_URL
cast call $PROXY_ADDRESS "totalSupply()" --rpc-url $RPC_URL
```

Check balance:
```bash
cast call $PROXY_ADDRESS "balanceOf(address)" $USER_ADDRESS --rpc-url $RPC_URL
```

Mint tokens (as owner/minter):
```bash
cast send $PROXY_ADDRESS "mint(address,uint256)" $RECIPIENT $AMOUNT \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

### Using Interaction Scripts

Get token information:
```bash
forge script script/Interact.s.sol:InteractScript \
  --sig "getInfo(address)" $PROXY_ADDRESS \
  --rpc-url $RPC_URL \
  --no-git
```

Check account balance:
```bash
forge script script/Interact.s.sol:InteractScript \
  --sig "checkBalance(address,address)" $PROXY_ADDRESS $ACCOUNT \
  --rpc-url $RPC_URL \
  --no-git
```

Mint tokens:
```bash
forge script script/Interact.s.sol:InteractScript \
  --sig "mint(address,address,uint256)" $PROXY_ADDRESS $RECIPIENT $AMOUNT \
  --rpc-url $RPC_URL \
  --broadcast \
  --no-git
```

Stake tokens (V2 only):
```bash
forge script script/Interact.s.sol:InteractScript \
  --sig "stake(address,uint256)" $PROXY_ADDRESS $AMOUNT \
  --rpc-url $RPC_URL \
  --broadcast \
  --no-git
```

## Security Considerations

### UUPS Pattern
- Only the owner can authorize upgrades
- Implementation contracts are initialized to prevent takeover
- Proxy uses ERC1967 standard storage slots

### Access Control
- Owner-based access control for administrative functions
- Separate minter role for token minting
- Pausable functionality for emergency situations

### Staking Security (V2)
- Minimum staking duration prevents reward gaming
- Rewards calculated based on actual staking time
- Safe math operations (Solidity 0.8+)

### Best Practices
- Comprehensive test coverage including fuzz tests
- Events emitted for all state changes
- Input validation on all external functions
- Reentrancy protection where applicable

## Gas Optimization

The contracts are optimized for gas efficiency:
- Custom errors instead of require strings
- Efficient storage patterns using ERC7201
- Optimized loops and calculations
- Storage packing where possible

## Advanced Features

### Custom Storage Layout (ERC7201)
Both V1 and V2 use namespaced storage to prevent collisions:
```solidity
/// @custom:storage-location erc7201:upgradeabletoken.storage.v1
struct UpgradeableTokenStorage {
    uint256 maxSupply;
    mapping(address => bool) minters;
    uint256 version;
}
```

### Fuzz Testing
Comprehensive fuzz tests ensure robustness:
```solidity
function testFuzz_MintWithinMaxSupply(uint256 amount)
function testFuzz_Transfer(uint256 mintAmount, uint256 transferAmount)
function testFuzz_StakingRewards(uint256 stakeAmount, uint256 duration)
```

### Invariant Testing Support
The test suite supports invariant testing for protocol properties:
- Total supply never exceeds max supply
- Sum of balances equals total supply
- Staked tokens are properly accounted

## Troubleshooting

### Common Issues

1. **"Only owner can upgrade"**: Ensure you're using the owner's private key
2. **"Max supply exceeded"**: Check current total supply before minting
3. **"Staking duration not met"**: Wait for minimum duration before unstaking
4. **Compilation errors**: Ensure dependencies are installed with `forge install --no-git`

### Verification Issues

If contract verification fails:
```bash
forge verify-contract $CONTRACT_ADDRESS UpgradeableToken \
  --chain sepolia \
  --constructor-args $(cast abi-encode "constructor()") \
  --no-git
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new features
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Resources

- [OpenZeppelin Upgrades](https://docs.openzeppelin.com/contracts/5.x/upgradeable)
- [UUPS Pattern](https://eips.ethereum.org/EIPS/eip-1822)
- [ERC1967 Proxy Storage](https://eips.ethereum.org/EIPS/eip-1967)
- [Foundry Documentation](https://book.getfoundry.sh/)
- [ERC7201 Namespaced Storage](https://eips.ethereum.org/EIPS/eip-7201)

## Audit Recommendations

Before mainnet deployment:
1. Conduct thorough internal review
2. Run static analysis tools (Slither, Mythril)
3. Consider professional audit for high-value deployments
4. Test upgrade process on testnet multiple times
5. Implement time-locks for upgrades in production
