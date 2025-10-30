# urgood - AI Mental Health Coach

A SwiftUI iOS app designed to provide mental health support for ages 16-25 through AI-powered conversations, mood tracking, and personalized insights.

## Features

### 🗣️ AI Chat Coach
- Voice chat with CBT/DBT-informed AI responses
- Crisis detection with emergency resource links
- Daily message limits for free users
- Premium unlocks unlimited conversations

### 💝 Daily Check-ins
- 5-point mood scale with emoji interface
- Optional mood tags (Exams, Sleep, Friends, etc.)
- Streak tracking and progress visualization
- 7-day mood trends

### 🧠 AI-Powered Insights
- Advanced mood analysis and trend detection
- Personalized recommendations and insights
- Crisis detection and emergency support
- Session summaries and progress tracking

### 🔥 Streaks & Progress
- Visual streak ring with milestone tracking
- Statistics dashboard
- Progress towards goals
- Achievement system

### 💎 Premium Features
- Unlimited chat conversations
- Advanced AI insights and recommendations
- Detailed insights and trends
- Voice chat (coming soon)
- Priority support

## Architecture

Built with **SwiftUI + MVVM** architecture:

- **App Layer**: Dependency injection container, app router
- **Core Layer**: Data models, services, local storage
- **Design Layer**: Theme system, reusable components
- **Features Layer**: Chat, check-ins, insights, streaks, paywall

### Key Components

- **DIContainer**: Manages all services and dependencies
- **LocalStore**: UserDefaults-based persistence
- **Mock Services**: Offline-capable with realistic data
- **Theme System**: Consistent colors, typography, spacing
- **Component Library**: Buttons, cards, badges, progress rings

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

1. Clone the repository
2. Open `urgood.xcodeproj` in Xcode
3. Select your development team in project settings
4. Build and run on device or simulator

## Project Structure

```
urgood/
├── App/
│   ├── DIContainer.swift          # Dependency injection
│   └── AppRouter.swift            # Navigation routing
├── Core/
│   ├── Models/                    # Data models
│   ├── Services/                  # Business logic
│   └── Storage/                   # Data persistence
├── Design/
│   ├── Theme.swift                # Design system
│   └── Components/                # Reusable UI components
├── Features/
│   ├── Chat/                      # AI chat interface
│   ├── Checkins/                  # Mood tracking
│   ├── VoiceChat/                 # Voice chat functionality
│   ├── Streaks/                   # Progress tracking
│   └── Paywall/                   # Premium subscription
└── ContentView.swift              # Main tab view
```

## Design System

### Colors
- **Brand Primary**: Blue-violet (#6633CC)
- **Brand Secondary**: Mint (#99E6B3)
- **Background**: Off-white (#FAFAFA)
- **Semantic**: Success, warning, error states

### Typography
- **Headings**: SF Rounded (bold)
- **Body**: SF Pro (regular)
- **Scale**: Large title (34pt) to caption (12pt)

### Components
- **Cards**: Elevated surfaces with shadows
- **Buttons**: Primary, secondary, destructive styles
- **Chips**: Selectable tags and filters
- **Progress**: Rings, bars, and indicators

## Mock Services

All external dependencies are mocked for offline development:

- **ChatService**: Generates CBT/DBT-informed responses
- **CheckinService**: Manages mood entries and streaks
- **CrisisDetectionService**: AI-powered crisis detection
- **BillingService**: Simulates subscription management
- **CrisisDetectionService**: Keyword-based crisis detection

## Crisis Safety

The app includes crisis detection and emergency resources:

- **Keywords**: suicide, self-harm, etc.
- **Resources**: US 988, crisis text lines, emergency services
- **Disclaimer**: Clear "not therapy" messaging
- **Help Sheet**: Immediate crisis intervention

## Development Notes

- **Offline First**: All features work without internet
- **Mock Data**: Seeded with realistic sample content
- **Preview Support**: SwiftUI previews for all components
- **Accessibility**: Dynamic Type, VoiceOver, large hit areas
- **Dark Mode**: Full light/dark theme support

## Future Enhancements

- Voice chat integration
- Advanced analytics and insights
- Voice chat features
- Professional therapist connections
- Wearable device integration

## Disclaimer

This app is for educational and development purposes. It is not a substitute for professional mental health care. For emergencies, contact local crisis services or call 911 (US) or your local emergency number.

## License

This project is for demonstration purposes. Please ensure compliance with all applicable laws and regulations when using mental health-related content.
