.PHONY: help build up down restart logs clean dev prod backup restore deploy-secrets setup docker-start check-env

ifeq ($(OS),Windows_NT)
OS_TYPE := windows
else
OS_TYPE := unix
endif

# Default target
help:
	@echo "Detected OS: $(OS_TYPE)"
	@echo "Available commands:"
	@echo ""
	@echo "Main Operations:"
	@echo "  dev            - Start services in development mode"
	@echo "  prod           - Start services in production mode"
	@echo "  down           - Stop all services"
	@echo "  restart        - Restart all services"
	@echo ""
	@echo "Build & Setup:"
	@echo "  build-dev      - Build all Docker images"
	@echo "  setup          - Copy environment file template"
	@echo "  deploy-secrets - Deploy using environment variables (for CI/CD)"
	@echo ""
	@echo "Monitoring:"
	@echo "  status         - Show service status"
	@echo "  health         - Check service health"
	@echo "  logs           - Show logs for all services"
	@echo "  logs-backend   - Show backend logs only"
	@echo "  logs-frontend  - Show frontend logs only"
	@echo "  logs-database  - Show database logs only"
	@echo ""
	@echo "Database Operations:"
	@echo "  db-status      - Check database volume and connection status"
	@echo "  db-connect     - Connect to database as root"
	@echo "  db-size        - Show database volume size"
	@echo "  backup         - Backup database"
	@echo "  restore        - Restore database from backup"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean-safe     - Clean containers (PRESERVES database data)"
	@echo "  clean          - Remove containers and volumes (⚠️ DELETES database)"
	@echo "  clean-all      - Remove everything including images (⚠️ DELETES database)"

# Check and start Docker Desktop if needed
ifeq ($(OS_TYPE),windows)
docker-start:
	@echo "Checking Docker status..."
	@docker version >/dev/null 2>&1 || (echo "Starting Docker Desktop..." && start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe" && echo "Waiting for Docker to start..." && timeout /t 30 /nobreak >nul && echo "Docker should be ready now")
	@echo "Docker is running"
else
docker-start:
	@echo "Checking Docker status..."
	@docker version >/dev/null 2>&1 || (echo "Starting Docker service..." && (sudo systemctl start docker 2>/dev/null || echo "Could not start Docker service automatically. Please start Docker manually.") && echo "Waiting for Docker to start..." && sleep 30 && echo "Docker should be ready now")
	@echo "Docker is running"
endif

# Check if .env file exists, create it if not
ifeq ($(OS_TYPE),windows)
check-env:
	@if not exist .env (echo .env file not found, creating from template... && $(MAKE) setup) else (echo .env file found)
else
check-env:
	@echo "Checking .env file..."
	@test -f .env && echo ".env file found" || (echo ".env file not found, creating from template..." && $(MAKE) setup)
endif


# Setup environment (cross-platform)
setup:
	@echo "Setting up environment file..."
	@cp env.example .env 2>/dev/null || copy env.example .env 2>nul || echo "Environment file setup complete"
	@echo "Environment file created from template"
	@echo "You can edit .env to customize values, or use defaults for development"

# Build all images
build-dev: docker-start
	docker-compose -f docker-compose.dev.yml build --no-cache

build-prod: docker-start
	docker-compose -f docker-compose.prod.yml build --no-cache

# Start development environment (explicit)
dev: docker-start check-env
	@echo "Starting development environment..."
	docker-compose -f docker-compose.dev.yml up -d 

# Start production environment
prod: docker-start check-env
	@echo "Starting production environment..."
	docker-compose -f docker-compose.prod.yml up -d 

# Deploy with environment variables (for CI/CD with secrets)
deploy-secrets: docker-start
	@echo "Deploying with environment variables..."
	docker-compose -f docker-compose.prod.yml up -d --build

# Stop all services
down:
	docker-compose -f docker-compose.dev.yml down

# Stop production services
down-prod:
	docker-compose -f docker-compose.prod.yml down

# Restart all services
restart-dev: docker-start
	docker-compose -f docker-compose.dev.yml restart

restart-prod: docker-start
	docker-compose -f docker-compose.prod.yml restart

# Show logs
logs:
	docker-compose -f docker-compose.dev.yml logs -f

# Show logs for specific service
logs-backend:
	docker-compose -f docker-compose.dev.yml logs -f backend

logs-frontend:
	docker-compose -f docker-compose.dev.yml logs -f frontend

logs-database:
	docker-compose -f docker-compose.dev.yml logs -f database

logs-nginx:
	docker-compose -f docker-compose.dev.yml logs -f nginx

# Database operations
db-status: docker-start
	@echo "=== Database Volume Status ==="
	@docker volume ls | findstr mysql_data 2>nul || echo "No database volume found"
	@echo ""
	@echo "=== Database Container Status ==="
	@docker-compose -f docker-compose.dev.yml ps database
	@echo ""
	@echo "=== Database Connection Test ==="
	@docker-compose -f docker-compose.dev.yml exec database mysqladmin ping -h localhost 2>nul && echo "✅ Database is responding" || echo "❌ Database not responding"

db-connect: docker-start
	@echo "Connecting to database as root..."
	@docker-compose -f docker-compose.dev.yml exec database mysql -u root -p

db-size: docker-start
	@echo "Database volume size:"
	@docker system df -v | findstr mysql_data 2>nul || echo "Volume not found"

# Clean everything
clean:
	@echo "WARNING: This will DELETE all database data!"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@pause >nul 2>&1 || read -p ""
	docker-compose -f docker-compose.dev.yml down -v --remove-orphans
	docker system prune -f

# Clean everything including images
ifeq ($(OS_TYPE),windows)
clean-all:
	@echo "WARNING: This will DELETE all database data and images!"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@pause >nul 2>&1 || read -p ""
	docker-compose -f docker-compose.dev.yml down -v --remove-orphans --rmi all
	docker system prune -af
else
clean-all:
	@echo "WARNING: This will DELETE all database data and images!"
	@read -p "Press Enter to continue..." dummy
	docker-compose -f docker-compose.dev.yml down -v --remove-orphans --rmi all
	docker system prune -af
endif

# Safe cleanup (preserves database)
clean-safe:
	@echo "Cleaning containers and networks (preserving database data)..."
	docker-compose -f docker-compose.dev.yml down --remove-orphans
	docker system prune -f

# Database backup (cross-platform)
backup: docker-start
	@echo "Creating database backup..."
	@docker-compose -f docker-compose.dev.yml exec database mysqldump -u root -p rbarros_db > backup-$(shell date +%Y%m%d-%H%M%S 2>/dev/null || echo %date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%).sql 2>/dev/null || echo "Backup created"

# Database restore (requires BACKUP_FILE variable)
restore: docker-start
	@echo "Restoring database from $(BACKUP_FILE)..."
	@docker-compose -f docker-compose.dev.yml exec -T database mysql -u root -p rbarros_db < $(BACKUP_FILE)

# Health check
health: docker-start
	@echo "Checking service health..."
	@docker-compose -f docker-compose.dev.yml ps
	@echo "Backend health:"
	@curl -f http://localhost:3000/health 2>/dev/null || echo "Backend not responding"
	@echo "Frontend health:"
	@curl -f http://localhost:8081 2>/dev/null || echo "Frontend not responding"

# Update and rebuild
update: docker-start
	git pull
	docker-compose -f docker-compose.dev.yml build --no-cache
	docker-compose -f docker-compose.dev.yml -f docker-compose.prod.yml up -d

# Show service status
status: docker-start
	docker-compose -f docker-compose.dev.yml ps

# Execute shell in containers
shell-backend: docker-start
	docker-compose -f docker-compose.dev.yml exec backend sh

shell-frontend: docker-start
	docker-compose -f docker-compose.dev.yml exec frontend sh

shell-database: docker-start
	docker-compose -f docker-compose.dev.yml exec database bash

shell-nginx: docker-start
	docker-compose -f docker-compose.dev.yml exec nginx sh 