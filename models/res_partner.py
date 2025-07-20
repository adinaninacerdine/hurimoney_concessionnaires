# -*- coding: utf-8 -*-
from odoo import models, fields, api
from datetime import datetime, timedelta

class ResPartner(models.Model):
    _inherit = 'res.partner'

    # Champs B2C
    x_b2c_segment = fields.Selection([
        ('HIGH_VALUE', 'Haute Valeur'),
        ('LOYAL', 'Fidèle'),
        ('NEW', 'Nouveau'),
        ('AT_RISK', 'À Risque'),
        ('OTHER', 'Autre')
    ], string='Segment B2C', help="Segment du client final calculé par le pipeline de données.", readonly=True, tracking=True)
    
    x_total_transactions = fields.Integer(string='Total Transactions', help="Nombre total de transactions", readonly=True)
    x_total_amount = fields.Float(string='Volume Total', help="Volume total des transactions", readonly=True)
    x_first_transaction = fields.Datetime(string='Première Transaction', readonly=True)
    x_last_transaction = fields.Datetime(string='Dernière Transaction', readonly=True)
    x_avg_transaction = fields.Float(string='Montant Moyen', compute='_compute_avg_transaction', store=True)
    x_customer_score = fields.Float(string='Score Client', compute='_compute_customer_score', store=True)
    x_is_high_potential = fields.Boolean(string='Fort Potentiel', compute='_compute_high_potential', store=True)
    
    # Relations avec les transactions HuriMoney
    hurimoney_transaction_ids = fields.One2many('hurimoney.transaction', 'customer_id', string='Transactions HuriMoney')
    
    @api.depends('x_total_transactions', 'x_total_amount')
    def _compute_avg_transaction(self):
        for record in self:
            if record.x_total_transactions > 0:
                record.x_avg_transaction = record.x_total_amount / record.x_total_transactions
            else:
                record.x_avg_transaction = 0.0
    
    @api.depends('x_total_transactions', 'x_total_amount', 'x_first_transaction', 'x_last_transaction')
    def _compute_customer_score(self):
        for record in self:
            score = 0.0
            
            # Score basé sur le volume (max 40 points)
            if record.x_total_amount:
                volume_score = min(record.x_total_amount / 100000 * 20, 40)
                score += volume_score
            
            # Score basé sur la fréquence (max 30 points)
            if record.x_total_transactions:
                frequency_score = min(record.x_total_transactions * 2, 30)
                score += frequency_score
            
            # Score basé sur la récence (max 30 points)
            if record.x_last_transaction:
                days_since_last = (datetime.now() - record.x_last_transaction).days
                if days_since_last <= 7:
                    recency_score = 30
                elif days_since_last <= 30:
                    recency_score = 20
                elif days_since_last <= 90:
                    recency_score = 10
                else:
                    recency_score = 0
                score += recency_score
            
            record.x_customer_score = min(score, 100)
    
    @api.depends('x_customer_score', 'x_total_amount', 'x_total_transactions')
    def _compute_high_potential(self):
        for record in self:
            # Critères pour identifier un client à fort potentiel
            record.x_is_high_potential = (
                record.x_customer_score >= 70 or
                record.x_total_amount >= 500000 or
                record.x_total_transactions >= 20
            )
    
    def action_create_crm_opportunity(self):
        """Créer une opportunité CRM pour ce client"""
        self.ensure_one()
        if not self.x_is_high_potential:
            return
        
        # Vérifier s'il n'y a pas déjà une opportunité récente
        existing_opportunity = self.env['crm.lead'].search([
            ('partner_id', '=', self.id),
            ('create_date', '>=', datetime.now() - timedelta(days=30))
        ], limit=1)
        
        if existing_opportunity:
            return existing_opportunity
        
        # Créer l'opportunité
        opportunity = self.env['crm.lead'].create({
            'name': f'Opportunité HuriMoney - {self.name}',
            'partner_id': self.id,
            'phone': self.phone,
            'email': self.email,
            'description': f"""
Client à fort potentiel identifié via HuriMoney:
- Score client: {self.x_customer_score}/100
- Volume total: {self.x_total_amount:,.0f}
- Nombre de transactions: {self.x_total_transactions}
- Segment: {dict(self._fields['x_b2c_segment'].selection).get(self.x_b2c_segment, 'Non défini')}
""",
            'expected_revenue': self.x_total_amount * 0.02,  # 2% du volume comme potentiel
            'probability': 60 if self.x_customer_score >= 80 else 40,
            'stage_id': self.env.ref('crm.stage_lead1').id if self.env.ref('crm.stage_lead1') else False,
        })
        
        return opportunity
    
    def action_view_customer_analytics(self):
        """Voir les analytics client B2C"""
        self.ensure_one()
        analytics = self.env['hurimoney.customer.analytics'].search([
            ('customer_phone', '=', self.phone)
        ], limit=1)
        
        if not analytics:
            # Créer l'enregistrement analytics s'il n'existe pas
            analytics = self.env['hurimoney.customer.analytics'].create({
                'customer_phone': self.phone,
                'customer_name': self.name,
            })
            analytics.update_from_transactions()
        
        return {
            'type': 'ir.actions.act_window',
            'name': f'Analytics B2C - {self.name}',
            'res_model': 'hurimoney.customer.analytics',
            'view_mode': 'form',
            'res_id': analytics.id,
            'target': 'current',
        }
    
    def action_view_transactions(self):
        """Voir les transactions HuriMoney du client"""
        self.ensure_one()
        return {
            'type': 'ir.actions.act_window',
            'name': f'Transactions HuriMoney - {self.name}',
            'res_model': 'hurimoney.transaction',
            'view_mode': 'list,form',
            'domain': [('customer_phone', '=', self.phone)],
            'context': {'default_customer_phone': self.phone, 'default_customer_name': self.name},
            'target': 'current',
        }