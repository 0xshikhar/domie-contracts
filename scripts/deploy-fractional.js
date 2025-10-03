const hre = require("hardhat");

async function main() {
  console.log("Deploying FractionalDomain contract...");
  console.log("Network:", hre.network.name);

  // Get deployer account
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);
  console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

  // Deploy FractionalDomain
  console.log("\nDeploying FractionalDomain...");
  const FractionalDomain = await hre.ethers.getContractFactory("FractionalDomain");
  const fractionalDomain = await FractionalDomain.deploy();

  await fractionalDomain.waitForDeployment();
  const address = await fractionalDomain.getAddress();

  console.log("\n✅ FractionalDomain deployed successfully!");
  console.log("Contract address:", address);
  console.log("\nSave this address to your frontend config:");
  console.log(`FRACTIONAL_DOMAIN_ADDRESSES[${hre.network.config.chainId}] = "${address}";`);

  // Verify contract (if not on localhost/hardhat)
  if (hre.network.name !== "localhost" && hre.network.name !== "hardhat") {
    console.log("\nWaiting for block confirmations...");
    await fractionalDomain.deploymentTransaction().wait(5);
    
    console.log("\nTo verify the contract, run:");
    console.log(`npx hardhat verify --network ${hre.network.name} ${address}`);
  }

  // Save deployment info
  const fs = require("fs");
  const deploymentInfo = {
    network: hre.network.name,
    chainId: hre.network.config.chainId,
    contractName: "FractionalDomain",
    contractAddress: address,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    constructorArgs: {}
  };

  const deploymentsDir = "./deployments";
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir);
  }

  fs.writeFileSync(
    `${deploymentsDir}/FractionalDomain-${hre.network.name}-${Date.now()}.json`,
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
