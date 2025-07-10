#!/bin/bash

# Exit on any error
set -e

# Update and install dependencies
apt-get update
apt-get upgrade -y

# Install system dependencies for Odoo + pandas
apt-get install -y \
    git \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-wheel \
    python3-setuptools \
    build-essential \
    wget \
    curl \
    libxslt-dev \
    libzip-dev \
    libldap2-dev \
    libsasl2-dev \
    node-less \
    libjpeg-dev \
    libpq-dev \
    libffi-dev \
    pkg-config \
    gfortran \
    libopenblas-dev \
    liblapack-dev \
    libblas-dev \
    libatlas-base-dev \
    python3-numpy \
    python3-scipy

# Install wkhtmltopdf dependencies first
apt-get install -y xfonts-base xfonts-75dpi fontconfig

# Install wkhtmltopdf for Ubuntu 22.04
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
dpkg -i wkhtmltox_0.12.6.1-3.jammy_amd64.deb || apt-get -f install -y
apt-get -f install -y

# Install PostgreSQL
apt-get install -y postgresql
su - postgres -c "createuser -s odoo"

# Create Odoo user
useradd -m -d /opt/odoo -U -r -s /bin/bash odoo

# Install Odoo
su - odoo -c "git clone https://www.github.com/odoo/odoo --depth 1 --branch 18.0 /opt/odoo/odoo"
su - odoo -c "python3 -m venv /opt/odoo/venv"

# Upgrade pip and install wheel first
/opt/odoo/venv/bin/pip install --upgrade pip setuptools wheel

# Install compilation dependencies for gevent
apt-get install -y libevent-dev libssl-dev

# Install numpy and scipy first (pandas dependencies)
/opt/odoo/venv/bin/pip install numpy scipy

# Install gevent separately to avoid compilation issues
/opt/odoo/venv/bin/pip install --only-binary=all gevent || /opt/odoo/venv/bin/pip install gevent==21.12.0

# Install Odoo requirements (excluding problematic packages)
/opt/odoo/venv/bin/pip install -r /opt/odoo/odoo/requirements.txt --ignore-installed gevent

# Install pandas separately with no-deps to avoid conflicts
/opt/odoo/venv/bin/pip install pandas --no-deps

# Create custom addons folder
su - odoo -c "mkdir -p /opt/odoo/extra-addons"

# Create deployment script for module updates
cat <<'EOF' > /opt/odoo/deploy_module.sh
#!/bin/bash
# Script de déploiement/mise à jour des modules Odoo

MODULE_NAME="hurimoney_concessionnaires"
MODULE_PATH="/opt/odoo/extra-addons/$MODULE_NAME"
REPO_URL="${REPO_URL:-https://github.com/username/repo.git}"
BRANCH="${BRANCH:-main}"

echo "🚀 Déploiement du module $MODULE_NAME..."

# Arrêter Odoo
echo "📋 Arrêt d'Odoo..."
systemctl stop odoo.service

# Backup du module existant
if [ -d "$MODULE_PATH" ]; then
    echo "💾 Backup de l'ancien module..."
    mv "$MODULE_PATH" "${MODULE_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Cloner/mettre à jour le module
echo "📥 Téléchargement du module..."
if [ -n "$GITHUB_TOKEN" ]; then
    # Avec token GitHub
    git clone -b $BRANCH https://$GITHUB_TOKEN@github.com/username/repo.git $MODULE_PATH
else
    # Repository public
    git clone -b $BRANCH $REPO_URL $MODULE_PATH
fi

# Changer les permissions
chown -R odoo:odoo $MODULE_PATH

# Redémarrer Odoo
echo "🔄 Redémarrage d'Odoo..."
systemctl start odoo.service

# Attendre que le service soit prêt
sleep 10

# Mettre à jour le module via l'API
echo "🔄 Mise à jour du module..."
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "service": "object",
      "method": "execute",
      "args": ["odoo_db", 1, "admin", "ir.module.module", "upgrade", []]
    },
    "id": 1
  }' \
  http://localhost:8069/jsonrpc || echo "⚠️ Mise à jour manuelle nécessaire"

echo "✅ Déploiement terminé!"
EOF

chmod +x /opt/odoo/deploy_module.sh

# Créer un webhook endpoint pour GitHub
cat <<'EOF' > /opt/odoo/webhook.py
#!/usr/bin/env python3
import json
import subprocess
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/deploy':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                payload = json.loads(post_data.decode('utf-8'))
                
                # Vérifier que c'est un push sur main
                if payload.get('ref') == 'refs/heads/main':
                    # Déclencher le déploiement
                    subprocess.run(['/opt/odoo/deploy_module.sh'], check=True)
                    
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    self.wfile.write(b'{"status": "success"}')
                else:
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    self.wfile.write(b'{"status": "ignored"}')
                    
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(f'{{"error": "{str(e)}"}}'.encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 9000), WebhookHandler)
    server.serve_forever()
EOF

chmod +x /opt/odoo/webhook.py

# Créer service systemd pour le webhook
cat <<EOF > /etc/systemd/system/odoo-webhook.service
[Unit]
Description=Odoo Webhook Service
After=network.target

[Service]
Type=simple
User=odoo
ExecStart=/usr/bin/python3 /opt/odoo/webhook.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Déploiement initial du module
export REPO_URL="https://github.com/adinaninacerdine/hurimoney_concessionnaires.git"
export BRANCH="main"
/opt/odoo/deploy_module.sh

# Create Odoo config file
cat <<EOF > /etc/odoo.conf
[options]
; This is the password that allows database operations:
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = /opt/odoo/odoo/addons,/opt/odoo/extra-addons
EOF

# Create systemd service file
cat <<EOF > /etc/systemd/system/odoo.service
[Unit]
Description=Odoo

[Service]
Type=simple
User=odoo
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo.conf

[Install]
WantedBy=multi-user.target
EOF

# Start services
systemctl daemon-reload
systemctl enable --now odoo.service
systemctl enable --now odoo-webhook.service

echo "🎉 Installation terminée!"
echo "📋 Odoo: http://$(curl -s ifconfig.me):8069"
echo "🔄 Webhook: http://$(curl -s ifconfig.me):9000/deploy"
echo "⚙️ Pour déployer manuellement: /opt/odoo/deploy_module.sh"
