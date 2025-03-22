// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CreditsManagerPolygonHarness} from "test/credits/utils/CreditsManagerPolygonHarness.sol";

contract MockExternalCallTarget {
    CreditsManagerPolygonHarness public creditsManager;
    IERC20 public mana;
    uint256 public amount;
    address public beneficiary;

    constructor(CreditsManagerPolygonHarness _creditsManager, IERC20 _mana, uint256 _amount) {
        creditsManager = _creditsManager;
        mana = _mana;
        amount = _amount;
        beneficiary = address(this);
    }

    function someFunction() external {
        mana.transferFrom(address(creditsManager), beneficiary, amount);
    }

    function setBeneficiary(address _beneficiary) external {
        beneficiary = _beneficiary;
    }
}
