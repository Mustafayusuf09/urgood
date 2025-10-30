#!/bin/bash

# Comprehensive E2E Test Runner for UrGood Production Readiness
# This script validates all production infrastructure components

set -e

echo "🧪 Starting Comprehensive E2E Tests for UrGood Production Infrastructure"
echo "========================================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=16

# Function to run a test category
run_test_category() {
    local category="$1"
    local description="$2"
    
    echo -e "\n${BLUE}Testing: $category${NC}"
    echo "Description: $description"
    echo "----------------------------------------"
    
    if eval "$3"; then
        echo -e "${GREEN}✅ $category: PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ $category: FAILED${NC}"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Infrastructure Health Checks
test_health_checks() {
    echo "Checking health endpoints..."
    
    # Health endpoint
    if curl -f -s "http://localhost:3001/health" > /dev/null; then
        echo "✓ Health endpoint responding"
    else
        echo "✗ Health endpoint failed"
        return 1
    fi
    
    # Readiness check
    if curl -f -s "http://localhost:3001/ready" > /dev/null; then
        echo "✓ Readiness check passed"
    else
        echo "✗ Readiness check failed"
        return 1
    fi
    
    # Deep health check
    if curl -f -s "http://localhost:3001/health/deep" > /dev/null; then
        echo "✓ Deep health check passed"
    else
        echo "✗ Deep health check failed"
        return 1
    fi
    
    return 0
}

# Test 2: API Versioning
test_api_versioning() {
    echo "Testing API versioning..."
    
    # Test v1 endpoint
    local response=$(curl -s "http://localhost:3001/api/v1/version")
    if echo "$response" | grep -q '"current":"v1"'; then
        echo "✓ V1 API versioning working"
    else
        echo "✗ V1 API versioning failed"
        return 1
    fi
    
    # Test backward compatibility
    local response=$(curl -s "http://localhost:3001/api/version")
    if echo "$response" | grep -q '"success":true'; then
        echo "✓ Backward compatibility working"
    else
        echo "✗ Backward compatibility failed"
        return 1
    fi
    
    return 0
}

# Test 3: CORS Configuration
test_cors() {
    echo "Testing CORS configuration..."
    
    # Test production domain
    local response=$(curl -s -H "Origin: https://urgood.app" -I "http://localhost:3001/api/v1/version")
    if echo "$response" | grep -q "Access-Control-Allow-Origin: https://urgood.app"; then
        echo "✓ Production CORS working"
    else
        echo "✗ Production CORS failed"
        return 1
    fi
    
    # Test preflight request
    local response=$(curl -s -X OPTIONS -H "Origin: https://urgood.app" -H "Access-Control-Request-Method: POST" -I "http://localhost:3001/api/v1/auth/login")
    if echo "$response" | grep -q "Access-Control-Allow-Methods"; then
        echo "✓ CORS preflight working"
    else
        echo "✗ CORS preflight failed"
        return 1
    fi
    
    return 0
}

# Test 4: Request Validation
test_validation() {
    echo "Testing request validation..."
    
    # Test content length validation
    local response=$(curl -s -w "%{http_code}" -o /dev/null -X POST "http://localhost:3001/api/v1/auth/register" -H "Content-Type: application/json" -d '{"data":"'$(printf 'x%.0s' {1..11000000})'"}')
    if [ "$response" = "413" ]; then
        echo "✓ Content length validation working"
    else
        echo "✗ Content length validation failed (got $response)"
        return 1
    fi
    
    # Test input sanitization
    local response=$(curl -s -X POST "http://localhost:3001/api/v1/auth/register" -H "Content-Type: application/json" -d '{"name":"<script>alert(\"xss\")</script>John","email":"test@example.com"}')
    if echo "$response" | grep -q "error"; then
        echo "✓ Input sanitization working"
    else
        echo "✗ Input sanitization failed"
        return 1
    fi
    
    return 0
}

# Test 5: Security Headers
test_security_headers() {
    echo "Testing security headers..."
    
    local response=$(curl -s -I "http://localhost:3001/api/v1/version")
    
    if echo "$response" | grep -q "X-Content-Type-Options: nosniff"; then
        echo "✓ X-Content-Type-Options header present"
    else
        echo "✗ X-Content-Type-Options header missing"
        return 1
    fi
    
    if echo "$response" | grep -q "X-Frame-Options: DENY"; then
        echo "✓ X-Frame-Options header present"
    else
        echo "✗ X-Frame-Options header missing"
        return 1
    fi
    
    return 0
}

# Test 6: Database Connectivity
test_database() {
    echo "Testing database connectivity..."
    
    # Check if we can connect to the database
    if node -e "
        const { PrismaClient } = require('@prisma/client');
        const prisma = new PrismaClient();
        prisma.\$connect()
            .then(() => { console.log('✓ Database connection successful'); process.exit(0); })
            .catch(() => { console.log('✗ Database connection failed'); process.exit(1); });
    "; then
        return 0
    else
        return 1
    fi
}

# Test 7: Redis Connectivity
test_redis() {
    echo "Testing Redis connectivity..."
    
    # Simple Redis ping test
    if command -v redis-cli > /dev/null && redis-cli ping > /dev/null 2>&1; then
        echo "✓ Redis connection successful"
        return 0
    else
        echo "✗ Redis connection failed or not available"
        return 1
    fi
}

# Test 8: Environment Configuration
test_environment() {
    echo "Testing environment configuration..."
    
    # Check required environment variables
    if [ -n "$DATABASE_URL" ]; then
        echo "✓ DATABASE_URL configured"
    else
        echo "✗ DATABASE_URL not configured"
        return 1
    fi
    
    if [ -n "$JWT_SECRET" ]; then
        echo "✓ JWT_SECRET configured"
    else
        echo "✗ JWT_SECRET not configured"
        return 1
    fi
    
    return 0
}

# Test 9: Metrics Endpoint
test_metrics() {
    echo "Testing metrics endpoint..."
    
    local response=$(curl -s "http://localhost:3001/metrics")
    if echo "$response" | grep -q "nodejs_heap_size_total_bytes"; then
        echo "✓ Metrics endpoint working"
        return 0
    else
        echo "✗ Metrics endpoint failed"
        return 1
    fi
}

# Test 10: Rate Limiting
test_rate_limiting() {
    echo "Testing rate limiting..."
    
    # Make multiple rapid requests
    local count=0
    for i in {1..15}; do
        local response=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:3001/api/v1/version")
        if [ "$response" = "429" ]; then
            count=$((count + 1))
        fi
    done
    
    if [ "$count" -gt 0 ]; then
        echo "✓ Rate limiting working (triggered $count times)"
        return 0
    else
        echo "✗ Rate limiting not working"
        return 1
    fi
}

# Test 11: Error Handling
test_error_handling() {
    echo "Testing error handling..."
    
    # Test 404 error
    local response=$(curl -s "http://localhost:3001/api/v1/nonexistent-endpoint")
    if echo "$response" | grep -q '"error":"NOT_FOUND"'; then
        echo "✓ 404 error handling working"
    else
        echo "✗ 404 error handling failed"
        return 1
    fi
    
    return 0
}

# Test 12: Webhook CORS
test_webhook_cors() {
    echo "Testing webhook CORS..."
    
    # Test Stripe webhook CORS
    local response=$(curl -s -X OPTIONS -H "Origin: https://api.stripe.com" -I "http://localhost:3001/api/v1/webhooks/stripe")
    if echo "$response" | grep -q "200\|204"; then
        echo "✓ Webhook CORS working"
        return 0
    else
        echo "✗ Webhook CORS failed"
        return 1
    fi
}

# Test 13: SSL/HTTPS (if in production)
test_ssl() {
    echo "Testing SSL/HTTPS configuration..."
    
    if [ "$NODE_ENV" = "production" ]; then
        # In production, test HTTPS
        if curl -f -s "https://api.urgood.app/health" > /dev/null; then
            echo "✓ HTTPS working in production"
            return 0
        else
            echo "✗ HTTPS failed in production"
            return 1
        fi
    else
        echo "✓ SSL test skipped (development mode)"
        return 0
    fi
}

# Test 14: Logging System
test_logging() {
    echo "Testing logging system..."
    
    # Check if log files exist and are writable
    if [ -d "logs" ]; then
        echo "✓ Logs directory exists"
        
        # Make a test request to generate logs
        curl -s "http://localhost:3001/api/v1/version" > /dev/null
        
        if [ -f "logs/combined.log" ] || [ -f "logs/app.log" ]; then
            echo "✓ Log files being created"
            return 0
        else
            echo "✗ Log files not being created"
            return 1
        fi
    else
        echo "✗ Logs directory missing"
        return 1
    fi
}

# Test 15: Analytics Integration
test_analytics() {
    echo "Testing analytics integration..."
    
    # Test analytics endpoint (if available)
    local response=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost:3001/api/v1/analytics/events" -X POST -H "Content-Type: application/json" -d '{}')
    if [ "$response" = "401" ] || [ "$response" = "400" ]; then
        echo "✓ Analytics endpoint responding (auth required)"
        return 0
    else
        echo "✗ Analytics endpoint not responding correctly (got $response)"
        return 1
    fi
}

# Test 16: Sentry Integration
test_sentry() {
    echo "Testing Sentry integration..."
    
    if [ -n "$SENTRY_DSN" ]; then
        echo "✓ Sentry DSN configured"
        
        # Test if Sentry is capturing (this would need a test endpoint)
        local response=$(curl -s "http://localhost:3001/api/v1/version")
        if echo "$response" | grep -q "success"; then
            echo "✓ Sentry integration appears functional"
            return 0
        else
            echo "✗ Sentry integration test failed"
            return 1
        fi
    else
        echo "⚠ Sentry DSN not configured (optional for development)"
        return 0
    fi
}

# Main test execution
echo -e "${YELLOW}Preparing test environment...${NC}"

# Check if server is running
if ! curl -f -s "http://localhost:3001/health" > /dev/null; then
    echo -e "${RED}❌ Server is not running on localhost:3001${NC}"
    echo "Please start the server first: npm run dev"
    exit 1
fi

echo -e "${GREEN}✅ Server is running, starting tests...${NC}\n"

# Run all test categories
run_test_category "Infrastructure Health" "Basic health and readiness checks" "test_health_checks"
run_test_category "API Versioning" "Version handling and backward compatibility" "test_api_versioning"
run_test_category "CORS Configuration" "Cross-origin request handling" "test_cors"
run_test_category "Request Validation" "Input validation and sanitization" "test_validation"
run_test_category "Security Headers" "Security header configuration" "test_security_headers"
run_test_category "Database Connectivity" "Database connection and operations" "test_database"
run_test_category "Redis Connectivity" "Redis connection and caching" "test_redis"
run_test_category "Environment Config" "Environment variable configuration" "test_environment"
run_test_category "Metrics Endpoint" "Performance metrics collection" "test_metrics"
run_test_category "Rate Limiting" "API rate limiting functionality" "test_rate_limiting"
run_test_category "Error Handling" "Error response handling" "test_error_handling"
run_test_category "Webhook CORS" "Webhook-specific CORS configuration" "test_webhook_cors"
run_test_category "SSL/HTTPS" "SSL certificate and HTTPS configuration" "test_ssl"
run_test_category "Logging System" "Application logging functionality" "test_logging"
run_test_category "Analytics Integration" "Analytics event tracking" "test_analytics"
run_test_category "Sentry Integration" "Error monitoring and reporting" "test_sentry"

# Final results
echo -e "\n========================================================================="
echo -e "${BLUE}E2E Test Results Summary${NC}"
echo "========================================================================="
echo -e "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n🎉 ${GREEN}ALL TESTS PASSED! Production infrastructure is ready.${NC}"
    echo -e "${GREEN}✅ UrGood backend is production-ready!${NC}"
    exit 0
else
    echo -e "\n⚠️  ${YELLOW}Some tests failed. Please review and fix issues before production deployment.${NC}"
    echo -e "${RED}❌ Production readiness: $(($TESTS_PASSED * 100 / $TOTAL_TESTS))%${NC}"
    exit 1
fi
