#!/bin/bash

# Script de configuration d'Odoo avec RDS PostgreSQL
# À exécuter sur le serveur EC2

echo "🔧 Configuration d'Odoo avec RDS PostgreSQL..."

# Récupérer les informations de connexion RDS
RDS_ENDPOINT=$(terraform output -raw rds_address)
RDS_PORT=$(terraform output -raw rds_port)
RDS_CONNECTION=$(terraform output -raw rds_connection_string)

echo "📊 Informations RDS:"
echo "  Endpoint: $RDS_ENDPOINT"
echo "  Port: $RDS_PORT"

# Créer le fichier de configuration Odoo
cat > /etc/odoo/odoo.conf << EOF
[options]
# Configuration de base
admin_passwd = admin123
master_passwd = admin123

# Configuration de la base de données RDS
db_host = $RDS_ENDPOINT
db_port = $RDS_PORT
db_user = odoo
db_password = OdooPassword2024
database = odoo

# Modules et addons
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons
data_dir = /var/lib/odoo

# Configuration serveur
xmlrpc_port = 8069
longpolling_port = 8072

# Logs
logfile = /var/log/odoo/odoo.log
log_level = info
log_handler = :INFO
log_db = True

# Performance
workers = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200

# Configuration de session
max_cron_threads = 1
unaccent = True
list_db = True
db_filter = False

# Configuration proxy (si nécessaire)
proxy_mode = False

EOF

echo "✅ Configuration Odoo créée"

# Ajuster les permissions
chown odoo:odoo /etc/odoo/odoo.conf
chmod 640 /etc/odoo/odoo.conf

echo "🔐 Permissions ajustées"

# Tester la connexion à RDS
echo "🧪 Test de connexion à RDS..."
psql -h $RDS_ENDPOINT -p $RDS_PORT -U odoo -d odoo -c "SELECT version();" || echo "⚠️ Connexion RDS non disponible (normal si RDS en cours de démarrage)"

# Démarrer le service Odoo
echo "🚀 Démarrage du service Odoo..."
systemctl enable odoo
systemctl start odoo

# Vérifier le statut
sleep 10
systemctl status odoo --no-pager -l

echo ""
echo "🎉 Configuration terminée!"
echo "📋 Accès Odoo: http://$(curl -s ifconfig.me):8069"
echo "📋 Webhook: http://$(curl -s ifconfig.me):9000/deploy"
echo "📋 Logs: tail -f /var/log/odoo/odoo.log"
echo ""
echo "🔧 Prochaines étapes:"
echo "1. Accéder à Odoo et créer une base de données"
echo "2. Installer le module hurimoney_concessionnaires"
echo "3. Configurer les utilisateurs et permissions"