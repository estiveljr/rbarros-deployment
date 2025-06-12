#!/bin/bash
# Generate Application Secrets for RBarros Deployment
# This script generates secure random strings for application secrets

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔐 RBarros Application Secrets Generator${NC}"
echo -e "${CYAN}=======================================${NC}"
echo ""

# Function to generate a secure random string
generate_secure_string() {
    local length=${1:-64}
    local description=${2:-"Secret"}
    
    # Try different methods based on what's available
    if command -v openssl >/dev/null 2>&1; then
        # Use OpenSSL (most reliable)
        openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
    elif [[ -f /dev/urandom ]]; then
        # Use /dev/urandom
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c ${length}
    else
        # Fallback to date-based random (less secure)
        echo "WARNING: Using less secure random generation method" >&2
        echo "${RANDOM}${RANDOM}$(date +%s%N)" | sha256sum | head -c ${length}
    fi
}

# Function to generate URL-safe string (for webhook secrets)
generate_url_safe_string() {
    local length=${1:-32}
    
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | tr 'A-Z' 'a-z' | cut -c1-${length}
    elif [[ -f /dev/urandom ]]; then
        tr -dc 'a-zA-Z0-9-_' < /dev/urandom | head -c ${length}
    else
        echo "${RANDOM}${RANDOM}$(date +%s%N)" | sha256sum | cut -c1-${length}
    fi
}

echo -e "${YELLOW}Generating secure application secrets...${NC}"
echo ""

# Generate secrets
SECRET_KEY=$(generate_secure_string 64)
SECRET_KEY_REFRESH_TOKEN=$(generate_secure_string 64)
WEBHOOK_SECRET=$(generate_url_safe_string 32)
DB_PASSWORD=$(generate_secure_string 32)

# Display generated secrets
echo -e "${GREEN}📋 Generated Secrets:${NC}"
echo -e "${GREEN}===================${NC}"
echo ""

echo -e "${WHITE}SECRET_KEY:${NC}"
echo -e "${YELLOW}${SECRET_KEY}${NC}"
echo ""

echo -e "${WHITE}SECRET_KEY_REFRESH_TOKEN:${NC}"
echo -e "${YELLOW}${SECRET_KEY_REFRESH_TOKEN}${NC}"
echo ""

echo -e "${WHITE}WEBHOOK_SECRET:${NC}"
echo -e "${YELLOW}${WEBHOOK_SECRET}${NC}"
echo ""

echo -e "${WHITE}MYSQL_ROOT_PASSWORD (suggestion):${NC}"
echo -e "${YELLOW}${DB_PASSWORD}${NC}"
echo ""

# Additional secrets that need manual setup
echo -e "${CYAN}📋 Manual Setup Required:${NC}"
echo -e "${CYAN}========================${NC}"
echo ""

echo -e "${WHITE}SENDGRID_API_KEY:${NC}"
echo -e "${GRAY}  → Sign up at https://sendgrid.com${NC}"
echo -e "${GRAY}  → Go to Settings → API Keys → Create API Key${NC}"
echo -e "${GRAY}  → Copy the generated API key${NC}"
echo ""

# Generate .env template
echo -e "${GREEN}📝 Generating .env template...${NC}"

cat > .env.generated << EOF
# Database Configuration
DB_HOST=database
DB_USER=rbarros_user
DB_PASSWORD=your_secure_db_password_here
DB_NAME=rbarrosassurance
MYSQL_ROOT_PASSWORD=${DB_PASSWORD}

# Application Secrets
NODE_ENV=production
SECRET_KEY=${SECRET_KEY}
SECRET_KEY_REFRESH_TOKEN=${SECRET_KEY_REFRESH_TOKEN}
WEBHOOK_SECRET=${WEBHOOK_SECRET}

# Email Service (Get from SendGrid)
SENDGRID_API_KEY=your_sendgrid_api_key_here

# Frontend Configuration
VUE_APP_API_URL=https://yourdomain.com/api
EOF

echo -e "${GREEN}✅ Saved template to .env.generated${NC}"
echo ""

# GitHub Secrets format
echo -e "${MAGENTA}🔧 GitHub Secrets Setup:${NC}"
echo -e "${MAGENTA}========================${NC}"
echo ""
echo -e "${GRAY}Copy these values to your GitHub repository secrets:${NC}"
echo ""

GITHUB_SECRETS="SECRET_KEY=${SECRET_KEY}
SECRET_KEY_REFRESH_TOKEN=${SECRET_KEY_REFRESH_TOKEN}
WEBHOOK_SECRET=${WEBHOOK_SECRET}
MYSQL_ROOT_PASSWORD=${DB_PASSWORD}"

echo -e "${YELLOW}${GITHUB_SECRETS}${NC}"
echo ""

# Save GitHub secrets to file for easy copying
echo "${GITHUB_SECRETS}" > github-secrets.txt
echo -e "${GREEN}✅ GitHub secrets saved to github-secrets.txt${NC}"

# Try to copy to clipboard if possible
if command -v pbcopy >/dev/null 2>&1; then
    # macOS
    echo "${GITHUB_SECRETS}" | pbcopy
    echo -e "${GREEN}✅ GitHub secrets copied to clipboard!${NC}"
elif command -v xclip >/dev/null 2>&1; then
    # Linux with xclip
    echo "${GITHUB_SECRETS}" | xclip -selection clipboard
    echo -e "${GREEN}✅ GitHub secrets copied to clipboard!${NC}"
elif command -v xsel >/dev/null 2>&1; then
    # Linux with xsel
    echo "${GITHUB_SECRETS}" | xsel --clipboard --input
    echo -e "${GREEN}✅ GitHub secrets copied to clipboard!${NC}"
else
    echo -e "${BLUE}💡 Tip: Copy the secrets above to set them in GitHub${NC}"
fi

echo ""
echo -e "${CYAN}🚀 Next Steps:${NC}"
echo -e "${CYAN}==============${NC}"
echo -e "${WHITE}1. Set up SendGrid account and get API key${NC}"
echo -e "${WHITE}2. Go to GitHub repository → Settings → Secrets and variables → Actions${NC}"
echo -e "${WHITE}3. Add each secret with the generated values${NC}"
echo -e "${WHITE}4. Update server connection secrets (SERVER_HOST, SERVER_USERNAME, etc.)${NC}"
echo -e "${WHITE}5. Push to main branch to trigger deployment${NC}"
echo ""
echo -e "${GREEN}✨ Secrets generated successfully!${NC}"

# Make script executable
chmod +x "$0" 2>/dev/null || true 