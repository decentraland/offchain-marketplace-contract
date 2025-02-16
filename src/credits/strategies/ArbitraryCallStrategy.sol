// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";

abstract contract ArbitraryCallStrategy is CreditManagerBase {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /// @notice The role that can sign arbitrary call data.
    bytes32 public constant ARBITRARY_CALL_SIGNER_ROLE = keccak256("ARBITRARY_CALL_SIGNER_ROLE");

    /// @notice The role that can revoke arbitrary call signatures.
    bytes32 public constant ARBITRARY_CALL_REVOKER_ROLE = keccak256("ARBITRARY_CALL_REVOKER_ROLE");

    /// @notice Mapping of allowed targets and selectors.
    mapping(address => mapping(bytes4 => bool)) public isTargetSelectorAllowed;

    /// @notice Mapping of used arbitrary calls using the hashed call as a unique identifier.
    mapping(bytes32 => bool) public usedArbitraryCalls;

    /// @param _arbitraryCallSigner The address that can sign arbitrary call data.
    /// @param _arbitraryCallRevoker The address that can revoke arbitrary call signatures.
    /// @param _allowedTargets The list of targets that are allowed to be called.
    /// @param _allowedSelectors The list of selectors that are allowed to be called for the allowed targets.
    struct ArbitraryCallStrategyInit {
        address arbitraryCallSigner;
        address arbitraryCallRevoker;
        address[] allowedTargets;
        bytes4[] allowedSelectors;
    }

    /// @param _target The contract address to call.
    /// @param _data The data to call the target contract with.
    /// @param _expectedManaTransfer The expected amount of MANA that will be transferred out of the contract.
    /// @param _salt A random value to make the signature unique.
    /// @param _signature The signature of the arbitrary call.
    struct ArbitraryCall {
        address target;
        bytes data;
        uint256 expectedManaTransfer;
        bytes32 salt;
    }

    event TargetSelectorAllowed(address indexed _sender, address indexed _target, bytes4 indexed _selector, bool _allowed);
    event ArbitraryCallRevoked(address indexed _sender, bytes32 indexed _hashedArbitraryCall);

    /// @param _init The initialization parameters for the contract.
    constructor(ArbitraryCallStrategyInit memory _init) {
        _grantRole(ARBITRARY_CALL_SIGNER_ROLE, _init.arbitraryCallSigner);
        _grantRole(ARBITRARY_CALL_REVOKER_ROLE, _init.arbitraryCallRevoker);

        address[] memory allowedTargets = _init.allowedTargets;
        bytes4[] memory allowedSelectors = _init.allowedSelectors;
        uint256 allowedTargetsLength = allowedTargets.length;

        for (uint256 i = 0; i < allowedTargetsLength; i++) {
            _allowTargetSelector(allowedTargets[i], allowedSelectors[i], true);
        }
    }

    /// @notice Allows the owner to allow a target and selector.
    /// @param _target The address of the contract being called.
    /// @param _selector The selector of the function being called.
    /// @param _allowed Whether the selector for a given target is allowed.
    function allowTargetSelector(address _target, bytes4 _selector, bool _allowed) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _allowTargetSelector(_target, _selector, _allowed);
    }

    /// @notice Allows the arbitrary call revoker to revoke arbitrary calls.
    /// @param _hashedArbitraryCalls The list of hashed arbitrary calls to revoke.
    function revokeArbitraryCalls(bytes32[] calldata _hashedArbitraryCalls) external onlyRole(ARBITRARY_CALL_REVOKER_ROLE) {
        for (uint256 i = 0; i < _hashedArbitraryCalls.length; i++) {
            bytes32 hashedArbitraryCall = _hashedArbitraryCalls[i];

            usedArbitraryCalls[hashedArbitraryCall] = true;

            emit ArbitraryCallRevoked(_msgSender(), hashedArbitraryCall);
        }
    }

    /// @notice Allows the user to execute an arbitrary call to consume credits.
    /// This call however, must have been signed by the arbitrary call signer.
    /// @param _call The arbitrary call to execute.
    /// @param _callSignature The signature of the arbitrary call.
    /// @param _credits The list of credits to be consumed.
    function executeArbitraryCall(ArbitraryCall calldata _call, bytes calldata _callSignature, Credit[] calldata _credits) external nonReentrant {
        bytes32 hashedArbitraryCall = keccak256(abi.encode(_msgSender(), address(this), block.chainid, _call));

        if (!hasRole(ARBITRARY_CALL_SIGNER_ROLE, hashedArbitraryCall.recover(_callSignature))) {
            revert("Invalid signature");
        }

        if (_call.expectedManaTransfer == 0) {
            revert("Expected MANA transfer is 0");
        }

        if (usedArbitraryCalls[hashedArbitraryCall]) {
            revert("Arbitrary call already executed");
        }

        bytes4 selector = bytes4(_call.data[:4]);

        if (!isTargetSelectorAllowed[_call.target][selector]) {
            revert("Arbitrary call selector for target not allowed");
        }

        usedArbitraryCalls[hashedArbitraryCall] = true;

        uint256 manaToCredit = _computeTotalManaToCredit(_credits, _call.expectedManaTransfer);

        mana.forceApprove(address(this), _call.expectedManaTransfer);

        uint256 balanceBefore = mana.balanceOf(address(this));

        (bool success,) = _call.target.call(_call.data);

        if (!success) {
            revert("Arbitrary call failed");
        }

        _validateResultingBalance(balanceBefore, _call.expectedManaTransfer);

        _executeManaTransfers(manaToCredit, _call.expectedManaTransfer);
    }

    function _allowTargetSelector(address _target, bytes4 _selector, bool _allowed) internal {
        isTargetSelectorAllowed[_target][_selector] = _allowed;

        emit TargetSelectorAllowed(_msgSender(), _target, _selector, _allowed);
    }
}
