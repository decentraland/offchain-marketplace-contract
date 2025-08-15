// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {NativeMetaTransaction, EIP712} from "src/common/NativeMetaTransaction.sol";
import {IMarketplace} from "src/credits/interfaces/IMarketplace.sol";
import {ILegacyMarketplace} from "src/credits/interfaces/ILegacyMarketplace.sol";
import {ICollectionFactory} from "src/credits/interfaces/ICollectionFactory.sol";
import {ICollectionStore} from "src/credits/interfaces/ICollectionStore.sol";
import {IAggregator} from "src/marketplace/interfaces/IAggregator.sol";
import {AggregatorHelper} from "src/marketplace/AggregatorHelper.sol";

contract RegisterNameCrossChainExecutor is AccessControl, Pausable, ReentrancyGuard, AggregatorHelper {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SafeERC20 for IERC20;

     /// @notice The role that can pause the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice The address of the coral contract.
    address public immutable creditsManager;

    /// @notice The address of the MANA token.
    IERC20 public immutable mana;

    /// @notice percentage allowed for the fee.
    uint256 public maxUSDMANAFee;
    

    /// @notice The address of the coral contract.
    address public immutable coral;

    /// @notice The MANA/USD Chainlink aggregator.
    /// @dev Used to obtain the rate of MANA expressed in USD.
    IAggregator public manaUsdAggregator;

    /// @notice Maximum time (in seconds) since the MANA/USD aggregator result was last updated before it is considered outdated.
    uint256 public manaUsdAggregatorTolerance;

    /// @param target The contract address of the external call.
    /// @param selector The selector of the external call.
    /// @param data The data of the external call.
    /// @param expiresAt The timestamp when the external call expires.
    /// Only used for custom external calls.
    /// @param salt The salt of the external call.
    /// Only used for custom external calls.
    struct ExternalCall {
        address target;
        bytes4 selector;
        bytes data;
        bytes extra;
    }

    event Executed(ExternalCall _externalCall);
    event ERC20Withdrawn(address indexed _sender, address indexed _token, uint256 _amount, address indexed _to);
    event ERC721Withdrawn(address indexed _sender, address indexed _token, uint256 indexed _tokenId, address _to);
    event ManaUsdAggregatorUpdated(address indexed _aggregator, uint256 _tolerance);

    error Unauthorized(address _sender);
    error InvalidTarget();
    error MANAforFeeExceeded();
    error ExternalCallFailed(ExternalCall _externalCall);


    /// @param _owner The owner of the contract.
    /// @param _creditsManager The credits manager contract.
    /// @param _mana The MANA token.
    /// @param _coral The coral contract.
    /// @param _maxUSDMANAFee The maximum USD to pay in MANA that can be used for the fee.
    /// @param _manaUsdAggregator The address of the MANA/USD price aggregator.
    /// @param _manaUsdAggregatorTolerance The tolerance (in seconds) that indicates if the result provided by the aggregator is old.
    constructor(
        address _owner,
        address _creditsManager,
        IERC20 _mana,
        address _coral,
        uint256 _maxUSDMANAFee,
        address _manaUsdAggregator,
        uint256 _manaUsdAggregatorTolerance    
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        creditsManager = _creditsManager;
        mana = _mana;
        coral = _coral;

        _updateMaxUSDMANAFee(_maxUSDMANAFee);
        _updateManaUsdAggregator(_manaUsdAggregator, _manaUsdAggregatorTolerance);
    }

    /// @notice Use credits to pay for external calls that transfer MANA.
    /// @param _args The arguments for the useCredits function.
    function execute(ExternalCall calldata _args) external nonReentrant whenNotPaused {
        // Get the sender of the transaction.
        // Defined here to prevent calling _msgSender() multiple times for this transaction.
        address sender = _msgSender();

        // Validate that the sender is the credits manager.
        if(sender != creditsManager) {
            revert Unauthorized(sender);
        }

        // Validate that the target is the coral contract.
        if(_args.target != coral) {
            revert InvalidTarget();
        }

        // Validate that the MANA fee is not greater than the maximum allowed.
        (uint32 manaFee) = abi.decode(_args.extra, (uint32));
        _validateMANAFee(manaFee);

        uint256 namePrice = 100 ether;

        // Approve the MANA tokens to the coral contract for the total amount of the MANA fee plus the name price.
        mana.forceApprove(coral, manaFee + namePrice);
        // Transfer the name price in MANA to the contract from the credits manager.
        mana.transferFrom(creditsManager, address(this), namePrice);

        // Execute the external call.
        (bool success,) = _args.target.call(abi.encodePacked(_args.selector, _args.data));

        if (!success) {
            revert ExternalCallFailed(_args);
        }

        // Reset the approval of the MANA tokens to the coral contract.
        mana.forceApprove(coral, 0);

        emit Executed(_args);
    }

    function _validateMANAFee(uint256 _manaFee) internal view {
        // Obtains the price of MANA in USD.
        int256 manaUsdRate = _getRateFromAggregator(manaUsdAggregator, manaUsdAggregatorTolerance);

        uint256 maxMANA =  maxUSDMANAFee * 1e18 / uint256(manaUsdRate);

        if (_manaFee > maxMANA) {
            revert MANAforFeeExceeded();
        }
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

    /// @notice Updates the MANA/USD price aggregator and tolerance.
    /// @param _aggregator The new MANA/USD price aggregator.
    /// @param _tolerance The new tolerance that indicates if the result provided by the aggregator is old.
    function updateManaUsdAggregator(address _aggregator, uint256 _tolerance) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateManaUsdAggregator(_aggregator, _tolerance);
    }

      /// @dev Updates the MANA/USD price aggregator and tolerance.
    function _updateManaUsdAggregator(address _aggregator, uint256 _tolerance) private {
        manaUsdAggregator = IAggregator(_aggregator);
        manaUsdAggregatorTolerance = _tolerance;

        emit ManaUsdAggregatorUpdated(_aggregator, _tolerance);
    }

    function updateMaxUSDMANAFee(uint256 _maxUSDMANAFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _updateMaxUSDMANAFee(_maxUSDMANAFee);
    }

    function _updateMaxUSDMANAFee(uint256 _maxUSDMANAFee) internal {
        maxUSDMANAFee = _maxUSDMANAFee;
    }
}
