# base-nft-marketplace-royalties/contracts/NFTMarketplaceRoyalties.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarketplaceRoyalties is ERC721, Ownable, ReentrancyGuard {
    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
        address royaltyRecipient;
        uint256 royaltyPercentage;
    }
    
    struct Sale {
        uint256 tokenId;
        address buyer;
        address seller;
        uint256 price;
        uint256 royaltyAmount;
        uint256 timestamp;
    }
    
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Sale) public sales;
    mapping(address => uint256[]) public sellerSales;
    
    uint256 public platformFeePercentage;
    uint256 public nextSaleId;
    
    event NFTListed(uint256 indexed listingId, uint256 indexed tokenId, address seller, uint256 price);
    event NFTSold(uint256 indexed saleId, uint256 indexed tokenId, address buyer, address seller, uint256 price, uint256 royaltyAmount);
    event PlatformFeeUpdated(uint256 newFee);
    
    constructor(
        uint256 _platformFeePercentage
    ) ERC721("BaseNFT", "BNFT") {
        platformFeePercentage = _platformFeePercentage;
    }
    
    function setPlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 10000, "Fee too high"); // Maximum 100%
        platformFeePercentage = newFee;
        emit PlatformFeeUpdated(newFee);
    }
    
    function listNFT(
        uint256 tokenId,
        uint256 price,
        address royaltyRecipient,
        uint256 royaltyPercentage
    ) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(listings[tokenId].active == false, "Already listed");
        require(royaltyPercentage <= 10000, "Royalty too high"); // Maximum 100%
        
        listings[tokenId] = Listing({
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true,
            royaltyRecipient: royaltyRecipient,
            royaltyPercentage: royaltyPercentage
        });
        
        emit NFTListed(tokenId, tokenId, msg.sender, price);
    }
    
    function buyNFT(uint256 tokenId) external payable nonReentrant {
        Listing storage listing = listings[tokenId];
        require(listing.active, "Not for sale");
        require(msg.value >= listing.price, "Insufficient funds");
        
        uint256 platformFee = (listing.price * platformFeePercentage) / 10000;
        uint256 royaltyAmount = (listing.price * listing.royaltyPercentage) / 10000;
        uint256 sellerAmount = listing.price - platformFee - royaltyAmount;
        
        // Transfer funds
        payable(listing.seller).transfer(sellerAmount);
        payable(owner()).transfer(platformFee);
        payable(listing.royaltyRecipient).transfer(royaltyAmount);
        
        // Transfer NFT
        transferFrom(listing.seller, msg.sender, tokenId);
        
        // Update listing
        listing.active = false;
        
        // Record sale
        uint256 saleId = nextSaleId++;
        sales[saleId] = Sale({
            tokenId: tokenId,
            buyer: msg.sender,
            seller: listing.seller,
            price: listing.price,
            royaltyAmount: royaltyAmount,
            timestamp: block.timestamp
        });
        
        sellerSales[listing.seller].push(saleId);
        
        emit NFTSold(saleId, tokenId, msg.sender, listing.seller, listing.price, royaltyAmount);
    }
    
    function cancelListing(uint256 tokenId) external {
        Listing storage listing = listings[tokenId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.active, "Not listed");
        
        listing.active = false;
        emit NFTSold(0, tokenId, address(0), listing.seller, 0, 0);
    }
    
    function getRoyaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address, uint256) {
        Listing storage listing = listings[tokenId];
        if (listing.active) {
            uint256 royaltyAmount = (salePrice * listing.royaltyPercentage) / 10000;
            return (listing.royaltyRecipient, royaltyAmount);
        }
        return (address(0), 0);
    }
    
    function getSalesBySeller(address seller) external view returns (uint256[] memory) {
        return sellerSales[seller];
    }
}
