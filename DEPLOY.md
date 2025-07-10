# 🚀 Déploiement Odoo 18 sur AWS avec Terraform

## 📋 Prérequis

### 1. Outils nécessaires
```bash
# Installer Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Installer AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
```

### 2. Configuration AWS
```bash
# Configurer AWS CLI
aws configure
# AWS Access Key ID: VOTRE_ACCESS_KEY
# AWS Secret Access Key: VOTRE_SECRET_KEY
# Default region name: us-east-1
# Default output format: json

# Créer une paire de clés SSH
aws ec2 create-key-pair --key-name odoo-key --query 'KeyMaterial' --output text > ~/.ssh/odoo-key.pem
chmod 400 ~/.ssh/odoo-key.pem
```

## 🎯 Déploiement

### 1. Initialisation Terraform
```bash
# Cloner le repo
git clone https://github.com/adinaninacerdine/hurimoney_concessionnaires.git
cd hurimoney_concessionnaires

# Initialiser Terraform
terraform init
```

### 2. Configuration des variables
```bash
# Créer terraform.tfvars
cat > terraform.tfvars << EOF
aws_region = "us-east-1"
instance_type = "t3.small"
ssh_key_name = "odoo-key"
allowed_ssh_cidr = "YOUR_IP/32"  # Remplacer par votre IP
EOF
```

### 3. Déploiement
```bash
# Valider la configuration
terraform validate

# Planifier le déploiement
terraform plan

# Appliquer (⚠️ Coûts AWS)
terraform apply
```

### 4. Récupération des informations
```bash
# Afficher les outputs
terraform output

# Exemple de sortie:
# odoo_url = "http://1.2.3.4:8069"
# webhook_url = "http://1.2.3.4:9000/deploy"
# ssh_command = "ssh -i ~/.ssh/odoo-key.pem ubuntu@1.2.3.4"
```

## 🔧 Configuration post-déploiement

### 1. Vérifier l'installation
```bash
# Se connecter via SSH
ssh -i ~/.ssh/odoo-key.pem ubuntu@YOUR_SERVER_IP

# Vérifier les services
sudo systemctl status odoo
sudo systemctl status odoo-webhook

# Vérifier les logs
sudo journalctl -u odoo -f
```

### 2. Accéder à Odoo
1. Ouvrir `http://YOUR_SERVER_IP:8069`
2. Créer une base de données
3. Installer le module `hurimoney_concessionnaires`

## 🔄 Mise à jour automatique des modules

### 1. Configuration GitHub Webhook
1. Aller dans GitHub > Settings > Webhooks
2. Ajouter webhook:
   - URL: `http://YOUR_SERVER_IP:9000/deploy`
   - Content type: `application/json`
   - Events: `push`

### 2. Déploiement manuel
```bash
# Se connecter au serveur
ssh -i ~/.ssh/odoo-key.pem ubuntu@YOUR_SERVER_IP

# Déployer manuellement
sudo /opt/odoo/deploy_module.sh
```

## 🐛 Résolution des problèmes

### Problème pandas
```bash
# Si pandas ne s'installe pas
sudo apt-get install python3-numpy python3-scipy
/opt/odoo/venv/bin/pip install pandas --no-deps
```

### Problème mémoire
```bash
# Augmenter la taille d'instance
# Dans terraform.tfvars:
instance_type = "t3.medium"  # Au lieu de t3.small
```

### Problème de permissions
```bash
# Corriger les permissions
sudo chown -R odoo:odoo /opt/odoo/
sudo systemctl restart odoo
```

## 📊 Monitoring

### Logs système
```bash
# Logs Odoo
sudo journalctl -u odoo -f

# Logs webhook
sudo journalctl -u odoo-webhook -f

# Logs système
sudo tail -f /var/log/syslog
```

### Métriques système
```bash
# Utilisation CPU/RAM
htop

# Espace disque
df -h

# Processus Odoo
ps aux | grep odoo
```

## 🚨 Sauvegarde

### Sauvegarde base de données
```bash
# Backup automatique
sudo -u postgres pg_dump odoo_db > backup_$(date +%Y%m%d).sql

# Restauration
sudo -u postgres psql -c "CREATE DATABASE odoo_db_restore;"
sudo -u postgres psql odoo_db_restore < backup_20231201.sql
```

### Sauvegarde modules
```bash
# Backup modules
tar -czf modules_backup_$(date +%Y%m%d).tar.gz /opt/odoo/extra-addons/
```

## 🛡️ Sécurité Production

### 1. HTTPS avec Let's Encrypt
```bash
# Installer Certbot
sudo apt install certbot python3-certbot-nginx

# Configurer Nginx
sudo apt install nginx
sudo certbot --nginx -d yourdomain.com
```

### 2. Firewall
```bash
# Configurer UFW
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 3. Base de données externe
```bash
# Utiliser RDS en production
# Modifier /etc/odoo.conf:
# db_host = your-rds-endpoint.amazonaws.com
# db_user = odoo
# db_password = your-secure-password
```

## 💰 Coûts estimés

### AWS (par mois)
- EC2 t3.small: ~$15/mois
- EBS 20GB: ~$2/mois  
- Trafic: ~$1-5/mois
- **Total: ~$20-25/mois**

### Production (recommandé)
- EC2 t3.medium: ~$30/mois
- RDS db.t3.micro: ~$15/mois
- ELB: ~$18/mois
- **Total: ~$65-80/mois**

## 🎯 Prochaines étapes

1. **SSL/HTTPS** avec certificat Let's Encrypt
2. **Base de données RDS** pour la production
3. **Load Balancer** pour haute disponibilité
4. **Auto Scaling** pour gérer la charge
5. **Monitoring** avec CloudWatch
6. **Backup automatique** S3

## 📞 Support

En cas de problème:
1. Vérifier les logs: `sudo journalctl -u odoo -f`
2. Redémarrer les services: `sudo systemctl restart odoo`
3. Vérifier les permissions: `sudo chown -R odoo:odoo /opt/odoo/`

---

✅ **Déploiement testé et validé** - Prêt pour la production !