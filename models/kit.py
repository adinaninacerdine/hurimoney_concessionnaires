# -*- coding: utf-8 -*-
from odoo import models, fields, api
from odoo.exceptions import ValidationError


class HuriMoneyKit(models.Model):
    _name = 'hurimoney.kit'
    _description = 'Kit HuriMoney'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _rec_name = 'serial_number'
    _order = 'delivery_date desc, id desc'
    
    serial_number = fields.Char(string='Numéro de série', required=True, copy=False, tracking=True)
    concessionnaire_id = fields.Many2one(
        'hurimoney.concessionnaire',
        string='Concessionnaire',
        required=True,
        ondelete='restrict'
    )
    
    # Informations sur le téléphone
    phone_model = fields.Char(string='Modèle de téléphone')
    phone_imei = fields.Char(string='IMEI', tracking=True)
    phone_cost = fields.Monetary(string='Coût du téléphone')
    
    # Informations sur le kit
    kit_type = fields.Selection([
        ('standard', 'Standard'),
        ('premium', 'Premium'),
        ('basic', 'Basic'),
    ], string='Type de kit', default='standard', required=True)
    kit_cost = fields.Monetary(string='Coût du kit')
    
    # Devise
    currency_id = fields.Many2one('res.currency', related='company_id.currency_id', readonly=True)
    
    # Dates
    delivery_date = fields.Date(string='Date de livraison', default=fields.Date.today, tracking=True)
    activation_date = fields.Date(string='Date d\'activation', tracking=True)
    
    # Statut
    state = fields.Selection([
        ('draft', 'Brouillon'),
        ('delivered', 'Livré'),
        ('active', 'Actif'),
        ('lost', 'Perdu'),
        ('damaged', 'Endommagé'),
        ('returned', 'Retourné'),
    ], string='État', default='draft', tracking=True)
    
    # Caution
    deposit_amount = fields.Monetary(string='Montant de la caution')
    deposit_paid = fields.Boolean(string='Caution payée', tracking=True)
    deposit_paid_date = fields.Date(string='Date paiement caution')
    
    # Coût total
    total_cost = fields.Monetary(string='Coût total', compute='_compute_total_cost', store=True)
    
    # Autres
    notes = fields.Text(string='Notes')
    company_id = fields.Many2one('res.company', string='Société', default=lambda self: self.env.company)
    
    _sql_constraints = [
        ('serial_unique', 'UNIQUE(serial_number)', 'Le numéro de série doit être unique!'),
        ('imei_unique', 'UNIQUE(phone_imei)', 'L\'IMEI doit être unique!'),
    ]
    
    @api.depends('phone_cost', 'kit_cost')
    def _compute_total_cost(self):
        for record in self:
            record.total_cost = (record.phone_cost or 0) + (record.kit_cost or 0)
    
    @api.constrains('phone_cost', 'kit_cost', 'deposit_amount')
    def _check_costs(self):
        for record in self:
            if record.phone_cost < 0:
                raise ValidationError("Le coût du téléphone ne peut pas être négatif")
            if record.kit_cost < 0:
                raise ValidationError("Le coût du kit ne peut pas être négatif")
            if record.deposit_amount < 0:
                raise ValidationError("Le montant de la caution ne peut pas être négatif")
    
    def action_deliver(self):
        self.ensure_one()
        self.write({
            'state': 'delivered',
            'delivery_date': fields.Date.today()
        })
        self.message_post(body="Kit marqué comme livré")
    
    def action_activate(self):
        self.ensure_one()
        self.write({
            'state': 'active',
            'activation_date': fields.Date.today()
        })
        self.message_post(body="Kit activé")
    
    def action_report_lost(self):
        self.ensure_one()
        self.state = 'lost'
        self.message_post(body="Kit déclaré perdu")
    
    def action_report_damaged(self):
        self.ensure_one()
        self.state = 'damaged'
        self.message_post(body="Kit déclaré endommagé")
    
    def action_return(self):
        self.ensure_one()
        self.state = 'returned'
        self.message_post(body="Kit retourné")
    
    @api.onchange('deposit_paid')
    def _onchange_deposit_paid(self):
        if self.deposit_paid and not self.deposit_paid_date:
            self.deposit_paid_date = fields.Date.today()
        elif not self.deposit_paid:
            self.deposit_paid_date = False