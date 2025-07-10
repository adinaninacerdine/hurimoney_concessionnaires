#!/bin/bash

# Script d'installation manuel Odoo 18 - Version robuste
set -e

echo "🚀 Installation manuelle d'Odoo 18..."

# Update system
echo "📦 Mise à jour du système..."
sudo apt-get update -y
sudo apt-get upgrade -y

# Install dependencies without problematic packages
echo "📦 Installation des dépendances..."
sudo apt-get install -y \
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
    python3-scipy \
    libevent-dev \
    libssl-dev \
    xfonts-base \
    xfonts-75dpi \
    fontconfig

# Install wkhtmltopdf
echo "📄 Installation de wkhtmltopdf..."
if [ ! -f /usr/local/bin/wkhtmltopdf ]; then
    wget -q https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
    sudo dpkg -i wkhtmltox_0.12.6.1-3.jammy_amd64.deb || sudo apt-get -f install -y
    rm -f wkhtmltox_0.12.6.1-3.jammy_amd64.deb
fi

# Install PostgreSQL
echo "🗄️ Installation de PostgreSQL..."
sudo apt-get install -y postgresql
sudo -u postgres createuser -s odoo 2>/dev/null || echo "Utilisateur odoo existe déjà"

# Create Odoo user
echo "👤 Création de l'utilisateur Odoo..."
sudo useradd -m -d /opt/odoo -U -r -s /bin/bash odoo 2>/dev/null || echo "Utilisateur odoo existe déjà"

# Clone Odoo
echo "📥 Téléchargement d'Odoo 18..."
if [ ! -d /opt/odoo/odoo ]; then
    sudo -u odoo git clone https://www.github.com/odoo/odoo --depth 1 --branch 18.0 /opt/odoo/odoo
fi

# Create virtual environment
echo "🐍 Création de l'environnement virtuel..."
if [ ! -d /opt/odoo/venv ]; then
    sudo -u odoo python3 -m venv /opt/odoo/venv
fi

# Upgrade pip and essential tools
echo "🔧 Mise à jour des outils pip..."
sudo -u odoo /opt/odoo/venv/bin/pip install --upgrade pip setuptools wheel

# Install packages individually to avoid conflicts
echo "📦 Installation des paquets Python (méthode robuste)..."

# Core numerical libraries first
sudo -u odoo /opt/odoo/venv/bin/pip install numpy scipy

# Install gevent from binary if possible
echo "⚡ Installation de gevent..."
sudo -u odoo /opt/odoo/venv/bin/pip install --only-binary=all gevent || \
sudo -u odoo /opt/odoo/venv/bin/pip install gevent==21.12.0 || \
echo "⚠️ Gevent installation failed, continuing..."

# Install pandas with no dependencies to avoid conflicts
echo "🐼 Installation de pandas..."
sudo -u odoo /opt/odoo/venv/bin/pip install pandas --no-deps

# Install other required packages one by one
echo "📦 Installation des autres dépendances..."
sudo -u odoo /opt/odoo/venv/bin/pip install \
    Babel \
    chardet \
    cryptography \
    decorator \
    docutils \
    ebaysdk \
    freezegun \
    idna \
    Jinja2 \
    libsass \
    lxml \
    Markdown \
    MarkupSafe \
    num2words \
    ofxparse \
    passlib \
    Pillow \
    polib \
    psutil \
    psycopg2-binary \
    pydot \
    pyopenssl \
    PyPDF2 \
    pyserial \
    python-dateutil \
    python-stdnum \
    pytz \
    pyusb \
    qrcode \
    reportlab \
    requests \
    urllib3 \
    vobject \
    Werkzeug \
    xlrd \
    XlsxWriter \
    xlwt \
    zeep

# Create addons directory
sudo -u odoo mkdir -p /opt/odoo/extra-addons

# Clone custom module
echo "📥 Téléchargement du module personnalisé..."
if [ -d /opt/odoo/extra-addons/hurimoney_concessionnaires ]; then
    sudo rm -rf /opt/odoo/extra-addons/hurimoney_concessionnaires
fi
sudo -u odoo git clone https://github.com/adinaninacerdine/hurimoney_concessionnaires.git /opt/odoo/extra-addons/hurimoney_concessionnaires

# Create Odoo config
echo "⚙️ Configuration d'Odoo..."
sudo tee /etc/odoo.conf > /dev/null <<EOF
[options]
; This is the password that allows database operations:
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = /opt/odoo/odoo/addons,/opt/odoo/extra-addons
logfile = /var/log/odoo/odoo.log
log_level = info
EOF

# Create log directory
sudo mkdir -p /var/log/odoo
sudo chown odoo:odoo /var/log/odoo

# Create systemd service
echo "🔧 Création du service systemd..."
sudo tee /etc/systemd/system/odoo.service > /dev/null <<EOF
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
After=network.target postgresql.service

[Service]
Type=simple
User=odoo
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo.conf
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create deployment script
echo "🚀 Création du script de déploiement..."
sudo tee /opt/odoo/deploy_module.sh > /dev/null <<'EOF'
#!/bin/bash
set -e

MODULE_NAME="hurimoney_concessionnaires"
MODULE_PATH="/opt/odoo/extra-addons/$MODULE_NAME"
REPO_URL="https://github.com/adinaninacerdine/hurimoney_concessionnaires.git"
BRANCH="main"

echo "🚀 Déploiement du module $MODULE_NAME..."

# Stop Odoo
echo "📋 Arrêt d'Odoo..."
sudo systemctl stop odoo.service

# Backup existing module
if [ -d "$MODULE_PATH" ]; then
    echo "💾 Backup de l'ancien module..."
    sudo mv "$MODULE_PATH" "${MODULE_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Clone module
echo "📥 Téléchargement du module..."
sudo -u odoo git clone -b $BRANCH $REPO_URL $MODULE_PATH

# Start Odoo
echo "🔄 Redémarrage d'Odoo..."
sudo systemctl start odoo.service

echo "✅ Déploiement terminé!"
EOF

sudo chmod +x /opt/odoo/deploy_module.sh

# Create webhook script
echo "🔗 Création du webhook..."
sudo tee /opt/odoo/webhook.py > /dev/null <<'EOF'
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
                
                if payload.get('ref') == 'refs/heads/main':
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

sudo chmod +x /opt/odoo/webhook.py

# Create webhook service
sudo tee /etc/systemd/system/odoo-webhook.service > /dev/null <<EOF
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

# Start services
echo "🔄 Démarrage des services..."
sudo systemctl daemon-reload
sudo systemctl enable odoo.service
sudo systemctl enable odoo-webhook.service
sudo systemctl start odoo.service
sudo systemctl start odoo-webhook.service

# Wait for services to start
sleep 10

# Check services status
echo "📊 État des services:"
sudo systemctl status odoo.service --no-pager -l
sudo systemctl status odoo-webhook.service --no-pager -l

echo ""
echo "🎉 Installation terminée!"
echo "📋 Odoo: http://$(curl -s ifconfig.me):8069"
echo "🔄 Webhook: http://$(curl -s ifconfig.me):9000/deploy"
echo "📊 Logs: sudo journalctl -u odoo -f"