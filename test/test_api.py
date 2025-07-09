# -*- coding: utf-8 -*-
import json
from odoo.tests import HttpCase

class TestAPI(HttpCase):
    
    def setUp(self):
        super().setUp()
        
        # Créer un concessionnaire test
        partner = self.env['res.partner'].create({
            'name': 'API Test Partner',
            'phone': '+269 999 88 77',
        })
        
        self.concessionnaire = self.env['hurimoney.concessionnaire'].create({
            'partner_id': partner.id,
            'name': 'API Test Concessionnaire',
            'phone': '+269 999 88 77',
            'code': 'API-TEST-001',
            'zone': 'moroni',
            'state': 'active',
        })
    
    def test_01_get_concessionnaires(self):
        """Test l'endpoint GET des concessionnaires"""
        response = self.url_open(
            '/api/hurimoney/concessionnaires',
            headers={'Content-Type': 'application/json'},
        )
        
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.text)
        self.assertTrue(data['success'])
        self.assertIsInstance(data['data'], list)
    
    def test_02_create_transaction(self):
        """Test l'endpoint POST des transactions"""
        payload = {
            'concessionnaire_code': 'API-TEST-001',
            'amount': 25000,
            'transaction_type': 'deposit',
            'external_id': 'EXT-123456',
        }
        
        response = self.url_open(
            '/api/hurimoney/transactions',
            data=json.dumps(payload),
            headers={'Content-Type': 'application/json'},
        )
        
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.text)
        self.assertTrue(data['success'])
        self.assertIn('data', data)