// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/registry/AssetRegistry.sol";
import "../../src/verification/VerificationRegistry.sol";
import "../../src/marketplace/MarketplaceRegistry.sol";

contract MarketplaceRegistryTest is Test {
    AssetRegistry assetRegistry;
    VerificationRegistry verificationRegistry;
    MarketplaceRegistry marketplaceRegistry;

    address seller = address(0x100);
    address nonOwner = address(0x200);
    address paymentToken = address(0x300);

    bytes32 assetHash = keccak256("asset_content");
    bytes32 transcriptHash = keccak256("transcript_content");
    bytes32 sandboxVersion = keccak256("sandbox_v1");

    bytes32 assetId;
    bytes32 verificationId;
    uint256 initialPrice = 500 * 10 ** 18;

    event ListingCreated(bytes32 indexed listingId, bytes32 indexed assetId);
    event ListingUpdated(bytes32 indexed listingId);
    event ListingSold(bytes32 indexed listingId);
    event ListingDelisted(bytes32 indexed listingId);

    function setUp() public {
        assetRegistry = new AssetRegistry();
        verificationRegistry = new VerificationRegistry(address(assetRegistry));
        marketplaceRegistry = new MarketplaceRegistry(address(assetRegistry), address(verificationRegistry));

        vm.prank(seller);
        assetId = assetRegistry.registerAsset(assetHash);

        vm.prank(seller);
        verificationId = verificationRegistry.requestVerification(assetId, transcriptHash, sandboxVersion);

        // Complete verification
        verificationRegistry.completeVerification(verificationId, VerificationRegistry.VerificationStatus.VERIFIED);
    }

    function testListingCreation() public {
        vm.startPrank(seller);

        bytes32 expectedListingId = keccak256(abi.encodePacked(assetId, verificationId, seller, block.timestamp));

        vm.expectEmit(true, true, false, false);
        emit ListingCreated(expectedListingId, assetId);

        bytes32 listingId = marketplaceRegistry.createListing(assetId, verificationId, paymentToken, initialPrice);
        assertEq(listingId, expectedListingId);
        vm.stopPrank();

        MarketplaceRegistry.Listing memory listing = marketplaceRegistry.getListing(listingId);
        assertTrue(listing.exists);
        assertEq(listing.listingId, listingId);
        assertEq(listing.assetId, assetId);
        assertEq(listing.verificationId, verificationId);
        assertEq(listing.seller, seller);
        assertEq(listing.paymentToken, paymentToken);
        assertEq(listing.price, initialPrice);
        assertTrue(listing.status == MarketplaceRegistry.ListingStatus.ACTIVE);

        MarketplaceRegistry.Listing memory listingByAsset = marketplaceRegistry.getListingByAsset(assetId);
        assertEq(listingByAsset.listingId, listingId);
    }

    function testZeroPriceRejection() public {
        vm.prank(seller);
        vm.expectRevert(MarketplaceRegistry.ZeroPrice.selector);
        marketplaceRegistry.createListing(assetId, verificationId, paymentToken, 0);
    }

    function testZeroPaymentTokenRejection() public {
        vm.prank(seller);
        vm.expectRevert(MarketplaceRegistry.ZeroPaymentToken.selector);
        marketplaceRegistry.createListing(assetId, verificationId, address(0), initialPrice);
    }

    function testNonOwnerRevert() public {
        vm.prank(nonOwner);
        vm.expectRevert(MarketplaceRegistry.NotAssetOwner.selector);
        marketplaceRegistry.createListing(assetId, verificationId, paymentToken, initialPrice);
    }

    function testDuplicateListingRevert() public {
        vm.startPrank(seller);
        marketplaceRegistry.createListing(assetId, verificationId, paymentToken, initialPrice);

        vm.expectRevert(MarketplaceRegistry.ActiveListingExists.selector);
        marketplaceRegistry.createListing(assetId, verificationId, paymentToken, initialPrice);
        vm.stopPrank();
    }

    function testPriceUpdate() public {
        vm.prank(seller);
        bytes32 listingId = marketplaceRegistry.createListing(assetId, verificationId, paymentToken, initialPrice);

        uint256 newPrice = 800 * 10 ** 18;

        vm.startPrank(seller);
        vm.expectEmit(true, false, false, false);
        emit ListingUpdated(listingId);

        marketplaceRegistry.updatePrice(listingId, newPrice);
        vm.stopPrank();

        assertEq(marketplaceRegistry.getListing(listingId).price, newPrice);
    }

    function testSoldTransition() public {
        vm.prank(seller);
        bytes32 listingId = marketplaceRegistry.createListing(assetId, verificationId, paymentToken, initialPrice);

        vm.expectEmit(true, false, false, false);
        emit ListingSold(listingId);

        marketplaceRegistry.markSold(listingId);

        assertTrue(marketplaceRegistry.getListing(listingId).status == MarketplaceRegistry.ListingStatus.SOLD);
    }

    function testDelistTransition() public {
        vm.prank(seller);
        bytes32 listingId = marketplaceRegistry.createListing(assetId, verificationId, paymentToken, initialPrice);

        vm.startPrank(seller);
        vm.expectEmit(true, false, false, false);
        emit ListingDelisted(listingId);

        marketplaceRegistry.delist(listingId);
        vm.stopPrank();

        assertTrue(marketplaceRegistry.getListing(listingId).status == MarketplaceRegistry.ListingStatus.DELISTED);
    }

    function testTerminalStateImmutability() public {
        vm.prank(seller);
        bytes32 listingId = marketplaceRegistry.createListing(assetId, verificationId, paymentToken, initialPrice);

        marketplaceRegistry.markSold(listingId);

        // Cannot update price, sell, or delist a SOLD listing
        vm.startPrank(seller);
        vm.expectRevert(MarketplaceRegistry.ListingNotActive.selector);
        marketplaceRegistry.updatePrice(listingId, 900);

        vm.expectRevert(MarketplaceRegistry.ListingNotActive.selector);
        marketplaceRegistry.delist(listingId);
        vm.stopPrank();

        vm.expectRevert(MarketplaceRegistry.ListingNotActive.selector);
        marketplaceRegistry.markSold(listingId);
    }

    function testGetterValidation() public {
        bytes32 dummyId = keccak256("dummy");
        MarketplaceRegistry.Listing memory listing = marketplaceRegistry.getListing(dummyId);
        assertFalse(listing.exists);
        assertEq(listing.price, 0);

        MarketplaceRegistry.Listing memory listingByAsset = marketplaceRegistry.getListingByAsset(dummyId);
        assertFalse(listingByAsset.exists);
    }
}
