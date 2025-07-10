#!/bin/bash

echo "🔄 Synchronisation des corrections avec GitHub..."

# Corriger le manifest local pour supprimer web_map et dépendances externes
cat > __manifest__.py << 'MANIFEST_EOF'
# -*- coding: utf-8 -*-
{
    'name': 'HuriMoney Concessionnaires',
    'version': '18.0.1.0.0',
    'category': 'Sales',
    'summary': 'Gestion des concessionnaires HuriMoney',
    'description': """
        Module de gestion des concessionnaires HuriMoney
        ================================================
        
        Fonctionnalités:
        - Gestion des concessionnaires et leurs informations
        - Suivi des kits et téléphones distribués
        - Enregistrement des transactions
        - Dashboard et rapports de performance
        - Géolocalisation des concessionnaires
    """,
    'author': 'HuriMoney',
    'website': 'https://www.hurimoney.com',
    'depends': [
        'base',
        'mail',
        'contacts',
        'base_geolocalize',
    ],
    'data': [
        # Security
        'security/hurimoney_security.xml',
        'security/ir.model.access.csv',
        
        # Data
        'data/sequence_data.xml',
        
        # Views
        'views/menu_views.xml',
        'views/concessionnaire_views.xml',
        'views/kit_views.xml',
        'views/transaction_views.xml',
        'views/dashboard_views.xml',
    ],
    'installable': True,
    'application': True,
    'auto_install': False,
    'license': 'LGPL-3',
}
MANIFEST_EOF

# Corriger models/__init__.py pour exclure sms_integration
cat > models/__init__.py << 'INIT_EOF'
from . import concessionnaire
from . import kit
from . import transaction
from . import dashboard
from . import res_config_settings
from . import wakati_connector
INIT_EOF

# Neutraliser sms_integration.py
cat > models/sms_integration.py << 'SMS_EOF'
# -*- coding: utf-8 -*-
# Module SMS désactivé - dépendances externes non disponibles
# Pour activer, installer: pip install twilio
SMS_EOF

# Corriger api_controller.py pour éviter les erreurs f-string
cat > controllers/api_controller.py << 'PYTHON_EOF'
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
            _logger.error("Erreur API get_concessionnaires: %s", str(e))
            return {'success': False, 'error': str(e)}
    
    @http.route('/api/hurimoney/transactions', type='json', auth='api_key', methods=['POST'], csrf=False)
    def create_transaction(self, **kwargs):
        """Créer une nouvelle transaction"""
        try:
            required_fields = ['concessionnaire_code', 'amount', 'transaction_type', 'external_id']
            for field in required_fields:
                if field not in kwargs:
                    return {'success': False, 'error': 'Champ requis manquant: ' + field}
            
            # Trouver le concessionnaire
            concessionnaire = request.env['hurimoney.concessionnaire'].search([
                ('code', '=', kwargs['concessionnaire_code'])
            ], limit=1)
        
            if not concessionnaire:
                return {'success': False, 'error': 'Concessionnaire non trouvé avec le code ' + kwargs['concessionnaire_code']}

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
            _logger.error("Erreur API create_transaction: %s", str(e))
            return {'success': False, 'error': str(e)}
PYTHON_EOF

echo "✅ Fichiers corrigés localement"
echo ""
echo "📋 Pour pousser vers GitHub:"
echo "git add ."
echo "git commit -m 'fix: Remove external dependencies and syntax errors'"
echo "git push origin main"