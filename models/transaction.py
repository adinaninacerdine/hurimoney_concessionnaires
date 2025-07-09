# -*- coding: utf-8 -*-
from odoo import models, fields, api

class HuriMoneyTransaction(models.Model):
    _name = 'hurimoney.transaction'
    _description = 'Transaction HuriMoney'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'transaction_date desc'
    
    name = fields.Char(
        string='Référence',
        required=True,
        copy=False,
        readonly=True,
        default=lambda self: self.env['ir.sequence'].next_by_code('hurimoney.transaction')
    )
    
    concessionnaire_id = fields.Many2one('hurimoney.concessionnaire', string='Concessionnaire', required=True)
    transaction_date = fields.Datetime(string='Date de transaction', default=fields.Datetime.now, required=True)
    
    # Détails de la transaction
    transaction_type = fields.Selection([
        ('deposit', 'Dépôt'),
        ('withdrawal', 'Retrait'),
        ('transfer', 'Transfert'),
        ('payment', 'Paiement'),
    ], string='Type', required=True)
    
    amount = fields.Float(string='Montant', required=True)
    currency_id = fields.Many2one('res.currency', string='Devise', default=lambda self: self.env.ref('base.KMF'))
    
    # Commission
    commission_rate = fields.Float(string='Taux de commission (%)', default=2.0)
    commission = fields.Float(string='Commission', compute='_compute_commission', store=True)
    
    # Informations client
    customer_name = fields.Char(string='Nom du client')
    customer_phone = fields.Char(string='Téléphone du client')
    
    # Référence externe
    external_id = fields.Char(string='ID externe', help='Référence dans le système WAKATI')
    
    # État
    state = fields.Selection([
        ('draft', 'Brouillon'),
        ('pending', 'En attente'),
        ('done', 'Effectué'),
        ('cancelled', 'Annulé'),
        ('failed', 'Échoué'),
    ], string='État', default='draft', tracking=True)
    
    # Autres
    notes = fields.Text(string='Notes')
    company_id = fields.Many2one('res.company', string='Société', default=lambda self: self.env.company)
    
    @api.depends('amount', 'commission_rate')
    def _compute_commission(self):
        for record in self:
            record.commission = record.amount * record.commission_rate / 100
    
    def action_confirm(self):
        self.state = 'pending'
    
    def action_done(self):
        self.write({
            'state': 'done',
            'concessionnaire_id.last_activity_date': fields.Datetime.now()
        })
    
    def action_cancel(self):
        self.state = 'cancelled'
    
    def action_retry(self):
        if self.state == 'failed':
            self.state = 'pending'