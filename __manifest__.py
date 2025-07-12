# -*- coding: utf-8 -*-
{
    'name': 'HuriMoney Concessionnaires',
    'version': '18.0.1.0.0',
    'category': 'Sales',
    'summary': 'Gestion des concessionnaires HuriMoney',
    'description': """
Module de gestion des concessionnaires HuriMoney
================================================

Fonctionnalités principales:
* Gestion des concessionnaires (création, activation, suspension)
* Suivi des kits distribués (téléphones et accessoires)
* Enregistrement et suivi des transactions
* Tableaux de bord avec vues pivot et graphiques
* Import/Export de données CSV
* API REST pour intégration externe

Ce module permet de gérer efficacement un réseau de concessionnaires
pour les services de transfert d'argent mobile.
    """,
    'author': 'ADINANI Nacer-Dine',
    'website': 'https://www.hurimoney.com',
    'depends': [
        'base',
        'mail',
        'contacts',
    ],
    'data': [
        # Security
        'security/hurimoney_security.xml',
        'security/ir.model.access.csv',
        
        # Data
        'data/sequence_data.xml',
        
        # Views (ordre important)
        'views/concessionnaire_views.xml',
        'views/kit_views.xml',
        'views/transaction_views.xml',
        'views/menu_views.xml',
        
        # Wizards
        'wizards/import_wizard_views.xml',
    ],
    'demo': [],
    'installable': True,
    'application': True,
    'auto_install': False,
    'license': 'LGPL-3',
    'assets': {},
}