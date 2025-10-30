# UrGood - AI Mental Health Companion

<div align="center">
  <img src="urgood/urgood/Assets.xcassets/AppIcon.appiconset/AppIcon-60@2x.png" alt="UrGood Logo" width="120" height="120">
  
  **Your personal AI mental health companion for ages 16-25**
  
  [![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
  [![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
  [![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
</div>

---

## 🌟 Overview

UrGood is a revolutionary AI-powered mental health platform designed specifically for young adults (ages 16-25). The app provides 24/7 emotional support through intelligent conversations, mood tracking, and personalized insights using evidence-based therapy techniques like CBT and DBT.

### 🎯 Mission
To make mental health support accessible to everyone, everywhere, through innovative AI technology and proven therapy techniques.

### 🔒 Privacy-First Design
- **End-to-end encryption** - Your conversations stay private
- **Local data storage** - All data encrypted on your device
- **Works offline** - No internet? No problem
- **No data sharing** - Your information never leaves your device

---

## ✨ Key Features

### 🗣️ AI Chat Coach
- **Voice-Only Chat** - Natural, speech-first conversations with the AI coach
- **CBT/DBT-Informed Responses** - Evidence-based therapy techniques
- **Crisis Detection** - Automatic detection with emergency resource links
- **Daily Message Limits** - Free users get 10 messages/day
- **Premium Unlimited** - Unlock unlimited conversations

### 💝 Daily Check-ins & Mood Tracking
- **5-Point Mood Scale** - Simple emoji-based interface
- **Mood Tags** - Track context (Exams, Sleep, Friends, etc.)
- **Streak Tracking** - Visual progress rings with milestones
- **7-Day Trends** - See your mood patterns over time
- **Weekly Recaps** - AI-generated insights and recommendations

### 🧠 AI-Powered Insights
- **Advanced Mood Analysis** - Pattern recognition and trend detection
- **Personalized Recommendations** - Tailored suggestions for improvement
- **Session Summaries** - Review your chat sessions and progress
- **Progress Tracking** - Visualize your mental wellness journey

### 🎙️ Voice Chat Features
- **Real-time Voice Conversations** - Natural speech interaction with AI
- **Voice Activity Detection** - Smart conversation flow
- **Audio Playback** - Listen to AI responses
- **Multi-language Support** - Conversational in multiple languages

### 🔥 Streaks & Progress
- **Visual Streak Rings** - Beautiful progress visualization
- **Milestone Tracking** - Celebrate achievements
- **Statistics Dashboard** - Comprehensive progress metrics
- **Achievement System** - Unlock badges and rewards

### 💎 Premium Features
- **Unlimited Conversations** - No daily message limits
- **Advanced AI Insights** - Deeper analysis and recommendations
- **Voice Chat Access** - Full voice conversation capabilities
- **Priority Support** - Enhanced customer service
- **Weekly Wellness Recaps** - Detailed progress reports

---

## 🏗️ Architecture

### iOS App (SwiftUI + MVVM)
Built with modern iOS development practices:

```
urgood/
├── App/                    # Dependency injection & app router
├── Core/                   # Data models, services, local storage
│   ├── Models/            # Data structures
│   ├── Services/          # Business logic services
│   └── Config/            # Configuration & constants
├── Design/                # Theme system & reusable components
├── Features/              # Feature-specific views & view models
│   ├── Chat/             # AI conversation interface
│   ├── Insights/         # Mood analytics & trends
│   ├── VoiceChat/        # Voice conversation features
│   ├── Checkins/         # Daily mood tracking
│   ├── Settings/         # User preferences & profile
│   └── Paywall/          # Premium subscription flow
└── Tests/                # XCTest suites
```

### Backend API (Node.js + TypeScript)
Production-ready backend with comprehensive features:

```
backend/
├── src/
│   ├── routes/           # API endpoints
│   ├── services/         # Business logic
│   ├── middleware/       # Authentication, validation, etc.
│   └── utils/            # Helper functions
├── prisma/              # Database schema & migrations
└── tests/               # Jest test suites
```

### Firebase Functions (TypeScript)
Cloud functions for async processing:

```
firebase-functions/
└── src/
    └── index.ts         # Cloud function handlers
```

---

## 🚀 Getting Started

### Prerequisites
- **iOS Development**: Xcode 15.0+, iOS 17.0+
- **Backend Development**: Node.js 18.0+, npm
- **Database**: PostgreSQL (via Prisma)
- **Firebase**: Account for cloud functions

### iOS App Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/urgood.git
   cd urgood
   ```

2. **Open in Xcode**
   ```bash
   open urgood/urgood.xcodeproj
   ```

3. **Configure your development team**
   - Select the project in Xcode
   - Go to "Signing & Capabilities"
   - Choose your development team

4. **Build and run**
   - Select your target device/simulator
   - Press `Cmd + R` to build and run

### Backend Setup

1. **Install dependencies**
   ```bash
   cd backend
   npm install
   ```

2. **Environment configuration**
   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

3. **Database setup**
   ```bash
   npm run migrate:dev
   npm run db:seed
   ```

4. **Start development server**
   ```bash
   npm run dev
   ```

### Firebase Functions Setup

1. **Install dependencies**
   ```bash
   cd firebase-functions
   npm install
   ```

2. **Deploy functions**
   ```bash
   npm run deploy
   ```

---

## 🧪 Testing

### iOS Tests
```bash
# Run all tests
xcodebuild -scheme urgood -destination 'platform=iOS Simulator,name=iPhone 15' test

# Run the critical voice chat UI test
xcodebuild -scheme urgood -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:UrGoodUITests/testVoiceChat
```

### Backend Tests
```bash
cd backend

# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Run in watch mode
npm run test:watch
```

### Firebase Functions Tests
```bash
cd firebase-functions
npm test
```

---

## 📱 App Store Information

- **App Name**: UrGood
- **Subtitle**: "Your AI mental health companion"
- **Category**: Health & Fitness
- **Age Rating**: 12+ (likely)
- **Price**: Free with in-app purchases
- **Platform**: iOS (Android coming soon)

---

## 🔧 Development Commands

### Backend
```bash
npm run dev          # Start development server
npm run build        # Build for production
npm run start        # Start production server
npm run lint         # Run ESLint
npm run lint:fix     # Fix linting issues
npm run migrate      # Run database migrations
npm run db:seed      # Seed database with test data
```

### Firebase
```bash
npm run build        # Build functions
npm run serve        # Serve locally
npm run deploy       # Deploy to Firebase
```

### iOS
```bash
# Build for device
xcodebuild -scheme urgood -destination 'generic/platform=iOS' build

# Build for simulator
xcodebuild -scheme urgood -destination 'platform=iOS Simulator,name=iPhone 15' build
```

---

## 🛡️ Security & Compliance

- **HIPAA Compliant** - Healthcare data protection standards
- **SOC 2 Type II** - Security and availability controls
- **End-to-End Encryption** - All data encrypted in transit and at rest
- **Local Data Storage** - Sensitive data never leaves the device
- **Regular Security Audits** - Automated security scanning

---

## 📊 Analytics & Monitoring

- **Crash Reporting** - Firebase Crashlytics integration
- **Performance Monitoring** - Real-time performance metrics
- **User Analytics** - Privacy-compliant usage tracking
- **A/B Testing** - Feature flag system for experiments

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Workflow
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🆘 Support

- **Documentation**: [Wiki](https://github.com/yourusername/urgood/wiki)
- **Issues**: [GitHub Issues](https://github.com/yourusername/urgood/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/urgood/discussions)
- **Email**: support@urgood.app

---

## ⚠️ Important Disclaimer

UrGood is not a replacement for professional therapy or medical treatment. If you're experiencing a mental health crisis, please contact your local emergency services or crisis hotline:

- **US**: 988 Suicide & Crisis Lifeline
- **UK**: 116 123 (Samaritans)
- **Canada**: 1-833-456-4566 (Crisis Services Canada)

---

## 🎉 Acknowledgments

- Built with ❤️ for mental health awareness
- Powered by OpenAI's GPT models
- Designed with accessibility in mind
- Inspired by evidence-based therapy practices

---

<div align="center">
  <strong>Made with ❤️ for better mental health</strong>
</div>
