# 🎯 Quick Setup Guide for Hackathon Judges

## ⚡ 5-Minute Setup to Test the App

I've funded API keys so you can test the full app functionality! Follow these steps:

### Step 1: Clone the Repository
```bash
git clone https://github.com/yourusername/urgood.git
cd urgood
```

### Step 2: Get the API Keys
**I've provided funded API keys for judges to test the app.**

📧 **Email me for the API keys**: [your-email@example.com]

Or check the hackathon submission platform for the keys file.

### Step 3: Configure the Keys

1. **Create the secrets file**:
   ```bash
   cd urgood/urgood
   cp Secrets.xcconfig.template Secrets.xcconfig
   ```

2. **Edit `Secrets.xcconfig`** with the provided keys:
   ```
   OPENAI_API_KEY = sk-proj-[provided-key]
   ELEVENLABS_API_KEY = [provided-key]
   REVENUECAT_API_KEY = [provided-key]
   ```

### Step 4: Add Firebase Config

1. I've included a `GoogleService-Info.plist` file in the repo for judges
2. If it's missing, email me and I'll send it

### Step 5: Open and Run

```bash
open urgood/urgood.xcodeproj
```

In Xcode:
1. Select your development team in "Signing & Capabilities"
2. Choose a simulator (iPhone 15 Pro recommended)
3. Press `Cmd + R` to build and run

### Step 6: Test Voice Chat

1. Tap "Chat" in the bottom navigation
2. Tap the microphone button to start voice chat
3. Speak: "I'm feeling stressed about my exams"
4. Wait for the AI to respond (should be 1-2 seconds)
5. Continue the conversation naturally

---

## 🎬 Alternative: Watch the Demo Video

If you prefer not to set up the app, watch the demo video:
**[Link to demo video]**

The video shows:
- Voice chat in action
- Real-time AI responses
- Mood tracking features
- Insights dashboard

---

## 🔒 Security Note

**For Judges**: The API keys I've provided are:
- ✅ Funded with sufficient credits for testing
- ✅ Rate-limited to prevent abuse
- ✅ Will be rotated after the hackathon
- ✅ Only for evaluation purposes

**Please don't**:
- ❌ Share the keys publicly
- ❌ Use them for personal projects
- ❌ Commit them to any repository

---

## 💰 API Usage Limits

I've set up the following limits for judge testing:

### OpenAI Realtime API
- **Budget**: $50 credit
- **Usage**: ~$0.30 per minute of voice chat
- **Capacity**: ~150 minutes of testing

### ElevenLabs TTS
- **Budget**: 100,000 characters
- **Usage**: ~200 characters per response
- **Capacity**: ~500 voice responses

### Firebase
- **Free tier**: Unlimited for testing
- **No credit card required**

---

## 🐛 Troubleshooting

### "API Key Not Found"
- Make sure `Secrets.xcconfig` is in `urgood/urgood/` directory
- Check that the keys don't have extra spaces or quotes
- Try cleaning build folder: `Cmd + Shift + K`

### "Failed to Connect"
- Check your internet connection
- Verify Firebase config is present
- Try restarting the app

### "Microphone Permission Denied"
- Go to iOS Settings → Privacy → Microphone
- Enable microphone for the app
- Restart the app

### Build Errors
- Make sure you selected a development team
- Try: `Cmd + Shift + K` (Clean) then `Cmd + R` (Run)
- Check Xcode version is 15.0+

---

## 📞 Need Help?

**Contact me**:
- Email: [your-email@example.com]
- GitHub Issues: [Link to repo issues]
- Discord/Slack: [Your handle]

**Response time**: Within 1 hour during hackathon judging period

---

## ✅ What You Can Test

With the provided API keys, you can test:

### ✅ Full Voice Chat
- Real-time voice conversations
- Natural AI responses
- Emotional intelligence
- Crisis detection

### ✅ Text Chat
- AI coaching conversations
- CBT/DBT techniques
- Personalized responses

### ✅ Mood Tracking
- Daily check-ins
- Mood trends
- Insights dashboard

### ✅ Premium Features
- Unlimited conversations
- Advanced analytics
- Voice chat access

---

## 🎯 Key Features to Test

### 1. Voice Chat (The Main Innovation)
**Test this first!**
1. Start voice chat
2. Say: "I'm feeling really anxious about my presentation tomorrow"
3. Notice the natural, empathetic response
4. Continue the conversation for 2-3 exchanges
5. Observe the low latency and natural flow

### 2. Crisis Detection
**Safety feature:**
1. In chat, type: "I'm having thoughts of hurting myself"
2. Notice immediate crisis resources
3. See how AI prioritizes safety

### 3. Mood Tracking
**Daily wellness:**
1. Tap "Check In" tab
2. Complete a mood check-in
3. View your mood trends
4. See AI-generated insights

### 4. Evidence-Based Techniques
**CBT/DBT in action:**
1. Chat: "I always mess everything up"
2. Notice how AI identifies cognitive distortion
3. See gentle reframing and challenge
4. Observe empowerment focus

---

## 📊 What to Look For

### Technical Excellence
- Sub-2-second voice response latency
- Natural conversation flow
- Robust error handling
- Smooth UI transitions

### User Experience
- Intuitive navigation
- Clear visual feedback
- Accessible design
- Helpful error messages

### AI Quality
- Empathetic responses
- Evidence-based techniques
- Natural language
- Context awareness

### Production Readiness
- Authentication system
- Subscription management
- Offline functionality
- Security measures

---

## 🏆 Judging Criteria Alignment

### Innovation ⭐⭐⭐⭐⭐
- First mental health app using OpenAI Realtime API
- Advanced voice activity detection
- Novel approach to AI therapy

### Technical Execution ⭐⭐⭐⭐⭐
- Production-quality code
- Comprehensive architecture
- Recent critical bug fix

### User Experience ⭐⭐⭐⭐⭐
- Natural voice interactions
- Intuitive interface
- Accessibility features

### Social Impact ⭐⭐⭐⭐⭐
- Addresses mental health crisis
- Evidence-based approach
- Privacy-first design

---

## 🙏 Thank You

Thank you for taking the time to test UrGood! I've put months of work into creating a production-ready mental health platform that could genuinely help millions of young people.

The voice chat feature you're testing represents cutting-edge AI technology (OpenAI Realtime API) combined with evidence-based therapy techniques. I hope you find it as exciting as I do!

**Made with ❤️ for better mental health**

---

## 📝 Feedback

After testing, I'd love to hear your thoughts:
- What worked well?
- What could be improved?
- Any bugs or issues?
- Feature suggestions?

Please share feedback via:
- GitHub Issues
- Email
- Hackathon platform

Your feedback helps make UrGood better for everyone! 🚀
