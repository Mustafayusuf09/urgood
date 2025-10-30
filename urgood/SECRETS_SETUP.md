# Secrets Configuration Setup

This guide explains how to set up the `Secrets.xcconfig` file for the UrGood iOS app.

## Quick Setup

1. Copy the template file:
   ```bash
   cp Secrets.xcconfig.template Secrets.xcconfig
   ```

2. Edit `Secrets.xcconfig` with your actual API keys and configuration values.

## Required Configuration Values

### RevenueCat API Key
- **Where to get it**: RevenueCat Dashboard → Project Settings → API Keys
- **Format**: `appl_xxxxxxxxxxxxxxxxxxxxxxxxx`
- **Used for**: In-app purchase and subscription management

### OpenAI API Key  
- **Where to get it**: OpenAI Platform → API Keys
- **Format**: `sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- **Used for**: AI chat functionality

### Push Notification Key ID
- **Where to get it**: Apple Developer Portal → Certificates, Identifiers & Profiles → Keys
- **Format**: `XXXXXXXXXX` (10 character alphanumeric)
- **Used for**: Push notifications via APNs

### ElevenLabs API Key
- **Where to get it**: ElevenLabs Dashboard → Profile → API Keys
- **Format**: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- **Used for**: Voice synthesis

### Firebase Web API Key
- **Where to get it**: Firebase Console → Project Settings → General → Web API Key
- **Format**: `AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
- **Used for**: Firebase authentication and services

### Backend Base URL
- **Format**: `https://your-backend-url.com`
- **Used for**: API calls to your backend service

## Security Notes

- ✅ `Secrets.xcconfig` is already added to `.gitignore`
- ✅ Never commit actual API keys to version control
- ✅ Use different keys for development and production
- ✅ Rotate keys regularly for security

## Troubleshooting

If you see fatal errors about missing configuration:
1. Ensure `Secrets.xcconfig` exists in the project root
2. Verify all required values are set (not placeholder values)
3. Clean and rebuild the project in Xcode

## Production Deployment

For production builds:
1. Use production API keys in `Secrets.xcconfig`
2. Verify all services are configured for production
3. Test the configuration with `ProductionConfig.validateConfiguration()`
