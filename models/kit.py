# -*- coding: utf-8 -*-
from odoo import models, fields, api

class HuriMoneyKit(models.Model):
    _name = 'hurimoney.kit'
    _description = 'Kit HuriMoney'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _rec_name = 'serial_number'
    
    serial_number = fields.Char(string='Numéro de série', required=True, copy=False)
    concessionnaire_id = fields.Many2one('hurimoney.concessionnaire', string='Concessionnaire', required=True)
    
    # Informations sur le téléphone
    phone_model = fields.Char(string='Modèle de téléphone')
    phone_imei = fields.Char(string='IMEI')
    phone_cost = fields.Float(string='Coût du téléphone')
    
    # Informations sur le kit
    kit_type = fields.Selection([
        ('standard', 'Standard'),
        ('premium', 'Premium'),
        ('basic', 'Basic'),
    ], string='Type de kit', default='standard')
    kit_cost = fields.Float(string='Coût du kit')
    
    # Dates
    delivery_date = fields.Date(string='Date de livraison', default=fields.Date.today)
    activation_date = fields.Date(string='Date d\'activation')
    
    # Statut
    state = fields.Selection([
        ('draft', 'Brouillon'),
        ('delivered', 'Livré'),
        ('active', 'Actif'),
        ('lost', 'Perdu'),
        ('damaged', 'Endommagé'),
        ('returned', 'Retourné'),
    ], string='État', default='draft', tracking=True)
    
    # Coûts et caution
    deposit_amount = fields.Float(string='Montant de la caution')
    deposit_paid = fields.Boolean(string='Caution payée')
    total_cost = fields.Float(string='Coût total', compute='_compute_total_cost', store=True)
    
    notes = fields.Text(string='Notes')
    company_id = fields.Many2one('res.company', string='Société', default=lambda self: self.env.company)
    
    _sql_constraints = [
        ('serial_unique', 'UNIQUE(serial_number)', 'Le numéro de série doit être unique!'),
        ('imei_unique', 'UNIQUE(phone_imei)', 'L\'IMEI doit être unique!'),
    ]
    
    @api.depends('phone_cost', 'kit_cost')
    def _compute_total_cost(self):
        for record in self:
            record.total_cost = record.phone_cost + record.kit_cost
    
    def action_deliver(self):
        self.write({
            'state': 'delivered',
            'delivery_date': fields.Date.today()
        })
    
    def action_activate(self):
        self.write({
            'state': 'active',
            'activation_date': fields.Date.today()
        })
    
    def action_report_lost(self):
        self.state = 'lost'
    
    def action_report_damaged(self):
        self.state = 'damaged'
    
    def action_return(self):
        self.state = 'returned'