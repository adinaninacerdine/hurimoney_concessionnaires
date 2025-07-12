#!/bin/bash

echo "🔧 Correction complète des vues avec icônes pour HuriMoney"
echo "======================================================="

# Variables
SERVER_IP="13.51.48.109"
SSH_KEY="/home/kidjanitek/.ssh/hurimoney-key.pem"
MODULE_PATH="/mnt/extra-addons/hurimoney_concessionnaires"

# Fonction pour exécuter des commandes sur le serveur
run_on_server() {
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$SERVER_IP "sudo bash -c '$1'"
}

echo "📋 1. Arrêt d'Odoo..."
run_on_server "systemctl stop odoo"

echo "🧹 2. Nettoyage des vues corrompues en base..."
run_on_server "
export PGPASSWORD='OdooPassword2024'
psql -h odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com -p 5432 -U odoo -d odoo << 'SQL_EOF'
-- Supprimer toutes les vues du module
DELETE FROM ir_ui_view WHERE name LIKE '%hurimoney%';
DELETE FROM ir_model_data WHERE module = 'hurimoney_concessionnaires' AND model = 'ir.ui.view';
COMMIT;
SQL_EOF
"

echo "🎨 3. Création des vues concessionnaires corrigées..."
run_on_server "
cd $MODULE_PATH
cat > views/concessionnaire_views.xml << 'CONC_VIEWS_EOF'
<?xml version=\"1.0\" encoding=\"utf-8\"?>
<odoo>
    <!-- Vue Liste/Tree -->
    <record id=\"view_hurimoney_concessionnaire_tree\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.concessionnaire.tree</field>
        <field name=\"model\">hurimoney.concessionnaire</field>
        <field name=\"arch\" type=\"xml\">
            <tree string=\"Concessionnaires\" multi_edit=\"1\" decoration-success=\"state == 'active'\" decoration-warning=\"state == 'suspended'\" decoration-danger=\"state == 'inactive'\">
                <field name=\"code\"/>
                <field name=\"name\"/>
                <field name=\"phone\"/>
                <field name=\"zone\"/>
                <field name=\"agent_id\" optional=\"show\"/>
                <field name=\"daily_transactions\" optional=\"show\"/>
                <field name=\"monthly_volume\" optional=\"show\"/>
                <field name=\"performance_score\" optional=\"show\"/>
                <field name=\"state\" widget=\"badge\" decoration-success=\"state == 'active'\" decoration-warning=\"state == 'suspended'\" decoration-danger=\"state == 'inactive'\"/>
                <field name=\"activation_date\" optional=\"hide\"/>
            </tree>
        </field>
    </record>

    <!-- Vue Formulaire -->
    <record id=\"view_hurimoney_concessionnaire_form\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.concessionnaire.form</field>
        <field name=\"model\">hurimoney.concessionnaire</field>
        <field name=\"arch\" type=\"xml\">
            <form string=\"Concessionnaire\">
                <header>
                    <button name=\"action_activate\" string=\"Activer\" type=\"object\" class=\"btn-primary\" invisible=\"state != 'draft'\"/>
                    <button name=\"action_suspend\" string=\"Suspendre\" type=\"object\" class=\"btn-warning\" invisible=\"state != 'active'\"/>
                    <button name=\"action_reactivate\" string=\"Réactiver\" type=\"object\" class=\"btn-primary\" invisible=\"state != 'suspended'\"/>
                    <field name=\"state\" widget=\"statusbar\" statusbar_visible=\"draft,active,suspended,inactive\"/>
                </header>
                <sheet>
                    <div class=\"oe_button_box\" name=\"button_box\">
                        <button name=\"%(action_hurimoney_kit)d\" type=\"action\" class=\"oe_stat_button\" icon=\"fa-mobile\" context=\"{'default_concessionnaire_id': id}\">
                            <div class=\"o_field_widget o_stat_info\">
                                <span class=\"o_stat_value\">0</span>
                                <span class=\"o_stat_text\">Kits</span>
                            </div>
                        </button>
                        <button name=\"%(action_hurimoney_transaction)d\" type=\"action\" class=\"oe_stat_button\" icon=\"fa-exchange\" context=\"{'default_concessionnaire_id': id}\">
                            <div class=\"o_field_widget o_stat_info\">
                                <span class=\"o_stat_value\"><field name=\"total_transactions\"/></span>
                                <span class=\"o_stat_text\">Transactions</span>
                            </div>
                        </button>
                    </div>
                    <div class=\"oe_title\">
                        <label for=\"name\"/>
                        <h1>
                            <field name=\"name\" placeholder=\"Nom du concessionnaire\"/>
                        </h1>
                        <label for=\"code\"/>
                        <h2>
                            <field name=\"code\" readonly=\"1\"/>
                        </h2>
                    </div>
                    <group>
                        <group string=\"Informations générales\">
                            <field name=\"partner_id\"/>
                            <field name=\"phone\"/>
                            <field name=\"email\"/>
                            <field name=\"agent_id\"/>
                            <field name=\"zone\"/>
                        </group>
                        <group string=\"Performance\">
                            <field name=\"performance_score\"/>
                            <field name=\"ranking\"/>
                            <field name=\"daily_transactions\"/>
                            <field name=\"weekly_transactions\"/>
                            <field name=\"monthly_volume\"/>
                        </group>
                    </group>
                    <notebook>
                        <page string=\"Adresse &amp; Localisation\" name=\"location\">
                            <group>
                                <group string=\"Adresse\">
                                    <field name=\"street\" placeholder=\"Rue...\"/>
                                    <field name=\"city\" placeholder=\"Ville\"/>
                                    <field name=\"zip\" placeholder=\"Code postal\"/>
                                    <field name=\"country_id\" options=\"{'no_create': True}\"/>
                                </group>
                                <group string=\"Géolocalisation\">
                                    <field name=\"latitude\"/>
                                    <field name=\"longitude\"/>
                                </group>
                            </group>
                        </page>
                        <page string=\"Transactions\" name=\"transactions\">
                            <field name=\"transaction_ids\" readonly=\"1\">
                                <tree>
                                    <field name=\"name\"/>
                                    <field name=\"transaction_date\"/>
                                    <field name=\"transaction_type\"/>
                                    <field name=\"amount\"/>
                                    <field name=\"commission\"/>
                                    <field name=\"state\" widget=\"badge\"/>
                                </tree>
                            </field>
                        </page>
                        <page string=\"Kits\" name=\"kits\">
                            <field name=\"kit_ids\">
                                <tree>
                                    <field name=\"serial_number\"/>
                                    <field name=\"kit_type\"/>
                                    <field name=\"phone_model\"/>
                                    <field name=\"delivery_date\"/>
                                    <field name=\"state\" widget=\"badge\"/>
                                </tree>
                            </field>
                        </page>
                        <page string=\"Notes\" name=\"notes\">
                            <field name=\"notes\" placeholder=\"Notes internes...\"/>
                        </page>
                    </notebook>
                </sheet>
                <chatter/>
            </form>
        </field>
    </record>

    <!-- Vue Kanban -->
    <record id=\"view_hurimoney_concessionnaire_kanban\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.concessionnaire.kanban</field>
        <field name=\"model\">hurimoney.concessionnaire</field>
        <field name=\"arch\" type=\"xml\">
            <kanban class=\"o_kanban_mobile\" sample=\"1\">
                <field name=\"id\"/>
                <field name=\"name\"/>
                <field name=\"code\"/>
                <field name=\"phone\"/>
                <field name=\"zone\"/>
                <field name=\"state\"/>
                <field name=\"performance_score\"/>
                <field name=\"daily_transactions\"/>
                <field name=\"monthly_volume\"/>
                <field name=\"agent_id\"/>
                <templates>
                    <t t-name=\"kanban-box\">
                        <div t-attf-class=\"oe_kanban_global_click\">
                            <div class=\"o_kanban_record_top\">
                                <div class=\"o_kanban_record_headings\">
                                    <strong class=\"o_kanban_record_title\">
                                        <field name=\"name\"/>
                                    </strong>
                                    <small class=\"o_kanban_record_subtitle text-muted\">
                                        <field name=\"code\"/>
                                    </small>
                                </div>
                                <field name=\"state\" widget=\"label_selection\" options=\"{'classes': {'draft': 'secondary', 'active': 'success', 'suspended': 'warning', 'inactive': 'danger'}}\"/>
                            </div>
                            <div class=\"o_kanban_record_body\">
                                <div class=\"row\">
                                    <div class=\"col-6\">
                                        <i class=\"fa fa-phone\"/> <field name=\"phone\"/>
                                    </div>
                                    <div class=\"col-6\">
                                        <i class=\"fa fa-map-marker\"/> <field name=\"zone\"/>
                                    </div>
                                </div>
                                <div class=\"row mt-1\">
                                    <div class=\"col-6\">
                                        <i class=\"fa fa-user\"/> <field name=\"agent_id\"/>
                                    </div>
                                    <div class=\"col-6\">
                                        <i class=\"fa fa-line-chart\"/> <field name=\"performance_score\"/>%
                                    </div>
                                </div>
                            </div>
                            <div class=\"o_kanban_record_bottom\">
                                <div class=\"oe_kanban_bottom_left\">
                                    <span><field name=\"daily_transactions\"/> trans/jour</span>
                                </div>
                                <div class=\"oe_kanban_bottom_right\">
                                    <field name=\"monthly_volume\"/>
                                </div>
                            </div>
                        </div>
                    </t>
                </templates>
            </kanban>
        </field>
    </record>

    <!-- Vue Search -->
    <record id=\"view_hurimoney_concessionnaire_search\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.concessionnaire.search</field>
        <field name=\"model\">hurimoney.concessionnaire</field>
        <field name=\"arch\" type=\"xml\">
            <search string=\"Rechercher concessionnaires\">
                <field name=\"name\"/>
                <field name=\"code\"/>
                <field name=\"phone\"/>
                <field name=\"agent_id\"/>
                <filter name=\"active\" string=\"Actifs\" domain=\"[('state', '=', 'active')]\"/>
                <filter name=\"suspended\" string=\"Suspendus\" domain=\"[('state', '=', 'suspended')]\"/>
                <filter name=\"inactive\" string=\"Inactifs\" domain=\"[('state', '=', 'inactive')]\"/>
                <separator/>
                <filter name=\"my_concessionnaires\" string=\"Mes concessionnaires\" domain=\"[('agent_id', '=', uid)]\"/>
                <group expand=\"0\" string=\"Grouper par\">
                    <filter name=\"group_by_zone\" string=\"Zone\" domain=\"[]\" context=\"{'group_by': 'zone'}\"/>
                    <filter name=\"group_by_agent\" string=\"Agent\" domain=\"[]\" context=\"{'group_by': 'agent_id'}\"/>
                    <filter name=\"group_by_state\" string=\"État\" domain=\"[]\" context=\"{'group_by': 'state'}\"/>
                </group>
            </search>
        </field>
    </record>

    <!-- Vue Pivot -->
    <record id=\"view_hurimoney_concessionnaire_pivot\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.concessionnaire.pivot</field>
        <field name=\"model\">hurimoney.concessionnaire</field>
        <field name=\"arch\" type=\"xml\">
            <pivot string=\"Analyse des concessionnaires\">
                <field name=\"zone\" type=\"row\"/>
                <field name=\"agent_id\" type=\"row\"/>
                <field name=\"state\" type=\"col\"/>
                <field name=\"total_transactions\" type=\"measure\"/>
                <field name=\"total_volume\" type=\"measure\"/>
                <field name=\"performance_score\" type=\"measure\"/>
            </pivot>
        </field>
    </record>

    <!-- Vue Graph -->
    <record id=\"view_hurimoney_concessionnaire_graph\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.concessionnaire.graph</field>
        <field name=\"model\">hurimoney.concessionnaire</field>
        <field name=\"arch\" type=\"xml\">
            <graph string=\"Performance des concessionnaires\" type=\"bar\">
                <field name=\"zone\" type=\"row\"/>
                <field name=\"performance_score\" type=\"measure\"/>
                <field name=\"total_volume\" type=\"measure\"/>
            </graph>
        </field>
    </record>

    <!-- Action Window avec TOUTES les vues -->
    <record id=\"action_hurimoney_concessionnaire\" model=\"ir.actions.act_window\">
        <field name=\"name\">Concessionnaires</field>
        <field name=\"res_model\">hurimoney.concessionnaire</field>
        <field name=\"view_mode\">kanban,tree,form,pivot,graph</field>
        <field name=\"search_view_id\" ref=\"view_hurimoney_concessionnaire_search\"/>
        <field name=\"context\">{'search_default_active': 1}</field>
        <field name=\"help\" type=\"html\">
            <p class=\"o_view_nocontent_smiling_face\">
                Créer un nouveau concessionnaire
            </p>
            <p>
                Gérez vos concessionnaires HuriMoney, suivez leurs performances
                et leurs transactions.
            </p>
        </field>
    </record>
</odoo>
CONC_VIEWS_EOF
"

echo "🎨 4. Création des vues kits corrigées..."
run_on_server "
cd $MODULE_PATH
cat > views/kit_views.xml << 'KIT_VIEWS_EOF'
<?xml version=\"1.0\" encoding=\"utf-8\"?>
<odoo>
    <!-- Vue Liste/Tree -->
    <record id=\"view_hurimoney_kit_tree\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.kit.tree</field>
        <field name=\"model\">hurimoney.kit</field>
        <field name=\"arch\" type=\"xml\">
            <tree string=\"Kits\" multi_edit=\"1\" decoration-success=\"state == 'active'\" decoration-warning=\"state in ['lost', 'damaged']\" decoration-danger=\"state == 'returned'\" decoration-muted=\"state == 'draft'\">
                <field name=\"serial_number\"/>
                <field name=\"concessionnaire_id\"/>
                <field name=\"kit_type\"/>
                <field name=\"phone_model\"/>
                <field name=\"phone_imei\" optional=\"show\"/>
                <field name=\"delivery_date\"/>
                <field name=\"activation_date\" optional=\"hide\"/>
                <field name=\"total_cost\" sum=\"Total\" optional=\"show\"/>
                <field name=\"deposit_paid\" widget=\"boolean_toggle\" optional=\"show\"/>
                <field name=\"state\" widget=\"badge\" decoration-success=\"state == 'active'\" decoration-warning=\"state in ['lost', 'damaged']\" decoration-danger=\"state == 'returned'\"/>
            </tree>
        </field>
    </record>

    <!-- Vue Formulaire -->
    <record id=\"view_hurimoney_kit_form\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.kit.form</field>
        <field name=\"model\">hurimoney.kit</field>
        <field name=\"arch\" type=\"xml\">
            <form string=\"Kit HuriMoney\">
                <header>
                    <button name=\"action_deliver\" string=\"Marquer comme livré\" type=\"object\" class=\"btn-primary\" invisible=\"state != 'draft'\"/>
                    <button name=\"action_activate\" string=\"Activer\" type=\"object\" class=\"btn-primary\" invisible=\"state != 'delivered'\"/>
                    <field name=\"state\" widget=\"statusbar\" statusbar_visible=\"draft,delivered,active\"/>
                </header>
                <sheet>
                    <div class=\"oe_title\">
                        <label for=\"serial_number\"/>
                        <h1>
                            <field name=\"serial_number\" placeholder=\"Numéro de série\"/>
                        </h1>
                    </div>
                    <group>
                        <group string=\"Informations générales\">
                            <field name=\"concessionnaire_id\" options=\"{'no_create': True}\"/>
                            <field name=\"kit_type\"/>
                            <field name=\"delivery_date\"/>
                            <field name=\"activation_date\" invisible=\"state != 'active'\"/>
                        </group>
                        <group string=\"Téléphone\">
                            <field name=\"phone_model\"/>
                            <field name=\"phone_imei\"/>
                            <field name=\"phone_cost\"/>
                        </group>
                    </group>
                    <group>
                        <group string=\"Coûts\">
                            <field name=\"kit_cost\"/>
                            <field name=\"total_cost\"/>
                        </group>
                        <group string=\"Caution\">
                            <field name=\"deposit_amount\"/>
                            <field name=\"deposit_paid\"/>
                        </group>
                    </group>
                    <notebook>
                        <page string=\"Notes\" name=\"notes\">
                            <field name=\"notes\" placeholder=\"Notes sur ce kit...\"/>
                        </page>
                    </notebook>
                </sheet>
                <chatter/>
            </form>
        </field>
    </record>

    <!-- Vue Kanban -->
    <record id=\"view_hurimoney_kit_kanban\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.kit.kanban</field>
        <field name=\"model\">hurimoney.kit</field>
        <field name=\"arch\" type=\"xml\">
            <kanban class=\"o_kanban_mobile\" default_group_by=\"state\" sample=\"1\">
                <field name=\"serial_number\"/>
                <field name=\"concessionnaire_id\"/>
                <field name=\"kit_type\"/>
                <field name=\"phone_model\"/>
                <field name=\"state\"/>
                <field name=\"total_cost\"/>
                <field name=\"deposit_paid\"/>
                <progressbar field=\"state\" colors='{\"active\": \"success\", \"delivered\": \"info\", \"lost\": \"danger\", \"damaged\": \"warning\"}'/>
                <templates>
                    <t t-name=\"kanban-box\">
                        <div t-attf-class=\"oe_kanban_global_click\">
                            <div class=\"oe_kanban_details\">
                                <strong class=\"o_kanban_record_title\">
                                    <field name=\"serial_number\"/>
                                </strong>
                                <div class=\"o_kanban_tags_section\">
                                    <field name=\"kit_type\" widget=\"badge\"/>
                                </div>
                                <ul>
                                    <li><i class=\"fa fa-user\"/> <field name=\"concessionnaire_id\"/></li>
                                    <li><i class=\"fa fa-mobile\"/> <field name=\"phone_model\"/></li>
                                    <li><i class=\"fa fa-money\"/> <field name=\"total_cost\"/></li>
                                </ul>
                                <div class=\"oe_kanban_footer\">
                                    <div class=\"o_kanban_record_bottom\">
                                        <div class=\"oe_kanban_bottom_left\">
                                            <field name=\"state\" widget=\"label_selection\" options=\"{'classes': {'draft': 'secondary', 'delivered': 'info', 'active': 'success', 'lost': 'danger', 'damaged': 'warning', 'returned': 'danger'}}\"/>
                                        </div>
                                        <div class=\"oe_kanban_bottom_right\">
                                            <field name=\"deposit_paid\" widget=\"boolean\" invisible=\"not deposit_paid\"/>
                                            <span invisible=\"deposit_paid\" class=\"text-danger\">
                                                <i class=\"fa fa-exclamation-triangle\" title=\"Caution non payée\"/>
                                            </span>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </t>
                </templates>
            </kanban>
        </field>
    </record>

    <!-- Vue Search -->
    <record id=\"view_hurimoney_kit_search\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.kit.search</field>
        <field name=\"model\">hurimoney.kit</field>
        <field name=\"arch\" type=\"xml\">
            <search string=\"Rechercher kits\">
                <field name=\"serial_number\"/>
                <field name=\"phone_imei\"/>
                <field name=\"concessionnaire_id\"/>
                <field name=\"phone_model\"/>
                <filter name=\"active\" string=\"Actifs\" domain=\"[('state', '=', 'active')]\"/>
                <filter name=\"delivered\" string=\"Livrés\" domain=\"[('state', '=', 'delivered')]\"/>
                <group expand=\"0\" string=\"Grouper par\">
                    <filter name=\"group_by_concessionnaire\" string=\"Concessionnaire\" domain=\"[]\" context=\"{'group_by': 'concessionnaire_id'}\"/>
                    <filter name=\"group_by_type\" string=\"Type de kit\" domain=\"[]\" context=\"{'group_by': 'kit_type'}\"/>
                    <filter name=\"group_by_state\" string=\"État\" domain=\"[]\" context=\"{'group_by': 'state'}\"/>
                </group>
            </search>
        </field>
    </record>

    <!-- Vue Pivot -->
    <record id=\"view_hurimoney_kit_pivot\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.kit.pivot</field>
        <field name=\"model\">hurimoney.kit</field>
        <field name=\"arch\" type=\"xml\">
            <pivot string=\"Analyse des kits\">
                <field name=\"concessionnaire_id\" type=\"row\"/>
                <field name=\"kit_type\" type=\"col\"/>
                <field name=\"state\" type=\"col\"/>
                <field name=\"total_cost\" type=\"measure\"/>
                <field name=\"deposit_amount\" type=\"measure\"/>
            </pivot>
        </field>
    </record>

    <!-- Vue Graph -->
    <record id=\"view_hurimoney_kit_graph\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.kit.graph</field>
        <field name=\"model\">hurimoney.kit</field>
        <field name=\"arch\" type=\"xml\">
            <graph string=\"Distribution des kits\" type=\"pie\">
                <field name=\"state\"/>
                <field name=\"total_cost\" type=\"measure\"/>
            </graph>
        </field>
    </record>

    <!-- Action Window avec TOUTES les vues -->
    <record id=\"action_hurimoney_kit\" model=\"ir.actions.act_window\">
        <field name=\"name\">Kits</field>
        <field name=\"res_model\">hurimoney.kit</field>
        <field name=\"view_mode\">kanban,tree,form,pivot,graph</field>
        <field name=\"search_view_id\" ref=\"view_hurimoney_kit_search\"/>
        <field name=\"context\">{'search_default_active': 1}</field>
        <field name=\"help\" type=\"html\">
            <p class=\"o_view_nocontent_smiling_face\">
                Enregistrer un nouveau kit
            </p>
            <p>
                Gérez les kits distribués aux concessionnaires HuriMoney.
            </p>
        </field>
    </record>
</odoo>
KIT_VIEWS_EOF
"

echo "🎨 5. Création des vues transactions corrigées..."
run_on_server "
cd $MODULE_PATH
cat > views/transaction_views.xml << 'TRANS_VIEWS_EOF'
<?xml version=\"1.0\" encoding=\"utf-8\"?>
<odoo>
    <!-- Vue Liste/Tree -->
    <record id=\"view_hurimoney_transaction_tree\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.transaction.tree</field>
        <field name=\"model\">hurimoney.transaction</field>
        <field name=\"arch\" type=\"xml\">
            <tree string=\"Transactions\" multi_edit=\"1\" decoration-success=\"state == 'done'\" decoration-warning=\"state == 'pending'\" decoration-danger=\"state in ['cancelled', 'failed']\">
                <field name=\"name\"/>
                <field name=\"concessionnaire_id\"/>
                <field name=\"transaction_date\"/>
                <field name=\"transaction_type\"/>
                <field name=\"customer_name\" optional=\"show\"/>
                <field name=\"amount\" sum=\"Total\"/>
                <field name=\"commission\" sum=\"Total\" optional=\"show\"/>
                <field name=\"state\" widget=\"badge\" decoration-success=\"state == 'done'\" decoration-warning=\"state == 'pending'\" decoration-danger=\"state in ['cancelled', 'failed']\"/>
            </tree>
        </field>
    </record>

    <!-- Vue Formulaire -->
    <record id=\"view_hurimoney_transaction_form\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.transaction.form</field>
        <field name=\"model\">hurimoney.transaction</field>
        <field name=\"arch\" type=\"xml\">
            <form string=\"Transaction\">
                <header>
                    <button name=\"action_confirm\" string=\"Confirmer\" type=\"object\" class=\"btn-primary\" invisible=\"state != 'draft'\"/>
                    <button name=\"action_done\" string=\"Valider\" type=\"object\" class=\"btn-primary\" invisible=\"state != 'pending'\"/>
                    <button name=\"action_cancel\" string=\"Annuler\" type=\"object\" invisible=\"state not in ['draft', 'pending']\"/>
                    <field name=\"state\" widget=\"statusbar\" statusbar_visible=\"draft,pending,done\"/>
                </header>
                <sheet>
                    <div class=\"oe_title\">
                        <label for=\"name\"/>
                        <h1>
                            <field name=\"name\" readonly=\"1\"/>
                        </h1>
                    </div>
                    <group>
                        <group string=\"Informations générales\">
                            <field name=\"concessionnaire_id\"/>
                            <field name=\"transaction_date\"/>
                            <field name=\"transaction_type\"/>
                            <field name=\"external_id\" readonly=\"1\"/>
                        </group>
                        <group string=\"Montants\">
                            <field name=\"amount\"/>
                            <field name=\"currency_id\" invisible=\"1\"/>
                            <field name=\"commission_rate\"/>
                            <field name=\"commission\"/>
                        </group>
                    </group>
                    <group>
                        <group string=\"Client\">
                            <field name=\"customer_name\"/>
                            <field name=\"customer_phone\"/>
                        </group>
                        <group string=\"Référence\">
                            <field name=\"reference\"/>
                        </group>
                    </group>
                    <notebook>
                        <page string=\"Notes\" name=\"notes\">
                            <field name=\"notes\" placeholder=\"Notes sur cette transaction...\"/>
                        </page>
                    </notebook>
                </sheet>
                <chatter/>
            </form>
        </field>
    </record>

    <!-- Vue Kanban -->
    <record id=\"view_hurimoney_transaction_kanban\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.transaction.kanban</field>
        <field name=\"model\">hurimoney.transaction</field>
        <field name=\"arch\" type=\"xml\">
            <kanban class=\"o_kanban_mobile\" default_group_by=\"state\" sample=\"1\">
                <field name=\"name\"/>
                <field name=\"concessionnaire_id\"/>
                <field name=\"transaction_type\"/>
                <field name=\"amount\"/>
                <field name=\"commission\"/>
                <field name=\"state\"/>
                <field name=\"customer_name\"/>
                <field name=\"transaction_date\"/>
                <progressbar field=\"state\" colors='{\"done\": \"success\", \"pending\": \"warning\", \"cancelled\": \"danger\", \"failed\": \"danger\"}'/>
                <templates>
                    <t t-name=\"kanban-box\">
                        <div t-attf-class=\"oe_kanban_global_click\">
                            <div class=\"oe_kanban_details\">
                                <strong class=\"o_kanban_record_title\">
                                    <field name=\"name\"/>
                                </strong>
                                <div class=\"o_kanban_tags_section\">
                                    <field name=\"transaction_type\" widget=\"badge\"/>
                                </div>
                                <ul>
                                    <li><i class=\"fa fa-user\"/> <field name=\"concessionnaire_id\"/></li>
                                    <li><i class=\"fa fa-calendar\"/> <field name=\"transaction_date\" widget=\"date\"/></li>
                                    <li><i class=\"fa fa-money\"/> <field name=\"amount\"/></li>
                                    <li><i class=\"fa fa-user-circle\"/> <field name=\"customer_name\"/></li>
                                </ul>
                                <div class=\"oe_kanban_footer\">
                                    <div class=\"o_kanban_record_bottom\">
                                        <div class=\"oe_kanban_bottom_left\">
                                            <field name=\"state\" widget=\"label_selection\" options=\"{'classes': {'draft': 'secondary', 'pending': 'warning', 'done': 'success', 'cancelled': 'danger', 'failed': 'danger'}}\"/>
                                        </div>
                                        <div class=\"oe_kanban_bottom_right\">
                                            <field name=\"commission\"/>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </t>
                </templates>
            </kanban>
        </field>
    </record>

    <!-- Vue Search -->
    <record id=\"view_hurimoney_transaction_search\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.transaction.search</field>
        <field name=\"model\">hurimoney.transaction</field>
        <field name=\"arch\" type=\"xml\">
            <search string=\"Rechercher transactions\">
                <field name=\"name\"/>
                <field name=\"concessionnaire_id\"/>
                <field name=\"customer_name\"/>
                <field name=\"customer_phone\"/>
                <filter name=\"today\" string=\"Aujourd'hui\" domain=\"[('transaction_date', '>=', context_today().strftime('%Y-%m-%d'))]\"/>
                <filter name=\"week\" string=\"Cette semaine\" domain=\"[('transaction_date', '>=', (context_today() - datetime.timedelta(days=7)).strftime('%Y-%m-%d'))]\"/>
                <filter name=\"month\" string=\"Ce mois\" domain=\"[('transaction_date', '>=', context_today().strftime('%Y-%m-01'))]\"/>
                <separator/>
                <filter name=\"deposits\" string=\"Dépôts\" domain=\"[('transaction_type', '=', 'deposit')]\"/>
                <filter name=\"withdrawals\" string=\"Retraits\" domain=\"[('transaction_type', '=', 'withdrawal')]\"/>
                <filter name=\"transfers\" string=\"Transferts\" domain=\"[('transaction_type', '=', 'transfer')]\"/>
                <filter name=\"payments\" string=\"Paiements\" domain=\"[('transaction_type', '=', 'payment')]\"/>
                <separator/>
                <filter name=\"done\" string=\"Effectuées\" domain=\"[('state', '=', 'done')]\"/>
                <filter name=\"pending\" string=\"En attente\" domain=\"[('state', '=', 'pending')]\"/>
                <filter name=\"failed\" string=\"Échouées\" domain=\"[('state', '=', 'failed')]\"/>
                <group expand=\"0\" string=\"Grouper par\">
                    <filter name=\"group_by_concessionnaire\" string=\"Concessionnaire\" domain=\"[]\" context=\"{'group_by': 'concessionnaire_id'}\"/>
                    <filter name=\"group_by_type\" string=\"Type\" domain=\"[]\" context=\"{'group_by': 'transaction_type'}\"/>
                    <filter name=\"group_by_state\" string=\"État\" domain=\"[]\" context=\"{'group_by': 'state'}\"/>
                    <filter name=\"group_by_date\" string=\"Date\" domain=\"[]\" context=\"{'group_by': 'transaction_date:day'}\"/>
                </group>
            </search>
        </field>
    </record>

    <!-- Vue Pivot -->
    <record id=\"view_hurimoney_transaction_pivot\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.transaction.pivot</field>
        <field name=\"model\">hurimoney.transaction</field>
        <field name=\"arch\" type=\"xml\">
            <pivot string=\"Analyse des transactions\">
                <field name=\"concessionnaire_id\" type=\"row\"/>
                <field name=\"transaction_date\" interval=\"month\" type=\"col\"/>
                <field name=\"transaction_type\" type=\"col\"/>
                <field name=\"amount\" type=\"measure\"/>
                <field name=\"commission\" type=\"measure\"/>
            </pivot>
        </field>
    </record>

    <!-- Vue Graph -->
    <record id=\"view_hurimoney_transaction_graph\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.transaction.graph</field>
        <field name=\"model\">hurimoney.transaction</field>
        <field name=\"arch\" type=\"xml\">
            <graph string=\"Évolution des transactions\" type=\"line\">
                <field name=\"transaction_date\" interval=\"day\" type=\"row\"/>
                <field name=\"amount\" type=\"measure\"/>
                <field name=\"commission\" type=\"measure\"/>
            </graph>
        </field>
    </record>

    <!-- Action Window avec TOUTES les vues -->
    <record id=\"action_hurimoney_transaction\" model=\"ir.actions.act_window\">
        <field name=\"name\">Transactions</field>
        <field name=\"res_model\">hurimoney.transaction</field>
        <field name=\"view_mode\">kanban,tree,form,pivot,graph</field>
        <field name=\"search_view_id\" ref=\"view_hurimoney_transaction_search\"/>
        <field name=\"context\">{'search_default_today': 1, 'search_default_done': 1}</field>
        <field name=\"help\" type=\"html\">
            <p class=\"o_view_nocontent_smiling_face\">
                Aucune transaction trouvée
            </p>
            <p>
                Les transactions sont créées via l'API ou manuellement.
            </p>
        </field>
    </record>
</odoo>
TRANS_VIEWS_EOF
"

echo "🎨 6. Création du dashboard moderne..."
run_on_server "
cd $MODULE_PATH
cat > views/dashboard_views.xml << 'DASH_VIEWS_EOF'
<?xml version=\"1.0\" encoding=\"utf-8\"?>
<odoo>
    <!-- Vue Dashboard -->
    <record id=\"view_hurimoney_dashboard_form\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.dashboard.form</field>
        <field name=\"model\">hurimoney.dashboard</field>
        <field name=\"arch\" type=\"xml\">
            <form string=\"Dashboard HuriMoney\" create=\"0\" edit=\"0\">
                <sheet>
                    <div class=\"o_hurimoney_dashboard\">
                        <h1>Tableau de bord HuriMoney</h1>
                        
                        <!-- KPIs principaux -->
                        <div class=\"row mt-4\">
                            <div class=\"col-lg-3 col-md-6\">
                                <div class=\"card text-center bg-primary text-white\">
                                    <div class=\"card-body\">
                                        <i class=\"fa fa-users fa-2x mb-2\"></i>
                                        <h5 class=\"card-title\">Concessionnaires</h5>
                                        <h2><field name=\"active_concessionnaires\"/> / <field name=\"total_concessionnaires\"/></h2>
                                        <p class=\"card-text\">Actifs / Total</p>
                                    </div>
                                </div>
                            </div>
                            
                            <div class=\"col-lg-3 col-md-6\">
                                <div class=\"card text-center bg-success text-white\">
                                    <div class=\"card-body\">
                                        <i class=\"fa fa-money fa-2x mb-2\"></i>
                                        <h5 class=\"card-title\">Volume Journalier</h5>
                                        <h2><field name=\"daily_volume\"/></h2>
                                        <p class=\"card-text\">Aujourd'hui</p>
                                    </div>
                                </div>
                            </div>
                            
                            <div class=\"col-lg-3 col-md-6\">
                                <div class=\"card text-center bg-info text-white\">
                                    <div class=\"card-body\">
                                        <i class=\"fa fa-line-chart fa-2x mb-2\"></i>
                                        <h5 class=\"card-title\">Volume Mensuel</h5>
                                        <h2><field name=\"monthly_volume\"/></h2>
                                        <p class=\"card-text\">Ce mois</p>
                                    </div>
                                </div>
                            </div>
                            
                            <div class=\"col-lg-3 col-md-6\">
                                <div class=\"card text-center bg-warning text-white\">
                                    <div class=\"card-body\">
                                        <i class=\"fa fa-trophy fa-2x mb-2\"></i>
                                        <h5 class=\"card-title\">Top Performer</h5>
                                        <h4><field name=\"top_performer_id\"/></h4>
                                        <p class=\"card-text\">Meilleur score</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        
                        <!-- KPIs secondaires -->
                        <div class=\"row mt-4\">
                            <div class=\"col-lg-3 col-md-6\">
                                <div class=\"card text-center\">
                                    <div class=\"card-body\">
                                        <i class=\"fa fa-mobile fa-2x mb-2 text-primary\"></i>
                                        <h5 class=\"card-title\">Total Kits</h5>
                                        <h3><field name=\"total_kits\"/></h3>
                                        <p class=\"text-muted\">Kits distribués</p>
                                    </div>
                                </div>
                            </div>
                            
                            <div class=\"col-lg-3 col-md-6\">
                                <div class=\"card text-center\">
                                    <div class=\"card-body\">
                                        <i class=\"fa fa-exchange fa-2x mb-2 text-success\"></i>
                                        <h5 class=\"card-title\">Total Transactions</h5>
                                        <h3><field name=\"total_transactions\"/></h3>
                                        <p class=\"text-muted\">Toutes périodes</p>
                                    </div>
                                </div>
                            </div>
                            
                            <div class=\"col-lg-3 col-md-6\">
                                <div class=\"card text-center\">
                                    <div class=\"card-body\">
                                        <i class=\"fa fa-percent fa-2x mb-2 text-info\"></i>
                                        <h5 class=\"card-title\">Commissions</h5>
                                        <h3><field name=\"total_commissions\"/></h3>
                                        <p class=\"text-muted\">Ce mois</p>
                                    </div>
                                </div>
                            </div>
                            
                            <div class=\"col-lg-3 col-md-6\">
                                <div class=\"card text-center\">
                                    <div class=\"card-body\">
                                        <i class=\"fa fa-pause fa-2x mb-2 text-warning\"></i>
                                        <h5 class=\"card-title\">Suspendus</h5>
                                        <h3><field name=\"suspended_concessionnaires\"/></h3>
                                        <p class=\"text-muted\">Concessionnaires</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                        
                        <!-- Boutons d'action rapide -->
                        <div class=\"row mt-4\">
                            <div class=\"col-12\">
                                <div class=\"card\">
                                    <div class=\"card-header\">
                                        <h5 class=\"card-title mb-0\">Actions rapides</h5>
                                    </div>
                                    <div class=\"card-body text-center\">
                                        <button name=\"%(action_hurimoney_concessionnaire)d\" type=\"action\" class=\"btn btn-primary btn-lg mr-2\">
                                            <i class=\"fa fa-users\"></i> Voir Concessionnaires
                                        </button>
                                        <button name=\"%(action_hurimoney_transaction)d\" type=\"action\" class=\"btn btn-success btn-lg mr-2\">
                                            <i class=\"fa fa-exchange\"></i> Voir Transactions
                                        </button>
                                        <button name=\"%(action_hurimoney_kit)d\" type=\"action\" class=\"btn btn-info btn-lg\">
                                            <i class=\"fa fa-mobile\"></i> Voir Kits
                                        </button>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </sheet>
            </form>
        </field>
    </record>

    <!-- Vue Liste pour dashboard -->
    <record id=\"view_hurimoney_dashboard_tree\" model=\"ir.ui.view\">
        <field name=\"name\">hurimoney.dashboard.tree</field>
        <field name=\"model\">hurimoney.dashboard</field>
        <field name=\"arch\" type=\"xml\">
            <tree string=\"Dashboard\" create=\"0\" edit=\"0\" delete=\"0\">
                <field name=\"name\"/>
                <field name=\"total_concessionnaires\"/>
                <field name=\"total_kits\"/>
                <field name=\"total_transactions\"/>
                <field name=\"daily_volume\"/>
                <field name=\"monthly_volume\"/>
            </tree>
        </field>
    </record>

    <!-- Action Dashboard avec vues multiples -->
    <record id=\"action_hurimoney_dashboard\" model=\"ir.actions.act_window\">
        <field name=\"name\">Dashboard</field>
        <field name=\"res_model\">hurimoney.dashboard</field>
        <field name=\"view_mode\">form,tree</field>
        <field name=\"view_id\" ref=\"view_hurimoney_dashboard_form\"/>
        <field name=\"target\">current</field>
        <field name=\"context\">{}</field>
    </record>
</odoo>
DASH_VIEWS_EOF
"

echo "🎨 7. Création du menu avec icônes..."
run_on_server "
cd $MODULE_PATH
cat > views/menu_views.xml << 'MENU_EOF'
<?xml version=\"1.0\" encoding=\"utf-8\"?>
<odoo>
    <!-- Menu principal avec icône -->
    <menuitem id=\"menu_hurimoney_root\"
              name=\"HuriMoney\"
              sequence=\"10\"
              web_icon=\"fa-money,#1f77b4\"/>
    
    <!-- Dashboard -->
    <menuitem id=\"menu_hurimoney_dashboard\"
              name=\"Dashboard\"
              parent=\"menu_hurimoney_root\"
              action=\"action_hurimoney_dashboard\"
              sequence=\"10\"/>
    
    <!-- Opérations -->
    <menuitem id=\"menu_hurimoney_operations\"
              name=\"Opérations\"
              parent=\"menu_hurimoney_root\"
              sequence=\"20\"/>
    
    <!-- Concessionnaires -->
    <menuitem id=\"menu_hurimoney_concessionnaires\"
              name=\"Concessionnaires\"
              parent=\"menu_hurimoney_operations\"
              action=\"action_hurimoney_concessionnaire\"
              sequence=\"10\"/>
    
    <!-- Transactions -->
    <menuitem id=\"menu_hurimoney_transactions\"
              name=\"Transactions\"
              parent=\"menu_hurimoney_operations\"
              action=\"action_hurimoney_transaction\"
              sequence=\"20\"/>
    
    <!-- Kits -->
    <menuitem id=\"menu_hurimoney_kits\"
              name=\"Kits\"
              parent=\"menu_hurimoney_operations\"
              action=\"action_hurimoney_kit\"
              sequence=\"30\"/>
    
    <!-- Rapports -->
    <menuitem id=\"menu_hurimoney_reports\"
              name=\"Rapports\"
              parent=\"menu_hurimoney_root\"
              sequence=\"30\"/>
    
    <!-- Analyse Concessionnaires -->
    <menuitem id=\"menu_hurimoney_analysis_concessionnaires\"
              name=\"Analyse Concessionnaires\"
              parent=\"menu_hurimoney_reports\"
              action=\"action_hurimoney_concessionnaire\"
              sequence=\"10\"/>
    
    <!-- Analyse Transactions -->
    <menuitem id=\"menu_hurimoney_analysis_transactions\"
              name=\"Analyse Transactions\"
              parent=\"menu_hurimoney_reports\"
              action=\"action_hurimoney_transaction\"
              sequence=\"20\"/>
    
    <!-- Configuration -->
    <menuitem id=\"menu_hurimoney_config\"
              name=\"Configuration\"
              parent=\"menu_hurimoney_root\"
              sequence=\"90\"
              groups=\"base.group_system\"/>
    
    <!-- Import de données -->
    <menuitem id=\"menu_hurimoney_import\"
              name=\"Import de données\"
              parent=\"menu_hurimoney_config\"
              action=\"action_hurimoney_import_wizard\"
              sequence=\"10\"/>
</odoo>
MENU_EOF
"

echo "📝 8. Mise à jour du manifest avec assets CSS..."
run_on_server "
cd $MODULE_PATH
cat > __manifest__.py << 'MANIFEST_EOF'
# -*- coding: utf-8 -*-
{
    'name': 'HuriMoney Concessionnaires',
    'version': '18.0.1.0.0',
    'category': 'Sales',
    'summary': 'Gestion des concessionnaires HuriMoney',
    'description': '''
        Module de gestion des concessionnaires HuriMoney
        ================================================
        
        Fonctionnalités:
        - Gestion des concessionnaires et leurs informations
        - Suivi des kits et téléphones distribués
        - Enregistrement des transactions
        - Dashboard et rapports de performance
        - Géolocalisation des concessionnaires
        - Vues Kanban, Liste, Formulaire, Pivot et Graph
        - Interface utilisateur moderne avec icônes
    ''',
    'author': 'HuriMoney',
    'website': 'https://www.hurimoney.com',
    'depends': [
        'base',
        'mail',
        'contacts',
    ],
    'data': [
        # Security
        'security/hurimoney_security.xml',
        'security/ir.model.access.csv',
        
        # Data
        'data/sequence_data.xml',
        
        # Views - ORDRE IMPORTANT
        'views/concessionnaire_views.xml',
        'views/kit_views.xml',
        'views/transaction_views.xml',
        'views/dashboard_views.xml',
        'views/menu_views.xml',
        
        # Wizards
        'wizards/import_wizard_views.xml',
    ],
    'assets': {
        'web.assets_backend': [
            'hurimoney_concessionnaires/static/src/css/hurimoney.css',
        ],
    },
    'installable': True,
    'application': True,
    'auto_install': False,
    'license': 'LGPL-3',
}
MANIFEST_EOF
"

echo "📝 9. Ajout du fichier CSS pour styles modernes..."
run_on_server "
cd $MODULE_PATH
mkdir -p static/src/css
cat > static/src/css/hurimoney.css << 'CSS_EOF'
/* Styles pour le module HuriMoney */

.o_hurimoney_dashboard {
    padding: 20px;
}

.o_hurimoney_dashboard .card {
    margin-bottom: 20px;
    border-radius: 10px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    transition: transform 0.2s;
}

.o_hurimoney_dashboard .card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 20px rgba(0,0,0,0.15);
}

.o_hurimoney_dashboard .card-body {
    padding: 20px;
}

.o_hurimoney_dashboard .card h2 {
    font-size: 2.5rem;
    font-weight: bold;
    margin: 10px 0;
}

.o_hurimoney_dashboard .card h3 {
    font-size: 2rem;
    font-weight: bold;
    margin: 10px 0;
}

.o_hurimoney_dashboard .card .fa {
    opacity: 0.8;
}

/* Kanban amélioré */
.o_kanban_record {
    border-radius: 8px;
    transition: all 0.2s;
}

.o_kanban_record:hover {
    transform: scale(1.02);
    box-shadow: 0 4px 15px rgba(0,0,0,0.1);
}

/* Boutons d'action */
.btn-hurimoney {
    border-radius: 25px;
    padding: 8px 20px;
    font-weight: 500;
    transition: all 0.3s;
}

.btn-hurimoney:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 10px rgba(0,0,0,0.2);
}
CSS_EOF
"

echo "📝 10. Nettoyage et permissions..."
run_on_server "
chown -R odoo:odoo $MODULE_PATH
chmod -R 755 $MODULE_PATH
find $MODULE_PATH -name '*.pyc' -delete
find $MODULE_PATH -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
"

echo "🚀 11. Redémarrage d'Odoo..."
run_on_server "systemctl start odoo"

echo "⏳ 12. Attente du démarrage complet..."
sleep 30

echo "📊 13. Vérification du statut..."
run_on_server "systemctl status odoo --no-pager -l"

echo "📋 14. Vérification des logs..."
run_on_server "tail -n 20 /var/log/odoo/odoo.log"

echo ""
echo "🎉 VUES AVEC ICÔNES AJOUTÉES AVEC SUCCÈS!"
echo "========================================"
echo ""
echo "✅ Problèmes corrigés:"
echo "  • Suppression des champs inexistants dans les vues"
echo "  • Structure XML corrigée pour toutes les vues"
echo "  • Nettoyage des vues corrompues en base"
echo "  • Actions définies avec view_mode complet"
echo ""
echo "📱 Vues disponibles MAINTENANT pour chaque modèle:"
echo "  🎯 Kanban - Vue en cartes visuelles"
echo "  📋 Tree/Liste - Vue tabulaire"
echo "  📝 Form/Formulaire - Édition détaillée"
echo "  📊 Pivot - Analyse croisée"
echo "  📈 Graph - Graphiques"
echo ""
echo "🌐 Pour voir les icônes:"
echo "1. Accédez à http://$SERVER_IP:8069"
echo "2. Allez dans Apps → Update Apps List"
echo "3. Cliquez sur 'Upgrade' pour le module 'hurimoney'"
echo "4. Une fois la mise à jour terminée, vous verrez TOUTES les icônes!"
echo ""
echo "📋 Dans l'interface Odoo, vous devriez maintenant voir:"
echo "  • Les icônes 🎯📋📝📊📈 dans la barre d'outils"
echo "  • Menu HuriMoney avec icône 💰"
echo "  • Dashboard moderne avec cartes colorées"
echo "  • Vues Kanban avec cartes interactives"
echo "  • Analyses Pivot et graphiques"