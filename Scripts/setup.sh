#!/bin/bash
# Простой скрипт установки зависимостей
# Использование: ./setup.sh

set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting setup..."

# Update packages
echo "Updating packages..."
sudo apt update -y

# Install Python 3.12 and dependencies
echo "Installing Python 3.12..."
sudo apt install -y python3.12 python3.12-venv python3-pip \
    postgresql-client libpq-dev build-essential

# Verify Python
if ! command -v python3.12 &> /dev/null; then
    echo "ERROR: Python 3.12 not found"
    exit 1
fi

echo "Python version: $(python3.12 --version)"

# Setup project
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
APP_DIR="${PROJECT_ROOT}/flask-auth-example"
VENV_DIR="${APP_DIR}/venv"

# Create venv
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3.12 -m venv "$VENV_DIR"
fi

# Install requirements
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r "${APP_DIR}/requirements.txt"

echo "=========================================="
echo "Setup completed successfully!"
echo "Activate: source $VENV_DIR/bin/activate"
echo "=========================================="
