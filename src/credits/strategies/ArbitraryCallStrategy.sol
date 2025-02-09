// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {CreditManagerBase} from "src/credits/CreditManagerBase.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

abstract contract ArbitraryCallStrategy is CreditManagerBase {
    using ECDSA for bytes32;

    /// @notice The role that can sign arbitrary call data.
    bytes32 public constant ARBITRARY_CALL_SIGNER_ROLE = keccak256("ARBITRARY_CALL_SIGNER_ROLE");

    /// @notice The role that can revoke arbitrary call signatures.
    bytes32 public constant ARBITRARY_CALL_REVOKER_ROLE = keccak256("ARBITRARY_CALL_REVOKER_ROLE");

    /// @notice Mapping of allowed targets and selectors.
    mapping(address => mapping(bytes4 => bool)) public isTargetSelectorAllowed;

    /// @notice Mapping of used arbitrary call signatures.
    mapping(bytes32 => bool) public usedArbitraryCallSignatures;

    /// @param _arbitraryCallSigner The address that can sign arbitrary call data.
    /// @param _arbitraryCallRevoker The address that can revoke arbitrary call signatures.
    struct ArbitraryCallInit {
        address arbitraryCallSigner;
        address arbitraryCallRevoker;
    }

    /// @param _target The contract address to call.
    /// @param _data The data to call the target contract with.
    /// @param _expectedManaTransfer The expected amount of MANA that will be transferred out of the contract.
    /// @param _salt A random value to make the signature unique.
    /// @param _credits The list of credits to be consumed.
    /// @param _signature The signature of the arbitrary call.
    struct ArbitraryCall {
        address target;
        bytes data;
        uint256 expectedManaTransfer;
        bytes32 salt;
        Credit[] credits;
        bytes signature;
    }

    /// @param _init The initialization parameters for the contract.
    constructor(ArbitraryCallInit memory _init) {
        _grantRole(ARBITRARY_CALL_SIGNER_ROLE, _init.arbitraryCallSigner);
        _grantRole(ARBITRARY_CALL_REVOKER_ROLE, _init.arbitraryCallRevoker);
    }

    /// @notice Allows the arbitrary call revoker to revoke arbitrary call signatures.
    /// @param _hashedSignatures The list of hashed signatures to revoke.
    function cancelArbitraryCallSignatures(bytes32[] calldata _hashedSignatures) external onlyRole(ARBITRARY_CALL_REVOKER_ROLE) {
        for (uint256 i = 0; i < _hashedSignatures.length; i++) {
            usedArbitraryCallSignatures[_hashedSignatures[i]] = true;
        }
    }

    /// @notice Allows the user to execute an arbitrary call to consume credits.
    /// This call however, must have been signed by the arbitrary call signer.
    /// @param _call The arbitrary call to execute.
    function executeArbitraryCall(ArbitraryCall calldata _call) external nonReentrant {
        bytes32 hashedArbitraryCall = keccak256(abi.encode(_msgSender(), address(this), block.chainid, _call.target, _call.data, _call.expectedManaTransfer, _call.salt, _call.credits));

        if (!hasRole(ARBITRARY_CALL_SIGNER_ROLE, hashedArbitraryCall.recover(_call.signature))) {
            revert("Invalid signature");
        }

        if (_call.expectedManaTransfer == 0) {
            revert("Expected MANA transfer is 0");
        }

        bytes32 hashedSignature = keccak256(_call.signature);

        if (usedArbitraryCallSignatures[hashedSignature]) {
            revert("Arbitrary call already executed");
        }

        bytes4 selector = bytes4(_call.data[:4]);

        if (!isTargetSelectorAllowed[_call.target][selector]) {
            revert("Arbitrary call selector for target not allowed");
        }

        usedArbitraryCallSignatures[hashedSignature] = true;

        uint256 manaToCredit = _computeTotalManaToCredit(_call.credits, _call.expectedManaTransfer);

        mana.approve(address(this), _call.expectedManaTransfer);

        uint256 balanceBefore = mana.balanceOf(address(this));

        (bool success,) = _call.target.call(_call.data);

        if (!success) {
            revert("Arbitrary call failed");
        }

        _validateResultingBalance(balanceBefore, _call.expectedManaTransfer);

        _executeManaTransfers(manaToCredit, _call.expectedManaTransfer);
    }
}
