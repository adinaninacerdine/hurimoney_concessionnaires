#!/bin/bash

echo "🔧 Correction complète des vues avec icônes pour HuriMoney"
echo "======================================================="

# Variables
SERVER_IP="13.51.48.109"
SSH_KEY="/home/kidjanitek/.ssh/hurimoney-key.pem"
MODULE_PATH="/mnt/extra-addons/hurimoney_concessionnaires"

# Fonction pour exécuter des commandes sur le serveur
run_on_server() {
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "sudo bash -c \"$1\""
}

echo "📋 1. Arrêt d'Odoo..."
run_on_server "systemctl stop odoo"

echo "🧹 2. Nettoyage des vues corrompues en base..."
run_on_server "
export PGPASSWORD='OdooPassword2024'
psql -h odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com -p 5432 -U odoo -d odoo -c \"DELETE FROM ir_ui_view WHERE name LIKE '%hurimoney%';\"
psql -h odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com -p 5432 -U odoo -d odoo -c \"DELETE FROM ir_model_data WHERE module = 'hurimoney_concessionnaires' AND model = 'ir.ui.view';\"
"

echo "🎨 3. Nettoyage et permissions..."
run_on_server "
chown -R odoo:odoo $MODULE_PATH
chmod -R 755 $MODULE_PATH
find $MODULE_PATH -name '*.pyc' -delete
find $MODULE_PATH -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
"

echo "🚀 4. Redémarrage d'Odoo..."
run_on_server "systemctl start odoo"

echo "⏳ 5. Attente du démarrage complet..."
sleep 30

echo "📊 6. Vérification du statut..."
run_on_server "systemctl status odoo --no-pager -l"

echo "📋 7. Vérification des logs..."
run_on_server "tail -n 20 /var/log/odoo/odoo.log"

echo ""
echo "🎉 NETTOYAGE TERMINÉ!"
echo "===================="
echo ""
echo "✅ Actions effectuées:"
echo "  • Suppression des vues corrompues en base"
echo "  • Nettoyage des fichiers temporaires"
echo "  • Redémarrage d'Odoo"
echo ""
echo "🌐 Pour voir les changements:"
echo "1. Accédez à http://$SERVER_IP:8069"
echo "2. Allez dans Apps → Update Apps List"
echo "3. Cliquez sur 'Upgrade' pour le module 'hurimoney'"
echo "4. Une fois la mise à jour terminée, vous verrez les vues corrigées!"