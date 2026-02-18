require("dotenv").config();
const fs = require("fs");
const path = require("path");

async function main() {
  const depPath = path.join(__dirname, "..", "deployments.json");
  const deployments = JSON.parse(fs.readFileSync(depPath, "utf8"));

  const nftAddr = deployments.contracts.NFTMarketplaceRoyalties;
  const [owner] = await ethers.getSigners();
  const nft = await ethers.getContractAt("NFTMarketplaceRoyalties", nftAddr);

  console.log("NFT:", nftAddr);

  const tx = await nft.mint(owner.address, "ipfs://example");
  const r = await tx.wait();
  const tokenId = r.events.find((e) => e.event === "Minted").args.tokenId.toString();
  console.log("Minted:", tokenId);

  await (await nft.setTokenRoyalty(tokenId, owner.address, 777)).wait();
  console.log("Set token royalty");

  const info = await nft.royaltyInfo(tokenId, ethers.utils.parseEther("1"));
  console.log("RoyaltyInfo:", info[0], info[1].toString());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

