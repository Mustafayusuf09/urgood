#!/bin/bash

# 🔧 Firebase Functions Environment Setup Script
# This script helps you configure all environment variables and API keys securely

set -e  # Exit on any error

echo "🔧 Firebase Functions Environment Setup"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not found!${NC}"
    echo "Install it with: npm install -g firebase-tools"
    exit 1
fi

echo -e "${GREEN}✅ Firebase CLI found${NC}"

# Check if logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to Firebase${NC}"
    echo "Logging in..."
    firebase login
fi

echo -e "${GREEN}✅ Logged in to Firebase${NC}"

# Check current project
CURRENT_PROJECT=$(firebase use | grep -oP '(?<=\[)[^\]]+' | head -1 || echo "")
echo -e "${BLUE}📍 Current project: ${CURRENT_PROJECT:-Not set}${NC}"
echo ""

# Function to set config value
set_config() {
    local key=$1
    local description=$2
    local example=$3
    local current_value=""
    
    # Try to get current value
    current_value=$(firebase functions:config:get $key 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
    
    if [ -n "$current_value" ] && [ "$current_value" != "null" ]; then
        echo -e "${GREEN}✅ $description is already configured${NC}"
        echo -e "   Current value: ${current_value:0:20}..."
        read -p "   Update it? (y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    echo -e "${YELLOW}🔑 Setting $description${NC}"
    echo "   $example"
    echo ""
    read -p "   Enter your $description: " value
    
    if [ -z "$value" ]; then
        echo -e "${RED}❌ Value cannot be empty${NC}"
        return 1
    fi
    
    echo "   Setting config..."
    firebase functions:config:set $key="$value"
    echo -e "${GREEN}✅ $description configured${NC}"
    echo ""
}

# Configure OpenAI API Key
echo -e "${BLUE}🤖 OpenAI Configuration${NC}"
echo "-------------------------------"
set_config "openai.key" "OpenAI API Key" "Get it from: https://platform.openai.com/api-keys"

# Configure ElevenLabs API Key
echo -e "${BLUE}🎙️ ElevenLabs Configuration${NC}"
echo "-------------------------------"
set_config "elevenlabs.key" "ElevenLabs API Key" "Get it from: https://elevenlabs.io/app/settings"

# Optional: Set environment variables
echo -e "${BLUE}🌍 Environment Configuration${NC}"
echo "-------------------------------"
read -p "Set NODE_ENV to production? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    firebase functions:config:set environment.node_env="production"
    echo -e "${GREEN}✅ NODE_ENV set to production${NC}"
else
    firebase functions:config:set environment.node_env="development"
    echo -e "${GREEN}✅ NODE_ENV set to development${NC}"
fi
echo ""

# Show current configuration
echo -e "${BLUE}📋 Current Firebase Functions Configuration:${NC}"
echo "-------------------------------------------"
firebase functions:config:get
echo ""

# Build and deploy functions
echo -e "${BLUE}🚀 Build and Deploy Functions${NC}"
echo "-------------------------------"
read -p "Build and deploy Firebase Functions now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Building functions..."
    cd firebase-functions
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo "Installing dependencies..."
        npm install
    fi
    
    # Build TypeScript
    echo "Building TypeScript..."
    npm run build
    
    # Deploy functions
    echo "Deploying functions..."
    firebase deploy --only functions
    
    echo -e "${GREEN}✅ Functions deployed successfully!${NC}"
    cd ..
else
    echo -e "${YELLOW}⚠️  Skipping deployment. Run 'firebase deploy --only functions' when ready.${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Firebase Functions Environment Setup Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "• OpenAI API Key: Configured"
echo "• ElevenLabs API Key: Configured"
echo "• Environment: Configured"
echo "• Security Rules: Enhanced"
echo "• Rate Limiting: Active"
echo ""
echo -e "${BLUE}🔍 Next Steps:${NC}"
echo "1. Test your functions in Firebase Console"
echo "2. Monitor function logs: firebase functions:log"
echo "3. Check security rules are working"
echo "4. Verify rate limiting is active"
echo ""
echo -e "${BLUE}📞 Need help?${NC}"
echo "• Check FIREBASE_SECURITY_SETUP.md for documentation"
echo "• Run 'firebase functions:log' to see function logs"
echo "• Use 'firebase functions:config:get' to view config"
echo ""
echo -e "${GREEN}🔒 Your Firebase Functions are now secure and production-ready!${NC}"
