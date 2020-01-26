#!/bin/bash

# Constants
APP_USER="todoapp"
APP_USER_PASS="P@ssw0rd"
APP_USER_HOME_DIR="/home/todoapp"
SETUP_DIR="/home/admin/setup"
APPLICATION_GITHUB_LINK="https://github.com/timoguic/ACIT4640-todo-app.git"
NGINX_CONFIG_TEMPLATE="${SETUP_DIR}/nginx.conf"
DATABASE_JS_TEMPLATE="${SETUP_DIR}/database.js"
SERVICE_TEMPLATATE="${SETUP_DIR}/todoapp.service"

# Check status of service running, pass in name of service
NUM_SERVICES_RUNNING=0
function check_service_status () { 
  if [ $? -eq 0 ]; then
    echo "$1 running"
    NUM_SERVICES_RUNNING=$(( $NUM_SERVICES_RUNNING + 1))
  else
    echo "$1 service is not running"
fi
}

# This script will be run within the virtual machine to:
# ... install the required packages to run the application
# ... creates the user to run the application
# ... retrieves the application code
# ... start all services


# Install required packages
install_packages () {
    yum update
    curl -sL https://rpm.nodesource.com/setup_13.x | bash -

    cp ./mongodb-org-4.2.repo /etc/yum.repos.d/mongodb-org-4.2.repo
    cp ./nginx.repo /etc/yum.repos.d/nginx.repo
    
    yum install git nodejs mongodb-org nginx yum-utils -y
    cp "${NGINX_CONFIG_TEMPLATE}" /etc/nginx/nginx.conf
}

# Creates user 'todoapp'
create_user () {
    userdel -r "${APP_USER}" 2>/dev/null
    useradd -m -r "${APP_USER}"
    usermod --password $(openssl passwd -1 "${APP_USER_PASS}") "${APP_USER}"
}

# Retrieve application code and configure to start application as a service (i.e, install NodeJS dependencies)
install_application () {
    git clone ${APPLICATION_GITHUB_LINK} "${APP_USER_HOME_DIR}/app"
    cp "${DATABASE_JS_TEMPLATE}" "${APP_USER_HOME_DIR}/app/config/database.js"
    chown "${APP_USER}" -R "${APP_USER_HOME_DIR}/app"
    chmod -R 755 "${APP_USER_HOME_DIR}"
    su - "${APP_USER}" -c "cd "${APP_USER_HOME_DIR}/app" && npm install -y"
    cp "${SERVICE_TEMPLATATE}" /etc/systemd/system/todoapp.service
}

# Set up web server to serve static files
enable_and_start_services () {
    systemctl enable mongod && systemctl start mongod
    systemctl daemon-reload && systemctl enable "${APP_USER}" && systemctl start "${APP_USER}"
    systemctl enable nginx && systemctl start nginx
}

echo "Starting Installation Script"

install_packages
create_user
install_application
enable_and_start_services

# Check if services are running
sudo systemctl status mongod
check_service_status mongod

sudo systemctl status nginx
check_service_status nginx

sudo systemctl status "${APP_USER}"
check_service_status "${APP_USER}"

if [ ${NUM_SERVICES_RUNNING} -eq 3 ]; then
  echo "Application is now set-up and running!"
  exit 0
else 
  echo "One or more services failed to start"
  exit 1
fi
