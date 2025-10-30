# 🎙️ iOS Voice Chat Setup Guide

## 📱 iOS App Direct Setup (No Backend Needed)

Since this is an iOS app, we'll configure it to connect directly to OpenAI's Realtime API for development.

## 🚀 Quick Setup (2 steps)

### Step 1: Get Your OpenAI API Key

1. **Go to OpenAI Platform:**
   - Visit https://platform.openai.com/api-keys
   - Sign in to your account
   - Click "Create new secret key"
   - Copy the key (starts with `sk-`)

### Step 2: Add API Key to Xcode

1. **Open your project in Xcode**
2. **Click the scheme dropdown** (next to the play button)
3. **Select "Edit Scheme..."**
4. **Go to Run → Arguments → Environment Variables**
5. **Click the "+" button**
6. **Add:**
   - **Name:** `OPENAI_API_KEY`
   - **Value:** `sk-proj-abc123xyz...` (your actual key)
7. **Click "Close"**

## 🎯 Test Voice Chat

1. **Build and run** the app (Cmd+R)
2. **Go to the Pulse tab**
3. **Tap the microphone button**
4. **Speak** - you should see "Listening..." 
5. **Wait for Nova's response** - you should hear audio back!

## 🔧 Current Configuration

- **Direct OpenAI Connection:** ✅ No backend needed
- **API Key Source:** Xcode environment variables
- **Model:** `gpt-4o-realtime-preview`
- **Voice:** Nova
- **Mode:** Development

## 🛠 Troubleshooting

### "API key not configured" error:
- Make sure you added `OPENAI_API_KEY` to Xcode environment variables
- Check the key starts with `sk-`
- Rebuild the app after adding the key

### "Connection failed" error:
- Check your internet connection
- Verify the API key is valid on OpenAI platform
- Make sure you have credits in your OpenAI account

### No audio output:
- Check device/simulator volume
- Try with headphones
- Check iOS audio permissions

### "Invalid session.temperature" error:
- This should be fixed in the current code
- If you still see it, let me know!

## 📋 What's Configured

The iOS app is now set up to:
- ✅ Connect directly to OpenAI Realtime API
- ✅ Use environment variable for API key
- ✅ Handle audio input/output properly
- ✅ Show proper UI indicators
- ✅ Handle errors gracefully

## 🎉 Ready to Test!

Just add your OpenAI API key to Xcode environment variables and you're good to go!

---

**Need help?** Check the Xcode console for any error messages while testing.
