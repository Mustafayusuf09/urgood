#!/bin/bash

# 🔒 Firebase Security Deployment Script
# This script deploys Firestore security rules, indexes, and functions

set -e  # Exit on any error

echo "🔥 Starting Firebase Security Deployment..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not logged in to Firebase. Please run:"
    echo "firebase login"
    exit 1
fi

# Verify we're in the right directory
if [ ! -f "firebase.json" ]; then
    echo "❌ firebase.json not found. Please run this script from the project root."
    exit 1
fi

echo "✅ Prerequisites check passed"

# Deploy Firestore security rules
echo "🛡️  Deploying Firestore security rules..."
if firebase deploy --only firestore:rules; then
    echo "✅ Firestore security rules deployed successfully"
else
    echo "❌ Failed to deploy Firestore security rules"
    exit 1
fi

# Deploy Firestore indexes
echo "📊 Deploying Firestore indexes..."
if firebase deploy --only firestore:indexes; then
    echo "✅ Firestore indexes deployed successfully"
else
    echo "❌ Failed to deploy Firestore indexes"
    exit 1
fi

# Check if Firebase Functions exist and deploy them
if [ -d "firebase-functions" ]; then
    echo "⚡ Deploying Firebase Functions..."
    
    # Check if environment variables are set
    echo "🔍 Checking Firebase Functions configuration..."
    
    # Check OpenAI API key
    if firebase functions:config:get openai.key &> /dev/null; then
        echo "✅ OpenAI API key configured"
    else
        echo "⚠️  OpenAI API key not configured. Set it with:"
        echo "firebase functions:config:set openai.key=\"your-openai-api-key\""
    fi
    
    # Check ElevenLabs API key
    if firebase functions:config:get elevenlabs.key &> /dev/null; then
        echo "✅ ElevenLabs API key configured"
    else
        echo "⚠️  ElevenLabs API key not configured. Set it with:"
        echo "firebase functions:config:set elevenlabs.key=\"your-elevenlabs-api-key\""
    fi
    
    # Deploy functions
    if firebase deploy --only functions; then
        echo "✅ Firebase Functions deployed successfully"
    else
        echo "❌ Failed to deploy Firebase Functions"
        exit 1
    fi
else
    echo "⚠️  Firebase Functions directory not found, skipping functions deployment"
fi

echo ""
echo "🎉 Firebase Security Deployment Complete!"
echo ""
echo "📋 Deployment Summary:"
echo "✅ Firestore Security Rules - Deployed"
echo "✅ Firestore Indexes - Deployed"
if [ -d "firebase-functions" ]; then
    echo "✅ Firebase Functions - Deployed"
fi
echo ""
echo "🔒 Security Features Active:"
echo "• User-based access control"
echo "• Authentication required for all operations"
echo "• Data validation and sanitization"
echo "• Rate limiting protection"
echo "• API key security"
echo "• Comprehensive logging"
echo ""
echo "🔍 Next Steps:"
echo "1. Test security rules in Firebase Console"
echo "2. Monitor function logs for any issues"
echo "3. Verify rate limiting is working"
echo "4. Check analytics data collection"
echo ""
echo "📞 Need help? Check FIREBASE_SECURITY_SETUP.md for detailed documentation"
