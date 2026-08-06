// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetRegistry} from "../registry/AssetRegistry.sol";
import {VerificationRegistry} from "../verification/VerificationRegistry.sol";

contract MarketplaceRegistry {
    enum ListingStatus {
        ACTIVE,
        SOLD,
        DELISTED
    }

    struct Listing {
        bool exists;
        bytes32 listingId;
        bytes32 assetId;
        bytes32 verificationId;
        address seller;
        address paymentToken;
        uint256 price;
        ListingStatus status;
        uint64 createdAt;
    }

    AssetRegistry public immutable assetRegistry;
    VerificationRegistry public immutable verificationRegistry;

    mapping(bytes32 => Listing) private listings;
    mapping(bytes32 => bytes32) private assetToListing;

    event ListingCreated(bytes32 indexed listingId, bytes32 indexed assetId);
    event ListingUpdated(bytes32 indexed listingId);
    event ListingSold(bytes32 indexed listingId);
    event ListingDelisted(bytes32 indexed listingId);

    error ZeroAddress();
    error ZeroPaymentToken();
    error ZeroPrice();
    error AssetDoesNotExist();
    error AssetInactive();
    error NotAssetOwner();
    error VerificationDoesNotExist();
    error VerificationNotVerified();
    error ActiveListingExists();
    error ListingDoesNotExist();
    error NotSeller();
    error ListingNotActive();

    constructor(address _assetRegistry, address _verificationRegistry) {
        if (_assetRegistry == address(0) || _verificationRegistry == address(0)) {
            revert ZeroAddress();
        }
        assetRegistry = AssetRegistry(_assetRegistry);
        verificationRegistry = VerificationRegistry(_verificationRegistry);
    }

    function createListing(bytes32 assetId, bytes32 verificationId, address paymentToken, uint256 price)
        external
        returns (bytes32 listingId)
    {
        if (price == 0) {
            revert ZeroPrice();
        }
        if (paymentToken == address(0)) {
            revert ZeroPaymentToken();
        }

        AssetRegistry.Asset memory asset = assetRegistry.getAsset(assetId);
        if (!asset.exists) {
            revert AssetDoesNotExist();
        }
        if (!asset.active) {
            revert AssetInactive();
        }
        if (msg.sender != asset.owner) {
            revert NotAssetOwner();
        }

        VerificationRegistry.Verification memory v = verificationRegistry.getVerification(verificationId);
        if (!v.exists) {
            revert VerificationDoesNotExist();
        }
        if (v.status != VerificationRegistry.VerificationStatus.VERIFIED) {
            revert VerificationNotVerified();
        }

        bytes32 existingListingId = assetToListing[assetId];
        if (existingListingId != bytes32(0) && listings[existingListingId].status == ListingStatus.ACTIVE) {
            revert ActiveListingExists();
        }

        listingId = keccak256(abi.encodePacked(assetId, verificationId, msg.sender, block.timestamp));

        listings[listingId] = Listing({
            exists: true,
            listingId: listingId,
            assetId: assetId,
            verificationId: verificationId,
            seller: msg.sender,
            paymentToken: paymentToken,
            price: price,
            status: ListingStatus.ACTIVE,
            createdAt: uint64(block.timestamp)
        });

        assetToListing[assetId] = listingId;

        emit ListingCreated(listingId, assetId);
    }

    function updatePrice(bytes32 listingId, uint256 newPrice) external {
        if (newPrice == 0) {
            revert ZeroPrice();
        }

        Listing storage listing = listings[listingId];
        if (!listing.exists) {
            revert ListingDoesNotExist();
        }
        if (msg.sender != listing.seller) {
            revert NotSeller();
        }
        if (listing.status != ListingStatus.ACTIVE) {
            revert ListingNotActive();
        }

        listing.price = newPrice;

        emit ListingUpdated(listingId);
    }

    function markSold(bytes32 listingId) external {
        Listing storage listing = listings[listingId];
        if (!listing.exists) {
            revert ListingDoesNotExist();
        }
        if (listing.status != ListingStatus.ACTIVE) {
            revert ListingNotActive();
        }

        listing.status = ListingStatus.SOLD;

        emit ListingSold(listingId);
    }

    function delist(bytes32 listingId) external {
        Listing storage listing = listings[listingId];
        if (!listing.exists) {
            revert ListingDoesNotExist();
        }
        if (msg.sender != listing.seller) {
            revert NotSeller();
        }
        if (listing.status != ListingStatus.ACTIVE) {
            revert ListingNotActive();
        }

        listing.status = ListingStatus.DELISTED;

        emit ListingDelisted(listingId);
    }

    function getListing(bytes32 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function getListingByAsset(bytes32 assetId) external view returns (Listing memory) {
        return listings[assetToListing[assetId]];
    }
}
