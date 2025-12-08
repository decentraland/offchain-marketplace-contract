// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {RegisterNameCrossChainExecutorTestBase} from "test/credits/utils/RegisterNameCrossChainExecutorTestBase.sol";
import {RegisterNameCrossChainExecutor} from "src/credits/executors/RegisterNameCrossChainExecutor.sol";

contract RegisterNameCrossChainExecutorCoreTest is RegisterNameCrossChainExecutorTestBase {
    function test_constructor() public view {
        assertEq(executor.hasRole(executor.DEFAULT_ADMIN_ROLE(), owner), true);
        assertEq(executor.hasRole(executor.PAUSER_ROLE(), pauser), true);
        assertEq(executor.creditsManager(), creditsManager);
        assertEq(address(executor.mana()), mana);
        assertEq(executor.coral(), address(coral));
        assertEq(executor.maxFeeUSD(), maxUSDMANAFee);
        assertEq(address(executor.manaUsdAggregator()), address(manaUsdAggregator));
        assertEq(executor.manaUsdAggregatorTolerance(), manaUsdAggregatorTolerance);
        assertEq(executor.NAME_PRICE(), NAME_PRICE);
    }

    function test_pause_RevertsWhenNotPauser() public {
        vm.expectRevert(abi.encodeWithSelector(RegisterNameCrossChainExecutor.Unauthorized.selector, address(this)));
        executor.pause();
    }

    function test_pause_WhenPauser() public {
        vm.prank(pauser);
        executor.pause();
        assertTrue(executor.paused());
    }

    function test_pause_WhenOwner() public {
        vm.prank(owner);
        executor.pause();
        assertTrue(executor.paused());
    }

    function test_unpause_RevertsWhenNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), executor.DEFAULT_ADMIN_ROLE())
        );
        executor.unpause();
    }

    function test_unpause_RevertsWhenPauser() public {
        vm.startPrank(pauser);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, pauser, executor.DEFAULT_ADMIN_ROLE()));
        executor.unpause();
        vm.stopPrank();
    }

    function test_unpause_WhenOwner() public {
        vm.startPrank(owner);
        executor.pause();
        executor.unpause();
        assertFalse(executor.paused());
        vm.stopPrank();
    }

    function test_updateMaxFeeUSD_RevertsWhenNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), executor.DEFAULT_ADMIN_ROLE())
        );
        executor.updateMaxFeeUSD(10 ether);
    }

    function test_updateMaxFeeUSD_WhenOwner() public {
        uint256 newMaxFee = 10 ether;

        vm.expectEmit(address(executor));
        emit MaxFeeUSDUpdated(newMaxFee);

        vm.prank(owner);
        executor.updateMaxFeeUSD(newMaxFee);

        assertEq(executor.maxFeeUSD(), newMaxFee);
    }

    function test_withdrawERC20_RevertsWhenNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), executor.DEFAULT_ADMIN_ROLE())
        );
        executor.withdrawERC20(mana, 100 ether, owner);
    }

    function test_withdrawERC20_WhenOwner() public {
        // Fund executor with MANA
        uint256 amount = 100 ether;
        vm.prank(manaHolder);
        IERC20(mana).transfer(address(executor), amount);

        uint256 ownerBalanceBefore = IERC20(mana).balanceOf(owner);

        vm.expectEmit(address(executor));
        emit ERC20Withdrawn(owner, mana, amount, owner);

        vm.prank(owner);
        executor.withdrawERC20(mana, amount, owner);

        assertEq(IERC20(mana).balanceOf(owner), ownerBalanceBefore + amount);
        assertEq(IERC20(mana).balanceOf(address(executor)), 0);
    }

    function test_withdrawERC721_RevertsWhenNotOwner() public {
        address nftContract = makeAddr("nftContract");
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), executor.DEFAULT_ADMIN_ROLE())
        );
        executor.withdrawERC721(nftContract, 1, owner);
    }

    function test_withdrawERC721_WhenOwner() public {
        // Deploy a mock ERC721 contract
        MockCollection nftContract = new MockCollection();
        uint256 tokenId = 1;

        // Deploy a helper contract that can receive NFTs and then transfer to executor
        ERC721ReceiverHelper helper = new ERC721ReceiverHelper();

        // Mint NFT to helper first
        nftContract.safeMint(address(helper), tokenId);

        // Helper transfers to executor (using regular transfer, not safeTransfer)
        vm.prank(address(helper));
        nftContract.transferFrom(address(helper), address(executor), tokenId);

        assertEq(nftContract.ownerOf(tokenId), address(executor));
        assertEq(nftContract.balanceOf(address(owner)), 0);

        vm.expectEmit(address(executor));
        emit ERC721Withdrawn(owner, address(nftContract), tokenId, owner);

        vm.prank(owner);
        executor.withdrawERC721(address(nftContract), tokenId, owner);

        assertEq(nftContract.ownerOf(tokenId), owner);
        assertEq(nftContract.balanceOf(owner), 1);
        assertEq(nftContract.balanceOf(address(executor)), 0);
    }
}

// Helper contract to mint NFTs for testing
contract MockCollection is ERC721 {
    constructor() ERC721("MockCollection", "MC") {}

    function safeMint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}

// Helper contract that can receive ERC721 tokens
contract ERC721ReceiverHelper is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

