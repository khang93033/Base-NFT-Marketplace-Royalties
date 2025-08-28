// base-nft-marketplace-royalties/scripts/deploy.js
const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Base NFT Marketplace with Royalties...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Деплой контракта
  const NFTMarketplaceRoyalties = await ethers.getContractFactory("NFTMarketplaceRoyalties");
  const marketplace = await NFTMarketplaceRoyalties.deploy(
    250, // 2.5% platform fee
    1000, // 10% maximum royalty
    3000 // 30% minimum royalty
  );

  await marketplace.deployed();

  console.log("Base NFT Marketplace with Royalties deployed to:", marketplace.address);
  
  // Сохраняем адрес для дальнейшего использования
  const fs = require("fs");
  const data = {
    marketplace: marketplace.address,
    owner: deployer.address
  };
  
  fs.writeFileSync("./config/deployment.json", JSON.stringify(data, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
