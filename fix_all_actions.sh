#!/bin/bash

# Script pour créer toutes les actions manquantes

echo "🔧 Création de toutes les actions manquantes..."

SERVER_IP="13.51.48.109"
SSH_KEY="~/.ssh/hurimoney-key.pem"

# Connexion au serveur pour créer les actions
echo "📝 Création des actions manquantes..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP << 'EOF'
    # Passer en root
    sudo su - << 'ROOT_EOF'

# Arrêter Odoo
systemctl stop odoo

# Aller dans le répertoire du module
cd /mnt/extra-addons/hurimoney_concessionnaires

# Créer kit_views.xml avec toutes les actions
cat > views/kit_views.xml << 'KIT_EOF'
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data>
        <!-- Vue Liste Kit -->
        <record id="view_hurimoney_kit_tree" model="ir.ui.view">
            <field name="name">hurimoney.kit.tree</field>
            <field name="model">hurimoney.kit</field>
            <field name="arch" type="xml">
                <tree string="Kits">
                    <field name="serial_number"/>
                    <field name="kit_type"/>
                    <field name="phone_model"/>
                    <field name="concessionnaire_id"/>
                    <field name="delivery_date"/>
                    <field name="state" widget="badge"/>
                </tree>
            </field>
        </record>

        <!-- Vue Formulaire Kit -->
        <record id="view_hurimoney_kit_form" model="ir.ui.view">
            <field name="name">hurimoney.kit.form</field>
            <field name="model">hurimoney.kit</field>
            <field name="arch" type="xml">
                <form string="Kit">
                    <sheet>
                        <group>
                            <group string="Informations du Kit">
                                <field name="serial_number"/>
                                <field name="kit_type"/>
                                <field name="phone_model"/>
                                <field name="concessionnaire_id"/>
                            </group>
                            <group string="Livraison">
                                <field name="delivery_date"/>
                                <field name="state"/>
                            </group>
                        </group>
                        <field name="notes" placeholder="Notes..."/>
                    </sheet>
                </form>
            </field>
        </record>

        <!-- Action Kit -->
        <record id="action_hurimoney_kit" model="ir.actions.act_window">
            <field name="name">Kits</field>
            <field name="res_model">hurimoney.kit</field>
            <field name="view_mode">tree,form</field>
            <field name="view_id" ref="view_hurimoney_kit_tree"/>
        </record>
    </data>
</odoo>
KIT_EOF

# Créer transaction_views.xml avec toutes les actions
cat > views/transaction_views.xml << 'TRANSACTION_EOF'
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data>
        <!-- Vue Liste Transaction -->
        <record id="view_hurimoney_transaction_tree" model="ir.ui.view">
            <field name="name">hurimoney.transaction.tree</field>
            <field name="model">hurimoney.transaction</field>
            <field name="arch" type="xml">
                <tree string="Transactions">
                    <field name="name"/>
                    <field name="concessionnaire_id"/>
                    <field name="transaction_date"/>
                    <field name="transaction_type"/>
                    <field name="amount" widget="monetary"/>
                    <field name="commission" widget="monetary"/>
                    <field name="state" widget="badge"/>
                </tree>
            </field>
        </record>

        <!-- Vue Formulaire Transaction -->
        <record id="view_hurimoney_transaction_form" model="ir.ui.view">
            <field name="name">hurimoney.transaction.form</field>
            <field name="model">hurimoney.transaction</field>
            <field name="arch" type="xml">
                <form string="Transaction">
                    <sheet>
                        <group>
                            <group string="Informations de base">
                                <field name="name"/>
                                <field name="concessionnaire_id"/>
                                <field name="transaction_date"/>
                                <field name="transaction_type"/>
                            </group>
                            <group string="Montants">
                                <field name="amount" widget="monetary"/>
                                <field name="commission" widget="monetary"/>
                                <field name="state"/>
                            </group>
                        </group>
                        <group>
                            <group string="Client">
                                <field name="customer_name"/>
                                <field name="customer_phone"/>
                            </group>
                            <group string="Référence">
                                <field name="external_id"/>
                                <field name="reference"/>
                            </group>
                        </group>
                        <field name="notes" placeholder="Notes..."/>
                    </sheet>
                </form>
            </field>
        </record>

        <!-- Action Transaction -->
        <record id="action_hurimoney_transaction" model="ir.actions.act_window">
            <field name="name">Transactions</field>
            <field name="res_model">hurimoney.transaction</field>
            <field name="view_mode">tree,form</field>
            <field name="view_id" ref="view_hurimoney_transaction_tree"/>
        </record>
    </data>
</odoo>
TRANSACTION_EOF

# Créer concessionnaire_views.xml avec toutes les actions
cat > views/concessionnaire_views.xml << 'CONCESSIONNAIRE_EOF'
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data>
        <!-- Vue Liste Concessionnaire -->
        <record id="view_hurimoney_concessionnaire_tree" model="ir.ui.view">
            <field name="name">hurimoney.concessionnaire.tree</field>
            <field name="model">hurimoney.concessionnaire</field>
            <field name="arch" type="xml">
                <tree string="Concessionnaires">
                    <field name="code"/>
                    <field name="name"/>
                    <field name="phone"/>
                    <field name="zone"/>
                    <field name="state" widget="badge"/>
                    <field name="performance_score" widget="percentage"/>
                </tree>
            </field>
        </record>

        <!-- Vue Formulaire Concessionnaire Simplifiée -->
        <record id="view_hurimoney_concessionnaire_form" model="ir.ui.view">
            <field name="name">hurimoney.concessionnaire.form</field>
            <field name="model">hurimoney.concessionnaire</field>
            <field name="arch" type="xml">
                <form string="Concessionnaire">
                    <sheet>
                        <group>
                            <group string="Informations générales">
                                <field name="code"/>
                                <field name="name"/>
                                <field name="phone"/>
                                <field name="email"/>
                                <field name="zone"/>
                                <field name="state"/>
                            </group>
                            <group string="Performance">
                                <field name="performance_score" widget="percentage"/>
                                <field name="ranking"/>
                                <field name="daily_transactions"/>
                                <field name="weekly_transactions"/>
                                <field name="monthly_volume" widget="monetary"/>
                            </group>
                        </group>
                        <group>
                            <group string="Adresse">
                                <field name="street"/>
                                <field name="city"/>
                                <field name="zip"/>
                                <field name="country_id"/>
                            </group>
                            <group string="Géolocalisation">
                                <field name="latitude"/>
                                <field name="longitude"/>
                            </group>
                        </group>
                        <field name="notes" placeholder="Notes..."/>
                    </sheet>
                </form>
            </field>
        </record>

        <!-- Action Concessionnaire -->
        <record id="action_hurimoney_concessionnaire" model="ir.actions.act_window">
            <field name="name">Concessionnaires</field>
            <field name="res_model">hurimoney.concessionnaire</field>
            <field name="view_mode">tree,form</field>
            <field name="view_id" ref="view_hurimoney_concessionnaire_tree"/>
        </record>
    </data>
</odoo>
CONCESSIONNAIRE_EOF

echo "✅ Toutes les actions créées"

# Vérifier les fichiers créés
echo "🔍 Vérification des fichiers créés:"
echo "--- kit_views.xml ---"
head -n 15 views/kit_views.xml
echo ""
echo "--- transaction_views.xml ---"
head -n 15 views/transaction_views.xml
echo ""
echo "--- concessionnaire_views.xml ---"
head -n 15 views/concessionnaire_views.xml
echo ""

# Nettoyer le cache Python
echo "🧹 Nettoyage du cache Python..."
find . -name "*.pyc" -delete
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Redémarrer Odoo
echo "🚀 Redémarrage d'Odoo..."
systemctl start odoo
sleep 25

# Vérifier le statut
echo "📊 Statut du service:"
systemctl status odoo --no-pager -l

echo ""
echo "📋 Logs récents:"
tail -n 15 /var/log/odoo/odoo.log

echo ""
echo "🎉 Toutes les actions créées!"
echo "🌐 Testez l'accès: http://$(curl -s ifconfig.me):8069"

ROOT_EOF
EOF

echo ""
echo "✅ Création de toutes les actions terminée!"
echo "🌐 Accès Odoo: http://$SERVER_IP:8069"
echo ""
echo "📋 Essayez maintenant d'installer le module :"
echo "1. Aller dans Apps → Update Apps List"
echo "2. Rechercher 'hurimoney' et installer"