.PHONY: help build up down restart logs clean dev prod backup restore deploy-secrets

# Default target
help:
	@echo "Available commands:"
	@echo "  build          - Build all Docker images"
	@echo "  up             - Start all services in production mode"
	@echo "  down           - Stop all services"
	@echo "  restart        - Restart all services"
	@echo "  logs           - Show logs for all services"
	@echo "  clean          - Remove all containers, networks, and volumes"
	@echo "  dev            - Start services in development mode"
	@echo "  prod           - Start services in production mode"
	@echo "  backup         - Backup database"
	@echo "  restore        - Restore database from backup"
	@echo "  setup          - Initial setup (copy env file)"
	@echo "  deploy-secrets - Deploy using environment variables (for CI/CD)"

# Setup environment
setup:
	@if [ ! -f .env ]; then \
		cp env.example .env; \
		echo "Created .env file from template. Please edit it with your values."; \
	else \
		echo ".env file already exists."; \
	fi

# Build all images
build:
	docker-compose build

# Start production environment
up: setup
	docker-compose up -d

# Start development environment
dev: setup
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Start production environment (explicit)
prod: setup
	docker-compose up -d

# Deploy with environment variables (for CI/CD with secrets)
deploy-secrets:
	@echo "Deploying with environment variables..."
	docker-compose up -d --build

# Stop all services
down:
	docker-compose down

# Restart all services
restart:
	docker-compose restart

# Show logs
logs:
	docker-compose logs -f

# Show logs for specific service
logs-backend:
	docker-compose logs -f backend

logs-frontend:
	docker-compose logs -f frontend

logs-database:
	docker-compose logs -f database

logs-nginx:
	docker-compose logs -f nginx

# Clean everything
clean:
	docker-compose down -v --remove-orphans
	docker system prune -f

# Clean everything including images
clean-all:
	docker-compose down -v --remove-orphans --rmi all
	docker system prune -af

# Database backup
backup:
	@echo "Creating database backup..."
	docker-compose exec database mysqldump -u root -p rbarros_db | gzip > backup-$(shell date +%Y%m%d-%H%M%S).sql.gz
	@echo "Backup created: backup-$(shell date +%Y%m%d-%H%M%S).sql.gz"

# Database restore (requires BACKUP_FILE variable)
restore:
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "Please specify BACKUP_FILE: make restore BACKUP_FILE=backup.sql.gz"; \
		exit 1; \
	fi
	@echo "Restoring database from $(BACKUP_FILE)..."
	gunzip -c $(BACKUP_FILE) | docker-compose exec -T database mysql -u root -p rbarros_db

# Health check
health:
	@echo "Checking service health..."
	docker-compose ps
	@echo "\nBackend health:"
	curl -f http://localhost:3000/health || echo "Backend not responding"
	@echo "\nFrontend health:"
	curl -f http://localhost:8080 || echo "Frontend not responding"

# Update and rebuild
update:
	git pull
	docker-compose build --no-cache
	docker-compose up -d

# Show service status
status:
	docker-compose ps

# Execute shell in containers
shell-backend:
	docker-compose exec backend sh

shell-frontend:
	docker-compose exec frontend sh

shell-database:
	docker-compose exec database bash

shell-nginx:
	docker-compose exec nginx sh 