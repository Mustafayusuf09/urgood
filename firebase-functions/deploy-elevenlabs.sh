#!/bin/bash

# ElevenLabs TTS Firebase Function Deployment Script
# This script helps you securely deploy the ElevenLabs TTS function

set -e  # Exit on error

echo "🚀 ElevenLabs TTS Deployment Script"
echo "===================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found!"
    echo "Install it with: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI found"
echo ""

# Check if logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo "⚠️  Not logged in to Firebase"
    echo "Logging in..."
    firebase login
fi

echo "✅ Logged in to Firebase"
echo ""

# Check current project
CURRENT_PROJECT=$(firebase use | grep -oP '(?<=\[)[^\]]+' | head -1 || echo "")
echo "📍 Current project: ${CURRENT_PROJECT:-Not set}"
echo ""

# Ask if they want to set the API key
read -p "❓ Do you want to set/update the ElevenLabs API key? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔑 Setting ElevenLabs API Key"
    echo "----------------------------"
    echo "Get your API key from: https://elevenlabs.io/app/settings"
    echo ""
    read -p "Enter your ElevenLabs API key: " API_KEY
    
    if [ -z "$API_KEY" ]; then
        echo "❌ API key cannot be empty"
        exit 1
    fi
    
    echo ""
    echo "Setting config..."
    firebase functions:config:set elevenlabs.key="$API_KEY"
    echo "✅ API key configured"
    echo ""
fi

# Show current config
echo "📋 Current Firebase Functions Config:"
echo "-----------------------------------"
firebase functions:config:get
echo ""

# Ask to deploy
read -p "❓ Deploy the synthesizeSpeech function? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "📦 Deploying function..."
    echo "----------------------"
    firebase deploy --only functions:synthesizeSpeech
    
    echo ""
    echo "✅ Deployment complete!"
    echo ""
    echo "🧪 Test the function with:"
    echo "   firebase functions:log --only synthesizeSpeech"
    echo ""
    echo "📱 Your iOS production build will now use this function automatically!"
else
    echo ""
    echo "⏭️  Deployment skipped"
fi

echo ""
echo "✨ Done!"

