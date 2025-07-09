# -*- coding: utf-8 -*-
import logging
from datetime import datetime, timedelta
from odoo import models, fields, api
from odoo.exceptions import ValidationError

_logger = logging.getLogger(__name__)

class HuriMoneyConcessionnaire(models.Model):
    _name = 'hurimoney.concessionnaire'
    _description = 'Concessionnaire HuriMoney'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _rec_name = 'name'
    _order = 'code'
    
    # Informations de base
    code = fields.Char(
        string='Code',
        required=True,
        copy=False,
        readonly=True,
        default=lambda self: self.env['ir.sequence'].next_by_code('hurimoney.concessionnaire')
    )
    name = fields.Char(string='Nom', required=True, tracking=True)
    partner_id = fields.Many2one('res.partner', string='Contact', required=True, ondelete='restrict')
    phone = fields.Char(string='Téléphone', required=True, tracking=True)
    email = fields.Char(string='Email', tracking=True)
    
    # Adresse et géolocalisation
    street = fields.Char(string='Rue')
    street2 = fields.Char(string='Rue 2')
    city = fields.Char(string='Ville')
    state_id = fields.Many2one('res.country.state', string='État')
    country_id = fields.Many2one('res.country', string='Pays', default=lambda self: self.env.ref('base.km'))
    zip = fields.Char(string='Code postal')
    latitude = fields.Float(string='Latitude', digits=(16, 5))
    longitude = fields.Float(string='Longitude', digits=(16, 5))
    address_complete = fields.Char(string='Adresse complète', compute='_compute_address_complete', store=True)
    
    # Informations commerciales
    agent_id = fields.Many2one('res.users', string='Agent commercial', tracking=True)
    zone = fields.Selection([
        ('moroni', 'Moroni'),
        ('mutsamudu', 'Mutsamudu'),
        ('fomboni', 'Fomboni'),
        ('rural', 'Zone rurale'),
    ], string='Zone', required=True)
    
    # État et dates
    state = fields.Selection([
        ('draft', 'Brouillon'),
        ('active', 'Actif'),
        ('suspended', 'Suspendu'),
        ('inactive', 'Inactif'),
    ], string='État', default='draft', tracking=True)
    
    activation_date = fields.Date(string='Date d\'activation', tracking=True)
    suspension_date = fields.Date(string='Date de suspension')
    last_activity_date = fields.Datetime(string='Dernière activité')
    
    # Relations
    kit_ids = fields.One2many('hurimoney.kit', 'concessionnaire_id', string='Kits')
    transaction_ids = fields.One2many('hurimoney.transaction', 'concessionnaire_id', string='Transactions')
    
    # Métriques
    total_transactions = fields.Integer(string='Total transactions', compute='_compute_metrics', store=True)
    total_volume = fields.Float(string='Volume total', compute='_compute_metrics', store=True)
    daily_transactions = fields.Integer(string='Transactions/jour', compute='_compute_daily_metrics')
    weekly_transactions = fields.Integer(string='Transactions/semaine', compute='_compute_weekly_metrics')
    monthly_volume = fields.Float(string='Volume mensuel', compute='_compute_monthly_metrics')
    performance_score = fields.Float(string='Score de performance', compute='_compute_performance_score')
    ranking = fields.Integer(string='Classement', compute='_compute_ranking')
    
    # Autres
    notes = fields.Text(string='Notes')
    active = fields.Boolean(string='Actif', default=True)
    company_id = fields.Many2one('res.company', string='Société', default=lambda self: self.env.company)
    
    _sql_constraints = [
        ('code_unique', 'UNIQUE(code)', 'Le code doit être unique!'),
        ('phone_unique', 'UNIQUE(phone)', 'Ce numéro de téléphone est déjà utilisé!'),
    ]
    
    @api.depends('street', 'street2', 'city', 'state_id', 'country_id', 'zip')
    def _compute_address_complete(self):
        for record in self:
            address_parts = []
            if record.street:
                address_parts.append(record.street)
            if record.street2:
                address_parts.append(record.street2)
            if record.city:
                address_parts.append(record.city)
            if record.state_id:
                address_parts.append(record.state_id.name)
            if record.country_id:
                address_parts.append(record.country_id.name)
            if record.zip:
                address_parts.append(record.zip)
            record.address_complete = ', '.join(address_parts)
    
    @api.depends('transaction_ids')
    def _compute_metrics(self):
        for record in self:
            record.total_transactions = len(record.transaction_ids)
            record.total_volume = sum(record.transaction_ids.mapped('amount'))
    
    @api.depends('transaction_ids', 'transaction_ids.transaction_date')
    def _compute_daily_metrics(self):
        for record in self:
            today = fields.Date.today()
            daily_transactions = record.transaction_ids.filtered(
                lambda t: t.transaction_date and t.transaction_date.date() == today
            )
            record.daily_transactions = len(daily_transactions)
    
    @api.depends('transaction_ids', 'transaction_ids.transaction_date')
    def _compute_weekly_metrics(self):
        for record in self:
            week_start = fields.Date.today() - timedelta(days=fields.Date.today().weekday())
            weekly_transactions = record.transaction_ids.filtered(
                lambda t: t.transaction_date and t.transaction_date.date() >= week_start
            )
            record.weekly_transactions = len(weekly_transactions)
    
    @api.depends('transaction_ids', 'transaction_ids.amount')
    def _compute_monthly_metrics(self):
        for record in self:
            month_start = fields.Date.today().replace(day=1)
            monthly_transactions = record.transaction_ids.filtered(
                lambda t: t.transaction_date and t.transaction_date.date() >= month_start
            )
            record.monthly_volume = sum(monthly_transactions.mapped('amount'))
    
    @api.depends('daily_transactions', 'weekly_transactions', 'monthly_volume', 'state')
    def _compute_performance_score(self):
        for record in self:
            score = 0
            if record.state == 'active':
                # Score basé sur les transactions quotidiennes (max 40 points)
                daily_score = min(record.daily_transactions * 2, 40)
                
                # Score basé sur le volume mensuel (max 40 points)
                volume_score = min(record.monthly_volume / 1000000 * 40, 40) if record.monthly_volume else 0
                
                # Score basé sur la régularité (max 20 points)
                regularity_score = 20 if record.weekly_transactions >= 50 else record.weekly_transactions * 0.4
                
                score = daily_score + volume_score + regularity_score
            
            record.performance_score = min(score, 100)
    
    def _compute_ranking(self):
        all_active = self.search([('state', '=', 'active')], order='performance_score desc')
        for i, record in enumerate(all_active):
            record.ranking = i + 1
    
    @api.constrains('latitude', 'longitude')
    def _check_coordinates(self):
        for record in self:
            if record.latitude and not (-90 <= record.latitude <= 90):
                raise ValidationError("La latitude doit être entre -90 et 90")
            if record.longitude and not (-180 <= record.longitude <= 180):
                raise ValidationError("La longitude doit être entre -180 et 180")
    
    @api.constrains('partner_id')
    def _check_unique_partner(self):
        for record in self:
            if record.partner_id:
                existing = self.search([
                    ('partner_id', '=', record.partner_id.id),
                    ('id', '!=', record.id)
                ])
                if existing:
                    raise ValidationError("Ce contact est déjà associé à un autre concessionnaire")
    
    def action_activate(self):
        self.write({
            'state': 'active',
            'activation_date': fields.Date.today()
        })
    
    def action_suspend(self):
        self.write({
            'state': 'suspended',
            'suspension_date': fields.Date.today()
        })
    
    def action_reactivate(self):
        self.write({
            'state': 'active',
            'suspension_date': False
        })
    
    def action_deactivate(self):
        self.write({
            'state': 'inactive',
            'active': False
        })
    
    def action_geocode(self):
        """Géocode l'adresse du concessionnaire"""
        for record in self:
            if record.address_complete:
                try:
                    # Utilisation de l'API de géocodage d'Odoo
                    result = self.env['res.partner']._geo_localize(
                        record.address_complete,
                        country='KM'  # Comores
                    )
                    if result:
                        record.write({
                            'latitude': result[0],
                            'longitude': result[1],
                        })
                        self.message_post(body="Géolocalisation réussie")
                    else:
                        self.message_post(body="Impossible de géolocaliser cette adresse")
                except Exception as e:
                    _logger.error(f"Erreur géocodage: {str(e)}")
                    self.message_post(body=f"Erreur lors de la géolocalisation: {str(e)}")
    
    def action_geocode_batch(self):
        """Géocode plusieurs concessionnaires"""
        for record in self:
            record.action_geocode()