// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {RegisterNameCrossChainExecutorTestBase} from "test/credits/utils/RegisterNameCrossChainExecutorTestBase.sol";
import {RegisterNameCrossChainExecutor} from "src/credits/executors/RegisterNameCrossChainExecutor.sol";
import {AggregatorHelper} from "src/marketplace/AggregatorHelper.sol";

contract RegisterNameCrossChainExecutorExecuteTest is RegisterNameCrossChainExecutorTestBase {
    function test_execute_RevertsWhenNotCreditsManager() public {
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(1 ether);

        vm.expectRevert(abi.encodeWithSelector(RegisterNameCrossChainExecutor.Unauthorized.selector, address(this)));
        executor.execute(call);
    }

    function test_execute_RevertsWhenPaused() public {
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(1 ether);

        vm.prank(owner);
        executor.pause();

        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_RevertsWhenInvalidTarget() public {
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(1 ether);
        call.target = makeAddr("invalidTarget");

        vm.expectRevert(abi.encodeWithSelector(RegisterNameCrossChainExecutor.InvalidTarget.selector));
        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_RevertsWhenInvalidSelector() public {
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(1 ether);
        call.selector = 0x12345678;

        vm.expectRevert(abi.encodeWithSelector(RegisterNameCrossChainExecutor.InvalidSelector.selector));
        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_RevertsWhenExpired() public {
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(1 ether);
        call.expiresAt = block.timestamp - 1;

        vm.expectRevert(abi.encodeWithSelector(RegisterNameCrossChainExecutor.ExecutionExpired.selector, call));
        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_RevertsWhenMANAFeeExceeded() public {
        // With MANA at $0.50, max fee of $5 = 10 MANA
        // So trying to use 11 MANA should fail
        uint256 excessiveFee = 11 ether;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(excessiveFee);

        vm.expectRevert(abi.encodeWithSelector(RegisterNameCrossChainExecutor.MANAforFeeExceeded.selector));
        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_RevertsWhenMANAFeeExceeded_AtBoundary() public {
        // With MANA at $0.50 (normalized to 18 decimals = 0.5e18)
        // maxUSDMANAFee = 5 ether (5 USD with 18 decimals)
        // maxMANA = (5 * 1e18) * 1e18 / (0.5e18) = 10 MANA
        // So 10 MANA should pass, but 10.000000000000000001 should fail

        uint256 maxAllowedFee = 10 ether;
        uint256 justOverMaxFee = maxAllowedFee + 1;

        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(justOverMaxFee);

        vm.expectRevert(abi.encodeWithSelector(RegisterNameCrossChainExecutor.MANAforFeeExceeded.selector));
        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_RevertsWhenCreditsManagerInsufficientBalance() public {
        uint256 manaFee = 1 ether;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);

        // Transfer manaFee to executor
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);

        // Remove all MANA from creditsManager (leaving it with less than NAME_PRICE)
        uint256 creditsManagerBalance = IERC20(mana).balanceOf(creditsManager);
        vm.prank(creditsManager);
        IERC20(mana).transfer(address(0xdead), creditsManagerBalance - (NAME_PRICE - 1)); // Leave 99 MANA

        // Execution should revert because creditsManager doesn't have enough MANA
        vm.expectRevert();
        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_RevertsWhenExecutorInsufficientBalanceForFee() public {
        uint256 manaFee = 2 ether;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);

        // Transfer only part of the fee to executor (less than required)
        uint256 partialFee = manaFee - 1 ether; // Transfer 1 MANA instead of 2
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), partialFee);

        // Approve MANA from creditsManager to executor
        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);

        // Execution should revert because executor doesn't have enough MANA for the fee
        // Coral will try to transferFrom executor the full amount (manaFee + NAME_PRICE) but executor only has partialFee + NAME_PRICE
        vm.expectRevert();
        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_RevertsWhenAggregatorAnswerIsNegative() public {
        // Set negative price
        vm.prank(owner);
        manaUsdAggregator.setAnswer(-1);

        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(1 ether);

        vm.expectRevert(abi.encodeWithSelector(AggregatorHelper.AggregatorAnswerIsNegative.selector));
        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_RevertsWhenAggregatorAnswerIsStale() public {
        // Set stale data (more than tolerance)
        vm.prank(owner);
        manaUsdAggregator.setUpdatedAtOffset(manaUsdAggregatorTolerance + 1);

        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(1 ether);

        vm.expectRevert(abi.encodeWithSelector(AggregatorHelper.AggregatorAnswerIsStale.selector));
        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_RevertsWhenCoralCallFails() public {
        // Make coral revert - coral owner is the test contract
        coral.setShouldRevert(true);

        uint256 manaFee = 1 ether;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);

        // Transfer manaFee to executor
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);

        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);

        vm.expectRevert(abi.encodeWithSelector(RegisterNameCrossChainExecutor.CallFailed.selector, call));

        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_Success() public {
        uint256 manaFee = 2 ether;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(creditsManager);
        uint256 executorBalanceBefore = IERC20(mana).balanceOf(address(executor));
        uint256 coralBalanceBefore = IERC20(mana).balanceOf(address(coral));

        // Transfer manaFee to executor (executor needs this balance)
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);

        // Verify executor now has the manaFee
        assertEq(IERC20(mana).balanceOf(address(executor)), executorBalanceBefore + manaFee);

        // Approve MANA from creditsManager to executor for NAME_PRICE only
        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);

        // Execute from creditsManager
        vm.prank(creditsManager);
        executor.execute(call);

        // Check balances
        // CreditsManager should have decreased by NAME_PRICE
        assertEq(IERC20(mana).balanceOf(creditsManager), creditsManagerBalanceBefore - NAME_PRICE);

        // Executor should have lost the manaFee (and NAME_PRICE was transferred from creditsManager then to coral)
        // So executor balance should be back to executorBalanceBefore (0 in this case)
        assertEq(IERC20(mana).balanceOf(address(executor)), executorBalanceBefore);

        // Coral should have received NAME_PRICE + manaFee
        assertEq(IERC20(mana).balanceOf(address(coral)), coralBalanceBefore + NAME_PRICE + manaFee);

        // Check that approval was reset
        assertEq(IERC20(mana).allowance(address(executor), address(coral)), 0);
    }

    function test_execute_Success_WithZeroFee() public {
        uint256 manaFee = 0;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(creditsManager);
        uint256 executorBalanceBefore = IERC20(mana).balanceOf(address(executor));
        uint256 coralBalanceBefore = IERC20(mana).balanceOf(address(coral));

        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);

        vm.prank(creditsManager);
        executor.execute(call);

        // Check balances - only NAME_PRICE should be transferred (no manaFee)
        // CreditsManager should have decreased by NAME_PRICE
        assertEq(IERC20(mana).balanceOf(creditsManager), creditsManagerBalanceBefore - NAME_PRICE);

        // Executor balance should remain the same (no manaFee was used)
        assertEq(IERC20(mana).balanceOf(address(executor)), executorBalanceBefore);

        // Coral should have received only NAME_PRICE (no manaFee)
        assertEq(IERC20(mana).balanceOf(address(coral)), coralBalanceBefore + NAME_PRICE);
    }

    function test_execute_Success_WithMaxFee() public {
        // Exactly at the maximum allowed fee (10 MANA with current price)
        uint256 manaFee = 10 ether;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(creditsManager);
        uint256 executorBalanceBefore = IERC20(mana).balanceOf(address(executor));
        uint256 coralBalanceBefore = IERC20(mana).balanceOf(address(coral));

        // Transfer manaFee to executor
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);

        // Verify executor received the manaFee
        assertEq(IERC20(mana).balanceOf(address(executor)), executorBalanceBefore + manaFee);

        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);

        vm.prank(creditsManager);
        executor.execute(call);

        // CreditsManager should have decreased by NAME_PRICE
        assertEq(IERC20(mana).balanceOf(creditsManager), creditsManagerBalanceBefore - NAME_PRICE);

        // Executor should have lost the manaFee (back to initial balance)
        assertEq(IERC20(mana).balanceOf(address(executor)), executorBalanceBefore);

        // Coral should have received NAME_PRICE + manaFee
        assertEq(IERC20(mana).balanceOf(address(coral)), coralBalanceBefore + NAME_PRICE + manaFee);
    }

    function test_execute_RevertsAfterPriceChange_FeeNowExcessive() public {
        // Initially, with MANA at $0.50, 8 MANA fee is valid (= $4)
        uint256 manaFee = 8 ether;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);

        // Transfer manaFee to executor
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);

        // This should succeed
        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);

        vm.prank(creditsManager);
        executor.execute(call);

        // Now increase MANA price to $1.00
        vm.prank(owner);
        manaUsdAggregator.setAnswer(100000000); // $1.00 with 8 decimals

        // Now 8 MANA = $8, which exceeds the $5 limit
        RegisterNameCrossChainExecutor.ExternalCall memory call2 = _createValidExternalCall(manaFee);

        vm.expectRevert(abi.encodeWithSelector(RegisterNameCrossChainExecutor.MANAforFeeExceeded.selector));
        vm.prank(creditsManager);
        executor.execute(call2);
    }

    function test_execute_Success_MultipleExecutions() public {
        uint256 manaFee = 1 ether;

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(creditsManager);
        uint256 executorBalanceBefore = IERC20(mana).balanceOf(address(executor));
        uint256 coralBalanceBefore = IERC20(mana).balanceOf(address(coral));

        // First execution
        RegisterNameCrossChainExecutor.ExternalCall memory call1 = _createValidExternalCall(manaFee);
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);
        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);
        vm.prank(creditsManager);
        executor.execute(call1);

        // Second execution
        RegisterNameCrossChainExecutor.ExternalCall memory call2 = _createValidExternalCall(manaFee);
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);
        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);
        vm.prank(creditsManager);
        executor.execute(call2);

        // Third execution
        RegisterNameCrossChainExecutor.ExternalCall memory call3 = _createValidExternalCall(manaFee);
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);
        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);
        vm.prank(creditsManager);
        executor.execute(call3);

        // Verify balances after all executions
        // CreditsManager should have decreased by NAME_PRICE * 3
        assertEq(IERC20(mana).balanceOf(creditsManager), creditsManagerBalanceBefore - (NAME_PRICE * 3));

        // Executor should be back to initial balance (all manaFee was used)
        assertEq(IERC20(mana).balanceOf(address(executor)), executorBalanceBefore);

        // Coral should have received NAME_PRICE + manaFee for each execution
        assertEq(IERC20(mana).balanceOf(address(coral)), coralBalanceBefore + (NAME_PRICE + manaFee) * 3);
    }

    function test_execute_Success_WithDifferentExpiration() public {
        uint256 manaFee = 1 ether;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);

        // Set expiration to 1 second from now
        call.expiresAt = block.timestamp + 1;

        // Transfer manaFee to executor
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);

        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);

        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_Success_WithUpdatedMaxFee() public {
        // Update max fee to $10
        vm.prank(owner);
        executor.updateMaxUSDMANAFee(10 ether);

        // Now 20 MANA should be valid (20 MANA * $0.50 = $10)
        uint256 manaFee = 20 ether;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);

        // Transfer manaFee to executor
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);

        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);

        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_EmitsExecutedEvent() public {
        uint256 manaFee = 2 ether;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);

        // Transfer manaFee to executor
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);

        // Approve MANA from creditsManager to executor
        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);

        // Expect the Executed event with the correct parameters
        vm.expectEmit(true, true, true, true);
        emit Executed(call);

        // Execute from creditsManager
        vm.prank(creditsManager);
        executor.execute(call);
    }

    function test_execute_Success_SameBlockNotExpired() public {
        uint256 manaFee = 1 ether;
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);
        call.expiresAt = block.timestamp;

        uint256 creditsManagerBalanceBefore = IERC20(mana).balanceOf(creditsManager);
        uint256 executorBalanceBefore = IERC20(mana).balanceOf(address(executor));
        uint256 coralBalanceBefore = IERC20(mana).balanceOf(address(coral));

        // Transfer manaFee to executor
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), manaFee);

        // Approve MANA from creditsManager to executor
        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);

        vm.prank(creditsManager);
        executor.execute(call);

        // Verify balances
        // CreditsManager should have decreased by NAME_PRICE
        assertEq(IERC20(mana).balanceOf(creditsManager), creditsManagerBalanceBefore - NAME_PRICE);

        // Executor should have lost the manaFee (back to initial balance)
        assertEq(IERC20(mana).balanceOf(address(executor)), executorBalanceBefore);

        // Coral should have received NAME_PRICE + manaFee
        assertEq(IERC20(mana).balanceOf(address(coral)), coralBalanceBefore + NAME_PRICE + manaFee);
    }

    function test_execute_RevertsOnReentrancy() public {
        // Deploy a malicious creditsManager contract that will attempt reentrancy
        ReentrancyAttackerCreditsManager maliciousCreditsManager = new ReentrancyAttackerCreditsManager();

        // Deploy a new executor with the malicious creditsManager
        RegisterNameCrossChainExecutor maliciousExecutor = new RegisterNameCrossChainExecutor(
            owner,
            address(maliciousCreditsManager),
            IERC20(mana),
            address(coral),
            maxUSDMANAFee,
            address(manaUsdAggregator),
            manaUsdAggregatorTolerance
        );

        // Set the executor in the malicious contract
        maliciousCreditsManager.setExecutor(maliciousExecutor);

        // Set the reentrancy callback in coral (coral owner is the test contract)
        coral.setReentrancyCallback(address(maliciousCreditsManager));

        // Fund the malicious creditsManager with MANA
        uint256 manaFee = 1 ether;
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(maliciousCreditsManager), NAME_PRICE + manaFee);

        // Transfer manaFee to executor
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(maliciousExecutor), manaFee);

        // Create a valid call
        RegisterNameCrossChainExecutor.ExternalCall memory call = _createValidExternalCall(manaFee);
        call.target = address(coral);

        // The malicious creditsManager will try to reenter during execution
        // This should revert due to nonReentrant modifier (ReentrancyGuardReentrantCall error)
        // The MockCoral will propagate the revert from the callback
        vm.expectRevert();
        maliciousCreditsManager.attack(call);
    }
}

/// @notice Malicious creditsManager contract that attempts reentrancy attack
/// @dev This contract will attempt to call execute again during the first execute call
contract ReentrancyAttackerCreditsManager {
    RegisterNameCrossChainExecutor public executor;
    RegisterNameCrossChainExecutor.ExternalCall public pendingCall;

    function setExecutor(RegisterNameCrossChainExecutor _executor) external {
        executor = _executor;
    }

    function attack(RegisterNameCrossChainExecutor.ExternalCall memory _call) external {
        pendingCall = _call;

        // Approve NAME_PRICE
        IERC20(executor.mana()).approve(address(executor), executor.NAME_PRICE());

        // First call - this will trigger coral callback which will attempt reentrancy
        executor.execute(_call);
    }

    // This function will be called by coral during execution, attempting reentrancy
    fallback() external {
        if (address(executor) != address(0)) {
            // Attempt reentrancy - this should fail due to nonReentrant modifier
            executor.execute(pendingCall);
        }
    }
}

