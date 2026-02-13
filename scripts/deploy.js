const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const defaultReceiver = process.env.ROYALTY_RECEIVER || deployer.address;
  const defaultFee = Number(process.env.ROYALTY_FEE || "500"); // 5%

  const M = await ethers.getContractFactory("NFTMarketplaceRoyalties");
  const m = await M.deploy(defaultReceiver, defaultFee);
  await m.deployed();

  console.log("NFTMarketplaceRoyalties:", m.address);

  // Optional: deploy RoyaltyManager if it exists and constructor takes marketplace
  let rmAddr = "";
  try {
    const RM = await ethers.getContractFactory("RoyaltyManager");
    const rm = await RM.deploy(m.address);
    await rm.deployed();
    rmAddr = rm.address;
    console.log("RoyaltyManager:", rmAddr);
  } catch (e) {
    console.log("RoyaltyManager not deployed (constructor mismatch or missing). Skipped.");
  }

  const out = {
    network: hre.network.name,
    chainId: (await ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    contracts: {
      NFTMarketplaceRoyalties: m.address,
      RoyaltyManager: rmAddr || null
    }
  };

  const outPath = path.join(__dirname, "..", "deployments.json");
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log("Saved:", outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
