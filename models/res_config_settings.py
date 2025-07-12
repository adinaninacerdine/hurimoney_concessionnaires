# -*- coding: utf-8 -*-
from odoo import models, fields, api


class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'
    
    # Configuration des commissions
    hurimoney_commission_rate = fields.Float(
        string='Taux de commission par défaut (%)',
        config_parameter='hurimoney.default_commission_rate',
        default=2.0,
        help="Taux de commission appliqué par défaut sur les transactions"
    )
    
    # Limites de transaction
    hurimoney_min_transaction = fields.Monetary(
        string='Transaction minimale',
        config_parameter='hurimoney.min_transaction_amount',
        default=1000.0,
        currency_field='currency_id',
        help="Montant minimum autorisé pour une transaction"
    )
    
    hurimoney_max_transaction = fields.Monetary(
        string='Transaction maximale',
        config_parameter='hurimoney.max_transaction_amount',
        default=5000000.0,
        currency_field='currency_id',
        help="Montant maximum autorisé pour une transaction"
    )
    
    # Devise
    currency_id = fields.Many2one('res.currency', related='company_id.currency_id', readonly=True)
    
    # Paramètres de performance
    hurimoney_performance_threshold = fields.Float(
        string='Seuil de performance minimal (%)',
        config_parameter='hurimoney.performance_threshold',
        default=30.0,
        help="Les concessionnaires en dessous de ce seuil seront signalés"
    )
    
    hurimoney_inactivity_days = fields.Integer(
        string='Jours d\'inactivité avant alerte',
        config_parameter='hurimoney.inactivity_days',
        default=30,
        help="Nombre de jours sans transaction avant de signaler un concessionnaire comme inactif"
    )
    
    # Notifications
    hurimoney_enable_email = fields.Boolean(
        string='Activer les notifications Email',
        config_parameter='hurimoney.enable_email',
        default=True
    )
    
    @api.model
    def get_values(self):
        res = super().get_values()
        params = self.env['ir.config_parameter'].sudo()
        res.update(
            hurimoney_commission_rate=float(params.get_param('hurimoney.default_commission_rate', 2.0)),
            hurimoney_min_transaction=float(params.get_param('hurimoney.min_transaction_amount', 1000.0)),
            hurimoney_max_transaction=float(params.get_param('hurimoney.max_transaction_amount', 5000000.0)),
            hurimoney_performance_threshold=float(params.get_param('hurimoney.performance_threshold', 30.0)),
            hurimoney_inactivity_days=int(params.get_param('hurimoney.inactivity_days', 30)),
            hurimoney_enable_email=params.get_param('hurimoney.enable_email', 'True') == 'True',
        )
        return res
    
    def set_values(self):
        super().set_values()
        params = self.env['ir.config_parameter'].sudo()
        params.set_param('hurimoney.default_commission_rate', self.hurimoney_commission_rate)
        params.set_param('hurimoney.min_transaction_amount', self.hurimoney_min_transaction)
        params.set_param('hurimoney.max_transaction_amount', self.hurimoney_max_transaction)
        params.set_param('hurimoney.performance_threshold', self.hurimoney_performance_threshold)
        params.set_param('hurimoney.inactivity_days', self.hurimoney_inactivity_days)
        params.set_param('hurimoney.enable_email', self.hurimoney_enable_email)