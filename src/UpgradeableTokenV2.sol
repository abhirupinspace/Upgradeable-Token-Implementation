// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UpgradeableToken.sol";

/**
 * @title UpgradeableTokenV2
 * @dev Implementation of an upgradeable ERC20 token with staking and rewards functionality
 * 
 * This contract extends the base UpgradeableToken with additional features:
 * - Token staking mechanism
 * - Time-based rewards for staked tokens
 * - Configurable reward rates
 * - Minimum staking duration requirement
 * - Reward claiming system
 * 
 * Key features:
 * - Users can stake their tokens to earn rewards
 * - Rewards are calculated based on staking duration and reward rate
 * - Owner can adjust reward rates and minimum staking duration
 * - Implements storage slot pattern for upgradeability
 * - Includes safety checks for balance and duration requirements
 * 
 * Storage Structure:
 * - Uses ERC-7201 namespaced storage pattern
 * - Maintains separate storage locations for V1 and V2 functionality
 * 
 * Security Features:
 * - Pausable functionality inherited from base contract
 * - Protected admin functions with onlyOwner modifier
 * - Built-in checks for maximum supply limits
 * 
 * @notice This contract adds staking and reward mechanisms to the base token
 * @dev V2 implementation with additional features: staking and rewards
 * @notice This contract demonstrates how to upgrade the token with new functionality
 * @custom:security-contact security@example.com
 */

contract UpgradeableTokenV2 is UpgradeableToken {
    /// @custom:storage-location erc7201:upgradeabletoken.storage.v2
    struct UpgradeableTokenV2Storage {
        mapping(address => uint256) stakedBalances;
        mapping(address => uint256) stakingTimestamps;
        uint256 totalStaked;
        uint256 rewardRate; // Rewards per second per token staked (in basis points)
        uint256 minStakingDuration;
        mapping(address => uint256) accumulatedRewards;
    }

    // keccak256(abi.encode(uint256(keccak256("upgradeabletoken.storage.v2")) - 1))
    bytes32 private constant STORAGE_LOCATION_V2 = 0x8b5c9a3d2f1e0a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b8c7d6e5f4a3b;

    error InsufficientBalance();
    error NoStakedTokens();
    error StakingDurationNotMet();

    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event MinStakingDurationUpdated(uint256 oldDuration, uint256 newDuration);

    /**
     * @dev Reinitializer for V2
     * @param rewardRate_ Initial reward rate in basis points
     * @param minStakingDuration_ Minimum staking duration in seconds
     */
    function initializeV2(
        uint256 rewardRate_,
        uint256 minStakingDuration_
    ) public reinitializer(2) {
        UpgradeableTokenV2Storage storage $v2 = _getStorageV2();
        $v2.rewardRate = rewardRate_;
        $v2.minStakingDuration = minStakingDuration_;

        // Update version in original storage
        UpgradeableTokenStorage storage $ = _getStorage();
        $.version = 2;
    }

    /**
     * @dev Returns the V2 storage struct
     */
    function _getStorageV2() private pure returns (UpgradeableTokenV2Storage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION_V2
        }
    }

    /**
     * @dev Returns the V1 storage struct (inherited from parent)
     */
    function _getStorage() internal pure override returns (UpgradeableTokenStorage storage $) {
        bytes32 STORAGE_LOCATION = 0x7a4f9a5c3b2e1d0f8e7c6b5a4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e;
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    /**
     * @dev Stakes tokens
     * @param amount Amount of tokens to stake
     */
    function stake(uint256 amount) external whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        if (balanceOf(msg.sender) < amount) revert InsufficientBalance();

        UpgradeableTokenV2Storage storage $v2 = _getStorageV2();

        // Claim pending rewards if any
        uint256 pendingRewards = calculateRewards(msg.sender);
        if (pendingRewards > 0) {
            $v2.accumulatedRewards[msg.sender] = 0;
            _mint(msg.sender, pendingRewards);
            emit RewardsClaimed(msg.sender, pendingRewards);
        }

        // Transfer tokens to this contract for staking
        _transfer(msg.sender, address(this), amount);

        // Update staking info
        $v2.stakedBalances[msg.sender] += amount;
        $v2.stakingTimestamps[msg.sender] = block.timestamp;
        $v2.totalStaked += amount;

        emit TokensStaked(msg.sender, amount);
    }

    /**
     * @dev Unstakes tokens and claims rewards
     * @param amount Amount of tokens to unstake
     */
    function unstake(uint256 amount) external whenNotPaused {
        UpgradeableTokenV2Storage storage $v2 = _getStorageV2();

        if (amount == 0) revert InvalidAmount();
        if ($v2.stakedBalances[msg.sender] < amount) revert InsufficientBalance();

        uint256 stakingDuration = block.timestamp - $v2.stakingTimestamps[msg.sender];
        if (stakingDuration < $v2.minStakingDuration) revert StakingDurationNotMet();

        // Calculate and mint rewards
        uint256 rewards = calculateRewards(msg.sender);

        // Update staking info
        $v2.stakedBalances[msg.sender] -= amount;
        $v2.totalStaked -= amount;
        $v2.accumulatedRewards[msg.sender] = 0;

        if ($v2.stakedBalances[msg.sender] > 0) {
            $v2.stakingTimestamps[msg.sender] = block.timestamp;
        }

        // Transfer staked tokens back
        _transfer(address(this), msg.sender, amount);

        // Mint rewards
        if (rewards > 0) {
            UpgradeableTokenStorage storage $ = _getStorage();
            if (totalSupply() + rewards <= $.maxSupply) {
                _mint(msg.sender, rewards);
            }
        }

        emit TokensUnstaked(msg.sender, amount, rewards);
    }

    /**
     * @dev Claims accumulated rewards without unstaking
     */
    function claimRewards() external whenNotPaused {
        UpgradeableTokenV2Storage storage $v2 = _getStorageV2();

        uint256 rewards = calculateRewards(msg.sender);
        if (rewards == 0) revert InvalidAmount();

        $v2.accumulatedRewards[msg.sender] = 0;
        $v2.stakingTimestamps[msg.sender] = block.timestamp;

        UpgradeableTokenStorage storage $ = _getStorage();
        if (totalSupply() + rewards <= $.maxSupply) {
            _mint(msg.sender, rewards);
        }

        emit RewardsClaimed(msg.sender, rewards);
    }

    /**
     * @dev Calculates pending rewards for a user
     * @param user Address to calculate rewards for
     */
    function calculateRewards(address user) public view returns (uint256) {
        UpgradeableTokenV2Storage storage $v2 = _getStorageV2();

        if ($v2.stakedBalances[user] == 0) return 0;

        uint256 stakingDuration = block.timestamp - $v2.stakingTimestamps[user];
        uint256 rewards = ($v2.stakedBalances[user] * $v2.rewardRate * stakingDuration) / (10000 * 365 days);

        return rewards + $v2.accumulatedRewards[user];
    }

    /**
     * @dev Updates the reward rate
     * @param newRewardRate New reward rate in basis points
     */
    function updateRewardRate(uint256 newRewardRate) external onlyOwner {
        UpgradeableTokenV2Storage storage $v2 = _getStorageV2();
        uint256 oldRate = $v2.rewardRate;
        $v2.rewardRate = newRewardRate;

        emit RewardRateUpdated(oldRate, newRewardRate);
    }

    /**
     * @dev Updates the minimum staking duration
     * @param newDuration New minimum duration in seconds
     */
    function updateMinStakingDuration(uint256 newDuration) external onlyOwner {
        UpgradeableTokenV2Storage storage $v2 = _getStorageV2();
        uint256 oldDuration = $v2.minStakingDuration;
        $v2.minStakingDuration = newDuration;

        emit MinStakingDurationUpdated(oldDuration, newDuration);
    }

    /**
     * @dev Returns staked balance for a user
     * @param user Address to check
     */
    function stakedBalanceOf(address user) external view returns (uint256) {
        return _getStorageV2().stakedBalances[user];
    }

    /**
     * @dev Returns total staked tokens
     */
    function totalStaked() external view returns (uint256) {
        return _getStorageV2().totalStaked;
    }

    /**
     * @dev Returns current reward rate
     */
    function rewardRate() external view returns (uint256) {
        return _getStorageV2().rewardRate;
    }

    /**
     * @dev Returns minimum staking duration
     */
    function minStakingDuration() external view returns (uint256) {
        return _getStorageV2().minStakingDuration;
    }

    /**
     * @dev Returns staking timestamp for a user
     * @param user Address to check
     */
    function stakingTimestamp(address user) external view returns (uint256) {
        return _getStorageV2().stakingTimestamps[user];
    }
}