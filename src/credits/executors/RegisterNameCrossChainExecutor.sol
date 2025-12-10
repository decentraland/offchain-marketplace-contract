// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IAggregator} from "src/marketplace/interfaces/IAggregator.sol";
import {AggregatorHelper} from "src/marketplace/AggregatorHelper.sol";

/// @title RegisterNameCrossChainExecutor
/// @notice Contract that executes cross-chain name registrations using the Coral contract
/// @dev This contract validates and executes external calls to register names cross-chain, ensuring proper MANA fee limits
contract RegisterNameCrossChainExecutor is AccessControl, Pausable, ReentrancyGuard, AggregatorHelper {
    using SafeERC20 for IERC20;

    /// @notice The role that can pause the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice The fixed price in MANA for registering a name (100 MANA).
    uint256 public constant NAME_PRICE = 100 ether;

    /// @notice The address of the credits manager contract.
    address public immutable creditsManager;

    /// @notice The address of the MANA token.
    IERC20 public immutable mana;

    /// @notice The address of the Coral contract used for cross-chain execution.
    address public immutable coral;

    /// @notice The MANA/USD Chainlink aggregator.
    /// @dev Used to obtain the rate of MANA expressed in USD.
    IAggregator public immutable manaUSDAggregator;

    /// @notice Maximum time (in seconds) since the MANA/USD aggregator result was last updated before it is considered outdated.
    uint256 public immutable manaUSDAggregatorTolerance;

    /// @notice Maximum USD amount that can be paid in MANA for the transaction fee.
    /// @dev Expressed in USD with 18 decimals (e.g., 1000000000000000000 = $1.00).
    uint256 public maxUSDFee;

    /// @notice Struct containing the parameters for an external call to be executed.
    /// @param target The contract address of the external call.
    /// @param data The calldata for the external call (without the selector).
    /// @param extra Additional data containing the MANA fee amount needed for the transaction in Ethereum (abi.encoded).
    struct ExternalCall {
        address target;
        bytes data;
        bytes extra;
    }

    event Executed(ExternalCall _externalCall);
    event ERC20Withdrawn(address indexed _sender, address indexed _token, uint256 _amount, address indexed _to);
    event ERC721Withdrawn(address indexed _sender, address indexed _token, uint256 indexed _tokenId, address _to);
    event MaxUSDFeeUpdated(uint256 _maxUSDFee);

    error Unauthorized(address _sender);
    error InvalidTarget();
    error MANAforFeeExceeded();
    error ExecutionFailed(ExternalCall _externalCall);

    /// @notice Initializes the RegisterNameCrossChainExecutor contract.
    /// @param _owner The owner of the contract who will have DEFAULT_ADMIN_ROLE.
    /// @param _creditsManager The address of the credits manager contract.
    /// @param _mana The address of the MANA token contract.
    /// @param _coral The address of the Coral contract for cross-chain execution.
    /// @param _maxUSDFee The maximum USD amount (in 18 decimals) that can be paid in MANA for the fee.
    /// @param _manaUSDAggregator The address of the MANA/USD price aggregator.
    /// @param _manaUSDAggregatorTolerance The tolerance (in seconds) that indicates if the result provided by the aggregator is old.
    constructor(
        address _owner,
        address _creditsManager,
        IERC20 _mana,
        address _coral,
        uint256 _maxUSDFee,
        address _manaUSDAggregator,
        uint256 _manaUSDAggregatorTolerance
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        creditsManager = _creditsManager;
        mana = _mana;
        coral = _coral;
        manaUSDAggregator = IAggregator(_manaUSDAggregator);
        manaUSDAggregatorTolerance = _manaUSDAggregatorTolerance;

        _updateMaxUSDFee(_maxUSDFee);
    }

    /// @notice Executes a cross-chain name registration call through the Coral contract.
    /// @dev Can only be called by the credits manager. Validates the fee, transfers MANA, and executes the call.
    /// @param _args The external call parameters including target, selector, data, MANA fee, and expiration.
    function execute(ExternalCall calldata _args) external nonReentrant whenNotPaused {
        // Get the sender of the transaction.
        // Defined here to prevent calling _msgSender() multiple times for this transaction.
        address sender = _msgSender();

        // Validate that the sender is the credits manager.
        if (sender != creditsManager) {
            revert Unauthorized(sender);
        }

        // Validate that the target is the coral contract.
        if (_args.target != coral) {
            revert InvalidTarget();
        }

        // Validate that the MANA fee is not greater than the maximum allowed.
        (uint256 manaFee) = abi.decode(_args.extra, (uint256));
        _validateMANAFee(manaFee);

        // Transfer the name price in MANA to the contract from the credits manager.
        mana.transferFrom(creditsManager, address(this), NAME_PRICE);
        // Approve the MANA tokens to the coral contract for the total amount of the MANA fee plus the name price.
        mana.forceApprove(coral, manaFee + NAME_PRICE);

        // Execute the external call.
        (bool success, bytes memory returnData) = _args.target.call(_args.data);

        if (!success) {
            // Bubble up the revert reason if present
            if (returnData.length > 0) {
                assembly {
                    // The first 32 bytes of the bytes data is its length
                    let returnDataSize := mload(returnData)
                    // Move the pointer 32 bytes to ignore the length of the bytes data,
                    // Revert with the actual error message.
                    revert(add(32, returnData), returnDataSize)
                }
            } else {
                // No revert reason, use generic error
                revert ExecutionFailed(_args);
            }
        }

        // Reset the approval of the MANA tokens to the coral contract.
        mana.forceApprove(coral, 0);

        emit Executed(_args);
    }

    /// @notice Withdraw ERC20 tokens from the contract.
    /// @dev Only the owner can withdraw ERC20 tokens from the contract.
    /// @param _token The address of the ERC20 token.
    /// @param _amount The amount of ERC20 tokens to withdraw.
    /// @param _to The address to send the ERC20 tokens to.
    function withdrawERC20(address _token, uint256 _amount, address _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(_token).safeTransfer(_to, _amount);

        emit ERC20Withdrawn(_msgSender(), _token, _amount, _to);
    }

    /// @notice Withdraw ERC721 tokens from the contract.
    /// @dev Only the owner can withdraw ERC721 tokens from the contract.
    /// @param _token The address of the ERC721 token.
    /// @param _tokenId The ID of the ERC721 token.
    /// @param _to The address to send the ERC721 token to.
    function withdrawERC721(address _token, uint256 _tokenId, address _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC721(_token).safeTransferFrom(address(this), _to, _tokenId);

        emit ERC721Withdrawn(_msgSender(), _token, _tokenId, _to);
    }

    /// @notice Pauses the contract.
    /// @dev Only the owner and pauser can pause the contract.
    function pause() external {
        address sender = _msgSender();

        if (!hasRole(DEFAULT_ADMIN_ROLE, sender) && !hasRole(PAUSER_ROLE, sender)) {
            revert Unauthorized(sender);
        }

        _pause();
    }

    /// @notice Unpauses the contract.
    /// @dev Only the owner can unpause the contract.
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Updates the maximum USD amount that can be paid in MANA for the transaction fee.
    /// @dev Only the contract admin can call this function.
    /// @param _maxUSDFee The new maximum USD MANA fee (in 18 decimals).
    function updateMaxUSDFee(uint256 _maxUSDFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateMaxUSDFee(_maxUSDFee);
    }

    /// @notice Validates that the MANA fee does not exceed the maximum allowed USD value.
    /// @dev Converts the maximum USD fee to MANA using the current price from the aggregator.
    /// @param _manaFee The MANA fee amount to validate.
    function _validateMANAFee(uint256 _manaFee) internal view {
        // Obtains the price of MANA in USD from the Chainlink aggregator.
        int256 manaUSDRate = _getRateFromAggregator(manaUSDAggregator, manaUSDAggregatorTolerance);

        // Calculate the maximum MANA amount based on the USD limit.
        // manaUSDRate has 18 decimals, so we multiply by 1e18 to get the result in MANA wei.
        uint256 maxMANA = maxUSDFee * 1e18 / uint256(manaUSDRate);

        if (_manaFee > maxMANA) {
            revert MANAforFeeExceeded();
        }
    }

    /// @dev Internal function to update the maximum USD MANA fee.
    /// @param _maxUSDFee The new maximum USD MANA fee (in 18 decimals).
    function _updateMaxUSDFee(uint256 _maxUSDFee) internal {
        maxUSDFee = _maxUSDFee;

        emit MaxUSDFeeUpdated(_maxUSDFee);
    }
}
