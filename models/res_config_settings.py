# -*- coding: utf-8 -*-
from odoo import models, fields, api

class ResConfigSettings(models.TransientModel):
    _inherit = 'res.config.settings'
    
    # HuriMoney Configuration
    hurimoney_commission_rate = fields.Float(
        string='Taux de commission par défaut (%)',
        config_parameter='hurimoney.default_commission_rate',
        default=2.0
    )
    
    hurimoney_min_transaction = fields.Float(
        string='Transaction minimale (KMF)',
        config_parameter='hurimoney.min_transaction_amount',
        default=1000.0
    )
    
    hurimoney_max_transaction = fields.Float(
        string='Transaction maximale (KMF)',
        config_parameter='hurimoney.max_transaction_amount',
        default=5000000.0
    )
    
    hurimoney_auto_geocode = fields.Boolean(
        string='Géocodage automatique',
        config_parameter='hurimoney.auto_geocode',
        default=True
    )
    
    hurimoney_performance_threshold = fields.Float(
        string='Seuil de performance minimal (%)',
        config_parameter='hurimoney.performance_threshold',
        default=30.0,
        help="Les concessionnaires en dessous de ce seuil recevront des alertes"
    )
    
    hurimoney_inactivity_days = fields.Integer(
        string='Jours d\'inactivité avant suspension',
        config_parameter='hurimoney.inactivity_days',
        default=30
    )
    
    # Notifications
    hurimoney_enable_sms = fields.Boolean(
        string='Activer les notifications SMS',
        config_parameter='hurimoney.enable_sms'
    )
    
    hurimoney_enable_email = fields.Boolean(
        string='Activer les notifications Email',
        config_parameter='hurimoney.enable_email',
        default=True
    )
    
    hurimoney_daily_report_time = fields.Float(
        string='Heure d\'envoi rapport journalier',
        config_parameter='hurimoney.daily_report_time',
        default=18.0,
        help="Heure d'envoi du rapport journalier (format 24h)"
    )

class Company(models.Model):
    _inherit = 'res.company'
    
    hurimoney_logo = fields.Binary(string='Logo HuriMoney')
    hurimoney_support_phone = fields.Char(string='Téléphone Support', default='+269 123 456')
    hurimoney_support_email = fields.Char(string='Email Support', default='support@hurimoney.km')