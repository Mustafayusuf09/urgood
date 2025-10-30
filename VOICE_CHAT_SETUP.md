# 🎙️ Voice Chat Setup Guide

## ✅ Current Status
- ✅ Backend voice server running on port 3001
- ✅ iOS app configured for development mode
- ⚠️ OpenAI API key needs to be added

## 🚀 Quick Setup (3 steps)

### Step 1: Add Your OpenAI API Key

1. **Get your OpenAI API key:**
   - Go to https://platform.openai.com/api-keys
   - Create a new key or copy existing one (starts with `sk-`)

2. **Update the .env file:**
   ```bash
   # Open the .env file
   open /Users/mustafayusuf/urgood/backend/.env
   ```
   
3. **Replace the placeholder:**
   Change this line:
   ```
   OPENAI_API_KEY=sk-your-openai-api-key-here
   ```
   To your actual key:
   ```
   OPENAI_API_KEY=sk-proj-abc123xyz...
   ```

### Step 2: Restart the Voice Server

```bash
# Kill any existing server
pkill -f "voice-server.js"

# Start the voice server
cd /Users/mustafayusuf/urgood/backend
PORT=3001 node voice-server.js
```

You should see:
```
🚀 Voice Chat Server running on port 3001
✅ OpenAI API key configured
```

### Step 3: Test in iOS App

1. **Build and run the app** (Cmd+R in Xcode)
2. **Go to Pulse tab** 
3. **Tap the microphone button**
4. **Speak** - you should see "Listening..." indicator
5. **Wait for response** - Nova should respond with audio

## 🔧 Troubleshooting

### "API key not configured" error:
- Make sure you saved the .env file after editing
- Restart the voice server after changing the API key

### "Connection failed" error:
- Check that voice server is running on port 3001
- Try: `curl http://localhost:3001/health`

### No audio output:
- Check device volume
- Try with headphones
- Check iOS simulator audio settings

### "Unauthorized" error:
- The app is in development mode, so it should work without authentication
- If you see this, check the backend logs

## 📱 Current Configuration

- **Backend URL:** `http://localhost:3001`
- **Voice endpoint:** `/api/v1/voice/realtime-token`
- **Mode:** Development (no auth required)
- **OpenAI Model:** `gpt-4o-realtime-preview`

## 🎯 Next Steps

Once voice chat works:
1. Add proper authentication for production
2. Deploy backend to cloud service
3. Update iOS app with production backend URL
4. Test with real users

---

**Need help?** The voice server logs will show what's happening. Check the terminal where you ran `node voice-server.js`.
