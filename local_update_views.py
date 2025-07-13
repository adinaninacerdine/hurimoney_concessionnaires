import psycopg2
import json

db_host = 'odoo-postgresql-v2.cna66scsaclz.eu-north-1.rds.amazonaws.com'
db_port = 5432
db_user = 'odoo'
db_password = 'OdooPassword2024'
db_name = 'odoo'

def update_view(view_id, xml_content):
    conn = None
    try:
        conn = psycopg2.connect(host=db_host, port=db_port, user=db_user, password=db_password, dbname=db_name)
        cur = conn.cursor()
        # Odoo stores XML in a JSONB field, typically with a language key (e.g., 'en_US')
        arch_db_json = json.dumps({"en_US": xml_content})
        update_query = "UPDATE ir_ui_view SET arch_db = %s::jsonb WHERE id = %s"
        cur.execute(update_query, (arch_db_json, view_id))
        conn.commit()
        print(f"View ID {view_id} updated successfully.")
    except Exception as e:
        print(f"Error updating view ID {view_id}: {e}")
    finally:
        if conn:
            conn.close()

# XML content for the tree view (ID 1176)
xml_content_tree = """<list string="Concessionnaires">
                <field name="code"/>
                <field name="name"/>
                <field name="phone" widget="phone"/>
                <field name="zone"/>
                <field name="agent_id" widget="many2one_avatar_user"/>
                <field name="daily_transactions"/>
                <field name="monthly_volume" widget="monetary" sum="Total"/>
                <field name="performance_score" widget="percentage"/>
                <field name="state" widget="badge" decoration-success="state == 'active'" decoration-warning="state == 'suspended'" decoration-danger="state == 'inactive'"/>
            </list>"""

# XML content for the search view (ID 1195)
xml_content_search = """<search string="Rechercher concessionnaires">
                <field name="name"/>
                <field name="code"/>
                <field name="phone"/>
                <field name="agent_id"/>
                <filter name="active" string="Actifs" domain="[('state', '=', 'active')]"/>
                <filter name="suspended" string="Suspendus" domain="[('state', '=', 'suspended')]"/>
                <filter name="inactive" string="Inactifs" domain="[('state', '=', 'inactive')]"/>
                <separator/>
                <filter name="my_concessionnaires" string="Mes concessionnaires" domain="[('agent_id', '=', uid)]"/>
                <separator/>
                <filter name="top_performers" string="Top performers" domain="[('performance_score', '&gt;', 80)]"/>
                <filter name="low_performers" string="Faible performance" domain="[('performance_score', '&lt;', 30)]"/>
                <group expand="0" string="Grouper par">
                    <filter name="group_by_zone" string="Zone" domain="[]" context="{'group_by': 'zone'}"/>
                    <filter name="group_by_agent" string="Agent" domain="[]" context="{'group_by': 'agent_id'}"/>
                    <filter name="group_by_state" string="État" domain="[]" context="{'group_by': 'state'}"/>
                </group>
            </search>"""

# XML content for the form view (ID 1177)
xml_content_form = """<form string="Concessionnaire">
                <header>
                    <button name="action_activate" string="Activer" type="object" class="btn-primary" invisible="state != 'draft'"/>
                    <button name="action_suspend" string="Suspendre" type="object" class="btn-warning" invisible="state != 'active'"/>
                    <button name="action_reactivate" string="Réactiver" type="object" class="btn-primary" invisible="state != 'suspended'"/>
                    <button name="action_deactivate" string="Désactiver" type="object" class="btn-danger" invisible="state == 'inactive'"/>
                    <field name="state" widget="statusbar" statusbar_visible="draft,active,suspended,inactive"/>
                </header>
                <sheet>
                    <widget name="web_ribbon" title="Archivé" bg_color="text-bg-danger" invisible="active"/>
                    <div class="oe_button_box" name="button_box">
                        <button name="%(action_hurimoney_kit)d" type="action" class="oe_stat_button" icon="fa-mobile">
                            <field name="kit_ids" widget="statinfo" string="Kits"/>
                        </button>
                        <button name="%(action_hurimoney_transaction)d" type="action" class="oe_stat_button" icon="fa-exchange">
                            <field name="total_transactions" widget="statinfo" string="Transactions"/>
                        </button>
                    </div>
                    <div class="oe_title">
                        <label for="name"/>
                        <h1>
                            <field name="name" placeholder="Nom du concessionnaire"/>
                        </h1>
                        <label for="code"/>
                        <h2>
                            <field name="code" readonly="1"/>
                        </h2>
                    </div>
                    <group>
                        <group string="Informations générales">
                            <field name="partner_id"/>
                            <field name="phone" widget="phone"/>
                            <field name="email" widget="email"/>
                            <field name="agent_id" widget="many2one_avatar_user"/>
                            <field name="zone"/>
                        </group>
                        <group string="Performance">
                            <field name="performance_score" widget="percentage"/>
                            <field name="daily_transactions"/>
                            <field name="weekly_transactions"/>
                            <field name="monthly_transactions"/>
                            <field name="monthly_volume" widget="monetary"/>
                        </group>
                    </group>
                    <notebook>
                        <page string="Adresse" name="address">
                            <group>
                                <group string="Adresse postale">
                                    <field name="street" placeholder="Rue..."/>
                                    <field name="street2"/>
                                    <field name="city" placeholder="Ville"/>
                                    <field name="state_id" options="{'no_create': True}"/>
                                    <field name="zip" placeholder="Code postal"/>
                                    <field name="country_id" options="{'no_create': True}"/>
                                </group>
                                <group string="Coordonnées GPS">
                                    <field name="latitude"/>
                                    <field name="longitude"/>
                                </group>
                            </group>
                        </page>
                        <page string="Transactions" name="transactions">
                            <field name="transaction_ids" readonly="1">
                                <list>
                                    <field name="name"/>
                                    <field name="transaction_date"/>
                                    <field name="transaction_type"/>
                                    <field name="amount" widget="monetary"/>
                                    <field name="commission" widget="monetary"/>
                                    <field name="state" widget="badge" decoration-success="state == 'done'" decoration-warning="state == 'pending'" decoration-danger="state == 'failed'"/>
                                </list>
                            </field>
                        </page>
                        <page string="Kits" name="kits">
                            <field name="serial_number"/>
                            <field name="kit_type"/>
                            <field name="phone_model"/>
                            <field name="delivery_date"/>
                            <field name="state" widget="badge"/>
                                </list>
                            </field>
                        </page>
                        <page string="Notes" name="notes">
                            <field name="notes" placeholder="Notes internes..."/>
                        </page>
                    </notebook>
                </sheet>
                <chatter/>
            </form>"""