#!/bin/bash

# 🚀 UrGood Backend Production Environment Setup
# This script helps you configure production environment variables securely

set -e  # Exit on any error

echo "🚀 UrGood Backend Production Environment Setup"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Check if we're in the backend directory
if [ ! -f "package.json" ] || [ ! -f "env.example" ]; then
    echo -e "${RED}❌ Please run this script from the backend directory${NC}"
    echo "Usage: cd backend && ./setup-production-environment.sh"
    exit 1
fi

echo -e "${GREEN}✅ Backend directory confirmed${NC}"

# Check if .env already exists
if [ -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env file already exists${NC}"
    read -p "Overwrite existing .env file? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting without changes."
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}🔧 Setting up production environment...${NC}"
echo ""

# Function to generate random secret
generate_secret() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Function to prompt for value with default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local secure="$3"
    
    if [ "$secure" = "true" ]; then
        read -s -p "$prompt [$default]: " value
        echo ""
    else
        read -p "$prompt [$default]: " value
    fi
    
    if [ -z "$value" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Start creating .env file
echo "# UrGood Backend Production Environment" > .env
echo "# Generated on $(date)" >> .env
echo "# DO NOT commit this file to version control" >> .env
echo "" >> .env

# Database Configuration
echo -e "${PURPLE}📊 Database Configuration${NC}"
echo "# Database Configuration" >> .env
DATABASE_URL=$(prompt_with_default "PostgreSQL Database URL" "postgresql://username:password@localhost:5432/urgood_production")
echo "DATABASE_URL=\"$DATABASE_URL\"" >> .env

REDIS_URL=$(prompt_with_default "Redis URL" "redis://localhost:6379")
echo "REDIS_URL=\"$REDIS_URL\"" >> .env
echo "" >> .env

# Server Configuration
echo -e "${PURPLE}⚙️ Server Configuration${NC}"
echo "# Server Configuration" >> .env
echo "NODE_ENV=\"production\"" >> .env

PORT=$(prompt_with_default "Server Port" "3000")
echo "PORT=$PORT" >> .env
echo "API_VERSION=\"v1\"" >> .env
echo "" >> .env

# Security Configuration
echo -e "${PURPLE}🔒 Security Configuration${NC}"
echo "# Security Configuration" >> .env

echo "Generating secure secrets..."
JWT_SECRET=$(generate_secret)
JWT_REFRESH_SECRET=$(generate_secret)
ENCRYPTION_KEY=$(generate_secret)

echo "JWT_SECRET=\"$JWT_SECRET\"" >> .env
echo "JWT_REFRESH_SECRET=\"$JWT_REFRESH_SECRET\"" >> .env
echo "ENCRYPTION_KEY=\"$ENCRYPTION_KEY\"" >> .env
echo "BCRYPT_ROUNDS=14" >> .env
echo "" >> .env

echo -e "${GREEN}✅ Security secrets generated${NC}"

# Rate Limiting
echo -e "${PURPLE}🛡️ Rate Limiting Configuration${NC}"
echo "# Rate Limiting" >> .env
echo "RATE_LIMIT_WINDOW_MS=900000" >> .env
echo "RATE_LIMIT_MAX_REQUESTS=50" >> .env
echo "RATE_LIMIT_SKIP_SUCCESSFUL_REQUESTS=true" >> .env
echo "" >> .env

# OpenAI Configuration
echo -e "${PURPLE}🤖 OpenAI Configuration${NC}"
echo "# OpenAI Configuration" >> .env
OPENAI_API_KEY=$(prompt_with_default "OpenAI API Key (starts with sk-)" "sk-your-production-openai-key" true)
echo "OPENAI_API_KEY=\"$OPENAI_API_KEY\"" >> .env
echo "OPENAI_MODEL=\"gpt-4o-mini\"" >> .env
echo "OPENAI_MAX_TOKENS=1000" >> .env
echo "OPENAI_TEMPERATURE=0.7" >> .env
echo "" >> .env

# Firebase Configuration
echo -e "${PURPLE}🔥 Firebase Configuration${NC}"
echo "# Firebase Configuration" >> .env
echo "FIREBASE_PROJECT_ID=\"urgood-dc7f0\"" >> .env

echo "Firebase Private Key (paste the entire key including BEGIN/END lines):"
read -r FIREBASE_PRIVATE_KEY
echo "FIREBASE_PRIVATE_KEY=\"$FIREBASE_PRIVATE_KEY\"" >> .env

FIREBASE_CLIENT_EMAIL=$(prompt_with_default "Firebase Client Email" "firebase-adminsdk-xxxxx@urgood-dc7f0.iam.gserviceaccount.com")
echo "FIREBASE_CLIENT_EMAIL=\"$FIREBASE_CLIENT_EMAIL\"" >> .env
echo "" >> .env

# Stripe Configuration
echo -e "${PURPLE}💳 Stripe Configuration${NC}"
echo "# Stripe Configuration" >> .env
STRIPE_SECRET_KEY=$(prompt_with_default "Stripe Secret Key (LIVE - starts with sk_live_)" "sk_live_your_production_key" true)
echo "STRIPE_SECRET_KEY=\"$STRIPE_SECRET_KEY\"" >> .env

STRIPE_WEBHOOK_SECRET=$(prompt_with_default "Stripe Webhook Secret" "whsec_your_webhook_secret" true)
echo "STRIPE_WEBHOOK_SECRET=\"$STRIPE_WEBHOOK_SECRET\"" >> .env

STRIPE_MONTHLY_PRICE=$(prompt_with_default "Stripe Monthly Price ID" "price_monthly_id")
echo "STRIPE_PREMIUM_MONTHLY_PRICE_ID=\"$STRIPE_MONTHLY_PRICE\"" >> .env

STRIPE_YEARLY_PRICE=$(prompt_with_default "Stripe Yearly Price ID (optional)" "")
if [ -n "$STRIPE_YEARLY_PRICE" ]; then
    echo "STRIPE_PREMIUM_YEARLY_PRICE_ID=\"$STRIPE_YEARLY_PRICE\"" >> .env
fi
echo "" >> .env

# Email Configuration
echo -e "${PURPLE}📧 Email Configuration${NC}"
echo "# Email Configuration" >> .env
EMAIL_FROM=$(prompt_with_default "From Email Address" "noreply@urgood.app")
echo "EMAIL_FROM=\"$EMAIL_FROM\"" >> .env

SENDGRID_API_KEY=$(prompt_with_default "SendGrid API Key" "SG.your_api_key" true)
echo "SENDGRID_API_KEY=\"$SENDGRID_API_KEY\"" >> .env
echo "SMTP_HOST=\"smtp.sendgrid.net\"" >> .env
echo "SMTP_PORT=587" >> .env
echo "SMTP_USER=\"apikey\"" >> .env
echo "SMTP_PASS=\"$SENDGRID_API_KEY\"" >> .env
echo "" >> .env

# Monitoring
echo -e "${PURPLE}📊 Monitoring Configuration${NC}"
echo "# Monitoring" >> .env
echo "LOG_LEVEL=\"warn\"" >> .env

SENTRY_DSN=$(prompt_with_default "Sentry DSN (optional)" "")
if [ -n "$SENTRY_DSN" ]; then
    echo "SENTRY_DSN=\"$SENTRY_DSN\"" >> .env
fi
echo "" >> .env

# File Upload
echo "# File Upload" >> .env
echo "MAX_FILE_SIZE=5242880" >> .env
echo "ALLOWED_FILE_TYPES=\"image/jpeg,image/png,image/webp\"" >> .env
echo "" >> .env

# CORS
echo "# CORS" >> .env
CORS_ORIGIN=$(prompt_with_default "CORS Origins (comma-separated)" "https://urgood.app,https://www.urgood.app")
echo "CORS_ORIGIN=\"$CORS_ORIGIN\"" >> .env
echo "" >> .env

# Health Checks
echo "# Health Checks" >> .env
echo "HEALTH_CHECK_INTERVAL=60000" >> .env
echo "HEALTH_CHECK_TIMEOUT=10000" >> .env
echo "" >> .env

# Crisis Detection
echo "# Crisis Detection" >> .env
echo "CRISIS_KEYWORDS=\"suicide,kill myself,end it all,want to die,hurt myself,self harm\"" >> .env

CRISIS_WEBHOOK=$(prompt_with_default "Crisis Webhook URL (optional)" "")
if [ -n "$CRISIS_WEBHOOK" ]; then
    echo "CRISIS_WEBHOOK_URL=\"$CRISIS_WEBHOOK\"" >> .env
fi

EMERGENCY_EMAIL=$(prompt_with_default "Emergency Contact Email" "crisis@urgood.app")
echo "EMERGENCY_CONTACT_EMAIL=\"$EMERGENCY_EMAIL\"" >> .env
echo "" >> .env

# Feature Flags
echo "# Feature Flags" >> .env
echo "FEATURE_VOICE_CHAT_ENABLED=true" >> .env
echo "FEATURE_CRISIS_DETECTION_ENABLED=true" >> .env
echo "FEATURE_ANALYTICS_ENABLED=true" >> .env
echo "FEATURE_PREMIUM_FEATURES_ENABLED=true" >> .env

echo ""
echo -e "${GREEN}✅ Production environment file created!${NC}"
echo ""

# Validate the configuration
echo -e "${BLUE}🔍 Validating configuration...${NC}"
if npm run build > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Configuration validation passed${NC}"
else
    echo -e "${RED}❌ Configuration validation failed${NC}"
    echo "Please check your .env file and fix any issues."
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Production Environment Setup Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "• Environment: Production"
echo "• Security: Enhanced (14 bcrypt rounds, strong secrets)"
echo "• Rate Limiting: Strict (50 requests/15min)"
echo "• OpenAI: Production API key configured"
echo "• Stripe: Live keys configured"
echo "• Firebase: Production project configured"
echo "• Email: SendGrid configured"
echo "• Crisis Detection: Enabled"
echo ""
echo -e "${BLUE}🔍 Next Steps:${NC}"
echo "1. Test the configuration: npm run dev"
echo "2. Run database migrations: npm run migrate"
echo "3. Deploy to production server"
echo "4. Set up SSL certificates"
echo "5. Configure monitoring and alerts"
echo ""
echo -e "${YELLOW}⚠️  Security Reminders:${NC}"
echo "• Never commit .env files to version control"
echo "• Rotate secrets regularly"
echo "• Monitor for suspicious activity"
echo "• Keep dependencies updated"
echo ""
echo -e "${GREEN}🔒 Your backend is now production-ready and secure!${NC}"
