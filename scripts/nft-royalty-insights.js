// base-nft-marketplace-royalties/scripts/insights.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function generateNFTRoyaltyInsights() {
  console.log("Generating royalty insights for Base NFT Marketplace with Royalties...");
  
  const marketplaceAddress = "0x...";
  const marketplace = await ethers.getContractAt("NFTMarketplaceRoyalties", marketplaceAddress);
  
  // Получение инсайтов
  const insights = {
    timestamp: new Date().toISOString(),
    marketplaceAddress: marketplaceAddress,
    royaltyDistribution: {},
    revenueAnalysis: {},
    creatorPerformance: {},
    marketTrends: {},
    optimizationOpportunities: []
  };
  
  // Распределение роялти
  const royaltyDistribution = await marketplace.getRoyaltyDistribution();
  insights.royaltyDistribution = {
    totalRoyalties: royaltyDistribution.totalRoyalties.toString(),
    creatorRoyalties: royaltyDistribution.creatorRoyalties.toString(),
    platformFees: royaltyDistribution.platformFees.toString(),
    avgRoyaltyRate: royaltyDistribution.avgRoyaltyRate.toString()
  };
  
  // Анализ доходов
  const revenueAnalysis = await marketplace.getRevenueAnalysis();
  insights.revenueAnalysis = {
    totalRevenue: revenueAnalysis.totalRevenue.toString(),
    creatorEarnings: revenueAnalysis.creatorEarnings.toString(),
    platformRevenue: revenueAnalysis.platformRevenue.toString(),
    roi: revenueAnalysis.roi.toString()
  };
  
  // Производительность создателей
  const creatorPerformance = await marketplace.getCreatorPerformance();
  insights.creatorPerformance = {
    topCreators: creatorPerformance.topCreators.map(creator => ({
      creatorAddress: creator.creator,
      totalEarnings: creator.totalEarnings.toString(),
      nftsSold: creator.nftsSold.toString(),
      avgRoyalty: creator.avgRoyalty.toString()
    })),
    avgCreatorEarnings: creatorPerformance.avgCreatorEarnings.toString(),
    totalCreators: creatorPerformance.totalCreators.toString()
  };
  
  // Рыночные тренды
  const marketTrends = await marketplace.getMarketTrends();
  insights.marketTrends = {
    trendingCategories: marketTrends.trendingCategories,
    priceRanges: marketTrends.priceRanges,
    volumeTrend: marketTrends.volumeTrend.toString(),
    creatorEngagement: marketTrends.creatorEngagement.toString()
  };
  
  // Возможности оптимизации
  if (parseFloat(insights.royaltyDistribution.avgRoyaltyRate) < 500) { // 5%
    insights.optimizationOpportunities.push("Consider increasing royalty rates for better creator incentives");
  }
  
  if (parseFloat(insights.revenueAnalysis.roi) < 100) { // 1%
    insights.optimizationOpportunities.push("Improve revenue generation strategies");
  }
  
  // Сохранение инсайтов
  const fileName = `nft-royalty-insights-${Date.now()}.json`;
  fs.writeFileSync(`./insights/${fileName}`, JSON.stringify(insights, null, 2));
  
  console.log("NFT royalty insights generated successfully!");
  console.log("File saved:", fileName);
}

generateNFTRoyaltyInsights()
  .catch(error => {
    console.error("Insights error:", error);
    process.exit(1);
  });
