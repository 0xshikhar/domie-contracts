const hre = require("hardhat");

async function main() {
  console.log("Deploying CommunityDeal contract...");
  console.log("Network:", hre.network.name);

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

  // DOMA contract addresses - UPDATE THESE FOR YOUR NETWORK
  const DOMA_ADDRESSES = {
    domaMainnet: {
      ownershipToken: "0x0000000000000000000000000000000000000000", // TODO: Get from DOMA docs
      fractionalization: "0x0000000000000000000000000000000000000000" // TODO: Get from DOMA docs
    },
    domaTestnet: {
      ownershipToken: "0x0000000000000000000000000000000000000000", // TODO: Get from DOMA docs
      fractionalization: "0x0000000000000000000000000000000000000000" // TODO: Get from DOMA docs
    },
    // For testing on other networks, use placeholder addresses
    localhost: {
      ownershipToken: "0x0000000000000000000000000000000000000001",
      fractionalization: "0x0000000000000000000000000000000000000002"
    },
    hardhat: {
      ownershipToken: "0x0000000000000000000000000000000000000001",
      fractionalization: "0x0000000000000000000000000000000000000002"
    }
  };

  const networkAddresses = DOMA_ADDRESSES[hre.network.name] || DOMA_ADDRESSES.localhost;
  
  console.log("\nConstructor arguments:");
  console.log("- DOMA Ownership Token:", networkAddresses.ownershipToken);
  console.log("- DOMA Fractionalization:", networkAddresses.fractionalization);

  // Deploy CommunityDeal
  console.log("\nDeploying CommunityDeal...");
  const CommunityDeal = await hre.ethers.getContractFactory("CommunityDeal");
  const communityDeal = await CommunityDeal.deploy(
    networkAddresses.ownershipToken,
    networkAddresses.fractionalization
  );

  await communityDeal.waitForDeployment();
  const address = await communityDeal.getAddress();

  console.log("\n✅ CommunityDeal deployed successfully!");
  console.log("Contract address:", address);
  console.log("\nSave this address to your frontend config:");
  console.log(`COMMUNITY_DEAL_ADDRESSES[${hre.network.config.chainId}] = "${address}";`);

  // Verify contract (if not on localhost/hardhat)
  if (hre.network.name !== "localhost" && hre.network.name !== "hardhat") {
    console.log("\nWaiting for block confirmations...");
    await communityDeal.deploymentTransaction().wait(5);
    
    console.log("\nTo verify the contract, run:");
    console.log(`npx hardhat verify --network ${hre.network.name} ${address} "${networkAddresses.ownershipToken}" "${networkAddresses.fractionalization}"`);
  }

  // Save deployment info
  const fs = require("fs");
  const deploymentInfo = {
    network: hre.network.name,
    chainId: hre.network.config.chainId,
    contractAddress: address,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    constructorArgs: {
      domaOwnershipToken: networkAddresses.ownershipToken,
      domaFractionalization: networkAddresses.fractionalization
    }
  };

  const deploymentsDir = "./deployments";
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }

  fs.writeFileSync(
    `${deploymentsDir}/${hre.network.name}-${Date.now()}.json`,
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("\nDeployment info saved to deployments/ directory");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
