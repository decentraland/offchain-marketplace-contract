// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CreditsManagerPolygonHarness} from "test/credits/utils/CreditsManagerPolygonHarness.sol";

contract MockExternalCallTarget {
    CreditsManagerPolygonHarness public creditsManager;
    IERC20 public mana;
    uint256 public amount;
    address public beneficiary;
    uint256 public beneficiaryCut;

    constructor(CreditsManagerPolygonHarness _creditsManager, IERC20 _mana, uint256 _amount) {
        creditsManager = _creditsManager;
        mana = _mana;
        amount = _amount;
        beneficiary = address(this);
        beneficiaryCut = _amount;
    }

    function someFunction() external {
        mana.transferFrom(address(creditsManager), address(this), amount);

        if (beneficiary != address(this)) {
            mana.transfer(beneficiary, beneficiaryCut);
        }
    }

    function setBeneficiary(address _beneficiary) external {
        beneficiary = _beneficiary;
    }

    function setBeneficiaryCut(uint256 _beneficiaryCut) external {
        beneficiaryCut = _beneficiaryCut;
    }
}
