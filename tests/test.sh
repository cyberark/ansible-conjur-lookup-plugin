#!/bin/bash -e

function finish {
  echo 'Removing test environment'
  echo '---'
  docker-compose down -v
}
trap finish EXIT
finish

# normalises project name by filtering non alphanumeric characters and transforming to lowercase
declare -x COMPOSE_PROJECT_NAME=$(echo ${BUILD_TAG:-"ansible-plugin-testing"} | sed -e 's/[^[:alnum:]]//g' | tr '[:upper:]' '[:lower:]')

declare -x CUSTOM_CONJUR_AUTHN_API_KEY=''
declare -x ANSIBLE_CONJUR_AUTHN_API_KEY=''
declare -x CUSTOM_CONJUR5_AUTHN_API_KEY=''
declare -x ANSIBLE_CONJUR5_AUTHN_API_KEY=''
declare -x CLI_CONJUR_AUTHN_API_KEY=''
declare -x CLI_CONJUR5_AUTHN_API_KEY=''
declare -x ANSIBLE_CONJUR_APPLIANCE_URL=''
declare -x ANSIBLE_CONJUR_CERT_FILE=''
declare -x ANSIBLE_CONJUR_VERSION=''
declare conjur5_cid=''
declare conjur_cid=''
declare cli5_cid=''
declare cli_cid=''

function hf_token {
  echo $(docker exec ${cli_cid} conjur hostfactory tokens create --duration-minutes=5 ansible/ansible-factory | jq -r '.[0].token')
}

function setup_conjur {
  echo "---- setting up conjur ----"
  local cid=$1
  docker exec ${cid} conjur policy load root /policy/root.yml

  docker exec ${cid} bash -c '
    conjur variable values add ansible/target-password target_secret_password
    conjur variable values add ansible/another-target-password another_target_secret_password
    conjur variable values add ansible/master-password ansible_master_secret_password
  '
}

function setup_conjur4 {
  echo "---- setting up conjur ----"
  local cid=$1

  docker exec ${cid} bash -c '
    cp /opt/conjur/etc/ssl/conjur.pem /root/conjur-cucumber.pem
    conjur authn login -u admin -p secret
  '

  docker exec ${cid} conjur policy load /policy/root.yml

  docker exec ${cid} bash -c '
    conjur variable values add ansible/target-password target_secret_password
    conjur variable values add ansible/another-target-password another_target_secret_password
    conjur variable values add ansible/master-password ansible_master_secret_password
  '
}

function run_test_cases {
  for test_case in `ls test_cases`; do
    run_test_case $test_case
  done
}

function run_test_case {
  echo "---- testing ${test_case} ----"
  local test_case=$1
  if [ ! -z "$test_case" ]
  then
    docker exec ${ansible_cid} env HFTOKEN=$(hf_token) bash -c "
      cd tests
      ansible-playbook test_cases/${test_case}/playbook.yml
    "
    docker exec ${ansible_cid} bash -c "
      cd tests
      py.test --junitxml=./junit/${test_case} --connection docker -v test_cases/${test_case}/tests/test_default.py
    "
  else
    echo ERROR: run_test called with no argument 1>&2
    exit 1
  fi
}

function wait_for_servers {
  docker exec ${cli5_cid} bash -c '
    echo -n "waiting for conjur 5 "
    for i in $(seq 20); do
      curl -o /dev/null -fs -X OPTIONS ${CONJUR_APPLIANCE_URL} > /dev/null && echo "ready" && break
      echo -n "."
      sleep 2
    done
  '
  docker exec ${conjur_cid} bash -c '
    echo -n "waiting for conjur 4 "
    for i in $(seq 20); do
      curl -o /dev/null -fs -X OPTIONS ${CONJUR_APPLIANCE_URL} > /dev/null && echo "ready" && break
      echo -n "."
      sleep 2
    done
  '
}

function fetch_ssl_certs {
  docker exec $(docker-compose ps -q conjur5_proxy) cat cert.crt > conjur5.pem
  docker exec $(docker-compose ps -q conjur) cat /opt/conjur/etc/ssl/conjur.pem > conjur.pem
}

function main() {
  docker-compose up -d --build

  conjur5_cid=$(docker-compose ps -q conjur5)
  conjur_cid=$(docker-compose ps -q conjur)
  cli5_cid=$(docker-compose ps -q conjur5_cli)

  echo "Fetching SSL certs"
  fetch_ssl_certs
  echo "Waiting for servers to come up"
  wait_for_servers

  echo "Fetching API credentials for v5"
  CLI_CONJUR5_AUTHN_API_KEY=$(docker exec ${conjur5_cid} conjurctl role retrieve-key cucumber:user:admin)

  echo "Reinitializing the conjur5 CLI with credentials"
  docker-compose up -d conjur5_cli
  cli5_cid=$(docker-compose ps -q conjur5_cli)

  echo "Configuring v5 via CLI"
  setup_conjur ${cli5_cid}

  echo "Fetching Ansible credentials for v5"
  CUSTOM_CONJUR_AUTHN_API_KEY=$(docker exec ${cli5_cid} conjur host rotate_api_key --host ansible/ansible-custom-target)
  ANSIBLE_CONJUR_AUTHN_API_KEY=$(docker exec ${cli5_cid} conjur host rotate_api_key --host ansible/ansible-master)
  ANSIBLE_CONJUR_APPLIANCE_URL='http://conjur5:3000'
  ANSIBLE_CONJUR_VERSION=5
  ANSIBLE_CONJUR_CERT_FILE='/conjurinc/tests/conjur5.pem'
  cli_cid=${cli5_cid}
  echo "Preparing Ansible for v5 test run"
  docker-compose up -d ansible
  ansible_cid=$(docker-compose ps -q ansible)
  echo "Running v5 tests"
  run_test_cases

  echo "Configuring v4 via CLI"
  setup_conjur4 ${conjur_cid}

  echo "Fetching Ansible credentials for v4"
  CUSTOM_CONJUR_AUTHN_API_KEY=$(docker exec ${conjur_cid} conjur host rotate_api_key --host ansible/ansible-custom-target)
  ANSIBLE_CONJUR_AUTHN_API_KEY=$(docker exec ${conjur_cid} conjur host rotate_api_key --host ansible/ansible-master)
  ANSIBLE_CONJUR_APPLIANCE_URL='https://conjur'
  ANSIBLE_CONJUR_VERSION=4
  ANSIBLE_CONJUR_CERT_FILE='/conjurinc/tests/conjur.pem'
  cli_cid=${conjur_cid}
  echo "Preparing Ansible for v4 test run"
  docker-compose up -d ansible
  ansible_cid=$(docker-compose ps -q ansible)
  echo "Running v4 tests"
  run_test_cases
}

main
