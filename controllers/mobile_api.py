# -*- coding: utf-8 -*-
import json
import jwt
from datetime import datetime, timedelta
from odoo import http
from odoo.http import request

class MobileAPIController(http.Controller):
    
    @http.route('/api/mobile/login', type='json', auth='public', methods=['POST'], csrf=False)
    def mobile_login(self, **kwargs):
        """Authentification mobile pour les concessionnaires"""
        phone = kwargs.get('phone')
        pin = kwargs.get('pin')
        
        if not phone or not pin:
            return {'success': False, 'error': 'Phone et PIN requis'}
        
        # Vérifier le concessionnaire
        concessionnaire = request.env['hurimoney.concessionnaire'].sudo().search([
            ('phone', '=', phone),
            ('pin', '=', pin),
            ('state', '=', 'active')
        ], limit=1)
        
        if not concessionnaire:
            return {'success': False, 'error': 'Identifiants invalides'}
        
        # Générer un token JWT
        payload = {
            'concessionnaire_id': concessionnaire.id,
            'exp': datetime.utcnow() + timedelta(days=30)
        }
        token = jwt.encode(payload, request.env['ir.config_parameter'].sudo().get_param('database.secret'), algorithm='HS256')
        
        return {
            'success': True,
            'token': token,
            'concessionnaire': {
                'id': concessionnaire.id,
                'name': concessionnaire.name,
                'code': concessionnaire.code,
                'performance_score': concessionnaire.performance_score,
            }
        }
    
    @http.route('/api/mobile/dashboard', type='json', auth='public', methods=['GET'], csrf=False)
    def mobile_dashboard(self, **kwargs):
        """Dashboard mobile du concessionnaire"""
        token = request.httprequest.headers.get('Authorization', '').replace('Bearer ', '')
        
        try:
            payload = jwt.decode(token, request.env['ir.config_parameter'].sudo().get_param('database.secret'), algorithms=['HS256'])
            concessionnaire_id = payload.get('concessionnaire_id')
        except:
            return {'success': False, 'error': 'Token invalide'}
        
        concessionnaire = request.env['hurimoney.concessionnaire'].sudo().browse(concessionnaire_id)
        
        if not concessionnaire.exists():
            return {'success': False, 'error': 'Concessionnaire non trouvé'}
        
        # Calculer les stats du jour
        today = fields.Date.today()
        today_transactions = concessionnaire.transaction_ids.filtered(
            lambda t: t.transaction_date.date() == today and t.state == 'done'
        )
        
        return {
            'success': True,
            'data': {
                'today_count': len(today_transactions),
                'today_volume': sum(today_transactions.mapped('amount')),
                'today_commission': sum(today_transactions.mapped('commission')),
                'monthly_volume': concessionnaire.monthly_volume,
                'performance_score': concessionnaire.performance_score,
                'ranking': concessionnaire.ranking,
            }
        }
    
    @http.route('/api/mobile/transaction/create', type='json', auth='public', methods=['POST'], csrf=False)
    def mobile_create_transaction(self, **kwargs):
        """Créer une transaction depuis mobile"""
        token = request.httprequest.headers.get('Authorization', '').replace('Bearer ', '')
        
        try:
            payload = jwt.decode(token, request.env['ir.config_parameter'].sudo().get_param('database.secret'), algorithms=['HS256'])
            concessionnaire_id = payload.get('concessionnaire_id')
        except:
            return {'success': False, 'error': 'Token invalide'}
        
        # Valider les données
        required_fields = ['amount', 'transaction_type', 'customer_phone']
        for field in required_fields:
            if field not in kwargs:
                return {'success': False, 'error': f'Champ requis: {field}'}
        
        try:
            # Créer la transaction
            transaction = request.env['hurimoney.transaction'].sudo().create({
                'concessionnaire_id': concessionnaire_id,
                'amount': float(kwargs['amount']),
                'transaction_type': kwargs['transaction_type'],
                'customer_name': kwargs.get('customer_name', ''),
                'customer_phone': kwargs['customer_phone'],
                'state': 'pending',
                'mobile_created': True,
            })
            
            # Traiter la transaction (validation avec API externe)
            # ... logique de traitement ...
            
            transaction.action_done()
            
            return {
                'success': True,
                'transaction': {
                    'id': transaction.id,
                    'name': transaction.name,
                    'amount': transaction.amount,
                    'commission': transaction.commission,
                }
            }
            
        except Exception as e:
            return {'success': False, 'error': str(e)}