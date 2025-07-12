# -*- coding: utf-8 -*-
from odoo import models, fields, api
from odoo.exceptions import ValidationError


class HuriMoneyTransaction(models.Model):
    _name = 'hurimoney.transaction'
    _description = 'Transaction HuriMoney'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'transaction_date desc, id desc'
    _rec_name = 'name'
    
    name = fields.Char(
        string='Référence',
        required=True,
        copy=False,
        readonly=True,
        default=lambda self: self.env['ir.sequence'].next_by_code('hurimoney.transaction')
    )
    
    concessionnaire_id = fields.Many2one(
        'hurimoney.concessionnaire',
        string='Concessionnaire',
        required=True,
        ondelete='restrict'
    )
    
    transaction_date = fields.Datetime(
        string='Date de transaction',
        default=fields.Datetime.now,
        required=True,
        tracking=True
    )
    
    # Type de transaction
    transaction_type = fields.Selection([
        ('deposit', 'Dépôt'),
        ('withdrawal', 'Retrait'),
        ('transfer', 'Transfert'),
        ('payment', 'Paiement'),
    ], string='Type', required=True, tracking=True)
    
    # Montants
    amount = fields.Monetary(string='Montant', required=True, tracking=True)
    currency_id = fields.Many2one('res.currency', related='company_id.currency_id', readonly=True)
    commission_rate = fields.Float(
        string='Taux de commission (%)',
        default=lambda self: float(self.env['ir.config_parameter'].sudo().get_param('hurimoney.default_commission_rate', 2.0))
    )
    commission = fields.Monetary(string='Commission', compute='_compute_commission', store=True)
    
    # Informations client
    customer_name = fields.Char(string='Nom du client')
    customer_phone = fields.Char(string='Téléphone du client')
    
    # Référence externe (pour intégration API)
    external_id = fields.Char(string='ID externe', help='Référence dans le système externe')
    reference = fields.Char(string='Référence additionnelle')
    
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
    
    # Champs pour l'API mobile
    mobile_created = fields.Boolean(string='Créé depuis mobile', default=False)
    
    @api.depends('amount', 'commission_rate')
    def _compute_commission(self):
        for record in self:
            record.commission = record.amount * record.commission_rate / 100
    
    @api.constrains('amount')
    def _check_amount(self):
        for record in self:
            if record.amount <= 0:
                raise ValidationError("Le montant doit être positif")
            
            # Vérifier les limites configurées
            min_amount = float(self.env['ir.config_parameter'].sudo().get_param('hurimoney.min_transaction_amount', 1000))
            max_amount = float(self.env['ir.config_parameter'].sudo().get_param('hurimoney.max_transaction_amount', 5000000))
            
            if record.amount < min_amount:
                raise ValidationError("Le montant minimum est de %s" % min_amount)
            if record.amount > max_amount:
                raise ValidationError("Le montant maximum est de %s" % max_amount)
    
    @api.model
    def create(self, vals):
        if vals.get('name', '/') == '/':
            vals['name'] = self.env['ir.sequence'].next_by_code('hurimoney.transaction') or '/'
        return super().create(vals)
    
    def action_confirm(self):
        self.ensure_one()
        self.state = 'pending'
        self.message_post(body="Transaction confirmée, en attente de traitement")
    
    def action_done(self):
        self.ensure_one()
        self.write({
            'state': 'done',
        })
        # Mettre à jour la dernière activité du concessionnaire
        self.concessionnaire_id.last_activity_date = fields.Datetime.now()
        self.message_post(body="Transaction effectuée avec succès")
    
    def action_cancel(self):
        self.ensure_one()
        self.state = 'cancelled'
        self.message_post(body="Transaction annulée")
    
    def action_retry(self):
        self.ensure_one()
        if self.state == 'failed':
            self.state = 'pending'
            self.message_post(body="Nouvelle tentative de traitement")