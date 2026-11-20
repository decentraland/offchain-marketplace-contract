// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract BuyerProxy {
    using SafeERC20 for IERC20;

    IERC20 public immutable mana;

    address public immutable creditsManager;

    error UnauthorizedCaller(address _caller);

    constructor(IERC20 _mana) {
        mana = _mana;
        creditsManager = msg.sender;
    }

    function execute(address _target, bytes calldata _data, uint256 _amount) external returns (bool success) {
        if (msg.sender != creditsManager) {
            revert UnauthorizedCaller(msg.sender);
        }

        uint256 balanceBefore = mana.balanceOf(address(this));

        mana.forceApprove(_target, _amount);

        (success,) = _target.call(_data);

        mana.forceApprove(_target, 0);

        mana.safeTransfer(creditsManager, _amount - (balanceBefore - mana.balanceOf(address(this))));
    }

    function withdrawERC20(address _token, uint256 _amount, address _to) external {
        if (msg.sender != creditsManager) {
            revert UnauthorizedCaller(msg.sender);
        }

        IERC20(_token).safeTransfer(_to, _amount);
    }

    function withdrawERC721(address _token, uint256 _tokenId, address _to) external {
        if (msg.sender != creditsManager) {
            revert UnauthorizedCaller(msg.sender);
        }

        IERC721(_token).safeTransferFrom(address(this), _to, _tokenId);
    }
}
