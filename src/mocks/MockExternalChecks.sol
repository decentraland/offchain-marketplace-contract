// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract MockExternalChecks {
    address public ownerOfResult;
    uint256 public balanceOfResult;
    bool public customCheckFunctionResult;
    uint256 private count;

    function setOwnerOfResult(address _ownerOfResult) external {
        ownerOfResult = _ownerOfResult;
    }

    function setBalanceOfResult(uint256 _balanceOfResult) external {
        balanceOfResult = _balanceOfResult;
    }

    function setCustomCheckFunctionResult(bool _customCheckFunctionResult) external {
        customCheckFunctionResult = _customCheckFunctionResult;
    }

    function ownerOf(uint256) external view returns (address) {
        return ownerOfResult;
    }

    function balanceOf(address) external view returns (uint256) {
        return balanceOfResult;
    }

    function customCheckFunctionBool(address, bool) external view returns (bool) {
        return customCheckFunctionResult;
    }

    function customCheckFunctionUint256(address, uint256) external view returns (bool) {
        return customCheckFunctionResult;
    }

    function customCheckFunctionBytes(address, bytes calldata) external view returns (bool) {
        return customCheckFunctionResult;
    }

    function customCheckFunctionBytesExpects100(address, bytes calldata _data) external view returns (bool) {
        if (100 != abi.decode(_data, (uint256))) {
            revert("Not 100!");
        }

        return customCheckFunctionResult;
    }

    function customCheckFunctionNotView(address, bytes calldata) external returns (bool) {
        count++;

        return customCheckFunctionResult;
    }
}
