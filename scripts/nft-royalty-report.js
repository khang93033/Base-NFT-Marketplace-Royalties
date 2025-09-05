// base-nft-marketplace-royalties/scripts/report.js
const { ethers } = require("hardhat");

async function generateNFTRoyaltyReport() {
  console.log("Generating Base NFT Marketplace Royalty Report...");
  
  const marketplaceAddress = "0x...";
  const marketplace = await ethers.getContractAt("NFTMarketplaceRoyalties", marketplaceAddress);
  
  // Получение статистики по роялти
  const royaltyStats = await marketplace.getRoyaltyStats();
  console.log("Royalty Stats:", {
    totalRoyalties: royaltyStats.totalRoyalties.toString(),
    totalNFTsSold: royaltyStats.totalNFTsSold.toString(),
    avgRoyaltyRate: royaltyStats.avgRoyaltyRate.toString(),
    totalRevenue: royaltyStats.totalRevenue.toString()
  });
  
  // Получение информации о конкретных NFT
  const nftRoyaltyInfo = await marketplace.getNFTRoyaltyInfo(1);
  console.log("NFT Royalty Info:", {
    tokenId: nftRoyaltyInfo.tokenId.toString(),
    royaltyRecipient: nftRoyaltyInfo.royaltyRecipient,
    royaltyPercentage: nftRoyaltyInfo.royaltyPercentage.toString(),
    totalRoyalties: nftRoyaltyInfo.totalRoyalties.toString()
  });
  
  // Получение списка проданных NFT
  const soldNFTs = await marketplace.getSoldNFTs(10);
  console.log("Sold NFTs:", soldNFTs);
  
  // Генерация отчета
  const fs = require("fs");
  const report = {
    timestamp: new Date().toISOString(),
    marketplaceAddress: marketplaceAddress,
    report: {
      royaltyStats: royaltyStats,
      nftRoyaltyInfo: nftRoyaltyInfo,
      soldNFTs: soldNFTs
    }
  };
  
  fs.writeFileSync("./reports/nft-royalty-report.json", JSON.stringify(report, null, 2));
  
  console.log("NFT royalty report generated successfully!");
}

generateNFTRoyaltyReport()
  .catch(error => {
    console.error("Report error:", error);
    process.exit(1);
  });
