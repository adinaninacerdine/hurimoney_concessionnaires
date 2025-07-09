#!/bin/bash

# Update and install dependencies
apt-get update
apt-get upgrade -y
apt-get install -y git python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libjpeg-dev libpq-dev libffi-dev

# Install pandas dependencies
apt-get install -y gfortran libopenblas-dev liblapack-dev

# Install wkhtmltopdf
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb
dpkg -i wkhtmltox_0.12.6.1-2.bullseye_amd64.deb
apt-get -f install -y

# Install PostgreSQL
apt-get install -y postgresql
su - postgres -c "createuser -s odoo"

# Create Odoo user
useradd -m -d /opt/odoo -U -r -s /bin/bash odoo

# Install Odoo
su - odoo -c "git clone https://www.github.com/odoo/odoo --depth 1 --branch 18.0 /opt/odoo/odoo"
su - odoo -c "python3 -m venv /opt/odoo/venv"
/opt/odoo/venv/bin/pip install -r /opt/odoo/odoo/requirements.txt
/opt/odoo/venv/bin/pip install pandas

# Create custom addons folder
su - odoo -c "mkdir /opt/odoo/extra-addons"

# Copy your module
mkdir -p /opt/odoo/extra-addons/hurimoney_concessionnaires
cp -r ./* /opt/odoo/extra-addons/hurimoney_concessionnaires/
chown -R odoo:odoo /opt/odoo/extra-addons/

# Create Odoo config file
cat <<EOF > /etc/odoo.conf
[options]
; This is the password that allows database operations:
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = /opt/odoo/odoo/addons,/opt/odoo/extra-addons
EOF

# Create systemd service file
cat <<EOF > /etc/systemd/system/odoo.service
[Unit]
Description=Odoo

[Service]
Type=simple
User=odoo
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo.conf

[Install]
WantedBy=multi-user.target
EOF

# Start Odoo service
systemctl daemon-reload
systemctl enable --now odoo.service
