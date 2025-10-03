#!/bin/bash

echo "🔧 Setting up Community Deals Smart Contracts..."
echo ""

# Check if node_modules exists
if [ -d "node_modules" ]; then
    echo "📦 Cleaning old dependencies..."
    rm -rf node_modules package-lock.json
fi

echo "📥 Installing dependencies..."
npm install

echo ""
echo "✅ Dependencies installed!"
echo ""
echo "🔨 Compiling contracts..."
npx hardhat compile

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Update .env with your PRIVATE_KEY"
echo "2. Run: npm run deploy:doma-testnet"
echo ""
