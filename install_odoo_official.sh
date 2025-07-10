#!/bin/bash

# Installation Odoo suivant la documentation officielle
# https://www.odoo.com/documentation/18.0/administration/install/install.html#linux

set -e

echo "🚀 Installation d'Odoo 18.0 suivant la documentation officielle..."

# Update system
echo "📦 Mise à jour du système..."
apt-get update -y
apt-get upgrade -y

# Install PostgreSQL client (for RDS connection)
echo "🐘 Installation du client PostgreSQL..."
apt-get install -y postgresql-client-14

# Add Odoo repository and key - Following official documentation
echo "🔑 Ajout de la clé de dépôt Odoo..."
wget -q -O - https://nightly.odoo.com/odoo.key | gpg --dearmor -o /usr/share/keyrings/odoo-archive-keyring.gpg

echo "📦 Ajout du dépôt Odoo..."
echo 'deb [signed-by=/usr/share/keyrings/odoo-archive-keyring.gpg] https://nightly.odoo.com/18.0/nightly/deb/ ./' | tee /etc/apt/sources.list.d/odoo.list

# Update package list
echo "🔄 Mise à jour de la liste des paquets..."
apt-get update

# Install Odoo - Official way
echo "📦 Installation d'Odoo..."
apt-get install -y odoo

# Stop Odoo service (we'll configure it first)
echo "⏸️ Arrêt du service Odoo pour configuration..."
systemctl stop odoo
systemctl disable odoo

# Create directories for custom modules
echo "📁 Création des répertoires pour les modules personnalisés..."
mkdir -p /mnt/extra-addons
chown odoo:odoo /mnt/extra-addons

# Wait for RDS to be available (will be configured later)
echo "⏳ Attente de la disponibilité RDS..."

# Create deployment script for custom module
echo "🚀 Création du script de déploiement..."
cat > /opt/deploy_module.sh << 'SCRIPT_EOF'
#!/bin/bash
set -e

MODULE_NAME="hurimoney_concessionnaires"
MODULE_PATH="/mnt/extra-addons/$MODULE_NAME"
REPO_URL="https://github.com/adinaninacerdine/hurimoney_concessionnaires.git"
BRANCH="main"

echo "🚀 Déploiement du module $MODULE_NAME..."

# Stop Odoo
echo "📋 Arrêt d'Odoo..."
systemctl stop odoo

# Backup existing module
if [ -d "$MODULE_PATH" ]; then
    echo "💾 Backup de l'ancien module..."
    mv "$MODULE_PATH" "${MODULE_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Clone module
echo "📥 Téléchargement du module..."
git clone -b $BRANCH $REPO_URL $MODULE_PATH
chown -R odoo:odoo $MODULE_PATH

# Start Odoo
echo "🔄 Redémarrage d'Odoo..."
systemctl start odoo

sleep 10
echo "✅ Déploiement terminé!"
SCRIPT_EOF

chmod +x /opt/deploy_module.sh

# Create webhook script
echo "🔗 Création du webhook..."
cat > /opt/webhook.py << 'WEBHOOK_EOF'
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
                        result = subprocess.run(['/opt/deploy_module.sh'], 
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

chmod +x /opt/webhook.py

# Create webhook service
tee /etc/systemd/system/odoo-webhook.service > /dev/null <<EOF
[Unit]
Description=Odoo Webhook Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /opt/webhook.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Install git for module deployment
echo "📦 Installation de git..."
apt-get install -y git

# Start webhook service
echo "🔄 Démarrage du service webhook..."
systemctl daemon-reload
systemctl enable odoo-webhook.service
systemctl start odoo-webhook.service

echo ""
echo "🎉 Installation d'Odoo terminée!"
echo "📋 Configuration manuelle requise pour la base de données RDS"
echo "📋 Fichier de configuration: /etc/odoo/odoo.conf"
echo "📋 Modules personnalisés: /mnt/extra-addons"
echo "🔄 Webhook: http://$(curl -s ifconfig.me 2>/dev/null):9000/deploy"
echo ""
echo "⚙️ Prochaines étapes:"
echo "1. Configurer /etc/odoo/odoo.conf avec les paramètres RDS"
echo "2. Démarrer le service: systemctl start odoo"
echo "3. Accéder à Odoo: http://$(curl -s ifconfig.me 2>/dev/null):8069"