# -*- coding: utf-8 -*-
import json
import logging
from datetime import datetime, timedelta
from odoo import http, fields
from odoo.http import request

_logger = logging.getLogger(__name__)


class HuriMoneyAPIController(http.Controller):
    
    @http.route('/api/hurimoney/concessionnaires', type='json', auth='public', methods=['POST'], csrf=False)
    def get_concessionnaires(self, **kwargs):
        """Récupérer la liste des concessionnaires"""
        try:
            # Utiliser sudo pour contourner les permissions
            domain = [('state', '=', 'active')]
            
            # Filtres optionnels
            if kwargs.get('code'):
                domain.append(('code', '=', kwargs['code']))
            if kwargs.get('zone'):
                domain.append(('zone', '=', kwargs['zone']))
            
            # Pagination
            limit = int(kwargs.get('limit', 100))
            offset = int(kwargs.get('offset', 0))
            
            concessionnaires = request.env['hurimoney.concessionnaire'].sudo().search(
                domain, 
                limit=limit, 
                offset=offset,
                order='code asc'
            )
            
            # Compter le total
            total_count = request.env['hurimoney.concessionnaire'].sudo().search_count(domain)
            
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
    
    @http.route('/api/hurimoney/transactions', type='json', auth='public', methods=['POST'], csrf=False)
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
    
    @http.route('/api/hurimoney/transactions/<int:transaction_id>', type='json', auth='public', methods=['POST'], csrf=False)
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
    
    @http.route('/api/hurimoney/kits', type='json', auth='public', methods=['POST'], csrf=False)
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
    
    @http.route('/api/hurimoney/customers/b2c-segments', type='json', auth='public', methods=['POST'], csrf=False)
    def get_b2c_segments(self, **kwargs):
        """Récupérer les clients B2C segmentés pour synchronisation CRM"""
        try:
            # Utiliser sudo pour contourner les permissions
            domain = [('x_b2c_segment', '!=', False)]
            
            # Filtres optionnels
            if kwargs.get('segment'):
                domain.append(('x_b2c_segment', '=', kwargs['segment']))
            if kwargs.get('min_score'):
                domain.append(('x_customer_score', '>=', float(kwargs['min_score'])))
            if kwargs.get('high_potential_only'):
                domain.append(('x_is_high_potential', '=', True))
            
            # Pagination
            limit = int(kwargs.get('limit', 100))
            offset = int(kwargs.get('offset', 0))
            
            customers = request.env['res.partner'].sudo().search(
                domain,
                limit=limit,
                offset=offset,
                order='x_customer_score desc, x_total_amount desc'
            )
            
            total_count = request.env['res.partner'].sudo().search_count(domain)
            
            return {
                'success': True,
                'data': [{
                    'id': c.id,
                    'name': c.name,
                    'phone': c.phone,
                    'email': c.email,
                    'segment': c.x_b2c_segment,
                    'customer_score': c.x_customer_score,
                    'total_transactions': c.x_total_transactions,
                    'total_amount': c.x_total_amount,
                    'avg_transaction': c.x_avg_transaction,
                    'first_transaction': c.x_first_transaction.isoformat() if c.x_first_transaction else None,
                    'last_transaction': c.x_last_transaction.isoformat() if c.x_last_transaction else None,
                    'is_high_potential': c.x_is_high_potential,
                    'street': c.street,
                    'city': c.city,
                    'country_id': c.country_id.code if c.country_id else None,
                } for c in customers],
                'total': total_count,
                'limit': limit,
                'offset': offset
            }
        except Exception as e:
            _logger.error("Erreur API get_b2c_segments: %s", str(e))
            return {'success': False, 'error': str(e)}
    
    @http.route('/api/hurimoney/wakati/sync', type='json', auth='public', methods=['POST'], csrf=False)
    def wakati_sync(self, **kwargs):
        """Synchroniser les données depuis Wakati mobile money"""
        try:
            # Traitement par batch des transactions Wakati
            transactions = kwargs.get('transactions', [])
            processed_count = 0
            errors = []
            
            for wakati_transaction in transactions:
                try:
                    # Utiliser une transaction séparée pour chaque transaction Wakati
                    with request.env.cr.savepoint():
                        # Mapping des données Wakati vers HuriMoney
                        transaction_vals = {
                            'external_id': wakati_transaction.get('wakati_id'),
                            'customer_phone': wakati_transaction.get('customer_phone'),
                            'customer_name': wakati_transaction.get('customer_name'),
                            'amount': float(wakati_transaction.get('amount', 0)),
                            'transaction_type': wakati_transaction.get('type', 'transfer'),
                            'transaction_date': wakati_transaction.get('timestamp'),
                            'reference': wakati_transaction.get('reference'),
                            'notes': f"Importé depuis Wakati - ID: {wakati_transaction.get('wakati_id')}",
                            'state': 'done',
                            'mobile_created': True,
                        }
                        
                        # Trouver ou créer le concessionnaire par défaut pour Wakati
                        concessionnaire = request.env['hurimoney.concessionnaire'].sudo().search([
                            ('code', '=', 'WAKATI_DEFAULT')
                        ], limit=1)
                        
                        if not concessionnaire:
                            # Créer d'abord le contact partner
                            partner = request.env['res.partner'].sudo().create({
                                'name': 'Wakati Mobile Money',
                                'is_company': True,
                                'phone': '+269 000 0000',
                                'email': 'wakati@hurimoney.com',
                                'comment': 'Partenaire virtuel pour les transactions Wakati'
                            })
                            
                            concessionnaire = request.env['hurimoney.concessionnaire'].sudo().create({
                                'name': 'Wakati Mobile Money',
                                'code': 'WAKATI_DEFAULT',
                                'partner_id': partner.id,
                                'phone': '+269 000 0000',
                                'email': 'wakati@hurimoney.com',
                                'zone': 'digital',
                                'state': 'active',
                                'notes': 'Concessionnaire virtuel pour les transactions Wakati'
                            })
                        
                        transaction_vals['concessionnaire_id'] = concessionnaire.id
                        
                        # Vérifier si la transaction existe déjà
                        existing = request.env['hurimoney.transaction'].sudo().search([
                            ('external_id', '=', transaction_vals['external_id'])
                        ], limit=1)
                        
                        if not existing:
                            request.env['hurimoney.transaction'].sudo().create(transaction_vals)
                            processed_count += 1
                    
                except Exception as e:
                    errors.append(f"Transaction {wakati_transaction.get('wakati_id')}: {str(e)}")
                    continue
            
            return {
                'success': True,
                'processed_count': processed_count,
                'total_sent': len(transactions),
                'errors': errors
            }
        except Exception as e:
            _logger.error("Erreur API wakati_sync: %s", str(e))
            return {'success': False, 'error': str(e)}
    
    @http.route('/api/hurimoney/mapsly/geodata', type='json', auth='public', methods=['POST'], csrf=False)
    def mapsly_geodata(self, **kwargs):
        """API pour Mapsly - données géospatiales des concessionnaires et clients"""
        try:
            # Récupérer les concessionnaires avec géolocalisation
            concessionnaires = request.env['hurimoney.concessionnaire'].sudo().search([
                ('latitude', '!=', 0),
                ('longitude', '!=', 0),
                ('state', '=', 'active')
            ])
            
            # Récupérer les clients B2C segmentés avec adresses
            customers = request.env['res.partner'].sudo().search([
                ('x_b2c_segment', '!=', False),
                ('x_is_high_potential', '=', True),
                '|', ('street', '!=', False), ('city', '!=', False)
            ])
            
            # Formatter les données pour Mapsly
            geojson_features = []
            
            # Ajouter les concessionnaires
            for conc in concessionnaires:
                geojson_features.append({
                    'type': 'Feature',
                    'geometry': {
                        'type': 'Point',
                        'coordinates': [conc.longitude, conc.latitude]
                    },
                    'properties': {
                        'id': conc.id,
                        'type': 'concessionnaire',
                        'name': conc.name,
                        'code': conc.code,
                        'zone': conc.zone,
                        'performance_score': conc.performance_score,
                        'daily_transactions': conc.daily_transactions,
                        'monthly_volume': conc.monthly_volume,
                        'phone': conc.phone,
                        'email': conc.email,
                        'address': f"{conc.street or ''} {conc.city or ''}".strip()
                    }
                })
            
            # Ajouter les clients B2C
            for customer in customers:
                if customer.partner_latitude and customer.partner_longitude:
                    geojson_features.append({
                        'type': 'Feature',
                        'geometry': {
                            'type': 'Point',
                            'coordinates': [customer.partner_longitude, customer.partner_latitude]
                        },
                        'properties': {
                            'id': customer.id,
                            'type': 'customer_b2c',
                            'name': customer.name,
                            'phone': customer.phone,
                            'segment': customer.x_b2c_segment,
                            'customer_score': customer.x_customer_score,
                            'total_amount': customer.x_total_amount,
                            'total_transactions': customer.x_total_transactions,
                            'is_high_potential': customer.x_is_high_potential,
                            'address': f"{customer.street or ''} {customer.city or ''}".strip()
                        }
                    })
            
            return {
                'success': True,
                'type': 'FeatureCollection',
                'features': geojson_features,
                'metadata': {
                    'total_concessionnaires': len(concessionnaires),
                    'total_customers': len(customers),
                    'generated_at': datetime.now().isoformat()
                }
            }
        except Exception as e:
            _logger.error("Erreur API mapsly_geodata: %s", str(e))
            return {'success': False, 'error': str(e)}
    
    @http.route('/api/hurimoney/analytics/segments', type='json', auth='public', methods=['POST'], csrf=False)
    def analytics_segments(self, **kwargs):
        """Analytics des segments B2C"""
        try:
            # Statistiques par segment
            segment_stats = {}
            segments = ['HIGH_VALUE', 'LOYAL', 'NEW', 'AT_RISK', 'OTHER']
            
            for segment in segments:
                customers = request.env['res.partner'].sudo().search([
                    ('x_b2c_segment', '=', segment)
                ])
                
                segment_stats[segment] = {
                    'count': len(customers),
                    'total_volume': sum(customers.mapped('x_total_amount')),
                    'avg_score': sum(customers.mapped('x_customer_score')) / len(customers) if customers else 0,
                    'high_potential_count': len(customers.filtered('x_is_high_potential'))
                }
            
            # Tendances temporelles
            last_30_days = fields.Datetime.now() - timedelta(days=30)
            recent_transactions = request.env['hurimoney.transaction'].sudo().search([
                ('create_date', '>=', last_30_days),
                ('state', '=', 'done')
            ])
            
            return {
                'success': True,
                'segment_stats': segment_stats,
                'recent_activity': {
                    'transactions_30d': len(recent_transactions),
                    'volume_30d': sum(recent_transactions.mapped('amount')),
                    'new_customers_30d': request.env['res.partner'].sudo().search_count([
                        ('create_date', '>=', last_30_days),
                        ('x_b2c_segment', '!=', False)
                    ])
                }
            }
        except Exception as e:
            _logger.error("Erreur API analytics_segments: %s", str(e))
            return {'success': False, 'error': str(e)}