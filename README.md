# Module HuriMoney Concessionnaires pour Odoo 18

## Description

Ce module permet de gérer les concessionnaires HuriMoney, leurs kits, transactions et performances.

## Fonctionnalités

- **Gestion des concessionnaires** : Création, modification, activation/suspension
- **Suivi des kits** : Distribution et état des téléphones et kits
- **Enregistrement des transactions** : Dépôts, retraits, transferts, paiements
- **Dashboard** : Vue d'ensemble des KPIs et performances
- **API REST** : Intégration avec systèmes externes
- **Synchronisation WAKATI** : Import automatique des données
- **Géolocalisation** : Carte des concessionnaires
- **Import CSV** : Import en masse des données

## Installation

1. Copier le dossier `hurimoney_concessionnaires` dans le répertoire des addons d'Odoo
2. Mettre à jour la liste des applications
3. Installer le module "HuriMoney Concessionnaires"

## Configuration

### API WAKATI

1. Aller dans HuriMoney > Configuration > API WAKATI
2. Renseigner l'URL de base, la clé API et le secret
3. Activer la synchronisation automatique si souhaité

### Droits d'accès

Trois groupes sont disponibles :
- **Utilisateur** : Accès à ses propres concessionnaires
- **Manager** : Accès à tous les concessionnaires
- **Administrateur** : Configuration complète

## Utilisation

### Import de données

1. Aller dans HuriMoney > Configuration > Import de données
2. Sélectionner le type d'import (Concessionnaires, Transactions, Kits)
3. Charger le fichier CSV avec le bon format
4. Cliquer sur "Importer"

### API REST

#### Authentification

Utiliser une clé API Odoo pour l'authentification.

#### Endpoints

- `GET /api/hurimoney/concessionnaires` : Liste des concessionnaires
- `POST /api/hurimoney/transactions` : Créer une transaction

## Format des fichiers CSV

### Concessionnaires

```csv
name,phone,email,street,city,zone,agent_email
Ali Mohamed,+269 321 12 34,ali@example.km,Rue du Commerce,Moroni,moroni,agent@hurimoney.km