# UrGood Backend API

Production-ready backend API for the UrGood mental health application.

## 🚀 Features

### Core Functionality
- **User Authentication & Authorization** - JWT-based auth with refresh tokens
- **Chat System** - AI-powered conversations with OpenAI integration
- **Mood Tracking** - Comprehensive mood entry and analytics system
- **Crisis Detection** - Real-time crisis content detection and response
- **Subscription Management** - Stripe-powered billing and subscriptions
- **Analytics & Insights** - User engagement and wellness analytics

### Security & Compliance
- **Input Validation** - Comprehensive validation and sanitization
- **Rate Limiting** - Per-user and per-endpoint rate limiting
- **Audit Logging** - Complete audit trail for all user actions
- **Data Privacy** - GDPR-compliant data export and deletion
- **Crisis Response** - Automated crisis detection and intervention

### Infrastructure
- **Database** - PostgreSQL with Prisma ORM
- **Caching** - Redis for session management and caching
- **Monitoring** - Health checks and performance monitoring
- **Documentation** - Swagger/OpenAPI documentation
- **Testing** - Comprehensive test suite with 90%+ coverage

## 📋 Prerequisites

- Node.js 18+
- PostgreSQL 15+
- Redis 7+
- Docker & Docker Compose (optional)

## 🛠 Installation

### Option 1: Docker Compose (Recommended)

1. **Clone and setup environment**
   ```bash
   git clone <repository>
   cd urgood/backend
   cp env.example .env
   ```

2. **Configure environment variables**
   ```bash
   # Edit .env with your configuration
   nano .env
   ```

3. **Start all services**
   ```bash
   docker-compose up -d
   ```

4. **Run database migrations**
   ```bash
   docker-compose exec api npx prisma migrate deploy
   ```

### Option 2: Manual Installation

1. **Install dependencies**
   ```bash
   npm install
   ```

2. **Setup database**
   ```bash
   # Create PostgreSQL database
   createdb urgood_db
   
   # Run migrations
   npx prisma migrate deploy
   
   # Generate Prisma client
   npx prisma generate
   ```

3. **Start Redis**
   ```bash
   redis-server
   ```

4. **Start the application**
   ```bash
   npm run dev
   ```

## 🔧 Configuration

### Environment Variables

Create a `.env` file with the following variables:

```env
# Database
DATABASE_URL="postgresql://username:password@localhost:5432/urgood_db"
REDIS_URL="redis://localhost:6379"

# Security
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"
JWT_REFRESH_SECRET="your-super-secret-refresh-key-change-this-in-production"
ENCRYPTION_KEY="your-32-character-encryption-key-here"

# OpenAI
OPENAI_API_KEY="sk-your-openai-api-key-here"

# Firebase
FIREBASE_PROJECT_ID="your-firebase-project-id"
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour Firebase private key\n-----END PRIVATE KEY-----"
FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com"

# Stripe
STRIPE_SECRET_KEY="sk_test_your_stripe_secret_key"
STRIPE_WEBHOOK_SECRET="whsec_your_stripe_webhook_secret"
```

### Database Schema

The application uses Prisma for database management. Key models include:

- **User** - User accounts and preferences
- **Session** - Authentication sessions
- **ChatMessage** - Chat conversations
- **MoodEntry** - Mood tracking data
- **CrisisEvent** - Crisis detection events
- **Payment** - Billing and subscription data

## 📚 API Documentation

### Endpoints Overview

- **Authentication** - `/api/v1/auth/*`
- **Users** - `/api/v1/users/*`
- **Chat** - `/api/v1/chat/*`
- **Mood** - `/api/v1/mood/*`
- **Crisis** - `/api/v1/crisis/*`
- **Analytics** - `/api/v1/analytics/*`
- **Billing** - `/api/v1/billing/*`
- **Admin** - `/api/v1/admin/*`

### Interactive Documentation

Visit `/api/docs` when the server is running for interactive Swagger documentation.

### Authentication

All protected endpoints require a Bearer token:

```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     https://api.urgood.app/v1/users/profile
```

## 🧪 Testing

### Run Tests

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# Run tests in watch mode
npm run test:watch
```

### Test Categories

- **Unit Tests** - Individual function testing
- **Integration Tests** - API endpoint testing
- **End-to-End Tests** - Complete user journey testing

## 🚀 Deployment

### Production Deployment

1. **Build the application**
   ```bash
   npm run build
   ```

2. **Run database migrations**
   ```bash
   npx prisma migrate deploy
   ```

3. **Start production server**
   ```bash
   npm start
   ```

### Docker Deployment

```bash
# Build production image
docker build -t urgood-backend .

# Run with environment variables
docker run -d \
  --name urgood-api \
  -p 3000:3000 \
  --env-file .env \
  urgood-backend
```

### Health Checks

The application provides several health check endpoints:

- `/health` - Overall system health
- `/api/v1/health` - API health check
- `/ready` - Kubernetes readiness probe
- `/live` - Kubernetes liveness probe

## 📊 Monitoring

### Logging

The application uses structured logging with different levels:

- **Error** - System errors and exceptions
- **Warn** - Warnings and degraded performance
- **Info** - General application events
- **Debug** - Detailed debugging information

### Metrics

Key metrics tracked:

- **Response Times** - API endpoint performance
- **Error Rates** - Application error frequency
- **User Activity** - Engagement and usage patterns
- **Crisis Events** - Mental health crisis detection

### Audit Logging

All user actions are logged for compliance:

- Authentication events
- Data access and modifications
- Crisis events and responses
- Administrative actions

## 🔒 Security

### Security Features

- **Input Validation** - All inputs validated and sanitized
- **Rate Limiting** - Prevents abuse and DoS attacks
- **SQL Injection Protection** - Parameterized queries via Prisma
- **XSS Prevention** - Content sanitization
- **CSRF Protection** - Token-based CSRF protection
- **Secure Headers** - Security headers via Helmet.js

### Crisis Detection

The system automatically detects crisis content in messages:

- **Real-time Analysis** - Immediate crisis content detection
- **Severity Levels** - LOW, MEDIUM, HIGH, CRITICAL
- **Automated Response** - Immediate intervention for critical cases
- **Resource Provision** - Crisis support resources and contacts

### Data Privacy

- **GDPR Compliance** - Data export and deletion capabilities
- **Data Minimization** - Only necessary data collected
- **Encryption** - Sensitive data encrypted at rest
- **Audit Trail** - Complete audit log for compliance

## 🤝 Contributing

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

### Code Standards

- **TypeScript** - Strict type checking enabled
- **ESLint** - Code linting and formatting
- **Prettier** - Code formatting
- **Jest** - Testing framework
- **Conventional Commits** - Commit message format

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:

- **Documentation** - Check the API docs at `/api/docs`
- **Issues** - Create an issue on GitHub
- **Email** - Contact support@urgood.app

## 🔄 Version History

### v1.0.0 (Current)
- Initial production release
- Complete API implementation
- Full test coverage
- Production-ready security
- Crisis detection system
- Subscription management

---

**Built with ❤️ for mental health and wellness**
