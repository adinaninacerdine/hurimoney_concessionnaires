#!/bin/bash

# Script pour corriger la configuration Odoo
echo "🔧 Configuration Odoo pour connexion RDS..."

RDS_ENDPOINT="odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com"
RDS_PASSWORD="OdooPassword2024"

# Arrêter Odoo
echo "⏸️ Arrêt d'Odoo..."
systemctl stop odoo

# Créer les répertoires nécessaires
echo "📁 Création des répertoires..."
mkdir -p /var/log/odoo
mkdir -p /var/lib/odoo
chown -R odoo:odoo /var/log/odoo
chown -R odoo:odoo /var/lib/odoo
chown -R odoo:odoo /mnt/extra-addons

# Configurer Odoo avec une configuration simple
echo "⚙️ Configuration d'Odoo..."
cat > /etc/odoo/odoo.conf << EOF
[options]
# Configuration de base
admin_passwd = admin123

# Configuration de la base de données RDS
db_host = $RDS_ENDPOINT
db_port = 5432
db_user = odoo
db_password = $RDS_PASSWORD
db_maxconn = 64

# Modules et addons
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons
data_dir = /var/lib/odoo

# Configuration serveur
xmlrpc_port = 8069
longpolling_port = 8072

# Logs
logfile = /var/log/odoo/odoo.log
log_level = info
log_db = False
log_db_level = warning

# Performance et limites
workers = 0
max_cron_threads = 1
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200

# Configuration de base
unaccent = True
list_db = True
dbfilter = False

# Sécurité
without_demo = False
EOF

# Ajuster les permissions
chown odoo:odoo /etc/odoo/odoo.conf
chmod 640 /etc/odoo/odoo.conf

echo "✅ Configuration Odoo créée"

# Tester la connexion PostgreSQL
echo "🧪 Test de connexion PostgreSQL..."
export PGPASSWORD="$RDS_PASSWORD"
psql -h $RDS_ENDPOINT -p 5432 -U odoo -d odoo -c "SELECT version();" || echo "⚠️ Test de connexion échoué"

# Démarrer Odoo
echo "🚀 Démarrage d'Odoo..."
systemctl start odoo

# Attendre le démarrage
sleep 15

# Vérifier le statut
echo "📊 Statut du service Odoo:"
systemctl status odoo --no-pager -l

echo ""
echo "📋 Logs récents:"
tail -n 10 /var/log/odoo/odoo.log 2>/dev/null || echo "Logs pas encore disponibles"

echo ""
echo "🎉 Configuration terminée!"
echo "🌐 Testez l'accès: http://$(curl -s ifconfig.me):8069"