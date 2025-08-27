// base-nft-marketplace-royalties/contracts/NFTMarketplaceRoyaltiesV2.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract NFTMarketplaceRoyaltiesV2 is ERC721, Ownable, ReentrancyGuard {
    using Address for address payable;

    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
        address royaltyRecipient;
        uint256 royaltyPercentage;
        uint256 createdAt;
        uint256 listingId;
    }

    struct Sale {
        uint256 tokenId;
        address buyer;
        address seller;
        uint256 price;
        uint256 royaltyAmount;
        uint256 platformFee;
        uint256 timestamp;
        uint256 saleId;
    }

    struct Collection {
        string name;
        string description;
        address creator;
        uint256 totalSupply;
        uint256 floorPrice;
        uint256 totalVolume;
        mapping(address => bool) verifiedCreators;
    }

    struct CollectionStats {
        uint256 totalSales;
        uint256 totalRevenue;
        uint256 avgSalePrice;
        uint256 highestSale;
        uint256 lowestSale;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Sale) public sales;
    mapping(address => uint256[]) public sellerSales;
    mapping(address => Collection) public collections;
    mapping(address => CollectionStats) public collectionStats;
    
    // Конфигурация
    uint256 public platformFeePercentage;
    uint256 public minimumListingPrice;
    uint256 public maximumRoyaltyPercentage;
    uint256 public nextSaleId;
    uint256 public nextListingId;
    uint256 public totalVolume;
    uint256 public totalTrades;
    
    // Статистика коллекций
    mapping(string => address[]) public collectionNFTs;
    mapping(string => uint256) public collectionCount;
    
    // События
    event NFTListed(
        uint256 indexed listingId, 
        uint256 indexed tokenId, 
        address seller, 
        uint256 price,
        uint256 royaltyPercentage,
        uint256 createdAt
    );
    
    event NFTSold(
        uint256 indexed saleId,
        uint256 indexed tokenId, 
        address buyer, 
        address seller, 
        uint256 price, 
        uint256 royaltyAmount,
        uint256 platformFee,
        uint256 timestamp
    );
    
    event ListingCancelled(uint256 indexed listingId, uint256 indexed tokenId, address seller);
    event FeeUpdated(uint256 newFee);
    event CollectionCreated(string indexed collectionName, address creator, uint256 timestamp);
    event CollectionVerified(string indexed collectionName, address verifier, bool verified);
    event RoyaltyUpdated(uint256 indexed listingId, address newRecipient, uint256 newPercentage);

    constructor(
        uint256 _platformFeePercentage,
        uint256 _minimumListingPrice,
        uint256 _maximumRoyaltyPercentage
    ) ERC721("BaseNFT", "BNFT") {
        platformFeePercentage = _platformFeePercentage;
        minimumListingPrice = _minimumListingPrice;
        maximumRoyaltyPercentage = _maximumRoyaltyPercentage;
    }
    
    // Создание коллекции
    function createCollection(
        string memory name,
        string memory description
    ) external {
        require(bytes(name).length > 0, "Collection name cannot be empty");
        
        collections[msg.sender] = Collection({
            name: name,
            description: description,
            creator: msg.sender,
            totalSupply: 0,
            floorPrice: 0,
            totalVolume: 0,
            verifiedCreators: new mapping(address => bool)
        });
        
        collections[msg.sender].verifiedCreators[msg.sender] = true;
        
        emit CollectionCreated(name, msg.sender, block.timestamp);
    }
    
    // Верификация коллекции
    function verifyCollection(
        string memory collectionName,
        address verifier
    ) external {
        Collection storage collection = collections[verifier];
        require(bytes(collection.name).length > 0, "Collection does not exist");
        require(collection.creator != address(0), "Invalid collection");
        
        collection.verifiedCreators[verifier] = true;
        emit CollectionVerified(collectionName, verifier, true);
    }
    
    // Установка комиссии платформы
    function setPlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 10000, "Fee too high"); // Maximum 100%
        platformFeePercentage = newFee;
        emit FeeUpdated(newFee);
    }
    
    // Создание листинга NFT с коллекцией
    function listNFT(
        uint256 tokenId,
        uint256 price,
        address royaltyRecipient,
        uint256 royaltyPercentage,
        string memory collectionName
    ) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(listings[tokenId].active == false, "Already listed");
        require(price >= minimumListingPrice, "Price too low");
        require(royaltyPercentage <= maximumRoyaltyPercentage, "Royalty too high");
        require(royaltyRecipient != address(0), "Invalid royalty recipient");
        
        // Проверка принадлежности к коллекции
        Collection storage collection = collections[msg.sender];
        require(bytes(collection.name).length > 0, "Collection does not exist");
        
        listings[tokenId] = Listing({
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true,
            royaltyRecipient: royaltyRecipient,
            royaltyPercentage: royaltyPercentage,
            createdAt: block.timestamp,
            listingId: nextListingId++
        });
        
        // Обновление статистики коллекции
        collection.totalSupply = collection.totalSupply + 1;
        if (collection.floorPrice == 0 || price < collection.floorPrice) {
            collection.floorPrice = price;
        }
        
        // Добавление в коллекцию
        collectionNFTs[collectionName].push(tokenId);
        collectionCount[collectionName]++;
        
        emit NFTListed(
            listings[tokenId].listingId,
            tokenId,
            msg.sender,
            price,
            royaltyPercentage,
            block.timestamp
        );
    }
    
    // Покупка NFT
    function buyNFT(uint256 tokenId) external payable nonReentrant {
        Listing storage listing = listings[tokenId];
        require(listing.active, "Not for sale");
        require(msg.value >= listing.price, "Insufficient funds");
        
        // Расчет комиссий
        uint256 platformFee = (listing.price * platformFeePercentage) / 10000;
        uint256 royaltyAmount = (listing.price * listing.royaltyPercentage) / 10000;
        uint256 sellerAmount = listing.price - platformFee - royaltyAmount;
        
        // Перевод средств
        payable(listing.seller).sendValue(sellerAmount);
        payable(owner()).sendValue(platformFee);
        payable(listing.royaltyRecipient).sendValue(royaltyAmount);
        
        // Передача NFT
        transferFrom(listing.seller, msg.sender, tokenId);
        
        // Отметить листинг как завершенный
        listing.active = false;
        
        // Записать продажу
        uint256 saleId = nextSaleId++;
        sales[saleId] = Sale({
            tokenId: tokenId,
            buyer: msg.sender,
            seller: listing.seller,
            price: listing.price,
            royaltyAmount: royaltyAmount,
            platformFee: platformFee,
            timestamp: block.timestamp,
            saleId: saleId
        });
        
        sellerSales[listing.seller].push(saleId);
        
        // Обновить статистику
        totalVolume += listing.price;
        totalTrades++;
        
        // Обновить статистику коллекции
        Collection storage collection = collections[listing.seller];
        collection.totalVolume += listing.price;
        
        emit NFTSold(
            saleId,
            tokenId,
            msg.sender,
            listing.seller,
            listing.price,
            royaltyAmount,
            platformFee,
            block.timestamp
        );
    }
    
    // Получение информации о коллекции
    function getCollectionInfo(string memory collectionName) external view returns (Collection memory) {
        return collections[msg.sender];
    }
    
    // Получение статистики коллекции
    function getCollectionStats(string memory collectionName) external view returns (CollectionStats memory) {
        return collectionStats[msg.sender];
    }
    
    // Получение NFT коллекции
    function getCollectionNFTs(string memory collectionName) external view returns (uint256[] memory) {
        return collectionNFTs[collectionName];
    }
    
    // Получение количества NFT в коллекции
    function getCollectionCount(string memory collectionName) external view returns (uint256) {
        return collectionCount[collectionName];
    }
    
    // Получение статистики продаж
    function getMarketplaceStats() external view returns (
        uint256 volume,
        uint256 trades,
        uint256 totalListings,
        uint256 activeListings
    ) {
        uint256 active = 0;
        for (uint256 i = 0; i < type(uint256).max; i++) {
            if (listings[i].active) active++;
        }
        return (totalVolume, totalTrades, i, active);
    }
    
    // Получение истории продаж продавца
    function getSellerSales(address seller) external view returns (uint256[] memory) {
        return sellerSales[seller];
    }
    
    // Получение информации о листинге
    function getListingInfo(uint256 tokenId) external view returns (Listing memory) {
        return listings[tokenId];
    }
    
    // Получение информации о продаже
    function getSaleInfo(uint256 saleId) external view returns (Sale memory) {
        return sales[saleId];
    }
    
    // Получение коллекций пользователя
    function getUserCollections(address user) external view returns (string[] memory) {
        // Реализация в будущем
        return new string[](0);
    }
}
