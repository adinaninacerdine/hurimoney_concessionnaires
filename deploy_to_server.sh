#!/bin/bash

# Script de déploiement automatique sur le serveur EC2

SERVER_IP=$(terraform output -raw odoo_web_server_ip)
SSH_KEY="~/.ssh/hurimoney-key.pem"

echo "🚀 Déploiement sur le serveur $SERVER_IP..."

# Copier le script de configuration sur le serveur
echo "📋 Copie du script de configuration..."
scp -i $SSH_KEY -o StrictHostKeyChecking=no configure_odoo_rds.sh ubuntu@$SERVER_IP:/tmp/

# Copier les informations Terraform nécessaires
echo "📊 Transmission des informations RDS..."
RDS_ENDPOINT=$(terraform output -raw rds_address)
RDS_PORT=$(terraform output -raw rds_port)

# Exécuter la configuration sur le serveur
echo "⚙️ Configuration d'Odoo sur le serveur..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP << EOF
    # Devenir root pour la configuration
    sudo su - << 'ROOT_EOF'

# Configuration d'Odoo avec RDS
echo "🔧 Configuration d'Odoo avec RDS PostgreSQL..."

# Créer le fichier de configuration Odoo
cat > /etc/odoo/odoo.conf << 'ODOO_EOF'
[options]
# Configuration de base
admin_passwd = admin123

# Configuration de la base de données RDS
db_host = $RDS_ENDPOINT
db_port = $RDS_PORT
db_user = odoo
db_password = OdooPassword2024

# Modules et addons
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons
data_dir = /var/lib/odoo

# Configuration serveur
xmlrpc_port = 8069
longpolling_port = 8072

# Logs
logfile = /var/log/odoo/odoo.log
log_level = info
log_db = True

# Performance
workers = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200

# Configuration
max_cron_threads = 1
unaccent = True
list_db = True
ODOO_EOF

# Ajuster les permissions
chown odoo:odoo /etc/odoo/odoo.conf
chmod 640 /etc/odoo/odoo.conf

echo "✅ Configuration Odoo créée"

# Démarrer le service Odoo
echo "🚀 Démarrage du service Odoo..."
systemctl enable odoo
systemctl start odoo

# Attendre un peu
sleep 15

# Vérifier le statut
systemctl status odoo --no-pager -l

echo "🎉 Configuration terminée!"

ROOT_EOF
EOF

echo ""
echo "✅ Déploiement terminé!"
echo ""
echo "🌐 URLs importantes:"
echo "  Odoo: http://$SERVER_IP:8069"
echo "  Webhook: http://$SERVER_IP:9000/deploy"
echo "  SSH: ssh -i $SSH_KEY ubuntu@$SERVER_IP"
echo ""
echo "📋 Prochaines étapes:"
echo "1. Accéder à Odoo pour créer une base de données"
echo "2. Installer le module hurimoney_concessionnaires"
echo "3. Tester l'intégration"