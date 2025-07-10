#!/bin/bash

# Installation simple Odoo Web Server
set -e

echo "🚀 Installation du serveur web Odoo..."

# Update system
echo "📦 Mise à jour du système..."
apt-get update -y
apt-get upgrade -y

# Install system dependencies
echo "📦 Installation des dépendances système..."
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
    python3-scipy \
    libevent-dev \
    libssl-dev \
    xfonts-base \
    xfonts-75dpi \
    fontconfig \
    postgresql-client-14

# Install wkhtmltopdf
echo "📄 Installation de wkhtmltopdf..."
if [ ! -f /usr/local/bin/wkhtmltopdf ]; then
    wget -q https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
    dpkg -i wkhtmltox_0.12.6.1-3.jammy_amd64.deb || apt-get -f install -y
    rm -f wkhtmltox_0.12.6.1-3.jammy_amd64.deb
fi

# Create Odoo user
echo "👤 Création de l'utilisateur Odoo..."
useradd -m -d /opt/odoo -U -r -s /bin/bash odoo 2>/dev/null || echo "Utilisateur odoo existe déjà"

# Clone Odoo
echo "📥 Téléchargement d'Odoo 18..."
if [ ! -d /opt/odoo/odoo ]; then
    su - odoo -c "git clone https://www.github.com/odoo/odoo --depth 1 --branch 18.0 /opt/odoo/odoo"
fi

# Create virtual environment
echo "🐍 Création de l'environnement virtuel..."
if [ ! -d /opt/odoo/venv ]; then
    su - odoo -c "python3 -m venv /opt/odoo/venv"
fi

# Upgrade pip and essential tools
echo "🔧 Mise à jour des outils pip..."
su - odoo -c "/opt/odoo/venv/bin/pip install --upgrade pip setuptools wheel"

# Install Python packages
echo "📦 Installation des packages Python..."
su - odoo -c "/opt/odoo/venv/bin/pip install \
    Babel \
    chardet \
    cryptography \
    decorator \
    docutils \
    freezegun \
    idna \
    Jinja2 \
    libsass \
    lxml \
    lxml-html-clean \
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
    pypdf \
    pyserial \
    python-dateutil \
    python-stdnum \
    pytz \
    pyusb \
    qrcode \
    reportlab \
    requests \
    rjsmin \
    urllib3 \
    vobject \
    Werkzeug==2.0.3 \
    xlrd \
    XlsxWriter \
    xlwt \
    zeep"

# Create directories
echo "📁 Création des répertoires..."
su - odoo -c "mkdir -p /opt/odoo/extra-addons"
su - odoo -c "mkdir -p /opt/odoo/data"
mkdir -p /var/log/odoo
chown odoo:odoo /var/log/odoo

# Create basic Odoo config (will be updated manually)
echo "⚙️ Configuration d'Odoo..."
tee /etc/odoo.conf > /dev/null <<EOF
[options]
admin_passwd = admin123
db_host = localhost
db_port = 5432
db_user = odoo
db_password = 
addons_path = /opt/odoo/odoo/addons,/opt/odoo/extra-addons
data_dir = /opt/odoo/data
logfile = /var/log/odoo/odoo.log
log_level = info
list_db = True
db_filter = False
EOF

chown odoo:odoo /etc/odoo.conf
chmod 640 /etc/odoo.conf

# Create systemd service
echo "🔧 Création du service systemd..."
tee /etc/systemd/system/odoo.service > /dev/null <<EOF
[Unit]
Description=Odoo Web Server
Documentation=http://www.odoo.com
After=network.target

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
cat > /opt/odoo/deploy_module.sh << 'SCRIPT_EOF'
#!/bin/bash
set -e

MODULE_NAME="hurimoney_concessionnaires"
MODULE_PATH="/opt/odoo/extra-addons/$MODULE_NAME"
REPO_URL="https://github.com/adinaninacerdine/hurimoney_concessionnaires.git"
BRANCH="main"

echo "🚀 Déploiement du module $MODULE_NAME..."

# Arrêter Odoo
echo "📋 Arrêt d'Odoo..."
sudo systemctl stop odoo.service

# Backup du module existant
if [ -d "$MODULE_PATH" ]; then
    echo "💾 Backup de l'ancien module..."
    sudo mv "$MODULE_PATH" "${MODULE_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Cloner le module
echo "📥 Téléchargement du module..."
sudo -u odoo git clone -b $BRANCH $REPO_URL $MODULE_PATH

# Redémarrer Odoo
echo "🔄 Redémarrage d'Odoo..."
sudo systemctl start odoo.service

sleep 10
echo "✅ Déploiement terminé!"
SCRIPT_EOF

chmod +x /opt/odoo/deploy_module.sh
chown odoo:odoo /opt/odoo/deploy_module.sh

# Create webhook script
echo "🔗 Création du webhook..."
cat > /opt/odoo/webhook.py << 'WEBHOOK_EOF'
#!/usr/bin/env python3
import json
import subprocess
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/deploy':
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length > 0:
                post_data = self.rfile.read(content_length)
                
                try:
                    payload = json.loads(post_data.decode('utf-8'))
                    logger.info(f"Received webhook payload: {payload.get('ref', 'unknown ref')}")
                    
                    if payload.get('ref') == 'refs/heads/main':
                        logger.info("Starting deployment...")
                        result = subprocess.run(['/opt/odoo/deploy_module.sh'], 
                                              capture_output=True, text=True, timeout=300)
                        
                        if result.returncode == 0:
                            logger.info("Deployment successful")
                            self.send_response(200)
                            self.send_header('Content-type', 'application/json')
                            self.end_headers()
                            self.wfile.write(b'{"status": "success", "message": "Deployment completed"}')
                        else:
                            logger.error(f"Deployment failed: {result.stderr}")
                            self.send_response(500)
                            self.send_header('Content-type', 'application/json')
                            self.end_headers()
                            self.wfile.write(f'{{"status": "error", "message": "Deployment failed: {result.stderr}"}}'.encode())
                    else:
                        logger.info(f"Ignoring push to {payload.get('ref', 'unknown')}")
                        self.send_response(200)
                        self.send_header('Content-type', 'application/json')
                        self.end_headers()
                        self.wfile.write(b'{"status": "ignored", "message": "Not a push to main branch"}')
                        
                except Exception as e:
                    logger.error(f"Error: {e}")
                    self.send_response(500)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    self.wfile.write(f'{{"error": "Internal server error: {str(e)}"}}'.encode())
            else:
                self.send_response(400)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(b'{"error": "No content"}')
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "Webhook server running", "endpoint": "/deploy"}')
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 9000), WebhookHandler)
    logger.info("Starting webhook server on port 9000...")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down webhook server...")
        server.shutdown()
WEBHOOK_EOF

chmod +x /opt/odoo/webhook.py
chown odoo:odoo /opt/odoo/webhook.py

# Create webhook service
tee /etc/systemd/system/odoo-webhook.service > /dev/null <<EOF
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

# Configure sudo permissions for odoo user
tee /etc/sudoers.d/odoo-deploy > /dev/null <<'EOF'
odoo ALL=(ALL) NOPASSWD: /bin/systemctl start odoo.service
odoo ALL=(ALL) NOPASSWD: /bin/systemctl stop odoo.service
odoo ALL=(ALL) NOPASSWD: /bin/systemctl restart odoo.service
odoo ALL=(ALL) NOPASSWD: /bin/systemctl status odoo.service
odoo ALL=(ALL) NOPASSWD: /bin/mv /opt/odoo/extra-addons/hurimoney_concessionnaires /opt/odoo/extra-addons/hurimoney_concessionnaires.backup.*
EOF

# Start services
echo "🔄 Démarrage des services..."
systemctl daemon-reload
systemctl enable odoo.service
systemctl enable odoo-webhook.service

# Don't start Odoo yet (will be configured manually)
systemctl start odoo-webhook.service

echo ""
echo "🎉 Installation terminée!"
echo "📋 Configuration manuelle requise pour la base de données"
echo "📋 Accès SSH: ssh -i ~/.ssh/hurimoney-key.pem ubuntu@$(curl -s ifconfig.me)"
echo "🔄 Webhook: http://$(curl -s ifconfig.me):9000/deploy"