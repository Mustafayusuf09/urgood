# Multi-stage build for production optimization
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY prisma ./prisma/

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY . .

# Generate Prisma client
RUN npx prisma generate

# Build the application
RUN npm run build

# Production stage
FROM node:18-alpine AS production

# Create app user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S urgood -u 1001

# Set working directory
WORKDIR /app

# Copy built application from builder stage
COPY --from=builder --chown=urgood:nodejs /app/dist ./dist
COPY --from=builder --chown=urgood:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=urgood:nodejs /app/package*.json ./
COPY --from=builder --chown=urgood:nodejs /app/prisma ./prisma

# Create logs directory
RUN mkdir -p logs && chown urgood:nodejs logs

# Install production dependencies only
RUN npm ci --only=production && npm cache clean --force

# Switch to non-root user
USER urgood

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start the application
CMD ["npm", "start"]
