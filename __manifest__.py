# -*- coding: utf-8 -*-
{
    'name': 'HuriMoney Concessionnaires',
    'version': '18.0.1.0.0',
    'category': 'Sales/Point of Sale',
    'summary': 'Gestion des concessionnaires HuriMoney',
    'description': """
        Module de gestion des concessionnaires HuriMoney
        ================================================
        
        Fonctionnalités:
        - Gestion des concessionnaires et leurs informations
        - Suivi des kits et téléphones distribués
        - Enregistrement des transactions
        - Intégration avec l'API WAKATI
        - Dashboard et rapports de performance
        - Géolocalisation des concessionnaires
    """,
    'author': 'HuriMoney',
    'website': 'https://www.hurimoney.com',
    'depends': [
        'base',
        'mail',
        'contacts',
        'web_map',
        'base_geolocalize',
    ],
    'data': [
        # Security
        'security/hurimoney_security.xml',
        'security/ir.model.access.csv',
        
        # Data
        'data/sequence_data.xml',
        'data/cron_data.xml',
        
        # Views
        'views/concessionnaire_views.xml',
        'views/kit_views.xml',
        'views/transaction_views.xml',
        'views/dashboard_views.xml',
        'views/wakati_connector_views.xml',
        'views/menu_views.xml',
        
        # Wizards
        'wizards/import_wizard_views.xml',
    ],
    'assets': {
        'web.assets_backend': [
            'hurimoney_concessionnaires/static/src/js/map_view.js',
            'hurimoney_concessionnaires/static/src/scss/map_view.scss',
        ],
    },
    'installable': True,
    'application': True,
    'auto_install': False,
    'license': 'LGPL-3',
}