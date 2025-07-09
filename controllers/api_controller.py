# -*- coding: utf-8 -*-
import json
import logging
from datetime import datetime
from odoo import http
from odoo.http import request

_logger = logging.getLogger(__name__)

class HuriMoneyAPIController(http.Controller):
    
    @http.route('/api/hurimoney/concessionnaires', type='json', auth='api_key', methods=['GET'], csrf=False)
    def get_concessionnaires(self, **kwargs):
        """Récupérer la liste des concessionnaires"""
        try:
            domain = [('state', '=', 'active')]
            if kwargs.get('code'):
                domain.append(('code', '=', kwargs['code']))
            
            concessionnaires = request.env['hurimoney.concessionnaire'].search(domain)
            
            return {
                'success': True,
                'data': [{
                    'id': c.id,
                    'code': c.code,
                    'name': c.name,
                    'phone': c.phone,
                    'state': c.state,
                    'latitude': c.latitude,
                    'longitude': c.longitude,
                } for c in concessionnaires]
            }
        except Exception as e:
            _logger.error(f"Erreur API get_concessionnaires: {str(e)}")
            return {'success': False, 'error': str(e)}
    
    @http.route('/api/hurimoney/transactions', type='json', auth='api_key', methods=['POST'], csrf=False)
    def create_transaction(self, **kwargs):
        """Créer une nouvelle transaction"""
        try:
            required_fields = ['concessionnaire_code', 'amount', 'transaction_type', 'external_id']
            for field in required_fields:
                if field not in kwargs:
                    return {'success': False, 'error': f'Champ requis manquant: {field}'}
            
            # Trouver le concessionnaire
            concessionnaire = request.env['hurimoney.concessionnaire'].search([
                ('code', '=', kwargs['concessionnaire_code'])
            ], limit=1)
        
        if not concessionnaire:
            return {'success': False, 'error': f"Concessionnaire non trouvé avec le code {kwargs['concessionnaire_code']}"}

        try:
            new_transaction = request.env['hurimoney.transaction'].create({
                'concessionnaire_id': concessionnaire.id,
                'transaction_date': datetime.now(),
                'transaction_type': kwargs.get('transaction_type'),
                'amount': kwargs.get('amount'),
                'customer_name': kwargs.get('customer_name'),
                'customer_phone': kwargs.get('customer_phone'),
                'external_id': kwargs.get('external_id'),
                'state': 'done',
            })
            return {
                'success': True,
                'transaction_id': new_transaction.id,
                'reference': new_transaction.name
            }
        except Exception as e:
            _logger.error(f"Erreur API create_transaction: {str(e)}")
            return {'success': False, 'error': str(e)}
    
    def sync_all(self):
        """Synchroniser toutes les données"""
        self.sync_concessionnaires()
        self.sync_transactions()
        return {
            'type': 'ir.actions.client',
            'tag': 'display_notification',
            'params': {
                'title': 'Synchronisation terminée',
                'message': 'Les données ont été synchronisées avec succès',
                'type': 'success',
                'sticky': False,
            }
        }

    @api.model
    def cron_sync_wakati(self):
        """Méthode appelée par le cron pour la synchronisation automatique"""
        connectors = self.search([('auto_sync', '=', True)])
        for connector in connectors:
            connector.sync_all()