# 🤖 OpenAI AI Integration Setup Guide

This guide will help you set up OpenAI integration for urgood's AI-powered chat and voice features.

## 🚀 Quick Start

### 1. Get Your OpenAI API Key

1. Go to [OpenAI Platform](https://platform.openai.com/api-keys)
2. Sign in or create an account
3. Click "Create new secret key"
4. Copy the generated API key (starts with `sk-`)

### 2. Configure the App

1. Open `urgood/Core/Config/APIConfig.swift`
2. Configure your API key in `Secrets.xcconfig`:

```
OPENAI_API_KEY = sk-your-actual-api-key-here
```

The app now uses secure environment-based configuration instead of hardcoded keys.

3. Save the file and restart the app

## 🔧 Configuration Options

### AI Model Selection

In `APIConfig.swift`, you can choose different AI models:

```swift
// Cost-effective (recommended for development)
static let openAIModel = "gpt-4o-mini"

// More capable but more expensive
static let openAIModel = "gpt-4o"

// Most capable but most expensive
static let openAIModel = "gpt-4-turbo"
```

### Voice Configuration

Choose different TTS voices:

```swift
// Warm, friendly (default)
static let ttsVoice = "alloy"

// Other options:
// static let ttsVoice = "echo"    // Bright, energetic
// static let ttsVoice = "fable"   // Soft, gentle
// static let ttsVoice = "onyx"    // Deep, authoritative
// static let ttsVoice = "nova"    // Clear, professional
// static let ttsVoice = "shimmer" // Warm, expressive
```

### Response Settings

Adjust AI response characteristics:

```swift
// More focused responses (0.0) vs creative (1.0)
static let temperature = 0.7

// Maximum response length
static let maxTokens = 1000
```

## 💰 Cost Management

### Pricing (as of 2024)

- **GPT-4o-mini**: $0.00015 per 1K input tokens, $0.0006 per 1K output tokens
- **GPT-4o**: $0.005 per 1K input tokens, $0.015 per 1K output tokens
- **Whisper (transcription)**: $0.006 per minute
- **TTS**: $0.015 per 1K characters

### Estimated Costs

For typical mental health conversations:
- **Voice conversation**: ~$0.01-0.02 per exchange (transcription + response)
- **Daily usage (10 messages)**: ~$0.10-0.20

### Cost Control

1. **Set daily limits** in `APIConfig.swift`:
```swift
static let dailyMessageLimit = 10
```

2. **Monitor usage** at [OpenAI Usage](https://platform.openai.com/usage)

3. **Use GPT-4o-mini** for development and testing

## 🧪 Testing

### 1. Test Voice Chat

1. Run the app
2. Open the Pulse/Chat screen
3. Tap the microphone button to start listening
4. Speak a message and wait for the transcript to animate
5. Verify the AI responds and audio playback begins

### 2. Test Error Handling

1. Temporarily use invalid API key
2. Test network disconnection
3. Verify graceful error messages

## 🛡️ Security Best Practices

### 1. Never Commit API Keys

Add to `.gitignore`:
```
# API Keys
**/APIConfig.swift
```

### 2. Use Environment Variables (Production)

```swift
static let openAIAPIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
```

### 3. Key Rotation

- Rotate API keys regularly
- Use different keys for development/production
- Monitor for unauthorized usage

## 🚨 Troubleshooting

### Common Issues

#### "API key not configured"
- Check `APIConfig.swift`
- Ensure API key is not empty
- Restart app after changes

#### "Invalid API key"
- Verify key format (starts with `sk-`)
- Check key at [OpenAI Platform](https://platform.openai.com/api-keys)
- Ensure account has credits

#### "Rate limit exceeded"
- Wait before sending more messages
- Check usage limits
- Consider upgrading OpenAI plan

#### "Network error"
- Check internet connection
- Verify firewall settings
- Check OpenAI status at [status.openai.com](https://status.openai.com)

### Debug Mode

Enable debug logging in `APIConfig.swift`:

```swift
static let debugMode = true
```

## 📱 Production Deployment

### 1. Environment Configuration

```swift
#if DEBUG
    static let openAIAPIKey = "dev-key-here"
#else
    static let openAIAPIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
#endif
```

### 2. Error Monitoring

- Implement crash reporting (Crashlytics, Sentry)
- Log API errors for debugging
- Monitor user experience metrics

### 3. Rate Limiting

- Implement client-side rate limiting
- Add exponential backoff for retries
- Graceful degradation when limits exceeded

## 🔍 Monitoring & Analytics

### Track Usage

- Message count per user
- Voice vs text usage
- Response times
- Error rates

### Cost Optimization

- Monitor token usage
- Optimize prompt engineering
- Use appropriate models for use cases

## 📚 Additional Resources

- [OpenAI API Documentation](https://platform.openai.com/docs)
- [OpenAI Pricing](https://openai.com/pricing)
- [OpenAI Status](https://status.openai.com)
- [OpenAI Community](https://community.openai.com)

## 🆘 Support

If you encounter issues:

1. Check this troubleshooting guide
2. Review OpenAI documentation
3. Check OpenAI status page
4. Contact OpenAI support if needed

---

**Note**: OpenAI services are subject to their terms of service and pricing. Monitor your usage and costs regularly.
