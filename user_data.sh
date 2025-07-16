#!/bin/bash
set -x

# Exit immediately if a command exits with a non-zero status.
set -e

LOG_FILE="/var/log/odoo_install.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "🚀 Starting Odoo 18.0 installation based on official documentation..."

# Update system
echo "📦 Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install required packages
echo "📦 Installing system dependencies..."
apt-get install -y \
    git \
    python3-pip \
    python3-dev \
    python3-venv \
    python3-wheel \
    python3-setuptools \
    build-essential \
    wget \
    curl \
    libxslt-dev \
    libzip-dev \
    libldap2-dev \
    libsasl2-dev \
    libjpeg-dev \
    libpq-dev \
    libffi-dev \
    pkg-config \
    gfortran \
    libopenblas-dev \
    liblapack-dev \
    libblas-dev \
    libatlas-base-dev \
    python3-numpy \
    python3-scipy \
    libevent-dev \
    libssl-dev \
    xfonts-base \
    xfonts-75dpi \
    fontconfig \
    postgresql-client 
    unzip

# Install wkhtmltopdf 0.12.6
echo "📄 Installing wkhtmltopdf 0.12.6..."
apt-get install -y libxrender1 # Ensure this dependency is met

if [ ! -f /usr/local/bin/wkhtmltopdf ]; then
    wget -q https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
    dpkg -i wkhtmltox_0.12.6.1-3.jammy_amd64.deb || apt-get -f install -y # Use apt-get -f install to fix broken dependencies
    rm -f wkhtmltox_0.12.6.1-3.jammy_amd64.deb
fi

# Create odoo user
echo "👤 Creating Odoo system user..."
adduser --system --home=/opt/odoo --group odoo || echo "User 'odoo' already exists."

# Clone Odoo
echo "📥 Cloning Odoo 18.0 repository..."
ODOO_ZIP_URL="https://github.com/odoo/odoo/archive/refs/heads/18.0.zip"
ODOO_DIR="/opt/odoo/odoo"
ODOO_ZIP="odoo-18.0.zip"

echo "📥 Downloading Odoo 18.0 source as ZIP archive..."
wget -q $ODOO_ZIP_URL -O $ODOO_ZIP

echo "📦 Unzipping Odoo source..."
mkdir -p $ODOO_DIR
unzip -q $ODOO_ZIP -d /opt/odoo
mv /opt/odoo/odoo-18.0 $ODOO_DIR
rm $ODOO_ZIP

chown -R odoo:odoo $ODOO_DIR

# Verify Odoo source existence and odoo-bin
if [ ! -d "$ODOO_DIR" ] || [ ! -f "$ODOO_DIR/odoo-bin" ]; then
    echo "Error: Odoo source download or extraction failed, or odoo-bin is missing. Aborting."
    exit 1
fi

# Create virtual environment and install dependencies
echo "🐍 Creating Python virtual environment and installing dependencies..."
sudo -u odoo python3 -m venv /opt/odoo/venv
sudo -u odoo /opt/odoo/venv/bin/pip install --upgrade pip setuptools wheel

# Install Odoo requirements
echo "📦 Installing specific versions of gevent and greenlet to avoid compilation issues..."
sudo -u odoo /opt/odoo/venv/bin/pip install gevent==21.8.0 greenlet==1.1.2 --no-build-isolation

echo "📦 Installing remaining Odoo Python requirements from requirements.txt (ignoring gevent and greenlet)..."
sudo -u odoo /opt/odoo/venv/bin/pip install -r /opt/odoo/odoo/requirements.txt --ignore-installed gevent greenlet

# Add a short delay after cloning to allow system to settle
sleep 10

# Create custom addons directory
echo "📁 Creating custom addons directory..."
mkdir -p /opt/odoo/custom-addons
chown -R odoo:odoo /opt/odoo/custom-addons

# Create log directory
echo "📁 Creating log directory..."
mkdir -p /var/log/odoo
chown odoo:odoo /var/log/odoo

# Configure odoo.conf for RDS connection
echo "⚙️ Configuring odoo.conf for RDS connection..."
cat > /etc/odoo.conf <<EOF
[options]
admin_passwd = admin123
db_host = ${db_host}
db_port = 5432
db_user = ${db_user}
db_password = ${db_password}
addons_path = /opt/odoo/odoo/addons,/opt/odoo/custom-addons
logfile = /var/log/odoo/odoo.log
log_level = info
workers = 2
xmlrpc_port = 8069
longpolling_port = 8072

# Odoo 18 security configuration
proxy_mode = False
list_db = True
db_template = template0
db_maxconn = 64
db_sslmode = require

# Geolocation configuration
# geoip_database = /usr/share/GeoIP/GeoLite2-City.mmdb # Commented out as GeoIP installation is not in this script

# Performance Odoo 18
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200
max_cron_threads = 1
unaccent = True
EOF

chown odoo:odoo /etc/odoo.conf
chmod 640 /etc/odoo.conf

# Create systemd service file
echo "🔧 Creating systemd service file for Odoo..."
cat > /etc/systemd/system/odoo.service <<EOF
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo.conf
StandardOutput=journal+console
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Odoo service
echo "🔄 Enabling and starting Odoo service..."
systemctl daemon-reload
systemctl enable odoo
systemctl start odoo

echo "🎉 Odoo installation script finished. Please create the database manually via the web interface."
echo "Odoo URL: http://$(curl -s ifconfig.me):8069"
