#!/bin/bash

# SSL Certificate Generation Script for UrGood Production
# Supports both self-signed certificates for development and Let's Encrypt for production

set -euo pipefail

# Configuration
DOMAIN="${DOMAIN:-urgood.app}"
EMAIL="${EMAIL:-admin@urgood.app}"
SSL_DIR="${SSL_DIR:-./nginx/ssl}"
CERT_TYPE="${CERT_TYPE:-letsencrypt}" # Options: letsencrypt, self-signed

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${2:-$NC}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error_exit() {
    log "❌ ERROR: $1" "$RED"
    exit 1
}

success() {
    log "✅ $1" "$GREEN"
}

warning() {
    log "⚠️ $1" "$YELLOW"
}

info() {
    log "ℹ️ $1" "$BLUE"
}

# Create SSL directory
mkdir -p "$SSL_DIR"

# Function to generate self-signed certificates
generate_self_signed() {
    info "Generating self-signed SSL certificates for $DOMAIN..."
    
    # Generate private key
    openssl genrsa -out "$SSL_DIR/urgood.app.key" 2048
    
    # Generate certificate signing request
    openssl req -new -key "$SSL_DIR/urgood.app.key" -out "$SSL_DIR/urgood.app.csr" -subj "/C=US/ST=CA/L=San Francisco/O=UrGood/CN=$DOMAIN/emailAddress=$EMAIL"
    
    # Generate self-signed certificate
    openssl x509 -req -in "$SSL_DIR/urgood.app.csr" -signkey "$SSL_DIR/urgood.app.key" -out "$SSL_DIR/urgood.app.crt" -days 365 -extensions v3_req -extfile <(
        echo '[v3_req]'
        echo 'basicConstraints = CA:FALSE'
        echo 'keyUsage = nonRepudiation, digitalSignature, keyEncipherment'
        echo 'subjectAltName = @alt_names'
        echo '[alt_names]'
        echo "DNS.1 = $DOMAIN"
        echo "DNS.2 = www.$DOMAIN"
        echo 'DNS.3 = localhost'
        echo 'IP.1 = 127.0.0.1'
    )
    
    # Generate DH parameters
    openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
    
    # Create chain file (same as cert for self-signed)
    cp "$SSL_DIR/urgood.app.crt" "$SSL_DIR/chain.pem"
    
    # Create default certificate (same as main)
    cp "$SSL_DIR/urgood.app.crt" "$SSL_DIR/default.crt"
    cp "$SSL_DIR/urgood.app.key" "$SSL_DIR/default.key"
    
    # Set proper permissions
    chmod 600 "$SSL_DIR"/*.key
    chmod 644 "$SSL_DIR"/*.crt "$SSL_DIR"/*.pem
    
    success "Self-signed SSL certificates generated successfully"
    warning "Self-signed certificates are for development only!"
    warning "For production, use Let's Encrypt certificates"
}

# Function to generate Let's Encrypt certificates
generate_letsencrypt() {
    info "Generating Let's Encrypt SSL certificates for $DOMAIN..."
    
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        error_exit "Certbot is not installed. Please install it first."
    fi
    
    # Check if running as root (required for certbot)
    if [[ $EUID -ne 0 ]]; then
        error_exit "Let's Encrypt certificate generation requires root privileges"
    fi
    
    # Generate certificates using certbot
    certbot certonly \
        --standalone \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --domains "$DOMAIN,www.$DOMAIN" \
        --cert-name urgood
    
    # Copy certificates to our SSL directory
    cp "/etc/letsencrypt/live/urgood/fullchain.pem" "$SSL_DIR/urgood.app.crt"
    cp "/etc/letsencrypt/live/urgood/privkey.pem" "$SSL_DIR/urgood.app.key"
    cp "/etc/letsencrypt/live/urgood/chain.pem" "$SSL_DIR/chain.pem"
    
    # Generate DH parameters if not exists
    if [[ ! -f "$SSL_DIR/dhparam.pem" ]]; then
        info "Generating DH parameters..."
        openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
    fi
    
    # Create default certificate (same as main)
    cp "$SSL_DIR/urgood.app.crt" "$SSL_DIR/default.crt"
    cp "$SSL_DIR/urgood.app.key" "$SSL_DIR/default.key"
    
    # Set proper permissions
    chmod 600 "$SSL_DIR"/*.key
    chmod 644 "$SSL_DIR"/*.crt "$SSL_DIR"/*.pem
    
    success "Let's Encrypt SSL certificates generated successfully"
    info "Certificates will expire in 90 days. Set up auto-renewal with cron."
}

# Function to set up Let's Encrypt auto-renewal
setup_auto_renewal() {
    info "Setting up Let's Encrypt auto-renewal..."
    
    # Create renewal script
    cat > /usr/local/bin/renew-urgood-certs.sh << 'EOF'
#!/bin/bash
# UrGood SSL Certificate Renewal Script

SSL_DIR="./nginx/ssl"
DOMAIN="urgood.app"

# Renew certificates
certbot renew --quiet

# Copy renewed certificates
if [[ -f "/etc/letsencrypt/live/urgood/fullchain.pem" ]]; then
    cp "/etc/letsencrypt/live/urgood/fullchain.pem" "$SSL_DIR/urgood.app.crt"
    cp "/etc/letsencrypt/live/urgood/privkey.pem" "$SSL_DIR/urgood.app.key"
    cp "/etc/letsencrypt/live/urgood/chain.pem" "$SSL_DIR/chain.pem"
    
    # Reload nginx
    docker-compose exec nginx nginx -s reload || systemctl reload nginx
    
    echo "$(date): SSL certificates renewed and nginx reloaded" >> /var/log/urgood-ssl-renewal.log
fi
EOF
    
    chmod +x /usr/local/bin/renew-urgood-certs.sh
    
    # Add to crontab (run twice daily)
    (crontab -l 2>/dev/null; echo "0 2,14 * * * /usr/local/bin/renew-urgood-certs.sh") | crontab -
    
    success "Auto-renewal set up successfully"
    info "Certificates will be checked for renewal twice daily at 2 AM and 2 PM"
}

# Function to verify certificates
verify_certificates() {
    info "Verifying SSL certificates..."
    
    if [[ ! -f "$SSL_DIR/urgood.app.crt" ]] || [[ ! -f "$SSL_DIR/urgood.app.key" ]]; then
        error_exit "SSL certificate files not found"
    fi
    
    # Check certificate validity
    if openssl x509 -in "$SSL_DIR/urgood.app.crt" -text -noout > /dev/null 2>&1; then
        success "Certificate file is valid"
    else
        error_exit "Certificate file is invalid"
    fi
    
    # Check private key
    if openssl rsa -in "$SSL_DIR/urgood.app.key" -check -noout > /dev/null 2>&1; then
        success "Private key is valid"
    else
        error_exit "Private key is invalid"
    fi
    
    # Check if certificate and key match
    cert_hash=$(openssl x509 -noout -modulus -in "$SSL_DIR/urgood.app.crt" | openssl md5)
    key_hash=$(openssl rsa -noout -modulus -in "$SSL_DIR/urgood.app.key" | openssl md5)
    
    if [[ "$cert_hash" == "$key_hash" ]]; then
        success "Certificate and private key match"
    else
        error_exit "Certificate and private key do not match"
    fi
    
    # Show certificate information
    info "Certificate information:"
    openssl x509 -in "$SSL_DIR/urgood.app.crt" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:|DNS:)"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --domain DOMAIN     Domain name (default: urgood.app)"
    echo "  -e, --email EMAIL       Email for Let's Encrypt (default: admin@urgood.app)"
    echo "  -t, --type TYPE         Certificate type: letsencrypt or self-signed (default: letsencrypt)"
    echo "  -s, --ssl-dir DIR       SSL directory (default: ./nginx/ssl)"
    echo "  -r, --auto-renewal      Set up auto-renewal for Let's Encrypt (requires root)"
    echo "  -v, --verify            Verify existing certificates"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --type self-signed                    # Generate self-signed certificates"
    echo "  $0 --domain myapp.com --email me@myapp.com  # Generate Let's Encrypt certificates"
    echo "  $0 --verify                              # Verify existing certificates"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -t|--type)
            CERT_TYPE="$2"
            shift 2
            ;;
        -s|--ssl-dir)
            SSL_DIR="$2"
            shift 2
            ;;
        -r|--auto-renewal)
            AUTO_RENEWAL=true
            shift
            ;;
        -v|--verify)
            VERIFY_ONLY=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            error_exit "Unknown option: $1"
            ;;
    esac
done

# Main execution
log "🔐 UrGood SSL Certificate Generator" "$BLUE"
log "Domain: $DOMAIN" "$BLUE"
log "Email: $EMAIL" "$BLUE"
log "Type: $CERT_TYPE" "$BLUE"
log "SSL Directory: $SSL_DIR" "$BLUE"

# Verify only mode
if [[ "${VERIFY_ONLY:-false}" == "true" ]]; then
    verify_certificates
    exit 0
fi

# Generate certificates based on type
case $CERT_TYPE in
    "self-signed")
        generate_self_signed
        ;;
    "letsencrypt")
        generate_letsencrypt
        if [[ "${AUTO_RENEWAL:-false}" == "true" ]]; then
            setup_auto_renewal
        fi
        ;;
    *)
        error_exit "Invalid certificate type: $CERT_TYPE. Use 'letsencrypt' or 'self-signed'"
        ;;
esac

# Verify generated certificates
verify_certificates

success "SSL certificate generation completed successfully!"

if [[ "$CERT_TYPE" == "self-signed" ]]; then
    warning "Remember to:"
    warning "1. Add the certificate to your browser's trusted certificates for local development"
    warning "2. Use Let's Encrypt certificates for production deployment"
elif [[ "$CERT_TYPE" == "letsencrypt" ]]; then
    info "Remember to:"
    info "1. Ensure your domain points to this server before running"
    info "2. Open ports 80 and 443 in your firewall"
    info "3. Set up auto-renewal if not already done with --auto-renewal flag"
fi

log "🎯 SSL setup complete for UrGood production deployment!" "$GREEN"
