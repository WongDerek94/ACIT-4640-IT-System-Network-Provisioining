#!/bin/bash -x

# Constants
USER_APP_USER="todoapp"
USER_APP_PASS="P@ssw0rd"
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

echo "Starting Installation Script"

# Install required packages
sudo yum install git -y

sudo curl -sL https://rpm.nodesource.com/setup_13.x | sudo bash -
sudo yum install nodejs -y

sudo cp ./mongodb-org-4.2.repo /etc/yum.repos.d/mongodb-org-4.2.repo
sudo yum install -y mongodb-org -y
sudo systemctl enable mongod && sudo systemctl start mongod

sudo yum install yum-utils -y
sudo cp ./nginx.repo /etc/yum.repos.d/nginx.repo
sudo yum install nginx -y

# Creates user 'todoapp'
sudo useradd -m -r "${USER_APP_USER}"
sudo usermod --password $(openssl passwd -1 "${USER_APP_PASS}") "${USER_APP_USER}"

# Retrieve application code
sudo git clone ${APPLICATION_GITHUB_LINK} "${USER_APP_HOME_DIR}/app"

# Additional configurations needed to start application as a service (i.e, install NodeJS dependencies)
sudo cp ~/setup/database.js "${USER_APP_HOME_DIR}/app/config/database.js"
sudo chown todoapp -R "${USER_APP_HOME_DIR}/app"
sudo chmod -R 755 "${USER_APP_HOME_DIR}"
# cd "${USER_APP_HOME_DIR}/app" && npm install -y
sudo su - todoapp -c "cd "${USER_APP_HOME_DIR}/app" && npm install -y"
sudo cp ~/setup/todoapp.service /etc/systemd/system/todoapp.service
sudo systemctl daemon-reload && sudo systemctl enable todoapp && sudo systemctl start todoapp

# Set up web server to serve static files
sudo cp ~/setup/nginx.conf /etc/nginx/nginx.conf
sudo systemctl enable nginx && sudo systemctl start nginx

# Check if services are running
sudo systemctl status mongod
check_service_status mongod

sudo systemctl status nginx
check_service_status nginx

sudo systemctl status todoapp
check_service_status todoapp

if [ ${NUM_SERVICES_RUNNING} -eq 3 ]; then
  echo "\nApplication is now set-up and running!"
  exit 0
else 
  echo "One or more services failed to start"
  exit 1
fi
