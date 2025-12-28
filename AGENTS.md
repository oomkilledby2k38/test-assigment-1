# DevOps Project Agent Guidelines

This is a multi-component DevOps project implementing Infrastructure as Code with Flask application deployment using Ansible, Terraform, Docker, and Nginx.

## Project Structure

- `flask-auth-example/` - Flask authentication web application (Python)
- `Ansible/` - Configuration management and deployment automation
- `Terraform/` - Cloud infrastructure provisioning (DigitalOcean)
- `Scripts/` - Operational scripts (backup, healthcheck, setup)
- `nginx/` - Reverse proxy configuration

## Build/Test/Deploy Commands

### Flask Application
```bash
# Development
cd flask-auth-example
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python main.py

# Production Docker
docker build -t flask-app .
docker run -p 5000:5000 --env-file .env flask-app

# Test single component (manual healthcheck)
curl -f http://localhost:5000/health || echo "Health check failed"
```

### Ansible Deployment
```bash
# Full infrastructure deployment
ansible-playbook Ansible/hosts/playbooks/site.yml --vault-password-file .vault_pass

# Application update only
ansible-playbook Ansible/hosts/playbooks/deploy.yml --vault-password-file .vault_pass

# Run testing role specifically
ansible-playbook site.yml --tags testing --vault-password-file .vault_pass

# Test specific host
ansible-playbook site.yml --limit vm1 --vault-password-file .vault_pass
```

### Terraform Infrastructure
```bash
cd Terraform
terraform init
terraform plan
terraform apply
```

### Operational Scripts
```bash
# Health monitoring
./Scripts/healthcheck.sh

# Database backup
./Scripts/backup.sh

# Local development setup
./Scripts/setup.sh
```

## Code Style Guidelines

### Python (Flask Application)
- **Import order**: Standard library → Flask modules → Third-party → Local imports
- **Naming**: snake_case for functions/variables, PascalCase for classes, UPPER_CASE for constants
- **Type hints**: Use selectively for function signatures (`def create_app(debug: bool = False) -> Flask`)
- **Structure**: Application factory pattern with modular blueprints
- **Error handling**: Try-except blocks with logging, proper HTTP status codes

### YAML/Ansible
- **Indentation**: 2 spaces consistently
- **Task names**: Present tense, descriptive ("Install Docker", "Configure PostgreSQL")
- **Variables**: snake_case with descriptive prefixes (`db_user`, `app_port`, `vault_password_file`)
- **Tags**: Use consistent role categorization (`common`, `database`, `application`, `webserver`)
- **Idempotency**: Ensure all tasks are idempotent and repeatable

### Docker
- **Multi-stage builds**: Separate builder and runtime stages
- **Security**: Non-root users, minimal base images, health checks
- **Environment**: Externalize all configuration via environment variables

### Bash Scripts
- **Error handling**: Always start with `set -euo pipefail`
- **Logging**: Use descriptive log messages with timestamps
- **Exit codes**: Proper exit codes for error conditions

## File Organization Patterns

### Flask Application Structure
```
flask-auth-example/
├── app/
│   ├── __init__.py          # App factory
│   ├── models.py            # SQLAlchemy models
│   ├── routes.py            # Flask routes/blueprints
│   ├── extensions.py        # Flask extensions init
│   └── forms.py             # WTForms validation
├── static/                  # CSS/JS assets
├── templates/               # Jinja2 templates
├── main.py                  # Application entry point
└── Dockerfile               # Container definition
```

### Ansible Role Structure
```
roles/
├── defaults/                # Default variables
├── handlers/                # Event handlers
├── tasks/                   # Main tasks
├── templates/               # Jinja2 templates
└── vars/                    # Role variables
```

## Security Guidelines

- **Secrets management**: Use ansible-vault for all sensitive data
- **Containers**: Run as non-root users, minimal attack surface
- **Network**: Configure firewall rules, use reverse proxy
- **Authentication**: Proper password hashing (bcrypt), session management
- **Environment**: Never commit secrets, use .env files for development

## Testing Approach

### Manual Testing Commands
```bash
# Flask application health
curl -f http://localhost:5000/

# Database connectivity
psql -h localhost -U {{ db_user }} -d {{ db_name }} -c "SELECT 1;"

# Container status
docker ps --filter "name=flask-app"
docker logs flask-app --tail 50

# Service availability
netstat -tlnp | grep :80
netstat -tlnp | grep :5432
```

### Ansible Testing
- Use `--check` mode for dry runs: `ansible-playbook --check site.yml`
- Test specific roles with tags: `ansible-playbook site.yml --tags database`
- Verify idempotency by running playbooks multiple times

## Common Patterns

### Variable Naming Conventions
- **Database**: `db_user`, `db_password`, `db_name`, `db_host`
- **Application**: `app_port`, `app_docker_image`, `app_network`
- **Security**: `vault_password_file`, `ansible_ssh_private_key_file`
- **Infrastructure**: `server_hostname`, `droplet_size`, `region`

### Import Patterns (Python)
```python
from flask import Flask, Blueprint, render_template
from flask_login import UserMixin, login_required
from werkzeug.security import generate_password_hash
from datetime import datetime
from app.extensions import db, bcrypt
from app.models import User
```

## Deployment Workflow

1. **Infrastructure**: `terraform apply` to provision cloud resources
2. **Configuration**: `ansible-playbook site.yml` for initial deployment
3. **Updates**: `ansible-playbook deploy.yml` for application updates
4. **Validation**: Run health checks and testing role
5. **Monitoring**: Use healthcheck.sh and log monitoring

## Environment Management

- **Development**: Local Flask server with SQLite
- **Production**: Gunicorn + Nginx + PostgreSQL
- **Container**: Docker image with multi-stage build
- **Infrastructure**: DigitalOcean droplets via Terraform

## Debugging Tips

- Check Ansible logs: `/var/log/ansible/`
- Application logs: Docker logs or `/var/log/flask-app/`
- Database logs: PostgreSQL log files
- Network issues: Use `ansible all -m ping` for connectivity
- Vault issues: Verify vault password file permissions

## Important Notes

- Always use vault password files with proper permissions (600)
- Test configuration changes in development first
- Backup database before major updates
- Monitor disk space and logs regularly
- Keep infrastructure code versioned with application code