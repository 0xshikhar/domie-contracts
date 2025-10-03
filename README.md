# Domie Smart Contracts

Smart contracts for community funded domain purchases with DOMA Protocol integration.

## 🚀 Deployed Contracts

### Doma Testnet (Chain ID: 97476)
- **CommunityDeal**: `0x216C3C0e1EF077b2268CCAb94E39e538e59f801A`
- **FractionalDomain**: `0x01135C724CA81FD3f8719bFD45E1F82Aad564d6a`

### Sepolia Testnet (Chain ID: 11155111)
- **CommunityDeal**: `0x216C3C0e1EF077b2268CCAb94E39e538e59f801A`

## 📝 Contracts

### CommunityDeal.sol
Main contract for pooling funds and managing community domain purchases.

**Features:**
- Create community deals with target price
- Contribute ETH to deals
- Automatic status updates (ACTIVE → FUNDED → EXECUTED)
- Refund mechanism for expired/cancelled deals
- Governance voting for participants
- Integration with DOMA fractionalization

### FractionalDomain.sol (Optional)
Custom ERC-1155 fractionalization contract if not using DOMA's native solution.


## 🚀 Quick Start

```bash
# 1. Install dependencies
npm install

# 2. Compile contracts
npm run compile

# 3. Deploy CommunityDeal to Doma Testnet
npm run deploy:doma-testnet

# 4. Deploy FractionalDomain to Doma Testnet
npm run deploy:fractional:doma-testnet
```

## 📋 Prerequisites

- Node.js v16+
- npm or yarn
- A wallet with funds on target network

## 🔧 Setup

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Configure environment:**
   Create `.env` file:
   ```env
   PRIVATE_KEY=your_private_key_here
   ```

3. **Compile contracts:**
   ```bash
   npm run compile
   ```

## 🌐 Networks

### Doma Protocol
- **Testnet**: Chain ID 90211
  ```bash
  npm run deploy:doma-testnet
  ```
- **Mainnet**: Chain ID 90210
  ```bash
  npm run deploy:doma-mainnet
  ```

### Base
- **Sepolia**: Chain ID 84532
  ```bash
  npm run deploy:base-sepolia
  ```
- **Mainnet**: Chain ID 8453
  ```bash
  npm run deploy:base
  ```

### Local
```bash
# Terminal 1: Start local node
npx hardhat node

# Terminal 2: Deploy
npm run deploy:local
```

## 📜 Available Scripts

```bash
npm run compile          # Compile contracts
npm run test            # Run tests
npm run clean           # Clean artifacts
npm run setup           # Install & compile

# Deploy CommunityDeal contract
npm run deploy:local    # Deploy to localhost
npm run deploy:doma-testnet    # Deploy to Doma Testnet
npm run deploy:doma-mainnet    # Deploy to Doma Mainnet
npm run deploy:sepolia         # Deploy to Sepolia
npm run deploy:base-sepolia    # Deploy to Base Sepolia
npm run deploy:base            # Deploy to Base

# Deploy FractionalDomain contract
npm run deploy:fractional:doma-testnet    # Deploy to Doma Testnet
npm run deploy:fractional:sepolia         # Deploy to Sepolia
```

## 🔍 Verification

After deployment, verify your contracts:

**CommunityDeal:**
```bash
npx hardhat verify --network domaTestnet 0x216C3C0e1EF077b2268CCAb94E39e538e59f801A "0x0000000000000000000000000000000000000000" "0x0000000000000000000000000000000000000000"
```

**FractionalDomain:**
```bash
npx hardhat verify --network domaTestnet 0x01135C724CA81FD3f8719bFD45E1F82Aad564d6a
```

## 📊 Contract Interaction

### CommunityDeal Contract

```javascript
const hre = require("hardhat");

async function main() {
  const contractAddress = "0x216C3C0e1EF077b2268CCAb94E39e538e59f801A";
  const CommunityDeal = await hre.ethers.getContractFactory("CommunityDeal");
  const contract = CommunityDeal.attach(contractAddress);

  // Create a deal
  const tx = await contract.createDeal(
    "premium.doma",                    // domain name
    hre.ethers.parseEther("5.0"),     // target price
    hre.ethers.parseEther("0.5"),     // min contribution
    10,                                // max participants
    7                                  // duration in days
  );
  await tx.wait();
  console.log("Deal created!");
}

main();
```

### FractionalDomain Contract

```javascript
const hre = require("hardhat");

async function main() {
  const contractAddress = "0x01135C724CA81FD3f8719bFD45E1F82Aad564d6a";
  const FractionalDomain = await hre.ethers.getContractFactory("FractionalDomain");
  const contract = FractionalDomain.attach(contractAddress);

  // Fractionalize a domain
  const tx = await contract.fractionalizeDomain(
    "premium.doma",                                    // domain name
    1000,                                              // total shares
    hre.ethers.parseEther("5.0"),                     // purchase price
    ["0xAddress1", "0xAddress2"],                     // shareholders
    [600, 400]                                         // share amounts
  );
  await tx.wait();
  console.log("Domain fractionalized!");
}

main();
```

### Network Issues

Make sure you're using the correct network names:
- `domaTestnet` (not `doma-testnet`)
- `domaMainnet` (not `doma-mainnet`)
- `baseSepolia` (not `base-sepolia`)

## 📚 Documentation

- [Hardhat Docs](https://hardhat.org/docs)
- [DOMA Protocol](https://docs.doma.xyz)
- [OpenZeppelin](https://docs.openzeppelin.com/contracts)

## 🔐 Security

- Never commit your `.env` file
- Keep your private keys secure
- Test on testnet before mainnet
- Consider auditing before production

## 📄 License

MIT

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---