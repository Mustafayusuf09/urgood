# 🚀 UrGood Backend Production Deployment Guide

This guide walks you through deploying the UrGood backend to production with enterprise-grade security and reliability.

## 📋 Prerequisites

### Required Services
- **PostgreSQL 15+** - Primary database
- **Redis 7+** - Caching and session storage
- **Node.js 18+** - Runtime environment
- **SSL Certificate** - For HTTPS encryption
- **Domain Name** - For production access

### Required API Keys
- **OpenAI API Key** - For AI chat functionality
- **Stripe Live Keys** - For payment processing
- **Firebase Admin SDK** - For authentication
- **SendGrid API Key** - For email notifications
- **Sentry DSN** (optional) - For error monitoring

## 🔧 Environment Setup

### 1. Clone and Setup
```bash
git clone <your-repo>
cd urgood/backend
npm install
```

### 2. Configure Environment
```bash
# Run the interactive setup script
./setup-production-environment.sh

# Or manually copy and edit
cp env.production.template .env
# Edit .env with your production values
```

### 3. Generate Secure Secrets
```bash
# Generate JWT secrets
openssl rand -base64 32

# Generate encryption key
openssl rand -base64 32

# Generate database password
openssl rand -base64 16
```

## 🐳 Docker Deployment (Recommended)

### 1. Build and Deploy
```bash
# Build the application
docker-compose build

# Start all services
docker-compose up -d

# Check service health
docker-compose ps
```

### 2. Run Database Migrations
```bash
# Run migrations
docker-compose exec api npm run migrate

# Verify database
docker-compose exec postgres psql -U urgood -d urgood_db -c "\dt"
```

### 3. Verify Deployment
```bash
# Check API health
curl http://localhost:3000/health

# Check logs
docker-compose logs api
```

## 🖥️ Manual Deployment

### 1. Database Setup
```bash
# Install PostgreSQL
sudo apt update
sudo apt install postgresql postgresql-contrib

# Create database and user
sudo -u postgres psql
CREATE DATABASE urgood_production;
CREATE USER urgood WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE urgood_production TO urgood;
\q
```

### 2. Redis Setup
```bash
# Install Redis
sudo apt install redis-server

# Configure Redis
sudo nano /etc/redis/redis.conf
# Set: requirepass your_redis_password

# Restart Redis
sudo systemctl restart redis-server
```

### 3. Application Deployment
```bash
# Build the application
npm run build

# Run database migrations
npm run migrate

# Start with PM2 (recommended)
npm install -g pm2
pm2 start dist/server.js --name urgood-api
pm2 startup
pm2 save
```

## 🔒 Security Configuration

### 1. Firewall Setup
```bash
# Allow only necessary ports
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
sudo ufw enable
```

### 2. SSL Certificate (Let's Encrypt)
```bash
# Install Certbot
sudo apt install certbot

# Get certificate
sudo certbot certonly --standalone -d api.urgood.app

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### 3. Nginx Configuration
```nginx
server {
    listen 80;
    server_name api.urgood.app;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.urgood.app;

    ssl_certificate /etc/letsencrypt/live/api.urgood.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.urgood.app/privkey.pem;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## 📊 Monitoring Setup

### 1. Health Checks
```bash
# API health endpoint
curl https://api.urgood.app/health

# Database health
curl https://api.urgood.app/health/db

# Redis health
curl https://api.urgood.app/health/redis
```

### 2. Log Monitoring
```bash
# Application logs
tail -f logs/app.log

# Error logs
tail -f logs/error.log

# Access logs
tail -f logs/access.log
```

### 3. Performance Monitoring
```bash
# System resources
htop

# Database performance
docker-compose exec postgres pg_stat_activity

# Redis performance
docker-compose exec redis redis-cli info stats
```

## 🔄 Backup Strategy

### 1. Database Backup
```bash
# Create backup script
cat > backup-db.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose exec -T postgres pg_dump -U urgood urgood_db > "backups/db_backup_$DATE.sql"
# Keep only last 7 days
find backups/ -name "db_backup_*.sql" -mtime +7 -delete
EOF

chmod +x backup-db.sh

# Schedule daily backups
crontab -e
# Add: 0 2 * * * /path/to/backup-db.sh
```

### 2. Redis Backup
```bash
# Redis automatically creates dump.rdb
# Copy it regularly
cp /var/lib/redis/dump.rdb backups/redis_backup_$(date +%Y%m%d).rdb
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Environment Variables Not Loading
```bash
# Check .env file exists
ls -la .env

# Verify environment variables
docker-compose exec api printenv | grep -E "(JWT_SECRET|OPENAI_API_KEY|STRIPE_SECRET_KEY)"
```

#### 2. Database Connection Issues
```bash
# Test database connection
docker-compose exec api npm run db:test

# Check database logs
docker-compose logs postgres
```

#### 3. API Key Validation Errors
```bash
# Check API key format
echo $OPENAI_API_KEY | cut -c1-10  # Should show "sk-proj-" or similar
echo $STRIPE_SECRET_KEY | cut -c1-8  # Should show "sk_live_"
```

#### 4. SSL Certificate Issues
```bash
# Check certificate validity
openssl x509 -in /etc/letsencrypt/live/api.urgood.app/cert.pem -text -noout

# Test SSL connection
curl -I https://api.urgood.app/health
```

## 📈 Performance Optimization

### 1. Database Optimization
```sql
-- Create indexes for common queries
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX idx_mood_entries_user_id_date ON mood_entries(user_id, created_at);
```

### 2. Redis Configuration
```bash
# Optimize Redis memory
redis-cli CONFIG SET maxmemory 256mb
redis-cli CONFIG SET maxmemory-policy allkeys-lru
```

### 3. Node.js Optimization
```bash
# Set production environment
export NODE_ENV=production

# Optimize garbage collection
export NODE_OPTIONS="--max-old-space-size=2048"
```

## 🔄 Updates and Maintenance

### 1. Application Updates
```bash
# Pull latest code
git pull origin main

# Install dependencies
npm install

# Build application
npm run build

# Run migrations
npm run migrate

# Restart application
pm2 restart urgood-api
```

### 2. Security Updates
```bash
# Update system packages
sudo apt update && sudo apt upgrade

# Update Node.js dependencies
npm audit fix

# Update Docker images
docker-compose pull
docker-compose up -d
```

## ✅ Production Checklist

### Pre-Deployment
- [ ] All environment variables configured
- [ ] Database migrations tested
- [ ] SSL certificates installed
- [ ] Firewall configured
- [ ] Backup strategy implemented
- [ ] Monitoring setup complete

### Post-Deployment
- [ ] Health checks passing
- [ ] API endpoints responding
- [ ] Database connections working
- [ ] Redis cache functioning
- [ ] Email notifications working
- [ ] Payment processing tested
- [ ] Crisis detection active
- [ ] Logs being written
- [ ] Monitoring alerts configured

### Security Verification
- [ ] No development secrets in production
- [ ] HTTPS enforced
- [ ] Rate limiting active
- [ ] CORS properly configured
- [ ] Security headers present
- [ ] File upload restrictions working
- [ ] Authentication required for protected routes

---

## 📞 Support

For deployment issues:
1. Check the logs: `docker-compose logs api`
2. Verify environment: `docker-compose exec api printenv`
3. Test health endpoints: `curl https://api.urgood.app/health`
4. Review this guide for troubleshooting steps

**Your UrGood backend is now production-ready and secure!** 🚀🔒
