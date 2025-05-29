#!/bin/bash

# RBarros Production Server Setup Script
# This script automates the setup of a production server for RBarros deployment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Check if user has sudo privileges
if ! sudo -n true 2>/dev/null; then
    error "This script requires sudo privileges. Please ensure your user can run sudo commands."
fi

log "Starting RBarros Production Server Setup..."

# Configuration variables
DEPLOY_DIR="/opt/rbarros-deployment"
BACKUP_DIR="/opt/backups"
REPO_URL="https://github.com/estiveljr/rbarros-deployment.git"
DOMAIN="https://www.rbarrosassurances.com/"
EMAIL="estiveljr@gmail.com"
USE_SSL="y"
USE_EXTERNAL_DB="n"
DB_ROOT_PASSWORD=""

# Function to prompt for user input
prompt_config() {
    log "Configuration Setup"
    
    read -p "Enter your GitHub repository URL (e.g., https://github.com/user/rbarros-deployment.git): " REPO_URL
    if [[ -z "$REPO_URL" ]]; then
        error "Repository URL is required"
    fi
    
    read -p "Enter your domain name (optional, press Enter to skip): " DOMAIN
    
    if [[ -n "$DOMAIN" ]]; then
        read -p "Do you want to setup SSL with Let's Encrypt? (y/n): " USE_SSL
        if [[ "$USE_SSL" == "y" ]]; then
            read -p "Enter your email for Let's Encrypt: " EMAIL
            if [[ -z "$EMAIL" ]]; then
                error "Email is required for Let's Encrypt"
            fi
        fi
    fi
    
    read -p "Do you want to use an external MySQL database? (y/n, default: n): " USE_EXTERNAL_DB
    
    if [[ "$USE_EXTERNAL_DB" != "y" ]]; then
        read -s -p "Enter MySQL root password for Docker database: " DB_ROOT_PASSWORD
        echo
        if [[ -z "$DB_ROOT_PASSWORD" ]]; then
            error "MySQL root password is required"
        fi
    fi
}

# Function to update system
update_system() {
    log "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget git ufw htop iotop nethogs unattended-upgrades
}

# Function to install Docker
install_docker() {
    log "Installing Docker..."
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        info "Docker is already installed"
        docker --version
    else
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        log "Added $USER to docker group. You may need to log out and back in for this to take effect."
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    log "Installing Docker Compose..."
    
    # Check if Docker Compose is already installed
    if command -v docker-compose &> /dev/null; then
        info "Docker Compose is already installed"
        docker-compose --version
    else
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        # Verify installation
        docker-compose --version
    fi
}

# Function to setup deployment directory
setup_deployment_dir() {
    log "Setting up deployment directory..."
    
    # Create deployment directory
    sudo mkdir -p "$DEPLOY_DIR"
    sudo chown $USER:$USER "$DEPLOY_DIR"
    
    # Clone repository
    if [[ -d "$DEPLOY_DIR/.git" ]]; then
        info "Repository already exists, pulling latest changes..."
        cd "$DEPLOY_DIR"
        git pull origin main
        git submodule update --init --recursive
    else
        log "Cloning repository..."
        git clone --recurse-submodules "$REPO_URL" "$DEPLOY_DIR"
        cd "$DEPLOY_DIR"
    fi
    
    # Ensure submodules are updated
    git submodule update --init --recursive
}

# Function to configure firewall
configure_firewall() {
    log "Configuring firewall..."
    
    # Install UFW if not installed
    if ! command -v ufw &> /dev/null; then
        sudo apt install -y ufw
    fi
    
    # Reset UFW to default
    sudo ufw --force reset
    
    # Set default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH (important!)
    sudo ufw allow ssh
    
    # Allow HTTP and HTTPS
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Allow development ports (optional)
    sudo ufw allow 3000/tcp comment 'Backend API'
    sudo ufw allow 8080/tcp comment 'Frontend'
    
    # Enable firewall
    sudo ufw --force enable
    
    # Show status
    sudo ufw status verbose
}

# Function to setup SSL with Let's Encrypt
setup_ssl() {
    if [[ "$USE_SSL" == "y" && -n "$DOMAIN" ]]; then
        log "Setting up SSL with Let's Encrypt..."
        
        # Install Certbot
        sudo apt install -y certbot
        
        # Stop any running web servers temporarily
        sudo systemctl stop apache2 2>/dev/null || true
        sudo systemctl stop nginx 2>/dev/null || true
        
        # Generate certificates
        sudo certbot certonly --standalone --agree-tos --no-eff-email --email "$EMAIL" -d "$DOMAIN" -d "www.$DOMAIN"
        
        # Create SSL directory in deployment
        mkdir -p "$DEPLOY_DIR/nginx/ssl"
        
        # Copy certificates to deployment directory
        sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$DEPLOY_DIR/nginx/ssl/certificate.crt"
        sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$DEPLOY_DIR/nginx/ssl/private.key"
        sudo chown $USER:$USER "$DEPLOY_DIR/nginx/ssl/"*
        
        # Setup auto-renewal
        echo "0 12 * * * /usr/bin/certbot renew --quiet && cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $DEPLOY_DIR/nginx/ssl/certificate.crt && cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $DEPLOY_DIR/nginx/ssl/private.key && cd $DEPLOY_DIR && docker-compose restart nginx" | sudo crontab -
        
        log "SSL certificates installed and auto-renewal configured"
    fi
}

# Function to setup database
setup_database() {
    if [[ "$USE_EXTERNAL_DB" == "y" ]]; then
        log "Setting up external MySQL database..."
        
        # Install MySQL
        sudo apt install -y mysql-server
        
        # Secure installation
        warn "Please run 'sudo mysql_secure_installation' manually after this script completes"
        
        info "Don't forget to create the database and user:"
        info "sudo mysql -u root -p"
        info "CREATE DATABASE rbarros_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        info "CREATE USER 'rbarros_user'@'%' IDENTIFIED BY 'your-secure-password';"
        info "GRANT ALL PRIVILEGES ON rbarros_db.* TO 'rbarros_user'@'%';"
        info "FLUSH PRIVILEGES;"
        info "EXIT;"
    else
        log "Database will be managed by Docker Compose"
    fi
}

# Function to setup backup system
setup_backups() {
    log "Setting up automatic backup system..."
    
    # Create backup directory
    sudo mkdir -p "$BACKUP_DIR"
    sudo chown $USER:$USER "$BACKUP_DIR"
    
    # Create backup script
    sudo tee /opt/backup-rbarros.sh > /dev/null <<EOF
#!/bin/bash
cd $DEPLOY_DIR
make backup
# Move backup to safe location
mv backup-*.sql.gz $BACKUP_DIR/ 2>/dev/null || true
# Keep only last 7 days
find $BACKUP_DIR -name "backup-*.sql.gz" -mtime +7 -delete
# Log backup
echo "\$(date): Backup completed" >> $BACKUP_DIR/backup.log
EOF
    
    # Make executable
    sudo chmod +x /opt/backup-rbarros.sh
    
    # Add to crontab (daily backup at 2 AM)
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/backup-rbarros.sh") | crontab -
    
    log "Automatic daily backups configured"
}

# Function to setup monitoring
setup_monitoring() {
    log "Setting up basic monitoring..."
    
    # Install monitoring tools
    sudo apt install -y htop iotop nethogs
    
    # Setup log rotation for Docker
    (crontab -l 2>/dev/null; echo "0 3 * * * docker system prune -f --filter 'until=24h'") | crontab -
    
    log "Basic monitoring tools installed"
}

# Function to setup automatic security updates
setup_security_updates() {
    log "Configuring automatic security updates..."
    
    # Configure unattended upgrades
    sudo apt install -y unattended-upgrades
    echo 'Unattended-Upgrade::Automatic-Reboot "false";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades
    sudo dpkg-reconfigure -plow unattended-upgrades
    
    log "Automatic security updates configured"
}

# Function to create environment file template
create_env_template() {
    log "Creating environment file template..."
    
    cd "$DEPLOY_DIR"
    
    if [[ ! -f .env ]]; then
        cp env.example .env
        
        # Update with user-provided values
        if [[ -n "$DB_ROOT_PASSWORD" ]]; then
            sed -i "s/MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$DB_ROOT_PASSWORD/" .env
        fi
        
        if [[ -n "$DOMAIN" ]]; then
            sed -i "s|VUE_APP_API_URL=.*|VUE_APP_API_URL=https://$DOMAIN|" .env
        fi
        
        warn "Please edit $DEPLOY_DIR/.env with your actual values before deploying"
        warn "Important: Update all SECRET_KEY values with secure random strings!"
    else
        info "Environment file already exists"
    fi
}

# Function to test deployment
test_deployment() {
    log "Testing deployment..."
    
    cd "$DEPLOY_DIR"
    
    # Check if we can build images
    if docker-compose build --no-cache; then
        log "Docker images built successfully"
    else
        error "Failed to build Docker images"
    fi
    
    # Test basic deployment
    if make deploy-secrets; then
        log "Deployment test successful"
        
        # Wait a moment for services to start
        sleep 10
        
        # Check service status
        make status
        
        # Try health check
        if curl -f http://localhost:3000/health 2>/dev/null; then
            log "Backend health check passed"
        else
            warn "Backend health check failed - this might be normal if database is still starting"
        fi
    else
        error "Deployment test failed"
    fi
}

# Function to display final instructions
display_final_instructions() {
    log "Setup completed successfully!"
    
    echo
    info "=== NEXT STEPS ==="
    info "1. Edit the environment file: nano $DEPLOY_DIR/.env"
    info "2. Update GitHub secrets in your repository settings"
    info "3. Update the deployment path in .github/workflows/workflow.yaml to: $DEPLOY_DIR"
    
    if [[ "$USE_EXTERNAL_DB" == "y" ]]; then
        info "4. Setup your external MySQL database (see instructions above)"
    fi
    
    if [[ "$USE_SSL" == "y" ]]; then
        info "5. Update nginx/nginx.conf with your SSL configuration"
    fi
    
    info "6. Test the deployment: cd $DEPLOY_DIR && make deploy-secrets"
    info "7. Check logs: make logs"
    info "8. Monitor status: make status"
    
    echo
    info "=== USEFUL COMMANDS ==="
    info "View logs: cd $DEPLOY_DIR && make logs"
    info "Restart services: cd $DEPLOY_DIR && make restart"
    info "Update deployment: cd $DEPLOY_DIR && git pull && make deploy-secrets"
    info "Backup database: cd $DEPLOY_DIR && make backup"
    info "Check service health: cd $DEPLOY_DIR && make health"
    
    echo
    info "=== IMPORTANT SECURITY NOTES ==="
    warn "1. Change all default passwords in $DEPLOY_DIR/.env"
    warn "2. Generate secure SECRET_KEY values (minimum 32 characters)"
    warn "3. Configure your GitHub secrets with production values"
    warn "4. Regularly update your system: sudo apt update && sudo apt upgrade"
    
    if [[ "$USE_EXTERNAL_DB" == "y" ]]; then
        warn "5. Run 'sudo mysql_secure_installation' to secure your MySQL installation"
    fi
    
    echo
    log "Server setup completed! 🚀"
}

# Main execution
main() {
    log "RBarros Production Server Setup"
    log "==============================="
    
    # Prompt for configuration
    prompt_config
    
    # Execute setup steps
    update_system
    install_docker
    install_docker_compose
    setup_deployment_dir
    configure_firewall
    setup_ssl
    setup_database
    setup_backups
    setup_monitoring
    setup_security_updates
    create_env_template
    test_deployment
    display_final_instructions
}

# Run main function
main "$@" 