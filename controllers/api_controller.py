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
            
            # Filtres optionnels
            if kwargs.get('code'):
                domain.append(('code', '=', kwargs['code']))
            if kwargs.get('zone'):
                domain.append(('zone', '=', kwargs['zone']))
            
            # Pagination
            limit = int(kwargs.get('limit', 100))
            offset = int(kwargs.get('offset', 0))
            
            concessionnaires = request.env['hurimoney.concessionnaire'].search(
                domain, 
                limit=limit, 
                offset=offset,
                order='code asc'
            )
            
            # Compter le total
            total_count = request.env['hurimoney.concessionnaire'].search_count(domain)
            
            return {
                'success': True,
                'data': [{
                    'id': c.id,
                    'code': c.code,
                    'name': c.name,
                    'phone': c.phone,
                    'email': c.email,
                    'zone': c.zone,
                    'state': c.state,
                    'latitude': c.latitude,
                    'longitude': c.longitude,
                    'performance_score': c.performance_score,
                    'daily_transactions': c.daily_transactions,
                    'monthly_volume': c.monthly_volume,
                } for c in concessionnaires],
                'total': total_count,
                'limit': limit,
                'offset': offset
            }
        except Exception as e:
            _logger.error("Erreur API get_concessionnaires: %s", str(e))
            return {'success': False, 'error': str(e)}
    
    @http.route('/api/hurimoney/transactions', type='json', auth='api_key', methods=['POST'], csrf=False)
    def create_transaction(self, **kwargs):
        """Créer une nouvelle transaction"""
        try:
            # Vérifier les champs requis
            required_fields = ['concessionnaire_code', 'amount', 'transaction_type']
            missing_fields = [f for f in required_fields if not kwargs.get(f)]
            if missing_fields:
                return {
                    'success': False, 
                    'error': 'Champs requis manquants: ' + ', '.join(missing_fields)
                }
            
            # Trouver le concessionnaire
            concessionnaire = request.env['hurimoney.concessionnaire'].search([
                ('code', '=', kwargs['concessionnaire_code']),
                ('state', '=', 'active')
            ], limit=1)
        
            if not concessionnaire:
                return {
                    'success': False, 
                    'error': 'Concessionnaire non trouvé ou inactif: ' + kwargs['concessionnaire_code']
                }
            
            # Vérifier le type de transaction
            valid_types = ['deposit', 'withdrawal', 'transfer', 'payment']
            if kwargs['transaction_type'] not in valid_types:
                return {
                    'success': False,
                    'error': 'Type de transaction invalide. Types valides: ' + ', '.join(valid_types)
                }
            
            # Créer la transaction
            transaction_vals = {
                'concessionnaire_id': concessionnaire.id,
                'transaction_date': kwargs.get('transaction_date', fields.Datetime.now()),
                'transaction_type': kwargs['transaction_type'],
                'amount': float(kwargs['amount']),
                'customer_name': kwargs.get('customer_name', ''),
                'customer_phone': kwargs.get('customer_phone', ''),
                'external_id': kwargs.get('external_id', ''),
                'reference': kwargs.get('reference', ''),
                'notes': kwargs.get('notes', ''),
                'state': 'pending',
            }
            
            # Si commission rate fournie
            if kwargs.get('commission_rate'):
                transaction_vals['commission_rate'] = float(kwargs['commission_rate'])
            
            new_transaction = request.env['hurimoney.transaction'].create(transaction_vals)
            
            # Si demandé, valider immédiatement
            if kwargs.get('auto_validate', False):
                new_transaction.action_done()
            
            return {
                'success': True,
                'data': {
                    'transaction_id': new_transaction.id,
                    'reference': new_transaction.name,
                    'state': new_transaction.state,
                    'amount': new_transaction.amount,
                    'commission': new_transaction.commission,
                }
            }
        except ValueError as e:
            _logger.error("Erreur de valeur API create_transaction: %s", str(e))
            return {'success': False, 'error': 'Valeur invalide: ' + str(e)}
        except Exception as e:
            _logger.error("Erreur API create_transaction: %s", str(e))
            return {'success': False, 'error': str(e)}
    
    @http.route('/api/hurimoney/transactions/<int:transaction_id>', type='json', auth='api_key', methods=['GET'], csrf=False)
    def get_transaction(self, transaction_id, **kwargs):
        """Récupérer le détail d'une transaction"""
        try:
            transaction = request.env['hurimoney.transaction'].browse(transaction_id)
            
            if not transaction.exists():
                return {'success': False, 'error': 'Transaction non trouvée'}
            
            return {
                'success': True,
                'data': {
                    'id': transaction.id,
                    'reference': transaction.name,
                    'concessionnaire_code': transaction.concessionnaire_id.code,
                    'concessionnaire_name': transaction.concessionnaire_id.name,
                    'transaction_date': transaction.transaction_date.isoformat() if transaction.transaction_date else None,
                    'transaction_type': transaction.transaction_type,
                    'amount': transaction.amount,
                    'commission_rate': transaction.commission_rate,
                    'commission': transaction.commission,
                    'customer_name': transaction.customer_name,
                    'customer_phone': transaction.customer_phone,
                    'external_id': transaction.external_id,
                    'reference': transaction.reference,
                    'state': transaction.state,
                    'notes': transaction.notes,
                }
            }
        except Exception as e:
            _logger.error("Erreur API get_transaction: %s", str(e))
            return {'success': False, 'error': str(e)}
    
    @http.route('/api/hurimoney/kits', type='json', auth='api_key', methods=['GET'], csrf=False)
    def get_kits(self, **kwargs):
        """Récupérer la liste des kits"""
        try:
            domain = []
            
            # Filtres optionnels
            if kwargs.get('concessionnaire_code'):
                concessionnaire = request.env['hurimoney.concessionnaire'].search([
                    ('code', '=', kwargs['concessionnaire_code'])
                ], limit=1)
                if concessionnaire:
                    domain.append(('concessionnaire_id', '=', concessionnaire.id))
            
            if kwargs.get('state'):
                domain.append(('state', '=', kwargs['state']))
            
            # Pagination
            limit = int(kwargs.get('limit', 100))
            offset = int(kwargs.get('offset', 0))
            
            kits = request.env['hurimoney.kit'].search(
                domain,
                limit=limit,
                offset=offset,
                order='delivery_date desc'
            )
            
            total_count = request.env['hurimoney.kit'].search_count(domain)
            
            return {
                'success': True,
                'data': [{
                    'id': k.id,
                    'serial_number': k.serial_number,
                    'concessionnaire_code': k.concessionnaire_id.code,
                    'concessionnaire_name': k.concessionnaire_id.name,
                    'kit_type': k.kit_type,
                    'phone_model': k.phone_model,
                    'phone_imei': k.phone_imei,
                    'total_cost': k.total_cost,
                    'delivery_date': k.delivery_date.isoformat() if k.delivery_date else None,
                    'activation_date': k.activation_date.isoformat() if k.activation_date else None,
                    'state': k.state,
                    'deposit_paid': k.deposit_paid,
                } for k in kits],
                'total': total_count,
                'limit': limit,
                'offset': offset
            }
        except Exception as e:
            _logger.error("Erreur API get_kits: %s", str(e))
            return {'success': False, 'error': str(e)}