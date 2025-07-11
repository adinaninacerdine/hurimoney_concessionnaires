#!/bin/bash

# Script pour corriger les types de vues pour Odoo 18 (tree -> list)

echo "🔧 Correction des types de vues pour Odoo 18..."

SERVER_IP="13.51.48.109"
SSH_KEY="~/.ssh/hurimoney-key.pem"

# Connexion au serveur pour corriger les types de vues
echo "📝 Correction des types de vues tree -> list..."
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP << 'EOF'
    # Passer en root
    sudo su - << 'ROOT_EOF'

# Arrêter Odoo
systemctl stop odoo

# Aller dans le répertoire du module
cd /mnt/extra-addons/hurimoney_concessionnaires

# Créer concessionnaire_views.xml corrigé pour Odoo 18
cat > views/concessionnaire_views.xml << 'CONCESSIONNAIRE_EOF'
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data>
        <!-- Vue Liste Concessionnaire -->
        <record id="view_hurimoney_concessionnaire_list" model="ir.ui.view">
            <field name="name">hurimoney.concessionnaire.list</field>
            <field name="model">hurimoney.concessionnaire</field>
            <field name="arch" type="xml">
                <list string="Concessionnaires">
                    <field name="code"/>
                    <field name="name"/>
                    <field name="phone"/>
                    <field name="zone"/>
                    <field name="state" widget="badge"/>
                    <field name="performance_score" widget="percentage"/>
                </list>
            </field>
        </record>

        <!-- Vue Formulaire Concessionnaire -->
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
            <field name="view_mode">list,form</field>
            <field name="view_id" ref="view_hurimoney_concessionnaire_list"/>
        </record>
    </data>
</odoo>
CONCESSIONNAIRE_EOF

# Créer kit_views.xml corrigé pour Odoo 18
cat > views/kit_views.xml << 'KIT_EOF'
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data>
        <!-- Vue Liste Kit -->
        <record id="view_hurimoney_kit_list" model="ir.ui.view">
            <field name="name">hurimoney.kit.list</field>
            <field name="model">hurimoney.kit</field>
            <field name="arch" type="xml">
                <list string="Kits">
                    <field name="serial_number"/>
                    <field name="kit_type"/>
                    <field name="phone_model"/>
                    <field name="concessionnaire_id"/>
                    <field name="delivery_date"/>
                    <field name="state" widget="badge"/>
                </list>
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
            <field name="view_mode">list,form</field>
            <field name="view_id" ref="view_hurimoney_kit_list"/>
        </record>
    </data>
</odoo>
KIT_EOF

# Créer transaction_views.xml corrigé pour Odoo 18
cat > views/transaction_views.xml << 'TRANSACTION_EOF'
<?xml version="1.0" encoding="utf-8"?>
<odoo>
    <data>
        <!-- Vue Liste Transaction -->
        <record id="view_hurimoney_transaction_list" model="ir.ui.view">
            <field name="name">hurimoney.transaction.list</field>
            <field name="model">hurimoney.transaction</field>
            <field name="arch" type="xml">
                <list string="Transactions">
                    <field name="name"/>
                    <field name="concessionnaire_id"/>
                    <field name="transaction_date"/>
                    <field name="transaction_type"/>
                    <field name="amount" widget="monetary"/>
                    <field name="commission" widget="monetary"/>
                    <field name="state" widget="badge"/>
                </list>
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
            <field name="view_mode">list,form</field>
            <field name="view_id" ref="view_hurimoney_transaction_list"/>
        </record>
    </data>
</odoo>
TRANSACTION_EOF

echo "✅ Types de vues corrigés pour Odoo 18"

# Vérifier les fichiers créés
echo "🔍 Vérification des fichiers corrigés:"
echo "--- concessionnaire_views.xml ---"
grep -n "list\|view_mode" views/concessionnaire_views.xml
echo ""
echo "--- kit_views.xml ---"
grep -n "list\|view_mode" views/kit_views.xml
echo ""
echo "--- transaction_views.xml ---"
grep -n "list\|view_mode" views/transaction_views.xml
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
echo "🎉 Types de vues corrigés pour Odoo 18!"
echo "🌐 Testez l'accès: http://$(curl -s ifconfig.me):8069"

ROOT_EOF
EOF

echo ""
echo "✅ Correction des types de vues terminée!"
echo "🌐 Accès Odoo: http://$SERVER_IP:8069"
echo ""
echo "📋 Essayez maintenant d'installer le module :"
echo "1. Aller dans Apps → Update Apps List"
echo "2. Rechercher 'hurimoney' et installer"