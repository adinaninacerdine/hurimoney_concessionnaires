# -*- coding: utf-8 -*-
from odoo.tests import TransactionCase

class TestTransaction(TransactionCase):
    
    def setUp(self):
        super().setUp()
        
        # Créer les données de test
        self.partner = self.env['res.partner'].create({
            'name': 'Test Partner',
            'phone': '+269 123 45 67',
        })
        
        self.concessionnaire = self.env['hurimoney.concessionnaire'].create({
            'partner_id': self.partner.id,
            'name': 'Test Concessionnaire',
            'phone': '+269 123 45 67',
            'zone': 'moroni',
            'state': 'active',
        })
    
    def test_01_commission_calculation(self):
        """Test le calcul des commissions"""
        transaction = self.env['hurimoney.transaction'].create({
            'concessionnaire_id': self.concessionnaire.id,
            'transaction_type': 'deposit',
            'amount': 100000,
            'commission_rate': 2.5,
        })
        
        self.assertEqual(transaction.commission, 2500)
    
    def test_02_transaction_workflow(self):
        """Test le workflow des transactions"""
        transaction = self.env['hurimoney.transaction'].create({
            'concessionnaire_id': self.concessionnaire.id,
            'transaction_type': 'withdrawal',
            'amount': 50000,
        })
        
        # État initial
        self.assertEqual(transaction.state, 'draft')
        
        # Confirmer
        transaction.action_confirm()
        self.assertEqual(transaction.state, 'pending')
        
        # Valider
        transaction.action_done()
        self.assertEqual(transaction.state, 'done')
    
    def test_03_metrics_update(self):
        """Test la mise à jour des métriques du concessionnaire"""
        # Créer plusieurs transactions
        for i in range(3):
            trans = self.env['hurimoney.transaction'].create({
                'concessionnaire_id': self.concessionnaire.id,
                'transaction_type': 'deposit',
                'amount': 20000,
                'state': 'done',
            })
        
        # Vérifier les métriques
        self.concessionnaire._compute_metrics()
        self.assertEqual(self.concessionnaire.total_transactions, 3)
        self.assertEqual(self.concessionnaire.total_volume, 60000)