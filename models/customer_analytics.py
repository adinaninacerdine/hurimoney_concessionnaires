# -*- coding: utf-8 -*-
import os
import logging
from datetime import datetime, timedelta
from odoo import models, fields, api
from odoo.exceptions import UserError, ValidationError

_logger = logging.getLogger(__name__)

class CustomerAnalytics(models.Model):
    _name = 'hurimoney.customer.analytics'
    _description = 'Analytics et segmentation clients B2C'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _rec_name = 'customer_name'
    _order = 'monetary_value desc, frequency desc'
    
    # Informations client
    customer_phone = fields.Char(string='Téléphone client', required=True, index=True)
    customer_name = fields.Char(string='Nom client', tracking=True)
    partner_id = fields.Many2one('res.partner', string='Partenaire associé', 
                                 compute='_compute_partner_id', store=True)
    
    # Métriques RFM (Récence, Fréquence, Valeur monétaire)
    recency_days = fields.Integer(string='Récence (jours)', 
                                  help='Nombre de jours depuis la dernière transaction')
    frequency = fields.Integer(string='Fréquence', 
                               help='Nombre total de transactions')
    monetary_value = fields.Monetary(string='Valeur monétaire', 
                                     currency_field='currency_id',
                                     help='Montant total des transactions')
    
    # Scores calculés (1-5)
    recency_score = fields.Integer(string='Score récence', default=1)
    frequency_score = fields.Integer(string='Score fréquence', default=1)
    monetary_score = fields.Integer(string='Score monétaire', default=1)
    rfm_score = fields.Char(string='Score RFM', compute='_compute_rfm_score', store=True)
    
    # Segmentation
    segment = fields.Selection([
        ('CHAMPIONS', 'Champions'),
        ('LOYAL', 'Clients fidèles'),
        ('POTENTIAL_LOYALISTS', 'Loyalistes potentiels'),
        ('NEW_CUSTOMERS', 'Nouveaux clients'),
        ('PROMISING', 'Prometteurs'),
        ('NEED_ATTENTION', 'Besoin d\'attention'),
        ('ABOUT_TO_SLEEP', 'Sur le point de partir'),
        ('AT_RISK', 'À risque'),
        ('CANNOT_LOSE', 'Ne peut pas perdre'),
        ('HIBERNATING', 'En hibernation'),
        ('LOST', 'Perdus')
    ], string='Segment', compute='_compute_segment', store=True, tracking=True)
    
    # Dates
    first_transaction_date = fields.Datetime(string='Première transaction')
    last_transaction_date = fields.Datetime(string='Dernière transaction')
    
    # Métriques additionnelles
    avg_transaction_amount = fields.Monetary(string='Montant moyen transaction', 
                                             compute='_compute_avg_transaction', store=True)
    days_as_customer = fields.Integer(string='Jours comme client', 
                                      compute='_compute_days_as_customer', store=True)
    
    # Configuration
    currency_id = fields.Many2one('res.currency', string='Devise', 
                                  default=lambda self: self.env.company.currency_id)
    data_source = fields.Selection([
        ('manual', 'Manuel'),
        ('kinesis', 'Kinesis Stream'),
        ('api', 'API Import'),
        ('batch', 'Import Batch')
    ], string='Source des données', default='manual')
    
    # État
    active = fields.Boolean(string='Actif', default=True)
    last_update = fields.Datetime(string='Dernière mise à jour', default=fields.Datetime.now)
    
    @api.depends('customer_phone')
    def _compute_partner_id(self):
        """Lier automatiquement au partenaire si il existe"""
        for record in self:
            if record.customer_phone:
                partner = self.env['res.partner'].search([
                    ('phone', '=', record.customer_phone)
                ], limit=1)
                record.partner_id = partner.id
            else:
                record.partner_id = False
    
    @api.depends('recency_score', 'frequency_score', 'monetary_score')
    def _compute_rfm_score(self):
        """Calculer le score RFM combiné"""
        for record in self:
            record.rfm_score = f"{record.recency_score}{record.frequency_score}{record.monetary_score}"
    
    @api.depends('frequency', 'monetary_value')
    def _compute_avg_transaction(self):
        """Calculer le montant moyen par transaction"""
        for record in self:
            if record.frequency > 0:
                record.avg_transaction_amount = record.monetary_value / record.frequency
            else:
                record.avg_transaction_amount = 0
    
    @api.depends('first_transaction_date')
    def _compute_days_as_customer(self):
        """Calculer l'ancienneté du client"""
        for record in self:
            if record.first_transaction_date:
                delta = datetime.now() - record.first_transaction_date
                record.days_as_customer = delta.days
            else:
                record.days_as_customer = 0
    
    @api.depends('recency_score', 'frequency_score', 'monetary_score')
    def _compute_segment(self):
        """Déterminer le segment basé sur les scores RFM"""
        for record in self:
            r, f, m = record.recency_score, record.frequency_score, record.monetary_score
            
            # Logique de segmentation RFM
            if r >= 4 and f >= 4 and m >= 4:
                segment = 'CHAMPIONS'
            elif r >= 3 and f >= 4 and m >= 3:
                segment = 'LOYAL'
            elif r >= 4 and f <= 2 and m >= 3:
                segment = 'POTENTIAL_LOYALISTS'
            elif r >= 4 and f <= 2 and m <= 2:
                segment = 'NEW_CUSTOMERS'
            elif r >= 3 and f <= 3 and m <= 3:
                segment = 'PROMISING'
            elif r <= 3 and f >= 3 and m >= 3:
                segment = 'NEED_ATTENTION'
            elif r <= 3 and f <= 3 and m >= 3:
                segment = 'ABOUT_TO_SLEEP'
            elif r <= 2 and f >= 3 and m >= 3:
                segment = 'AT_RISK'
            elif r <= 2 and f >= 4 and m >= 4:
                segment = 'CANNOT_LOSE'
            elif r <= 2 and f <= 2 and m <= 2:
                segment = 'HIBERNATING'
            else:
                segment = 'LOST'
            
            record.segment = segment
    
    @api.model
    def calculate_rfm_scores(self):
        """Recalculer tous les scores RFM"""
        customers = self.search([('active', '=', True)])
        
        if not customers:
            return
        
        # Calculer les quintiles pour chaque métrique
        recency_values = sorted([c.recency_days for c in customers if c.recency_days])
        frequency_values = sorted([c.frequency for c in customers if c.frequency])
        monetary_values = sorted([c.monetary_value for c in customers if c.monetary_value])
        
        def get_quintile_breaks(values):
            """Obtenir les seuils des quintiles"""
            if len(values) < 5:
                return [values[0], values[-1]]
            
            quintiles = []
            for i in range(1, 5):
                index = int(len(values) * i / 5)
                quintiles.append(values[index])
            return quintiles
        
        recency_breaks = get_quintile_breaks(recency_values)
        frequency_breaks = get_quintile_breaks(frequency_values)
        monetary_breaks = get_quintile_breaks(monetary_values)
        
        # Assigner les scores
        for customer in customers:
            # Score récence (inversé car moins c'est mieux)
            if customer.recency_days <= recency_breaks[0]:
                r_score = 5
            elif customer.recency_days <= recency_breaks[1]:
                r_score = 4
            elif customer.recency_days <= recency_breaks[2]:
                r_score = 3
            elif customer.recency_days <= recency_breaks[3]:
                r_score = 2
            else:
                r_score = 1
            
            # Score fréquence
            if customer.frequency >= frequency_breaks[-1]:
                f_score = 5
            elif customer.frequency >= frequency_breaks[-2]:
                f_score = 4
            elif customer.frequency >= frequency_breaks[-3]:
                f_score = 3
            elif customer.frequency >= frequency_breaks[0]:
                f_score = 2
            else:
                f_score = 1
            
            # Score monétaire
            if customer.monetary_value >= monetary_breaks[-1]:
                m_score = 5
            elif customer.monetary_value >= monetary_breaks[-2]:
                m_score = 4
            elif customer.monetary_value >= monetary_breaks[-3]:
                m_score = 3
            elif customer.monetary_value >= monetary_breaks[0]:
                m_score = 2
            else:
                m_score = 1
            
            customer.write({
                'recency_score': r_score,
                'frequency_score': f_score,
                'monetary_score': m_score,
                'last_update': fields.Datetime.now()
            })
        
        _logger.info(f"Scores RFM recalculés pour {len(customers)} clients")
    
    def update_from_transactions(self):
        """Mettre à jour les métriques depuis les transactions"""
        self.ensure_one()
        
        # Rechercher les transactions pour ce client
        transactions = self.env['hurimoney.transaction'].search([
            ('customer_phone', '=', self.customer_phone)
        ])
        
        if not transactions:
            return
        
        # Calculer les métriques
        total_amount = sum(transactions.mapped('amount'))
        transaction_count = len(transactions)
        
        dates = [t.transaction_date for t in transactions if t.transaction_date]
        if dates:
            first_date = min(dates)
            last_date = max(dates)
            recency = (datetime.now() - last_date).days
        else:
            first_date = last_date = recency = 0
        
        # Mettre à jour
        self.write({
            'frequency': transaction_count,
            'monetary_value': total_amount,
            'recency_days': recency,
            'first_transaction_date': first_date,
            'last_transaction_date': last_date,
            'customer_name': transactions[0].customer_name if transactions else self.customer_name,
            'last_update': fields.Datetime.now()
        })
    
    @api.model
    def sync_all_from_transactions(self):
        """Synchroniser toutes les analytics depuis les transactions"""
        # Obtenir tous les clients uniques depuis les transactions
        query = """
            SELECT DISTINCT customer_phone, customer_name
            FROM hurimoney_transaction 
            WHERE customer_phone IS NOT NULL
        """
        self.env.cr.execute(query)
        customers_data = self.env.cr.fetchall()
        
        for phone, name in customers_data:
            # Chercher ou créer l'enregistrement analytics
            analytics = self.search([('customer_phone', '=', phone)], limit=1)
            if not analytics:
                analytics = self.create({
                    'customer_phone': phone,
                    'customer_name': name or f'Client {phone}'
                })
            
            # Mettre à jour depuis les transactions
            analytics.update_from_transactions()
        
        # Recalculer les scores RFM
        self.calculate_rfm_scores()
        
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'Synchronisation terminée',
                'message': f'Analytics mises à jour pour {len(customers_data)} clients',
                'type': 'success',
            }
        }
    
    def action_create_partner(self):
        """Créer un partenaire à partir de l'analytics"""
        self.ensure_one()
        
        if self.partner_id:
            raise UserError("Un partenaire est déjà associé à ce client")
        
        partner = self.env['res.partner'].create({
            'name': self.customer_name or f'Client {self.customer_phone}',
            'phone': self.customer_phone,
            'is_company': False,
            'category_id': [(4, self.env.ref('base.res_partner_category_11').id)],  # Clients
            'x_b2c_segment': self.segment,
            'x_customer_score': (self.recency_score + self.frequency_score + self.monetary_score) / 15 * 100,
            'x_is_high_potential': self.segment in ['CHAMPIONS', 'LOYAL', 'POTENTIAL_LOYALISTS'],
            'x_total_transactions': self.frequency,
            'x_total_amount': self.monetary_value,
            'x_avg_transaction': self.avg_transaction_amount,
            'x_last_transaction': self.last_transaction_date
        })
        
        self.partner_id = partner.id
        
        return {
            'type': 'ir.actions.act_window',
            'res_model': 'res.partner',
            'view_mode': 'form',
            'res_id': partner.id,
            'target': 'current',
        }
    
    @api.model
    def get_segment_distribution(self):
        """Obtenir la distribution des segments pour le dashboard"""
        query = """
            SELECT segment, COUNT(*) as count, SUM(monetary_value) as total_value
            FROM hurimoney_customer_analytics
            WHERE active = true
            GROUP BY segment
            ORDER BY total_value DESC
        """
        self.env.cr.execute(query)
        return self.env.cr.dictfetchall()
    
    @api.model
    def get_top_customers(self, limit=10):
        """Obtenir les meilleurs clients"""
        return self.search([
            ('active', '=', True),
            ('segment', 'in', ['CHAMPIONS', 'LOYAL', 'CANNOT_LOSE'])
        ], limit=limit, order='monetary_value desc')
    
    @api.constrains('recency_score', 'frequency_score', 'monetary_score')
    def _check_scores(self):
        """Valider que les scores sont entre 1 et 5"""
        for record in self:
            scores = [record.recency_score, record.frequency_score, record.monetary_score]
            if any(score < 1 or score > 5 for score in scores):
                raise ValidationError("Les scores RFM doivent être entre 1 et 5")
    
    def name_get(self):
        """Personnaliser l'affichage du nom"""
        result = []
        for record in self:
            name = f"{record.customer_name or record.customer_phone} ({record.segment})"
            result.append((record.id, name))
        return result