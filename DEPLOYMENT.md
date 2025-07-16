# 🚀 Guide de Déploiement HuriMoney

## 📋 Stratégie de Versioning

### Structure des Branches
```
v1.0.0 (tag)          ← Version stable déployée
├── release/v1.0.0     ← Branche de release
├── develop            ← Développement actuel
└── main              ← Branche principale (sera mise à jour)
```

### Versions Disponibles
- **v1.0.0** : Version stable avec infrastructure B2C complète
  - ✅ Menus complets (Tableau de bord, Opérations, Rapports, Configuration)
  - ✅ Infrastructure B2C (Kinesis + DynamoDB + Lambda)
  - ✅ Intégration Kinesis dans les transactions
  - ✅ Toutes les vues fonctionnelles

## 🔧 Déploiement sur Serveur

### 1. Déploiement par Tag (RECOMMANDÉ)
```bash
# Sur le serveur
cd /opt/odoo/custom-addons/hurimoney_concessionnaires
git fetch --tags
git checkout v1.0.0
sudo chown -R odoo:odoo .
sudo pkill -f "odoo-bin"
sudo -u odoo /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf -d hurimoney_prod --init=hurimoney_concessionnaires --stop-after-init
sudo -u odoo /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf &
```

### 2. Vérification du Déploiement
```bash
# Vérifier la version déployée
git describe --tags

# Vérifier qu'Odoo fonctionne
ps aux | grep odoo
curl -I http://localhost:8069
```

### 3. Rollback si Nécessaire
```bash
# Revenir à la version précédente
git checkout v1.0.0  # ou version précédente
# Redémarrer Odoo
```

## 📈 Workflow de Développement

### Pour les Nouvelles Fonctionnalités
```bash
# Créer une branche depuis develop
git checkout develop
git pull origin develop
git checkout -b feature/nouvelle-fonctionnalite

# Développer et tester
# ...

# Fusionner dans develop
git checkout develop
git merge feature/nouvelle-fonctionnalite
git push origin develop
```

### Pour les Corrections Urgentes
```bash
# Créer une branche hotfix depuis la release
git checkout release/v1.0.0
git checkout -b hotfix/correction-urgente

# Corriger et tester
# ...

# Fusionner dans release et develop
git checkout release/v1.0.0
git merge hotfix/correction-urgente
git tag -a v1.0.1 -m "Correction urgente"
git push origin release/v1.0.0 v1.0.1
```

### Pour les Releases
```bash
# Créer une nouvelle release depuis develop
git checkout develop
git checkout -b release/v1.1.0

# Tests finaux et ajustements
# ...

# Taguer la nouvelle version
git tag -a v1.1.0 -m "Version 1.1.0 - Nouvelles fonctionnalités"
git push origin release/v1.1.0 v1.1.0
```

## 📊 Fonctionnalités v1.0.0

### Menus Disponibles
- **🎯 Tableau de bord** : Vue pivot des concessionnaires
- **📊 Opérations** : 
  - Concessionnaires (gestion complète)
  - Transactions (avec intégration Kinesis)
  - Kits (matériel)
- **📈 Rapports** :
  - Performance (graphiques)
  - Analyse des transactions (pivot)
- **⚙️ Configuration** :
  - Paramètres système
  - Import de données

### Infrastructure B2C
- **AWS Kinesis** : Stream des transactions
- **DynamoDB** : Stockage des données clients
- **Lambda** : Traitement des transactions
- **Intégration automatique** : Toutes les transactions sont envoyées vers Kinesis

## 🆘 Résolution de Problèmes

### Les Menus ne s'Affichent Pas
```bash
# Forcer la réinstallation du module
sudo pkill -f "odoo-bin"
sudo -u odoo /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf -d hurimoney_prod --init=hurimoney_concessionnaires --stop-after-init
sudo -u odoo /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf &
```

### Erreur boto3
```bash
# Installer boto3 si nécessaire
sudo -H pip3 install boto3
```

### Permissions Git
```bash
# Corriger les permissions
sudo chown -R odoo:odoo /opt/odoo/custom-addons/hurimoney_concessionnaires
git config --global --add safe.directory /opt/odoo/custom-addons/hurimoney_concessionnaires
```

## 🎯 Prochaines Étapes

1. **v1.1.0** : Améliorations des fonctionnalités existantes
2. **v1.2.0** : Nouvelles fonctionnalités B2C
3. **v2.0.0** : Refonte majeure (si nécessaire)

---
**⚠️ IMPORTANT** : Toujours déployer par tag pour éviter les problèmes de cohérence !