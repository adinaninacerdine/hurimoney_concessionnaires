#!/bin/bash

# Script complet de correction des erreurs du module HuriMoney
# À exécuter depuis votre machine locale

echo "🔧 Script de correction complète du module HuriMoney"
echo "=================================================="

SERVER_IP="13.51.48.109"
SSH_KEY="/home/kidjanitek/.ssh/hurimoney-key.pem"

# Fonction pour exécuter des commandes sur le serveur
execute_on_server() {
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "$1"
}

echo "📋 Connexion au serveur $SERVER_IP..."

# Script principal à exécuter sur le serveur
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP << 'REMOTE_SCRIPT'
    # Passer en root
    sudo su - << 'ROOT_SCRIPT'

echo "🛑 Arrêt d'Odoo..."
systemctl stop odoo

# Aller dans le répertoire du module
cd /mnt/extra-addons/hurimoney_concessionnaires

echo ""
echo "📝 1. Correction du __manifest__.py (ordre de chargement)..."
cat > __manifest__.py << 'MANIFEST_EOF'
# -*- coding: utf-8 -*-
{
    'name': 'HuriMoney Concessionnaires',
    'version': '18.0.1.0.0',
    'category': 'Sales',
    'summary': 'Gestion des concessionnaires HuriMoney',
    'description': """
        Module de gestion des concessionnaires HuriMoney
        ================================================
        
        Fonctionnalités:
        - Gestion des concessionnaires et leurs informations
        - Suivi des kits et téléphones distribués
        - Enregistrement des transactions
        - Dashboard et rapports de performance
        - Géolocalisation des concessionnaires
    """,
    'author': 'HuriMoney',
    'website': 'https://www.hurimoney.com',
    'depends': [
        'base',
        'mail',
        'contacts',
        'base_geolocalize',
    ],
    'data': [
        # Security
        'security/hurimoney_security.xml',
        'security/ir.model.access.csv',
        
        # Data
        'data/sequence_data.xml',
        
        # Views - ORDRE IMPORTANT: actions avant menus
        'views/concessionnaire_views.xml',
        'views/kit_views.xml', 
        'views/transaction_views.xml',
        'views/dashboard_views.xml',
        'views/wakati_connector_views.xml',
        'wizards/import_wizard_views.xml',
        'views/menu_views.xml',  # DOIT être en dernier
    ],
    'installable': True,
    'application': True,
    'auto_install': False,
    'license': 'LGPL-3',
}
MANIFEST_EOF

echo "✅ __manifest__.py corrigé"

echo ""
echo "📝 2. Ajout des champs manquants dans dashboard.py..."
# Sauvegarder l'original
cp models/dashboard.py models/dashboard.py.bak

# Ajouter le champ name après _description
sed -i '/_description = .*Dashboard HuriMoney.*/a\    \n    name = fields.Char(string="Nom", default="Dashboard HuriMoney", readonly=True)' models/dashboard.py

echo "✅ dashboard.py corrigé"

echo ""
echo "📝 3. Ajout des champs manquants dans kit.py..."
# Sauvegarder l'original
cp models/kit.py models/kit.py.bak

# Ajouter les champs avant _sql_constraints
sed -i '/_sql_constraints = \[/i\    color = fields.Integer(string="Couleur", default=0)\n    currency_id = fields.Many2one(\n        "res.currency",\n        default=lambda self: self.env.company.currency_id,\n        readonly=True\n    )\n' models/kit.py

echo "✅ kit.py corrigé"

echo ""
echo "📝 4. Création de wakati_connector_views.xml..."
mkdir -p views
cat > views/wakati_connector_views.xml << 'WAKATI_VIEW_EOF'
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <record id="view_wakati_connector_form" model="ir.ui.view">
        <field name="name">wakati.api.connector.form</field>
        <field name="model">wakati.api.connector</field>
        <field name="arch" type="xml">
            <form string="Configuration WAKATI">
                <header>
                    <field name="state" widget="statusbar" statusbar_visible="draft,connected"/>
                </header>
                <sheet>
                    <div class="oe_title">
                        <label for="name"/>
                        <h1>
                            <field name="name" placeholder="Nom du connecteur"/>
                        </h1>
                    </div>
                    <group>
                        <group string="Configuration API">
                            <field name="api_base_url"/>
                            <field name="api_key" password="True"/>
                            <field name="api_secret" password="True"/>
                        </group>
                        <group string="Synchronisation">
                            <field name="auto_sync"/>
                            <field name="sync_interval" invisible="not auto_sync"/>
                            <field name="last_sync_date" readonly="1"/>
                        </group>
                    </group>
                    <group>
                        <group string="Options de synchronisation">
                            <field name="sync_concessionnaires"/>
                            <field name="sync_transactions"/>
                            <field name="sync_kits"/>
                        </group>
                        <group string="Statistiques">
                            <field name="sync_success_count" readonly="1"/>
                            <field name="sync_error_count" readonly="1"/>
                        </group>
                    </group>
                    <group string="Dernière erreur" invisible="not last_error_message">
                        <field name="last_error_message" readonly="1" nolabel="1"/>
                    </group>
                    <footer>
                        <button name="action_test_connection" string="Tester Connexion" type="object" class="btn-primary"/>
                        <button name="sync_all" string="Synchroniser Tout" type="object" invisible="state != 'connected'"/>
                        <button name="action_view_logs" string="Voir les logs" type="object" class="btn-secondary"/>
                    </footer>
                </sheet>
            </form>
        </field>
    </record>

    <record id="action_wakati_connector" model="ir.actions.act_window">
        <field name="name">Configuration WAKATI</field>
        <field name="res_model">wakati.api.connector</field>
        <field name="view_mode">form</field>
        <field name="target">current</field>
    </record>
</odoo>
WAKATI_VIEW_EOF

echo "✅ wakati_connector_views.xml créé"

echo ""
echo "📝 5. Correction de l'action dashboard manquante..."
# Ajouter l'action dans dashboard_views.xml si elle n'existe pas
if ! grep -q "action_hurimoney_dashboard" views/dashboard_views.xml; then
    # Insérer l'action avant la fermeture </odoo>
    sed -i '/<\/odoo>/i\    <!-- Action Dashboard -->\n    <record id="action_hurimoney_dashboard" model="ir.actions.act_window">\n        <field name="name">Dashboard</field>\n        <field name="res_model">hurimoney.dashboard</field>\n        <field name="view_mode">form</field>\n        <field name="target">inline</field>\n    </record>' views/dashboard_views.xml
fi

echo "✅ Action dashboard ajoutée"

echo ""
echo "📝 6. Gestion des imports externes dans wakati_connector.py..."
# Modifier le début du fichier pour gérer l'import de requests
cat > models/wakati_connector_temp.py << 'WAKATI_TEMP_EOF'
# -*- coding: utf-8 -*-
import json
import logging
try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False
    logging.getLogger(__name__).warning("Module 'requests' non installé. Les fonctionnalités WAKATI seront désactivées.")

from datetime import datetime, timedelta
from odoo import models, fields, api
from odoo.exceptions import UserError, ValidationError

_logger = logging.getLogger(__name__)
WAKATI_TEMP_EOF

# Ajouter le reste du fichier original sans les imports du début
tail -n +11 models/wakati_connector.py >> models/wakati_connector_temp.py

# Modifier la méthode _make_api_request pour vérifier HAS_REQUESTS
sed -i '/_make_api_request.*(/,/self\.ensure_one()/c\    def _make_api_request(self, endpoint, method='\''GET'\'', data=None, params=None):\n        """Faire une requête API générique avec gestion des erreurs"""\n        if not HAS_REQUESTS:\n            raise UserError("Le module Python '\''requests'\'' doit être installé pour utiliser l'\''API WAKATI.")\n        self.ensure_one()' models/wakati_connector_temp.py

# Remplacer l'original
mv models/wakati_connector_temp.py models/wakati_connector.py

echo "✅ wakati_connector.py corrigé"

echo ""
echo "📝 7. Ajout des entrées manquantes dans ir.model.access.csv..."
# Ajouter les lignes si elles n'existent pas
if ! grep -q "wakati.sync.log" security/ir.model.access.csv; then
    echo "access_wakati_sync_log_user,wakati.sync.log user,model_wakati_sync_log,group_hurimoney_user,1,0,0,0" >> security/ir.model.access.csv
    echo "access_wakati_sync_log_manager,wakati.sync.log manager,model_wakati_sync_log,group_hurimoney_manager,1,1,1,1" >> security/ir.model.access.csv
fi

echo "✅ ir.model.access.csv mis à jour"

echo ""
echo "📝 8. Suppression des fichiers vides..."
rm -f data/cron_data.xml
rm -f static/src/js/map_view.js
rm -f static/src/scss/map_view.scss

echo "✅ Fichiers vides supprimés"

echo ""
echo "📝 9. Correction des vues dans kit_views.xml..."
# Corriger le widget boolean dans la vue kanban
if [ -f views/kit_views.xml ]; then
    sed -i 's/widget="boolean" invisible="not deposit_paid"/invisible="not deposit_paid"/g' views/kit_views.xml
fi

echo "✅ kit_views.xml corrigé"

echo ""
echo "📝 10. Vérification et ajout de l'action import wizard..."
if [ ! -f wizards/import_wizard_views.xml ]; then
    echo "⚠️ wizards/import_wizard_views.xml manquant, création..."
    mkdir -p wizards
    cat > wizards/import_wizard_views.xml << 'WIZARD_VIEW_EOF'
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <record id="view_hurimoney_import_wizard" model="ir.ui.view">
        <field name="name">hurimoney.import.wizard.form</field>
        <field name="model">hurimoney.import.wizard</field>
        <field name="arch" type="xml">
            <form string="Import de données HuriMoney">
                <group>
                    <group string="Type d'import">
                        <field name="import_type" widget="radio" options="{'horizontal': True}"/>
                    </group>
                    <group string="Fichier">
                        <field name="file" filename="filename" widget="binary"/>
                        <field name="filename" invisible="1"/>
                        <field name="delimiter"/>
                    </group>
                </group>
                <footer>
                    <button name="action_import" string="Importer" type="object" class="btn-primary"/>
                    <button string="Annuler" class="btn-secondary" special="cancel"/>
                </footer>
            </form>
        </field>
    </record>

    <record id="action_hurimoney_import_wizard" model="ir.actions.act_window">
        <field name="name">Import de données</field>
        <field name="res_model">hurimoney.import.wizard</field>
        <field name="view_mode">form</field>
        <field name="target">new</field>
    </record>
</odoo>
WIZARD_VIEW_EOF
fi

echo "✅ Vues wizard vérifiées"

echo ""
echo "🧹 11. Nettoyage du cache Python..."
find . -name "*.pyc" -delete
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

echo "✅ Cache Python nettoyé"

echo ""
echo "🔍 12. Vérification finale de la structure..."
echo "Structure actuelle du module:"
find . -type f -name "*.py" -o -name "*.xml" | sort

echo ""
echo "🚀 13. Redémarrage d'Odoo..."
systemctl start odoo

# Attendre le démarrage
sleep 15

echo ""
echo "📊 Statut du service Odoo:"
systemctl status odoo --no-pager -l

echo ""
echo "📋 Dernières lignes des logs:"
tail -n 30 /var/log/odoo/odoo.log | grep -E "(ERROR|WARNING|hurimoney)" || tail -n 30 /var/log/odoo/odoo.log

echo ""
echo "✅ ========================================="
echo "✅ TOUTES LES CORRECTIONS ONT ÉTÉ APPLIQUÉES"
echo "✅ ========================================="
echo ""
echo "📋 Prochaines étapes:"
echo "1. Accéder à Odoo: http://$(curl -s ifconfig.me):8069"
echo "2. Se connecter avec les identifiants admin"
echo "3. Aller dans Apps → Update Apps List"
echo "4. Rechercher 'hurimoney' et installer/mettre à jour le module"
echo ""
echo "⚠️ Note: Si le module 'requests' est nécessaire pour WAKATI:"
echo "   pip3 install requests"

ROOT_SCRIPT
REMOTE_SCRIPT

echo ""
echo "🎉 Script de correction terminé!"
echo ""
echo "📋 Résumé des corrections appliquées:"
echo "✅ 1. Ordre de chargement corrigé dans __manifest__.py"
echo "✅ 2. Champ 'name' ajouté dans dashboard.py"
echo "✅ 3. Champs 'color' et 'currency_id' ajoutés dans kit.py"
echo "✅ 4. Vue wakati_connector_views.xml créée"
echo "✅ 5. Action dashboard ajoutée"
echo "✅ 6. Gestion des imports externes dans wakati_connector.py"
echo "✅ 7. Entrées de sécurité ajoutées pour wakati.sync.log"
echo "✅ 8. Fichiers vides supprimés"
echo "✅ 9. Widgets corrigés dans les vues"
echo "✅ 10. Structure du module vérifiée"
echo ""
echo "🌐 Accès Odoo: http://$SERVER_IP:8069"



