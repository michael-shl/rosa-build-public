#!/usr/bin/bash

############################################################################
#                     Shell Script - Create ROSA Cluster                   #
#                     ==================================                   #
#                                                                          #
# Program Name: create-rosa-cluster.sh                                     #
#                                                                          #
# Author: Michael (Shihao) Li                                              #
#                                                                          #
# October 25, 2021                                                         #
############################################################################

#
## Defines Variables.
#

BINDIR='/usr/local/bin'
ROSA_VERSION='1.1.5'
ROSA_SERVICE_URL='https://console.aws.amazon.com/rosa/home'
ROSA_DOWNLOAD_URL="https://github.com/openshift/rosa/releases/download/v${ROSA_VERSION}/rosa-linux-amd64"
TOKEN_URL='https://console.redhat.com/openshift/token/rosa/show'

#
## Function - Validate the number of arguments
#

verify_argus()
{
num_argus=$1
num_argus_defined=$2
cluster_name=$3

if [ ${num_argus} -ne ${num_argus_defined} ]
then
  echo -e "\nError: Illegal number of parameters or wrong parameter!"
  display_usage
  exit 1
fi
}

#
## Functioin - Display usage mssage of this script
#

display_usage()
{
cat <<EOF

Usage:

  $0 <cluster_name>        # Create Your Cluster 
  $0 -h|--help|--usage     # Display Usage

Example:
  $0 mycluster
  $0 my-cluster

Arguments:
  <cluster_name>  Cluster name must consist of no more than 15 lowercase alphanumeric characters or '-', start with a letter, and end with an alphanumeric character.

EOF
}

#
## Function - Initialize the variable, ROSA_TOKEN
#

generate_rosa_token()
{
  xdg-open ${TOKEN_URL}
  echo "Please log in the pop-up page with your RedHat account if you have not logged in yet"
  read -sp 'Copy "You API token" and past it here: ' ROSA_TOKEN
  echo
  echo "You API token has been generated and saved with the variable, ROSA_TOKEN"
}

#
## Check argument options to print out help menu or continue the rest of steps.
#

case $1 in
  -h|--help|--usage)
     if [ $# -ne 1 ]
     then
       echo -e "\nError: Illegal number of parameters or wrong parameter!"
     fi
     display_usage
     exit
     ;;
  *)
    verify_argus $# 1 $1
    ;;
esac

#
## Set up the installation path for the packages, rosa, oc
#

if [ ! -d ${BINDIR} ]
then
  sudo mkdir -p ${BINDIR}
  sudo chmod 755 ${BINDIR}
  echo "The directory, ${BINDIR}, has been created"
fi

if [[ "${PATH}" != *"${BINDIR}"* ]]
then
  echo "PATH=${BINDIR}:\$PATH" >> ~/.profile
  source ~/.profile
  echo "The directory, ${BINDIR}, has been added the PATH variable"
fi

#
## Install or Updating the rosa CLI
#

which rosa >> /dev/null
if [[ $? > 0 ]]
then
  echo "Installing ROSA CLI..."
  wget -O ~/rosa ${ROSA_DOWNLOAD_URL}
  sudo mv ~/rosa ${BINDIR}
  sudo chmod u+x ${BINDIR}/rosa
  echo "ROSA CLI has been installed"
elif [[ $(rosa version) != ${ROSA_VERSION} ]]
then
  echo "Updating ROSA CLI..."
  wget -O ~/rosa ${ROSA_DOWNLOAD_URL}
  sudo mv -f ~/rosa ${BINDIR}
  sudo chmod u+x ${BINDIR}/rosa
  echo "ROSA CLI has been updated"
fi

#
## Configure your Bash shell to load rosa completions
#

if [ -f ~/.bashrc ]; then
  grep '. <(rosa completion)' ~/.bashrc > /dev/null
  if [[ $? > 0 ]]; then
    echo '. <(rosa completion)' >> ~/.bashrc
    source ~/.bashrc
    echo "rosa completion has been configured"
  fi
fi

#
## Ensure xdg-open installed
#

which xdg-open > /dev/null
if [[ $? > 0 ]]; then
  echo "Installing xdg-utils..."
  sudo apt install xdg-utils -y
  echo "rosa has been installed"
fi

#
## Enable ROSA service in AWS Console
#

while true; do
  read -p "Have you enabled the Red Hat OpenShift Service in the AWS Management Console? (y/n): " yn
  case $yn in
      [Nn]* )
        xdg-open ${ROSA_SERVICE_URL}
        echo "Please log in the pop-up page with your AWS account if you have not logged in yet"
        echo 'Please select "Enable OpenShift" to enable ROSA service on the AWS console'
        if [[ $yn =~ ^([yY][eE][sS]|[yY])$ ]]
        then
          break
        fi
        ;;
      [Yy]* )
        break
        ;;
      * )
        read -p "Have you enabled the Red Hat OpenShift Service in the AWS Management Console? (y/n): " yn
        ;;
  esac
done

## Verify that your AWS account has the necessary permissions
#

echo "Verify that your AWS account has the necessary permissions..."
rosa verify permissions

#
## Configure the ROSA_TOKEN variable if it is not configured as an evironment variable
#

if [ -z ${ROSA_TOKEN} ]
then
  generate_rosa_token
fi

#
## Log in to your Red Hat account
#

rosa login --token=${ROSA_TOKEN}
if [[ $? > 0 ]] 
then
  generate_rosa_token
  rosa login --token=$(echo ${ROSA_TOKEN})
  if [[ $? > 0 ]] 
  then
    echo "Error! ROSA Login failed."
    echo "Please verify your ROSA TOKEN."
    exit
  fi
fi

#
## Check and Install OpenShift Container Platform CLI (oc)
#

which oc >> /dev/null
if [[ $? > 0 ]]
then
  echo "Installing OCP CLI..."
  rosa download oc
  sudo tar -xf openshift-client-linux.tar.gz -C ${BINDIR}
  rosa verify oc
  if [[ $? == 0 ]] && [ -f openshift-client-linux.tar.gz ]
  then
    rm -f openshift-client-linux.tar.gz
    echo "ROSA CLI has been installed"
  fi
fi

#
## Display information about your AWS and Red Hat accounts
#

echo  "running rosa whoami..."
rosa whoami

#
## Initialize your AWS account
#

echo  "running rosa init..."
rosa init

#
## Create ROSA cluster
#

while true; do
  read -p "Do you want to create a cluster using interactive prompts? (y/n): " yn
  case $yn in
      [Nn]* )
        read -p "Do you want to create a cluster, $1, with the default settings? (y/n): " DEFAULT_SETTINGS
        if [[ ${DEFAULT_SETTINGS} =~ ^([yY][eE][sS]|[yY])$ ]]
        then
          rosa create cluster --cluster-name=$1 --watch
        fi
        ;;
      [Yy]* )
        rosa create cluster --cluster-name=$1 --interactive --watch
        ;;
      * )
        read -p "Do you want to create a cluster using interactive prompts? (y/n): " yn
        ;;
  esac
done