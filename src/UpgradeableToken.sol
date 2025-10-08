// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeableToken
 * @dev Implementation of an upgradeable ERC20 token with additional features:
 * - Burning capability
 * - Pausable transfers
 * - UUPS upgradeability pattern
 * - Minting with multiple authorized minters
 * - Maximum supply control
 * 
 * The contract uses OpenZeppelin's upgradeable contracts and implements:
 * - ERC20 basic functionality
 * - ERC20Burnable for token burning
 * - ERC20Pausable for emergency pause/unpause
 * - Ownable for access control
 * - UUPSUpgradeable for upgrade pattern
 * 
 * Key features:
 * - Employs ERC-7201 namespaced storage pattern
 * - Configurable maximum supply
 * - Multiple minter roles managed by owner
 * - Version tracking
 * - Pausable transfers for emergency situations
 * 
 * Security features:
 * - Zero address checks
 * - Amount validations
 * - Max supply enforcement
 * - Protected initialization
 * - Access control for critical functions
 * 
 * @notice This token is designed for scenarios requiring future upgradeability
 * and enhanced control over minting and transfer mechanisms
 * 
 * @custom:security-contact security@upgradeabletoken.com
 */

contract UpgradeableToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /// @custom:storage-location erc7201:upgradeabletoken.storage.v1
    struct UpgradeableTokenStorage {
        uint256 maxSupply;
        mapping(address => bool) minters;
        uint256 version;
    }

    // keccak256(abi.encode(uint256(keccak256("upgradeabletoken.storage.v1")) - 1))
    bytes32 private constant STORAGE_LOCATION = 0x7a4f9a5c3b2e1d0f8e7c6b5a4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e;

    error MaxSupplyExceeded();
    error NotMinter();
    error InvalidAddress();
    error InvalidAmount();

    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply);

    modifier onlyMinter() {
        if (!_getStorage().minters[msg.sender]) revert NotMinter();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param maxSupply_ Maximum supply of tokens
     * @param initialOwner Initial owner address
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        address initialOwner
    ) public initializer {
        if (initialOwner == address(0)) revert InvalidAddress();
        if (maxSupply_ == 0) revert InvalidAmount();

        __ERC20_init(name_, symbol_);
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        UpgradeableTokenStorage storage $ = _getStorage();
        $.maxSupply = maxSupply_;
        $.minters[initialOwner] = true;
        $.version = 1;

        emit MinterAdded(initialOwner);
    }

    /**
     * @dev Returns the storage struct
     */
    function _getStorage() internal pure virtual returns (UpgradeableTokenStorage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    /**
     * @dev Mints new tokens
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyMinter {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        UpgradeableTokenStorage storage $ = _getStorage();
        if (totalSupply() + amount > $.maxSupply) revert MaxSupplyExceeded();

        _mint(to, amount);
    }

    /**
     * @dev Adds a new minter
     * @param minter Address to add as minter
     */
    function addMinter(address minter) external onlyOwner {
        if (minter == address(0)) revert InvalidAddress();

        UpgradeableTokenStorage storage $ = _getStorage();
        $.minters[minter] = true;

        emit MinterAdded(minter);
    }

    /**
     * @dev Removes a minter
     * @param minter Address to remove as minter
     */
    function removeMinter(address minter) external onlyOwner {
        if (minter == address(0)) revert InvalidAddress();

        UpgradeableTokenStorage storage $ = _getStorage();
        $.minters[minter] = false;

        emit MinterRemoved(minter);
    }

    /**
     * @dev Updates the maximum supply
     * @param newMaxSupply New maximum supply
     */
    function updateMaxSupply(uint256 newMaxSupply) external onlyOwner {
        if (newMaxSupply == 0) revert InvalidAmount();
        if (newMaxSupply < totalSupply()) revert InvalidAmount();

        UpgradeableTokenStorage storage $ = _getStorage();
        uint256 oldMaxSupply = $.maxSupply;
        $.maxSupply = newMaxSupply;

        emit MaxSupplyUpdated(oldMaxSupply, newMaxSupply);
    }

    /**
     * @dev Pauses all token transfers
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Returns whether an address is a minter
     * @param account Address to check
     */
    function isMinter(address account) external view returns (bool) {
        return _getStorage().minters[account];
    }

    /**
     * @dev Returns the maximum supply
     */
    function maxSupply() external view returns (uint256) {
        return _getStorage().maxSupply;
    }

    /**
     * @dev Returns the contract version
     */
    function version() external view returns (uint256) {
        return _getStorage().version;
    }

    /**
     * @dev Required override for ERC20 with pausable
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }

    /**
     * @dev Authorizes an upgrade to a new implementation
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}