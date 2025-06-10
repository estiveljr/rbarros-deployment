# Environment Configuration Guide

## 🎯 Overview

This project follows a **clean, simple approach** to environment configuration:
- **`env.example`** contains all defaults and documentation
- **`.env`** is automatically created from the template when needed
- **No redundant fallback values** in Docker Compose

## 📁 Environment Files

### `env.example` (Template & Defaults)
- **Single source of truth** for all configuration
- **Working defaults** ready for immediate development
- **Comprehensive documentation** with comments
- **Safe to commit** (contains no real secrets)

### `.env` (Local Configuration)
- **Automatically created** from `env.example` when you run `make dev`
- **Customizable** - edit values as needed
- **Gitignored** - your local customizations stay private

## 🚀 Quick Start

### Zero-Configuration Development
```bash
# 1. Clone the repository
git clone --recurse-submodules <repo-url>
cd rbarros-deployment

# 2. Start immediately
make dev

# That's it! The .env file is created automatically with working defaults
```

### Custom Configuration (Optional)
```bash
# 1. Start with defaults (creates .env automatically)
make dev

# 2. Stop and customize if needed
make down
nano .env

# 3. Restart with your custom config
make dev
```

## 🔧 Environment Variables Explained

### Database Configuration
```env
DB_HOST=database              # Docker service name
DB_USER=rbarros_dev          # Database username
DB_PASSWORD=dev_password_123  # Database password
DB_NAME=rbarros_development  # Database name
MYSQL_ROOT_PASSWORD=root_dev_password_123  # MySQL root password
```

### Application Secrets
```env
# JWT secrets (minimum 32 characters for security)
SECRET_KEY=dev-jwt-secret-key-for-local-development-minimum-32-chars
SECRET_KEY_REFRESH_TOKEN=dev-refresh-token-secret-for-local-development-32-chars
```

### External Services
```env
SENDGRID_API_KEY=SG.dev-placeholder-key  # Email service (placeholder for dev)
WEBHOOK_SECRET=dev-webhook-secret-for-local-testing  # GitHub webhook secret
```

### Application Settings
```env
NODE_ENV=development          # Environment mode
PORT=3000                    # Backend port
VUE_APP_API_URL=http://localhost:3000  # Frontend API endpoint
```

## 🏗️ Configuration Approach

### **Simple Two-Layer System**
1. **`env.example`** → Template with working defaults
2. **`.env`** → Local copy (auto-created from template)

### **No Redundancy**
- ✅ **Single source** of default values (`env.example`)
- ✅ **No duplication** between files
- ✅ **Easy maintenance** - update one place only

### **Automatic Setup**
```bash
make dev  # Automatically creates .env if missing
```

## 🔒 Security Best Practices

### ✅ What's Safe for Development
- **Database passwords** (local only, clearly marked)
- **JWT secrets** (long strings with "dev" prefix)
- **Placeholder API keys** (obviously fake)
- **Local URLs** (localhost references only)

### ⚠️ What Must Change for Production
- **All passwords** → Strong, unique passwords
- **JWT secrets** → Cryptographically secure random strings
- **API keys** → Real service credentials
- **URLs** → Production domain names
- **NODE_ENV** → Set to 'production'

## 🚀 Production Deployment

### GitHub Secrets (Recommended)
Set these in your GitHub repository settings:

```
# Database
DB_HOST=your-production-db-host
DB_USER=your-production-db-user
DB_PASSWORD=your-strong-production-password
DB_NAME=your-production-db-name
MYSQL_ROOT_PASSWORD=your-strong-root-password

# Application
SECRET_KEY=your-32-char-production-jwt-secret
SECRET_KEY_REFRESH_TOKEN=your-32-char-refresh-secret
SENDGRID_API_KEY=your-real-sendgrid-api-key
WEBHOOK_SECRET=your-github-webhook-secret

# Frontend
VUE_APP_API_URL=https://api.yourdomain.com
```

### Manual Production Setup
```bash
# 1. Copy template
cp env.example .env.production

# 2. Edit with production values
nano .env.production

# 3. Deploy
export $(cat .env.production | xargs)
make deploy-secrets
```

## 🛠️ Development Workflows

### Standard Development
```bash
make dev  # Creates .env automatically, starts services
```

### Customizing Configuration
```bash
# 1. Start with defaults
make dev

# 2. Customize as needed
nano .env

# 3. Restart to apply changes
make restart
```

### Resetting to Defaults
```bash
# Remove custom config and recreate from template
rm .env
make dev
```

## 🔍 Troubleshooting

### "Environment variable not set" errors
1. Check if `.env` file exists: `ls -la .env`
2. If missing, run: `make setup` or `make dev`
3. Verify variable names match exactly in `env.example`
4. Ensure no spaces around `=` in `.env` file

### Database connection issues
1. Verify database credentials in `.env`
2. Check if database container is running: `make status`
3. Check database logs: `make logs-database`
4. Try connecting manually: `make shell-database`

### Application won't start
1. Ensure `.env` file exists (run `make dev` to create)
2. Verify JWT secrets are at least 32 characters
3. Check for conflicting port usage
4. Review application logs: `make logs`

## 🎯 Why This Approach?

### ✅ **Advantages**
- **No redundancy** - single source of truth
- **Automatic setup** - works immediately
- **Clear documentation** - everything in one place
- **Easy maintenance** - update defaults in one file
- **Flexible** - easy to customize when needed

### ❌ **What We Avoided**
- **Duplicate values** in multiple files
- **Complex fallback logic** in Docker Compose
- **Manual setup steps** for basic development
- **Confusion** about which file to edit

## 🤝 Contributing

When adding new environment variables:

1. **Add to `env.example`** with documentation and safe default
2. **Update this documentation**
3. **Test that `make dev` works without existing `.env`**
4. **Use safe, obvious development defaults**
5. **Mark production-sensitive values** clearly 