// base-nft-marketplace-royalties/scripts/tracking.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function trackNFTRoyalties() {
  console.log("Tracking royalties for Base NFT Marketplace with Royalties...");
  
  const marketplaceAddress = "0x...";
  const marketplace = await ethers.getContractAt("NFTMarketplaceRoyalties", marketplaceAddress);
  
  // Получение информации о роялти
  const royaltyTracking = {
    timestamp: new Date().toISOString(),
    marketplaceAddress: marketplaceAddress,
    totalRoyalties: "0",
    totalNFTs: 0,
    royaltyRecipients: {},
    topRoyaltyRecipients: [],
    dailyRoyaltyStats: []
  };
  
  // Получение статистики по роялти
  const totalRoyalties = await marketplace.getTotalRoyalties();
  royaltyTracking.totalRoyalties = totalRoyalties.toString();
  
  const totalNFTs = await marketplace.getTotalNFTs();
  royaltyTracking.totalNFTs = totalNFTs.toNumber();
  
  // Получение списка получателей роялти
  const royaltyRecipients = await marketplace.getRoyaltyRecipients();
  console.log("Royalty recipients:", royaltyRecipients.length);
  
  // Сбор статистики по каждому получателю
  for (let i = 0; i < Math.min(10, royaltyRecipients.length); i++) {
    const recipient = royaltyRecipients[i];
    const recipientRoyalties = await marketplace.getRecipientRoyalties(recipient);
    
    royaltyTracking.royaltyRecipients[recipient] = {
      totalRoyalties: recipientRoyalties.toString(),
      nftsSold: await marketplace.getRecipientNFTsSold(recipient)
    };
  }
  
  // Получение статистики за последние 7 дней
  const dailyStats = [];
  for (let i = 0; i < 7; i++) {
    const day = new Date();
    day.setDate(day.getDate() - i);
    
    const dayStats = await marketplace.getDayRoyaltyStats(day.toISOString().split('T')[0]);
    dailyStats.push({
      date: day.toISOString().split('T')[0],
      royalties: dayStats.toString()
    });
  }
  
  royaltyTracking.dailyRoyaltyStats = dailyStats;
  
  // Поиск топ получателей
  const sortedRecipients = Object.entries(royaltyTracking.royaltyRecipients)
    .sort(([,a], [,b]) => parseInt(b.totalRoyalties) - parseInt(a.totalRoyalties))
    .slice(0, 5);
  
  royaltyTracking.topRoyaltyRecipients = sortedRecipients.map(([address, data]) => ({
    address: address,
    totalRoyalties: data.totalRoyalties,
    nftsSold: data.nftsSold
  }));
  
  // Сохранение отчета
  fs.writeFileSync(`./royalty/royalty-tracking-${Date.now()}.json`, JSON.stringify(royaltyTracking, null, 2));
  
  console.log("Royalty tracking completed successfully!");
  console.log("Total NFTs:", royaltyTracking.totalNFTs);
  console.log("Top recipients:", royaltyTracking.topRoyaltyRecipients.length);
}

trackNFTRoyalties()
  .catch(error => {
    console.error("Royalty tracking error:", error);
    process.exit(1);
  });
