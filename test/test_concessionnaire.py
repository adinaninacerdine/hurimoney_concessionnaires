# -*- coding: utf-8 -*-
from odoo.tests import TransactionCase
from odoo.exceptions import ValidationError

class TestConcessionnaire(TransactionCase):
    
    def setUp(self):
        super().setUp()
        
        # Créer un partenaire test
        self.partner = self.env['res.partner'].create({
            'name': 'Test Partner',
            'phone': '+269 123 45 67',
            'email': 'test@example.km',
        })
        
        # Créer un concessionnaire test
        self.concessionnaire = self.env['hurimoney.concessionnaire'].create({
            'partner_id': self.partner.id,
            'name': 'Test Concessionnaire',
            'phone': '+269 123 45 67',
            'zone': 'moroni',
            'state': 'draft',
        })
    
    def test_01_activation(self):
        """Test l'activation d'un concessionnaire"""
        self.assertEqual(self.concessionnaire.state, 'draft')
        
        # Activer
        self.concessionnaire.action_activate()
        self.assertEqual(self.concessionnaire.state, 'active')
        self.assertTrue(self.concessionnaire.activation_date)
    
    def test_02_suspension(self):
        """Test la suspension d'un concessionnaire"""
        # Activer d'abord
        self.concessionnaire.action_activate()
        
        # Suspendre
        self.concessionnaire.action_suspend()
        self.assertEqual(self.concessionnaire.state, 'suspended')
        self.assertTrue(self.concessionnaire.suspension_date)
    
    def test_03_coordinates_validation(self):
        """Test la validation des coordonnées GPS"""
        # Latitude invalide
        with self.assertRaises(ValidationError):
            self.concessionnaire.latitude = 91
        
        # Longitude invalide
        with self.assertRaises(ValidationError):
            self.concessionnaire.longitude = 181
        
        # Coordonnées valides
        self.concessionnaire.write({
            'latitude': -11.7172,
            'longitude': 43.2473,
        })
        self.assertEqual(self.concessionnaire.latitude, -11.7172)
    
    def test_04_unique_partner(self):
        """Test l'unicité du partenaire"""
        # Essayer de créer un autre concessionnaire avec le même partenaire
        with self.assertRaises(ValidationError):
            self.env['hurimoney.concessionnaire'].create({
                'partner_id': self.partner.id,
                'name': 'Autre Concessionnaire',
                'phone': '+269 987 65 43',
                'zone': 'moroni',
            })
    
    def test_05_performance_score(self):
        """Test le calcul du score de performance"""
        # Créer des transactions
        for i in range(5):
            self.env['hurimoney.transaction'].create({
                'concessionnaire_id': self.concessionnaire.id,
                'transaction_type': 'deposit',
                'amount': 10000 * (i + 1),
                'state': 'done',
            })
        
        # Activer et recalculer
        self.concessionnaire.action_activate()
        self.concessionnaire._compute_performance_score()
        
        self.assertGreater(self.concessionnaire.performance_score, 0)
        self.assertLessEqual(self.concessionnaire.performance_score, 100)