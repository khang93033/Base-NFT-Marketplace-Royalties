// base-nft-marketplace-royalties/test/nft-royalties.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Base NFT Marketplace with Royalties", function () {
  let marketplace;
  let nft;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    
    // Деплой NFT контракта
    const NFT = await ethers.getContractFactory("BaseNFT");
    nft = await NFT.deploy();
    await nft.deployed();
    
    // Деплой Marketplace контракта
    const NFTMarketplaceRoyalties = await ethers.getContractFactory("NFTMarketplaceRoyalties");
    marketplace = await NFTMarketplaceRoyalties.deploy(
      250, // 2.5% platform fee
      1000, // 10% maximum royalty
      3000 // 30% minimum royalty
    );
    await marketplace.deployed();
    
    // Майнинг NFT для владельца
    await nft.mint(owner.address, 1);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await marketplace.owner()).to.equal(owner.address);
    });

    it("Should initialize with correct parameters", async function () {
      expect(await marketplace.platformFeePercentage()).to.equal(250);
      expect(await marketplace.maximumRoyaltyPercentage()).to.equal(1000);
      expect(await marketplace.minimumRoyaltyPercentage()).to.equal(3000);
    });
  });

  describe("Listing with Royalties", function () {
    it("Should create a listing with royalties", async function () {
      await nft.approve(marketplace.address, 1);
      
      await expect(marketplace.listNFT(
        1, 
        ethers.utils.parseEther("0.1"), 
        addr1.address, 
        500 // 5% royalty
      )).to.emit(marketplace, "NFTListed");
    });
  });

  describe("Royalty Calculation", function () {
    beforeEach(async function () {
      await nft.approve(marketplace.address, 1);
      await marketplace.listNFT(1, ethers.utils.parseEther("0.1"), addr1.address, 500);
    });

    it("Should calculate royalty correctly", async function () {
      const royaltyInfo = await marketplace.getRoyaltyInfo(1, ethers.utils.parseEther("0.1"));
      expect(royaltyInfo[0]).to.equal(addr1.address);
      expect(royaltyInfo[1]).to.be.gt(0);
    });
  });
});
