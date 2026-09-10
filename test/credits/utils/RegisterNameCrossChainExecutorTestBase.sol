// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {RegisterNameCrossChainExecutor} from "src/credits/executors/RegisterNameCrossChainExecutor.sol";
import {MockCoral} from "test/credits/mocks/MockCoral.sol";
import {MockAggregator} from "src/mocks/MockAggregator.sol";

contract RegisterNameCrossChainExecutorTestBase is Test {
    RegisterNameCrossChainExecutor internal executor;
    MockCoral internal coral;
    MockAggregator internal manaUSDAggregator;

    address internal owner;
    address internal creditsManager;
    address internal pauser;
    address internal mana;
    address internal manaHolder;
    uint256 internal maxUSDMANAFee;
    uint256 internal manaUSDAggregatorTolerance;

    // Mock external call data
    // Selector for fundAndRunMulticall
    bytes4 internal constant FUND_AND_RUN_MULTICALL_SELECTOR = 0x58181a80;
    uint256 internal constant NAME_PRICE = 100 ether;
    address internal nameRegistry;

    event Executed(RegisterNameCrossChainExecutor.ExternalCall _externalCall);
    event ERC20Withdrawn(address indexed _sender, address indexed _token, uint256 _amount, address indexed _to);
    event ERC721Withdrawn(address indexed _sender, address indexed _token, uint256 indexed _tokenId, address _to);
    event MaxUSDFeeUpdated(uint256 _maxUSDFee);
    event ExecutorUpdated(address _executor);

    function setUp() public virtual {
        vm.selectFork(vm.createFork("https://rpc.decentraland.org/polygon", 68650527)); // Mar-04-2025 09:10:51 PM +UTC

        owner = makeAddr("owner");
        creditsManager = makeAddr("creditsManager");
        pauser = makeAddr("pauser");
        nameRegistry = makeAddr("nameRegistry");

        // Real MANA address on Polygon
        mana = 0xA1c57f48F0Deb89f569dFbE6E2B7f46D33606fD4;
        manaHolder = 0xB08E3e7cc815213304d884C88cA476ebC50EaAB2;

        // Deploy mock contracts
        coral = new MockCoral();

        // Create mock aggregator
        // MANA/USD = $0.50 (with 8 decimals = 50000000)
        int256 manaUsdPrice = 50000000; // $0.50
        manaUSDAggregator = new MockAggregator(owner, manaUsdPrice, 0, 8);

        // Max fee: $5 USD (with 18 decimals)
        maxUSDMANAFee = 5 ether;
        manaUSDAggregatorTolerance = 1 hours;

        // Deploy executor
        vm.startPrank(owner);
        executor = new RegisterNameCrossChainExecutor(
            owner, creditsManager, IERC20(mana), address(coral), maxUSDMANAFee, address(manaUSDAggregator), manaUSDAggregatorTolerance
        );

        // Grant pauser role
        executor.grantRole(executor.PAUSER_ROLE(), pauser);
        vm.stopPrank();

        // Fund creditsManager with MANA
        vm.prank(manaHolder);
        IERC20(mana).transfer(creditsManager, 1000 ether);
    }

    /// @dev Helper function to create a valid external call
    function _createValidExternalCall(uint256 _manaFee) internal view returns (RegisterNameCrossChainExecutor.ExternalCall memory) {
        // Create mock multicall data with correct structure
        MockCoral.Call[] memory calls = new MockCoral.Call[](1);
        calls[0] = MockCoral.Call({
            callType: 0, target: nameRegistry, value: 0, callData: abi.encodeWithSignature("registerName(string)", "test.dcl.eth"), payload: ""
        });

        // Encode the full function call including selector
        // fundAndRunMulticall(address token, uint256 amount, Call[] calldata calls)
        bytes memory data = abi.encodeWithSelector(FUND_AND_RUN_MULTICALL_SELECTOR, mana, NAME_PRICE + _manaFee, calls);

        return RegisterNameCrossChainExecutor.ExternalCall({
            target: address(coral),
            data: data,
            extra: abi.encode(_manaFee)
        });
    }

    /// @dev Helper function to approve and execute
    function _approveAndExecute(RegisterNameCrossChainExecutor.ExternalCall memory _call) internal {
        // Decode the manaFee from extra
        (uint256 manaFee) = abi.decode(_call.extra, (uint256));

        // Transfer manaFee to executor (executor needs this balance)
        if (manaFee > 0) {
            vm.prank(manaHolder);
            IERC20(mana).transfer(address(executor), manaFee);
        }

        // Approve MANA from creditsManager to executor for NAME_PRICE only
        vm.prank(creditsManager);
        IERC20(mana).approve(address(executor), NAME_PRICE);

        // Execute from creditsManager
        vm.prank(creditsManager);
        executor.execute(_call);
    }
}

