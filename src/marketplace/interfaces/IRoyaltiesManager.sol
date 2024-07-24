// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Interface for the Royalties Manager contract.
interface IRoyaltiesManager {
    function getRoyaltiesReceiver(address _contractAddress, uint256 _tokenId) external view returns(address);
}
