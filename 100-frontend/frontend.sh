#!/bin/bash 

# script should on backend server 
# Now the scriptis in local, we should copy it 
# Copy the script from local to backend server by using terraform 
# we can copy by using file provisioners 

component=$1 
environment=$2
echo "Component: $component, Environment: $environment"
dnf install ansible -y 
ansible-pull -i localhost, -U https://github.com/lakshmimungara/expense-ansible-roles-tf.git main.yaml -e component=$component -e environment=$environment




