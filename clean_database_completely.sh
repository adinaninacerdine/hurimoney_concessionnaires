#!/bin/bash

# Script pour nettoyer complètement la base de données des résidus du module

echo "🧹 Nettoyage complet de la base de données..."

SERVER_IP="13.51.48.109"
SSH_KEY="~/.ssh/hurimoney-key.pem"

# Connexion au serveur pour nettoyer la base de données
echo "🗑️ Nettoyage des données corrompues..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP << 'EOF'
    # Passer en root
    sudo su - << 'ROOT_EOF'

# Arrêter Odoo complètement
echo "⏸️ Arrêt d'Odoo..."
systemctl stop odoo
sleep 5

# Nettoyer complètement toutes les références au module
echo "🧹 Nettoyage complet des références du module..."
export PGPASSWORD="OdooPassword2024"
psql -h odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com -p 5432 -U odoo -d odoo << 'SQL_EOF'

-- Supprimer toutes les références au module hurimoney_concessionnaires
DELETE FROM ir_model_data WHERE module = 'hurimoney_concessionnaires';
DELETE FROM ir_model_data WHERE name LIKE '%hurimoney%';

-- Supprimer les modules
DELETE FROM ir_module_module WHERE name = 'hurimoney_concessionnaires';
DELETE FROM ir_module_module WHERE name LIKE '%hurimoney%';

-- Supprimer les modèles
DELETE FROM ir_model WHERE model LIKE '%hurimoney%';
DELETE FROM ir_model_fields WHERE model LIKE '%hurimoney%';

-- Supprimer les vues
DELETE FROM ir_ui_view WHERE name LIKE '%hurimoney%';
DELETE FROM ir_ui_view WHERE key LIKE '%hurimoney%';

-- Supprimer les menus  
DELETE FROM ir_ui_menu WHERE name LIKE '%hurimoney%';
DELETE FROM ir_ui_menu WHERE name LIKE '%HuriMoney%';

-- Supprimer les actions
DELETE FROM ir_act_window WHERE name LIKE '%hurimoney%';
DELETE FROM ir_act_window WHERE name LIKE '%HuriMoney%';

-- Supprimer les permissions
DELETE FROM ir_model_access WHERE name LIKE '%hurimoney%';

-- Supprimer les groupes de sécurité
DELETE FROM res_groups WHERE name LIKE '%hurimoney%';
DELETE FROM res_groups WHERE name LIKE '%HuriMoney%';

-- Supprimer les catégories
DELETE FROM ir_model_category WHERE name LIKE '%hurimoney%';
DELETE FROM ir_model_category WHERE name LIKE '%HuriMoney%';

-- Supprimer les séquences
DELETE FROM ir_sequence WHERE name LIKE '%hurimoney%';
DELETE FROM ir_sequence WHERE name LIKE '%HuriMoney%';

-- Supprimer les données de base problématiques
DELETE FROM ir_model_data WHERE module = 'base' AND name = 'module_hurimoney_concessionnaires';

-- Nettoyer les tables qui pourraient exister
DROP TABLE IF EXISTS hurimoney_concessionnaire CASCADE;
DROP TABLE IF EXISTS hurimoney_transaction CASCADE;
DROP TABLE IF EXISTS hurimoney_kit CASCADE;

-- Commit les changements
COMMIT;

-- Vérifier qu'il n'y a plus de résidus
SELECT COUNT(*) as remaining_records FROM ir_model_data WHERE module = 'hurimoney_concessionnaires';
SELECT COUNT(*) as remaining_base_records FROM ir_model_data WHERE module = 'base' AND name = 'module_hurimoney_concessionnaires';

SQL_EOF

echo "✅ Nettoyage de la base de données terminé"

# Forcer la mise à jour de la liste des modules
echo "📋 Mise à jour forcée de la liste des modules..."
cd /mnt/extra-addons
rm -rf hurimoney_concessionnaires
git clone https://github.com/adinaninacerdine/hurimoney_concessionnaires.git
chown -R odoo:odoo hurimoney_concessionnaires

echo "🚀 Redémarrage d'Odoo..."
systemctl start odoo
sleep 20

echo "📊 Statut du service:"
systemctl status odoo --no-pager -l

echo "📋 Logs récents:"
tail -n 20 /var/log/odoo/odoo.log

echo ""
echo "🎉 Nettoyage terminé!"
echo "🌐 Testez l'accès: http://$(curl -s ifconfig.me):8069"
echo ""
echo "📋 Instructions pour installer le module:"
echo "1. Aller sur http://$(curl -s ifconfig.me):8069"
echo "2. Créer/Se connecter à une base de données"
echo "3. Aller dans Apps → Update Apps List"
echo "4. Rechercher 'hurimoney' et installer"

ROOT_EOF
EOF

echo ""
echo "✅ Nettoyage complet terminé!"
echo "🌐 Accès Odoo: http://$SERVER_IP:8069"