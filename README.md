# Ansible k8s Application Lifecycle Management

 * It is used ansible-playbook (and ansible-vault) inside a docker container with specific version in order to be able to guarantee that execution on different systems will have the same result and all dependancies of possible python modules... will be resolved.
 * The reason to use ansible with `k8s` ansible module is that it guarantees idempotence, so on every execution, ansible checks for every object

## Overview

 * Each cluster is a playbook that has N applications (test-ocp-cluster.yml, dev-ocp-cluster.yml, staging-ocp-cluster.yml...).
 * Each application is managed via ansible roles (which configures ansible-operators mainly, and uses jinja templates for the yaml files to have differences between the same app among different clusters).
 * Each application (ansible role) consists on:
    * Namespace object management (only if required). It can be specific name, description, node type (type=eip...).
    * Operator objects management (creation of CRD, service_acount, role, role_binding, operator objects).
    * CR objects management of specific operator (for every operator it can me specified N CR objects inside an ansible list).
    * Secret object management (only if required).
    * ConfigMap object management (only if required).
 * Each OCP USER/URL for every cluster is stored on `hosts_vars/$ENVIRONMENT-ocp-cluster/vars.yml` (for example on `hosts_vars/test-ocp-cluster/vars.yml`).
 * Each application variable for every cluster is stored `hosts_vars/$ENVIRONMENT-ocp-cluster/$APPLICATION-vars.yml` (for example on `hosts_vars/test-ocp-cluster/hello-world-vars.yml`).
 * Each application secret variables (and OCP password) for every cluster is stored on `hosts_vars/$ENVIRONMENT-ocp-cluster/vault.yml` using ansible-vault (for example on `hosts_vars/test-ocp-cluster/vault.yml`)

## OCP Authentication

 * When using ansible `k8s` module, basicly there are two main auth methods:
    * API KEY Token (but it lasts only 24h, so needs to be constantly renewed)
    * Username/password (but currently this method is not working, [ISSUE still opened](https://github.com/ansible/ansible/issues/44504))
 * So in order to be able to use the API KEY Token on a CICD without having to update it manually every 24h:
    * Each playbook (one per cluster) has a pre_task that uses username/password to get API KEY Token for cluster authentication by using ansible `uri` module:
```
curl -u $USERNAME:$PASSWORD -kv -H "X-CSRF-Token: xxx" '$MASTER_HOST/oauth/authorize?client_id=openshift-challenging-client&response_type=token'
```
 * OCP cluster admin password is stored securely on a file using `ansible-vault`.

## Ansible roles

 * Ansible roles are used to deploy Operators objects (Namespaces, Operator objects, CRs, and optionally Secrets and Configmaps) using `k8s` ansible module to `interact` with a OCP Cluster

## Usage

 * The lifecycle is managed via Makefile. Current targets:

```
$ make
----------------------------------------------
help                                           Print this help
list-environments                              List available OCP clusters
list-apps                                      List available applications for a given OCP Cluster
create-environment                             Create environment for OCP cluster
create-vault                                   Create vault secrets file for OCP Cluster using encryption password from AWS Secret Manager
edit-vault                                     Edit vault secrets file for OCP Cluster using encryption password from AWS Secret Manager
view-vault                                     Show vault secrets file for OCP Cluster using encryption password from AWS Secret Manager
deploy-app                                     Deploy specific application APP on OCP Cluster
deploy-app-all                                 Deploy all applications (make deploy-app APP=all) on OCP Cluster
----------------------------------------------
# Execution examples:
- NORMAL:               make create-environment ENVIRONMENT=staging
- NORMAL:               make create-vault ENVIRONMENT=staging
- NORMAL:               make edit-vault ENVIRONMENT=staging
- NORMAL:               make view-vault ENVIRONMENT=staging
- NORMAL:               make deploy-app APP=hello-world ENVIRONMENT=staging
- DRYRUN enabled:       make deploy-app APP=hello-world ENVIRONMENT=staging DRYRUN=true
- DEBUG enabled:        make deploy-app APP=hello-world ENVIRONMENT=staging DEBUG=true
- DRYRUN/DEBUG enabled: make deploy-app APP=hello-world ENVIRONMENT=staging DRYRUN=true DEBUG=true
- NORMAL:               make deploy-app APP=all ENVIRONMENT=staging
- NORMAL:               make deploy-app-all ENVIRONMENT=staging (same as make deploy-app APP=all)
-----------------------------------------------
``` 

## Environment creation example

 * Example of environment creation for `dev` OCP cluster:

```
$ make create-environment ENVIRONMENT=dev
[INFO] - ENVIRONMENT: dev
[INFO] - Checking if environment playbook dev-ocp-cluster.yml already exists...
[WARN] - Environment playbook dev-ocp-cluster.yml already exists, DOING NOTHING
[INFO] - Checking if host dev-ocp-cluster at ansible inventory already exists...
[WARN] - Ansible host dev-ocp-cluster at ansible inventory already exists, DOING NOTHING
[INFO] - Checking if environment vars file host_vars/dev-ocp-cluster/vars.yml already exists...
[INFO] - Creating environment vars file: host_vars/dev-ocp-cluster/vars.yml
[INFO] - Checking if VAULT_PASSWORD with SECRET_NAME dev-ocp-cluster-ansible-vault at AWS Secret Manager Service already exists...
[INFO] - Creating VAULT_PASSWORD with SECRET_NAME dev-ocp-cluster-ansible-vault at AWS Secret Manager Service
-------------------------------------
  SECRET_NAME: dev-ocp-cluster-ansible-vault
  KEY: dev-ocp-cluster-ansible-vault
  VALUE: 123456789QWERTY=
-------------------------------------
[INFO] - And then, PLEASE ADD it also to other Secret Service (KeePass, ZohoVault...) as a FALLBACK of AWS Secret Manager Service
```
 
 * It has done the following actions:
    * Create playbook `dev-ocp-cluster.yml`
    * Add host `dev-ocp-cluster` to ansible inventory
    * Create emtpy host vars file `host_vars/dev-ocp-cluster/vars.yml` with fake OCP cluster host URL (you will need to edit)
    * Create the VAULT_PASSWORD at AWS Secret Manager Service (it is used to create/edit encrypted OCP cluster vault file with secrets)
 * **It is recommended to save VAULT_PASSWORD on other Secret Service (like KeePass, ZohoVault...) as a FALLBACK:**
    * When deleting a secret from AWS Secret Manager Service using `AWS Console`, you have a recovery window to restore it of 7-30 days
    * When deleting a secret from AWS Secret Manager Service using `awscli` you can set a flag to not add any recovery window, so secret can be permanently deleted. If it happens, you will never have the possibility to decrypt all secrets you have on your ansible-vault file for a given OCP cluster.


## Vault files management

 * Now that environment has been created (ansible playbook, inventory, empty vars file, vault password at AWS Secret Manager Service), you need to create vault file to store secrets (like OCP cluster admin password) for every OCP cluster (one per cluster)
 * It will be created for each OCP cluster an encrypted ansible-vault file called `host_vars/$ENVIRONMENT-ocp-cluster/vault.yml` (for example `host_vars/dev-ocp-cluster/vault.yml`) that can be pushed to repository, it is encrypted with vault encryption password retrieved dynamically from AWS Secret Manager service:

```
$ make create-vault ENVIRONMENT=dev
[INFO] - ENVIRONMENT: dev
[INFO] - Obtaining VAULT_PASSWORD for ENVIRONMENT dev from AWS Secret Manager Service / SECRET_NAME: dev-ocp-cluster-ansible-vault...
[INFO] - Creating vault secrets file host_vars/dev-ocp-cluster/vault.yml...
```
 * If you want to update cluster vault file of specific OCP cluster:

```
$ make edit-vault ENVIRONMENT=dev
[INFO] - ENVIRONMENT: dev
[INFO] - Obtaining VAULT_PASSWORD for ENVIRONMENT dev from AWS Secret Manager Service / SECRET_NAME: dev-ocp-cluster-ansible-vault...
[INFO] - Opening vault secrets file for host_vars/dev-ocp-cluster/vault.yml...
```

 * If you just want to show cluster vault file content of specific OCP cluster:

```bash
$ make view-vault ENVIRONMENT=dev
[INFO] - ENVIRONMENT: dev
[INFO] - Obtaining VAULT_PASSWORD for ENVIRONMENT dev from AWS Secret Manager Service / SECRET_NAME: dev-ocp-cluster-ansible-vault...
[INFO] - Viewing vault secrets file for host_vars/dev-ocp-cluster/vault.yml...
# OCP
ocp_cluster_password: "123456789abcdef"

# prometheus-postgresql exporter
dev_postgresql_db_password: "123456789"
```

 * The password used to create/edit that encrypted ansible-vault file:
    * It is retrieved dynamically from AWS Secret Manager Service on every ansible execution
    * It is is stored temporarily on a file that is never commited (`vault/` directory is on `.gitignore`, for example `vault/dev-ocp-cluster.secret`)
    * It is removed dynamically once ansible execution has finished.

## List current defined environments
```
$ make list-environments
[INFO] - Available ENVIRONMENT OCP Clusters:
--------------------------------------------
dev
```

## List current defined applications for a given environment

```
$ make list-apps ENVIRONMENT=dev
[INFO] - ENVIRONMENT: dev
[INFO] - Available APPs defined on environment playbook dev-ocp-cluster.yml:
--------------------------------------------
'hello-world'
--------------------------------------------
```

## Deploy application example

 * In this example it will be deployed `hello-world` application on `dev` OCP cluster. 

 * First fill in application variables at `hosts_vars/dev-ocp-cluster/hello-world-vars.yml`:

```
---
# hello-world operator
hello_world_namespace_create: true
hello_world_namespace_state: "present"
hello_world_namespace_name: "hello-world-delete"
hello_world_operator_image: "slopezz/ansible-hello-world-operator:v1.1.0"
hello_world_operator_state: "present"
hello_world_operator_monitoring_state: "present"
hello_world_operator_monitoring_label_key: "{{ocp_cluster_prometheus_servicemonitor_monitoring_label_key }}"
hello_world_operator_monitoring_label_value: "{{ ocp_cluster_prometheus_servicemonitor_monitoring_label_value }}"
hello_world_cr:
  - name: "example1"
    state: "present"
    is_image_latest_tag: "1.0"
    is_image_tag: "1.0"
    is_image_name: "gcr.io/google-samples/hello-app:1.0"
    dc_replicas: 1
    dc_resources_requests_cpu: "50m"
    dc_resources_requests_memory: "32Mi"
    dc_resources_limits_cpu: "100m"
    dc_resources_limits_memory: "64Mi"
    route_hosts: "hello-world-example1.dev.example.net"
  - name: "example2"
    state: "present"
    is_image_latest_tag: "2.0"
    is_image_tag: "2.0"
    is_image_name: "gcr.io/google-samples/hello-app:2.0"
    dc_replicas: 2
    dc_resources_requests_cpu: "50m"
    dc_resources_requests_memory: "32Mi"
    dc_resources_limits_cpu: "100m"
    dc_resources_limits_memory: "64Mi"
    route_hosts: "hello-world-example2.dev.example.net"
```
 
 * Then execute `deploy-app` target with APP `hello-world` on ENVIRONMENT `dev` OCP cluster:

```
$ make deploy-app APP=hello-world ENVIRONMENT=dev
[INFO] - APP: hello-world
[INFO] - ENVIRONMENT: dev
[INFO] - Obtaining VAULT_PASSWORD for ENVIRONMENT dev from AWS Secret Manager Service / SECRET_NAME: dev-ocp-cluster-ansible-vault...
[INFO] - Ansible application hello-world started for ENVIRONMENT dev:

PLAY [Manage dev OCP Cluster] *************************************************************************************************************************************************************************************

TASK [Gathering Facts] ********************************************************************************************************************************************************************************************
ok: [dev-ocp-cluster]

TASK [Get OCP cluster API KEY Token using username/password] ******************************************************************************************************************************************************
ok: [dev-ocp-cluster]

TASK [Set OCP cluster API KEY Token] ******************************************************************************************************************************************************************************
ok: [dev-ocp-cluster]

TASK [hello-world : Manage hello-world Namespace hello-world-delete] **********************************************************************************************************************************************
changed: [dev-ocp-cluster]

TASK [hello-world : Manage hello-world CRD on Namespace hello-world-delete] ***************************************************************************************************************************************
ok: [dev-ocp-cluster]

TASK [hello-world : Manage hello-world Operator main objects on Namespace hello-world-delete] *********************************************************************************************************************
changed: [dev-ocp-cluster] => (item={u'name': u'service_account.yaml.j2'})
changed: [dev-ocp-cluster] => (item={u'name': u'role.yaml.j2'})
changed: [dev-ocp-cluster] => (item={u'name': u'role_binding.yaml.j2'})
changed: [dev-ocp-cluster] => (item={u'name': u'operator.yaml.j2'})

TASK [hello-world : Manage hello-world Operator specific prometheus monitoring objects on Namespace hello-world-delete] *******************************************************************************************
changed: [dev-ocp-cluster] => (item={u'name': u'operator-service.yaml.j2'})
changed: [dev-ocp-cluster] => (item={u'name': u'operator-servicemonitor.yaml.j2'})

TASK [hello-world : Manage hello-world CRs on Namespace hello-world-delete] ***************************************************************************************************************************************
changed: [dev-ocp-cluster] => (item={u'dc_resources_limits_cpu': u'100m', u'name': u'example1', u'route_hosts': u'hello-world-example1.dev.example.net', u'is_image_tag': u'1.0', u'dc_resources_limits_memory': u'64Mi', u'state': u'present', u'dc_replicas': 1, u'is_image_latest_tag': u'1.0', u'dc_resources_requests_memory': u'32Mi', u'is_image_name': u'gcr.io/google-samples/hello-app:1.0', u'dc_resources_requests_cpu': u'50m'})
changed: [dev-ocp-cluster] => (item={u'dc_resources_limits_cpu': u'100m', u'name': u'example2', u'route_hosts': u'hello-world-example2.dev.example.net', u'is_image_tag': u'2.0', u'dc_resources_limits_memory': u'64Mi', u'state': u'present', u'dc_replicas': 2, u'is_image_latest_tag': u'2.0', u'dc_resources_requests_memory': u'32Mi', u'is_image_name': u'gcr.io/google-samples/hello-app:2.0', u'dc_resources_requests_cpu': u'50m'})

PLAY RECAP ********************************************************************************************************************************************************************************************************
dev-ocp-cluster            : ok=8    changed=4    unreachable=0    failed=0   

[INFO] - Ansible application hello-world execution finished for ENVIRONMENT dev
```

 * Example of `deploy-app` target execution for APP `hello-world` on ENVIRONMENT `dev` OCP cluster with ANSIBLE_DEBUG mode enabled (so you can check exactly what is changing for example):

```
$ make deploy-app APP=hello-world ENVIRONMENT=dev DEBUG=true
```

 * Example of `deploy-app` target execution for APP `hello-world` on ENVIRONMENT `dev` OCP cluster with ANSIBLE_DRYRUN mode enabled:

```
$ make deploy-app APP=hello-world ENVIRONMENT=dev DRYRUN=true
```

 * Example of `deploy-app` target execution for APP `hello-world` on ENVIRONMENT `dev` OCP cluster with ANSIBLE_DEBUG and ANSIBLE_DRYRUN mode enabled:

```
$ make deploy-app APP=hello-world ENVIRONMENT=dev DEBUG=true DRYRUN=true
```

## Application CICD definition

 * Application CICD definition to deploy application using Github Flow with Jenkins execution can be found [here](CICD/README.md)
