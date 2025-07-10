#!/bin/bash

# Script pour corriger les références manquantes dans les vues

echo "🔧 Correction des références manquantes dans les vues..."

SERVER_IP="13.51.48.109"
SSH_KEY="~/.ssh/hurimoney-key.pem"

# Connexion au serveur pour corriger les vues
echo "📝 Correction des fichiers de vues..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP << 'EOF'
    # Passer en root
    sudo su - << 'ROOT_EOF'

# Arrêter Odoo
systemctl stop odoo

# Aller dans le répertoire du module
cd /mnt/extra-addons/hurimoney_concessionnaires

# Corriger menu_views.xml pour supprimer les références manquantes
cat > views/menu_views.xml << 'MENU_EOF'
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data>
        <!-- Menu principal -->
        <menuitem id="menu_hurimoney_root" 
                  name="HuriMoney"
                  sequence="100"
                  web_icon="hurimoney_concessionnaires,static/description/icon.png"/>
        
        <!-- Menu Concessionnaires -->
        <menuitem id="menu_hurimoney_concessionnaires" 
                  name="Concessionnaires" 
                  parent="menu_hurimoney_root"
                  action="action_hurimoney_concessionnaire" 
                  sequence="20"/>
        
        <!-- Menu Kits -->
        <menuitem id="menu_hurimoney_kits" 
                  name="Kits" 
                  parent="menu_hurimoney_root"
                  action="action_hurimoney_kit" 
                  sequence="30"/>
        
        <!-- Menu Transactions -->
        <menuitem id="menu_hurimoney_transactions" 
                  name="Transactions" 
                  parent="menu_hurimoney_root"
                  action="action_hurimoney_transaction" 
                  sequence="40"/>
    </data>
</odoo>
MENU_EOF

# Corriger dashboard_views.xml pour créer l'action manquante
cat > views/dashboard_views.xml << 'DASHBOARD_EOF'
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data>
        <!-- Vue Dashboard -->
        <record id="view_hurimoney_dashboard" model="ir.ui.view">
            <field name="name">hurimoney.dashboard.view</field>
            <field name="model">hurimoney.dashboard</field>
            <field name="arch" type="xml">
                <form string="Dashboard HuriMoney">
                    <sheet>
                        <group>
                            <field name="name"/>
                            <field name="total_concessionnaires"/>
                            <field name="total_kits"/>
                            <field name="total_transactions"/>
                        </group>
                    </sheet>
                </form>
            </field>
        </record>

        <!-- Action Dashboard -->
        <record id="action_hurimoney_dashboard" model="ir.actions.act_window">
            <field name="name">Dashboard</field>
            <field name="res_model">hurimoney.dashboard</field>
            <field name="view_mode">form</field>
            <field name="view_id" ref="view_hurimoney_dashboard"/>
        </record>
    </data>
</odoo>
DASHBOARD_EOF

# Corriger le manifest pour ne charger que les vues qui existent
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
        
        # Views - dans le bon ordre
        'views/concessionnaire_views.xml',
        'views/kit_views.xml', 
        'views/transaction_views.xml',
        'views/dashboard_views.xml',
        'views/menu_views.xml',
    ],
    'installable': True,
    'application': True,
    'auto_install': False,
    'license': 'LGPL-3',
}
MANIFEST_EOF

echo "✅ Fichiers de vues corrigés"

# Vérifier les fichiers créés
echo "🔍 Vérification des fichiers corrigés:"
echo "--- views/menu_views.xml ---"
head -n 20 views/menu_views.xml
echo ""
echo "--- views/dashboard_views.xml ---"
head -n 20 views/dashboard_views.xml
echo ""

# Nettoyer le cache Python
echo "🧹 Nettoyage du cache Python..."
find . -name "*.pyc" -delete
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Redémarrer Odoo
echo "🚀 Redémarrage d'Odoo..."
systemctl start odoo
sleep 20

# Vérifier le statut
echo "📊 Statut du service:"
systemctl status odoo --no-pager -l

echo ""
echo "📋 Logs récents:"
tail -n 15 /var/log/odoo/odoo.log

echo ""
echo "🎉 Correction terminée!"
echo "🌐 Testez l'accès: http://$(curl -s ifconfig.me):8069"

ROOT_EOF
EOF

echo ""
echo "✅ Correction des vues terminée!"
echo "🌐 Accès Odoo: http://$SERVER_IP:8069"
echo ""
echo "📋 Essayez maintenant d'installer le module :"
echo "1. Aller dans Apps → Update Apps List"
echo "2. Rechercher 'hurimoney' et installer"