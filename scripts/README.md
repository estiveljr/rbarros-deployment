# Production Server Setup Script

This directory contains an automated setup script for configuring a production server for RBarros deployment.

## 📋 Script: `setup-production-server.sh`

Automates the complete setup of a production server including:

- ✅ System updates and package installation
- ✅ Docker and Docker Compose installation
- ✅ Repository cloning with submodules
- ✅ Firewall configuration (UFW)
- ✅ SSL certificate setup (Let's Encrypt)
- ✅ Database configuration (Docker or external MySQL)
- ✅ Automatic backup system
- ✅ Basic monitoring tools
- ✅ Security updates configuration
- ✅ Environment file creation
- ✅ Deployment testing

## 🚀 Usage

### 1. Upload Script to Server

```bash
# Copy the script to your server
scp scripts/setup-production-server.sh user@your-server:/tmp/

# Or download directly on server
wget https://raw.githubusercontent.com/yourusername/rbarros-deployment/main/scripts/setup-production-server.sh
```

### 2. Make Executable and Run

```bash
# Make executable
chmod +x setup-production-server.sh

# Run the script
./setup-production-server.sh
```

### 3. Follow Interactive Prompts

The script will ask for:

- **Repository URL**: Your GitHub repository URL
- **Domain name**: Your production domain (optional)
- **SSL setup**: Whether to use Let's Encrypt SSL
- **Email**: For Let's Encrypt notifications
- **Database type**: Docker MySQL or external database
- **MySQL password**: For Docker database

## 📝 What the Script Does

### System Setup
- Updates all system packages
- Installs essential tools (curl, wget, git, ufw, htop, etc.)
- Configures automatic security updates

### Docker Installation
- Installs latest Docker CE
- Installs Docker Compose
- Adds user to docker group

### Repository Setup
- Clones your repository to `/opt/rbarros-deployment`
- Initializes and updates git submodules
- Sets proper permissions

### Security Configuration
- Configures UFW firewall
- Opens necessary ports (22, 80, 443, 3000, 8080)
- Sets up fail2ban (optional)

### SSL Configuration (if requested)
- Installs Certbot
- Generates Let's Encrypt certificates
- Sets up automatic renewal
- Copies certificates to deployment directory

### Database Setup
- **Docker option**: Configures MySQL in Docker
- **External option**: Installs MySQL server locally

### Backup System
- Creates automatic daily backup script
- Configures cron job for 2 AM daily backups
- Sets up backup retention (7 days)

### Monitoring
- Installs system monitoring tools
- Configures Docker log rotation
- Sets up basic health checks

### Environment Configuration
- Creates `.env` file from template
- Updates with user-provided values
- Provides security warnings for secrets

### Testing
- Builds Docker images
- Tests deployment
- Runs health checks
- Displays service status

## 🔧 Post-Setup Tasks

After the script completes, you'll need to:

1. **Edit environment file**:
   ```bash
   nano /opt/rbarros-deployment/.env
   ```

2. **Update GitHub secrets** in your repository settings

3. **Update workflow path** in `.github/workflows/workflow.yaml`:
   ```yaml
   script: |
     cd /opt/rbarros-deployment
   ```

4. **Configure SSL** (if using custom certificates):
   ```bash
   # Copy your certificates
   cp your-cert.crt /opt/rbarros-deployment/nginx/ssl/certificate.crt
   cp your-key.key /opt/rbarros-deployment/nginx/ssl/private.key
   ```

5. **Test deployment**:
   ```bash
   cd /opt/rbarros-deployment
   make deploy-secrets
   make health
   ```

## 🛠️ Manual Steps (if needed)

### External Database Setup
If you chose external MySQL:

```bash
sudo mysql_secure_installation
sudo mysql -u root -p
```

```sql
CREATE DATABASE rbarros_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'rbarros_user'@'%' IDENTIFIED BY 'your-secure-password';
GRANT ALL PRIVILEGES ON rbarros_db.* TO 'rbarros_user'@'%';
FLUSH PRIVILEGES;
EXIT;
```

### SSL Configuration
If you need to update Nginx for SSL:

```bash
nano /opt/rbarros-deployment/nginx/nginx.conf
```

Add SSL server block and HTTP redirect.

## 🔍 Troubleshooting

### Script Fails
```bash
# Check logs
tail -f /var/log/syslog

# Check Docker
docker --version
docker-compose --version

# Check services
systemctl status docker
```

### Permission Issues
```bash
# Fix ownership
sudo chown -R $USER:$USER /opt/rbarros-deployment

# Fix Docker permissions
sudo usermod -aG docker $USER
# Log out and back in
```

### Firewall Issues
```bash
# Check UFW status
sudo ufw status verbose

# Reset if needed
sudo ufw --force reset
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
```

### SSL Issues
```bash
# Check certificates
sudo certbot certificates

# Renew manually
sudo certbot renew

# Check nginx config
nginx -t
```

## 📞 Support

If you encounter issues:

1. Check the script output for error messages
2. Verify system requirements are met
3. Ensure you have sudo privileges
4. Check network connectivity
5. Review the main project README for additional troubleshooting

## 🔒 Security Notes

- The script configures basic security but review all settings
- Change all default passwords in the `.env` file
- Generate strong SECRET_KEY values (32+ characters)
- Regularly update your system and Docker images
- Monitor logs for suspicious activity
- Consider additional security measures for production 