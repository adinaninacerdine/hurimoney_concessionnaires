# -*- coding: utf-8 -*-
from datetime import datetime, timedelta
from odoo import models, fields, api

class HuriMoneyDashboard(models.TransientModel):
    _name = 'hurimoney.dashboard'
    _description = 'Dashboard HuriMoney'
    
    @api.model
    def _default_currency(self):
        return self.env.ref('base.KMF', raise_if_not_found=False) or self.env.company.currency_id
    
    currency_id = fields.Many2one('res.currency', default=_default_currency)
    
    # KPIs généraux
    total_concessionnaires = fields.Integer(string='Total concessionnaires', compute='_compute_kpis')
    active_concessionnaires = fields.Integer(string='Concessionnaires actifs', compute='_compute_kpis')
    suspended_concessionnaires = fields.Integer(string='Concessionnaires suspendus', compute='_compute_kpis')
    
    # KPIs financiers
    daily_volume = fields.Monetary(string='Volume journalier', compute='_compute_kpis', currency_field='currency_id')
    weekly_volume = fields.Monetary(string='Volume hebdomadaire', compute='_compute_kpis', currency_field='currency_id')
    monthly_volume = fields.Monetary(string='Volume mensuel', compute='_compute_kpis', currency_field='currency_id')
    total_commissions = fields.Monetary(string='Commissions totales', compute='_compute_kpis', currency_field='currency_id')
    
    # KPIs de performance
    avg_daily_transactions = fields.Float(string='Moyenne trans/jour', compute='_compute_kpis')
    top_performer_id = fields.Many2one('hurimoney.concessionnaire', string='Meilleur performer', compute='_compute_kpis')
    
    # Graphiques
    chart_data = fields.Text(string='Données graphiques', compute='_compute_chart_data')
    
    @api.depends()
    def _compute_kpis(self):
        for record in self:
            Concessionnaire = self.env['hurimoney.concessionnaire']
            Transaction = self.env['hurimoney.transaction']
            
            # KPIs généraux
            record.total_concessionnaires = Concessionnaire.search_count([])
            record.active_concessionnaires = Concessionnaire.search_count([('state', '=', 'active')])
            record.suspended_concessionnaires = Concessionnaire.search_count([('state', '=', 'suspended')])
            
            # KPIs financiers
            today = fields.Date.today()
            week_start = today - timedelta(days=today.weekday())
            month_start = today.replace(day=1)
            
            # Volume journalier
            daily_trans = Transaction.search([
                ('transaction_date', '>=', datetime.combine(today, datetime.min.time())),
                ('transaction_date', '<', datetime.combine(today + timedelta(days=1), datetime.min.time())),
                ('state', '=', 'done')
            ])
            record.daily_volume = sum(daily_trans.mapped('amount'))
            
            # Volume hebdomadaire
            weekly_trans = Transaction.search([
                ('transaction_date', '>=', datetime.combine(week_start, datetime.min.time())),
                ('state', '=', 'done')
            ])
            record.weekly_volume = sum(weekly_trans.mapped('amount'))
            
            # Volume mensuel
            monthly_trans = Transaction.search([
                ('transaction_date', '>=', datetime.combine(month_start, datetime.min.time())),
                ('state', '=', 'done')
            ])
            record.monthly_volume = sum(monthly_trans.mapped('amount'))
            record.total_commissions = sum(monthly_trans.mapped('commission'))
            
            # Performance
            if record.active_concessionnaires:
                record.avg_daily_transactions = len(daily_trans) / record.active_concessionnaires
            else:
                record.avg_daily_transactions = 0
            
            # Top performer
            top_performer = Concessionnaire.search([
                ('state', '=', 'active')
            ], order='performance_score desc', limit=1)
            record.top_performer_id = top_performer
    
    @api.depends()
    def _compute_chart_data(self):
        for record in self:
            # Préparer les données pour les graphiques
            # Ici on pourrait calculer des données JSON pour Chart.js
            record.chart_data = '{}'
    
    def action_view_active_concessionnaires(self):
        return {
            'name': 'Concessionnaires actifs',
            'type': 'ir.actions.act_window',
            'res_model': 'hurimoney.concessionnaire',
            'view_mode': 'tree,form',
            'domain': [('state', '=', 'active')],
            'context': {'search_default_state': 'active'},
        }
    
    def action_view_today_transactions(self):
        today = fields.Date.today()
        return {
            'name': 'Transactions du jour',
            'type': 'ir.actions.act_window',
            'res_model': 'hurimoney.transaction',
            'view_mode': 'tree,form',
            'domain': [
                ('transaction_date', '>=', datetime.combine(today, datetime.min.time())),
                ('transaction_date', '<', datetime.combine(today + timedelta(days=1), datetime.min.time()))
            ],
        }