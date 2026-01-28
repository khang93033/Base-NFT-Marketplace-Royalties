// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarketplaceRoyaltiesV2 is ERC721, Ownable, ReentrancyGuard {
    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
        address royaltyRecipient;
        uint256 royaltyPercentage;
        uint256 createdAt;
    }

    struct Bid {
        uint256 tokenId;
        address bidder;
        uint256 amount;
        uint256 createdAt;
        bool active;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Bid[]) public bids;
    mapping(address => uint256[]) public userListings;
    mapping(address => uint256[]) public userBids;
    
    uint256 public listingFee;
    uint256 public bidFee;
    address public feeCollector;
    uint256 public maxRoyaltyPercentage;
    
    // Events
    event NFTListed(uint256 indexed listingId, uint256 indexed tokenId, address seller, uint256 price, address royaltyRecipient, uint256 royaltyPercentage);
    event NFTSold(uint256 indexed listingId, uint256 indexed tokenId, address buyer, address seller, uint256 price, address royaltyRecipient, uint256 royaltyAmount);
    event BidPlaced(uint256 indexed tokenId, address bidder, uint256 amount);
    event BidAccepted(uint256 indexed tokenId, address bidder, uint256 amount);
    event ListingCancelled(uint256 indexed listingId, uint256 indexed tokenId);
    event RoyaltyUpdated(uint256 indexed tokenId, address newRecipient, uint256 newPercentage);
    event FeeUpdated(uint256 newListingFee, uint256 newBidFee, address newFeeCollector);

    constructor() ERC721("BaseNFT", "BNFT") {
        listingFee = 0;
        bidFee = 0;
        feeCollector = address(0);
        maxRoyaltyPercentage = 10000; // 100%
    }

    // Set fees
    function setFees(uint256 _listingFee, uint256 _bidFee, address _feeCollector) external onlyOwner {
        listingFee = _listingFee;
        bidFee = _bidFee;
        feeCollector = _feeCollector;
        emit FeeUpdated(_listingFee, _bidFee, _feeCollector);
    }

    // Set max royalty percentage
    function setMaxRoyaltyPercentage(uint256 _maxRoyaltyPercentage) external onlyOwner {
        require(_maxRoyaltyPercentage <= 10000, "Royalty too high"); // 100%
        maxRoyaltyPercentage = _maxRoyaltyPercentage;
    }

    // List NFT with royalties
    function listNFT(uint256 tokenId, uint256 price, address royaltyRecipient, uint256 royaltyPercentage) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(price > 0, "Price must be greater than 0");
        require(royaltyPercentage <= maxRoyaltyPercentage, "Royalty too high");
        require(royaltyRecipient != address(0), "Invalid royalty recipient");
        
        // Transfer NFT to marketplace
        transferFrom(msg.sender, address(this), tokenId);
        
        uint256 listingId = uint256(keccak256(abi.encodePacked(tokenId, block.timestamp)));
        
        listings[listingId] = Listing({
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true,
            royaltyRecipient: royaltyRecipient,
            royaltyPercentage: royaltyPercentage,
            createdAt: block.timestamp
        });
        
        userListings[msg.sender].push(listingId);
        
        emit NFTListed(listingId, tokenId, msg.sender, price, royaltyRecipient, royaltyPercentage);
    }

    // Buy NFT
    function buyNFT(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(msg.value >= listing.price, "Insufficient funds");
        
        // Calculate fees
        uint256 feeAmount = (listing.price * listingFee) / 10000;
        uint256 sellerAmount = listing.price - feeAmount;
        uint256 royaltyAmount = (listing.price * listing.royaltyPercentage) / 10000;
        uint256 finalSellerAmount = sellerAmount - royaltyAmount;
        
        // Transfer fees
        if (feeAmount > 0 && feeCollector != address(0)) {
            payable(feeCollector).transfer(feeAmount);
        }
        
        // Transfer royalty to creator
        if (royaltyAmount > 0) {
            payable(listing.royaltyRecipient).transfer(royaltyAmount);
        }
        
        // Transfer remaining to seller
        payable(listing.seller).transfer(finalSellerAmount);
        
        // Transfer NFT to buyer
        transferFrom(address(this), msg.sender, listing.tokenId);
        
        // Mark listing as inactive
        listing.active = false;
        
        emit NFTSold(listingId, listing.tokenId, msg.sender, listing.seller, listing.price, listing.royaltyRecipient, royaltyAmount);
    }

    // Cancel listing
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(listing.seller == msg.sender, "Not seller");
        
        // Return NFT to seller
        transferFrom(address(this), listing.seller, listing.tokenId);
        
        // Mark listing as inactive
        listing.active = false;
        
        emit ListingCancelled(listingId, listing.tokenId);
    }

    // Place bid
    function placeBid(uint256 tokenId, uint256 amount) external payable nonReentrant {
        require(amount > 0, "Bid amount must be greater than 0");
        require(msg.value >= amount, "Insufficient funds");
        
        // Store bid
        uint256 bidId = bids[tokenId].length;
        bids[tokenId].push(Bid({
            tokenId: tokenId,
            bidder: msg.sender,
            amount: amount,
            createdAt: block.timestamp,
            active: true
        }));
        
        userBids[msg.sender].push(tokenId);
        
        emit BidPlaced(tokenId, msg.sender, amount);
    }

    // Accept bid
    function acceptBid(uint256 tokenId, uint256 bidId) external nonReentrant {
        require(msg.sender == ownerOf(tokenId), "Not owner");
        
        Bid storage bid = bids[tokenId][bidId];
        require(bid.active, "Bid not active");
        require(bid.amount > 0, "Invalid bid amount");
        
        // Calculate fees and royalties
        uint256 feeAmount = (bid.amount * bidFee) / 10000;
        uint256 royaltyAmount = (bid.amount * listings[uint256(keccak256(abi.encodePacked(tokenId)))].royaltyPercentage) / 10000;
        uint256 sellerAmount = bid.amount - feeAmount - royaltyAmount;
        
        // Transfer fees
        if (feeAmount > 0 && feeCollector != address(0)) {
            payable(feeCollector).transfer(feeAmount);
        }
        
        // Transfer royalty to creator
        if (royaltyAmount > 0) {
            payable(listings[uint256(keccak256(abi.encodePacked(tokenId)))].royaltyRecipient).transfer(royaltyAmount);
        }
        
        // Transfer remaining to seller
        payable(msg.sender).transfer(sellerAmount);
        
        // Transfer NFT to bidder
        transferFrom(address(this), bid.bidder, tokenId);
        
        // Mark bid as inactive
        bid.active = false;
        
        emit BidAccepted(tokenId, bid.bidder, bid.amount);
    }

    // Update royalty info
    function updateRoyaltyInfo(uint256 tokenId, address newRecipient, uint256 newPercentage) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(newPercentage <= maxRoyaltyPercentage, "Royalty too high");
        require(newRecipient != address(0), "Invalid recipient");
        
        // Find listing for this token
        for (uint256 i = 0; i < userListings[msg.sender].length; i++) {
            uint256 listingId = userListings[msg.sender][i];
            if (listings[listingId].tokenId == tokenId) {
                listings[listingId].royaltyRecipient = newRecipient;
                listings[listingId].royaltyPercentage = newPercentage;
                emit RoyaltyUpdated(tokenId, newRecipient, newPercentage);
                return;
            }
        }
        revert("Token not listed by owner");
    }

    // Get listing info
    function getListingInfo(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    // Get bids for token
    function getBidsForToken(uint256 tokenId) external view returns (Bid[] memory) {
        return bids[tokenId];
    }

    // Get user listings
    function getUserListings(address user) external view returns (uint256[] memory) {
        return userListings[user];
    }

    // Get user bids
    function getUserBids(address user) external view returns (uint256[] memory) {
        return userBids[user];
    }

    // Get royalty info
    function getRoyaltyInfo(uint256 tokenId) external view returns (address, uint256) {
        // Find listing for this token
        for (uint256 i = 0; i < 1000000; i++) {
            if (listings[i].tokenId == tokenId && listings[i].active) {
                return (listings[i].royaltyRecipient, listings[i].royaltyPercentage);
            }
        }
        return (address(0), 0);
    }

    // Get total royalty earnings for creator
    function getCreatorEarnings(address creator) external view returns (uint256) {
        uint256 total = 0;
        // Implementation would iterate through all listings
        return total;
    }
    
struct Collection {
    string name;
    string description;
    address creator;
    uint256 royaltyPercentage;
    uint256 totalNFTs;
    bool active;
}


function createCollection(
    string memory name,
    string memory description,
    uint256 royaltyPercentage
) external {
    // Реализация создания коллекции
}

function addNFTToCollection(
    uint256 tokenId,
    address collectionId,
    uint256 royaltyPercentage
) external {
    // Реализация добавления NFT в коллекцию
}
}
