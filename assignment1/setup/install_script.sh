#!/bin/bash

# Constants
APP_USER="todoapp"
APP_USER_PASS="P@ssw0rd"
USER_APP_HOME_DIR="/home/todoapp"
APPLICATION_GITHUB_LINK="https://github.com/timoguic/ACIT4640-todo-app.git"

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
# ... set up web server to serve static files


# Install required packages
install_packages () {
    sudo yum install git -y

    sudo curl -sL https://rpm.nodesource.com/setup_13.x | sudo bash -
    sudo yum install nodejs -y

    sudo cp ./mongodb-org-4.2.repo /etc/yum.repos.d/mongodb-org-4.2.repo
    sudo yum install -y mongodb-org -y
    sudo systemctl enable mongod && sudo systemctl start mongod

    sudo yum install yum-utils -y
    sudo cp ./nginx.repo /etc/yum.repos.d/nginx.repo
    sudo yum install nginx -y
}

# Creates user 'todoapp'
create_user () {
    sudo useradd -m -r "${APP_USER}"
    sudo usermod --password $(openssl passwd -1 "${APP_USER_PASS}") "${APP_USER}"
}

# Retrieve application code and configure to start application as a service (i.e, install NodeJS dependencies)
install_application () {
    sudo git clone ${APPLICATION_GITHUB_LINK} "${USER_APP_HOME_DIR}/app"
    sudo cp ~/setup/database.js "${USER_APP_HOME_DIR}/app/config/database.js"
    sudo chown "${APP_USER}" -R "${USER_APP_HOME_DIR}/app"
    sudo chmod -R 755 "${USER_APP_HOME_DIR}"
    sudo su - "${APP_USER}" -c "cd "${USER_APP_HOME_DIR}/app" && npm install -y"
    sudo cp ~/setup/todoapp.service /etc/systemd/system/todoapp.service
    sudo systemctl daemon-reload && sudo systemctl enable "${APP_USER}" && sudo systemctl start "${APP_USER}"
}

# Set up web server to serve static files
setup_web_server () {
    sudo cp ~/setup/nginx.conf /etc/nginx/nginx.conf
    sudo systemctl enable nginx && sudo systemctl start nginx
}

echo "Starting Installation Script"

install_packages
create_user
install_application
setup_web_server

# Check if services are running
sudo systemctl status mongod
check_service_status mongod

sudo systemctl status nginx
check_service_status nginx

sudo systemctl status "${APP_USER}"
check_service_status "${APP_USER}"

if [ ${NUM_SERVICES_RUNNING} -eq 3 ]; then
  echo "\nApplication is now set-up and running!"
  exit 0
else 
  echo "One or more services failed to start"
  exit 1
fi
