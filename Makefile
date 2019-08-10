.PHONY: help list-environments list-apps create-environment create-vault edit-vault view-vault deploy-app deploy-app-all

.DEFAULT_GOAL := help

MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THISDIR_PATH := $(patsubst %/,%,$(abspath $(dir $(MKFILE_PATH))))

ANSIBLE_PLAYBOOK_COMMAND = docker run --rm -it -u $$(id -u):$$(id -g) -v /etc/passwd:/etc/passwd \
                               -v ~/:/home/$$(id -u -n) -v $$(pwd):/ansible/playbooks \
                               slopezz/ansible-playbook:${ANSIBLE_VERSION}

ANSIBLE_VAULT_COMMAND = docker run --rm -it -u $$(id -u):$$(id -g) -v /etc/passwd:/etc/passwd \
                            -v ~/:/home/$$(id -u -n) -v $$(pwd):/ansible/playbooks --entrypoint=ansible-vault \
                            slopezz/ansible-playbook:${ANSIBLE_VERSION}

AWS_SECRET_RETRIEVER_COMMAND = docker run --rm -it -u 10000001 \
                               -e AWS_SECRET_ACCESS_KEY -e AWS_ACCESS_KEY_ID \
                               slopezz/aws-secret-retriever:${AWS_SECRET_RETRIEVER_VERSION}

# Remove pseudo tty when executing docker from CICD server (Jenkins slave)
ifeq "$(CICD)" "true"

    AWS_SECRET_RETRIEVER_COMMAND = docker run --rm -i -u 10000001 \
                                   -e AWS_SECRET_ACCESS_KEY -e AWS_ACCESS_KEY_ID \
                                   slopezz/aws-secret-retriever:${AWS_SECRET_RETRIEVER_VERSION}

    ANSIBLE_PLAYBOOK_COMMAND = docker run --rm -i -u $$(id -u):$$(id -g) -v /etc/passwd:/etc/passwd \
                               -v ~/:/home/$$(id -u -n) -v $$(pwd):/ansible/playbooks \
                               slopezz/ansible-playbook:${ANSIBLE_VERSION}

endif

#Default Ansible Version
ANSIBLE_VERSION ?= 2.7.7

#Default AWS Secret Retriever Version
AWS_SECRET_RETRIEVER_VERSION ?= v1.0.0

# Initialize Ansible debug mode if ENV_VAR DEBUG=true
ifeq "$(DEBUG)" "true"
    ANSIBLE_DEBUG:= "-vvv"
endif

# Initialize Ansible dry-run (check) mode if ENV_VAR DRYRUN=true
ifeq "$(DRYRUN)" "true"
    ANSIBLE_DRYRUN:= "--check"
endif

# Initialize Ansible no_log variable if ENV_VAR NOLOG=false (used ONLY for Administrator debugging purpose, output may contain clear passwords)
ifeq "$(NOLOG)" "false"
    ANSIBLE_NOLOG:= "-e ansible_no_log=false"
endif

# Ansible environment management OCP Cluster targets

check-environment-var: # Check ENVIRONMENT VAR
	@if [ ! ${ENVIRONMENT} ] ; then \
		echo "[ERROR] ENVIRONMENT VAR NOT SET!!!" ; \
		echo "-------------------------------------" ; \
		echo "Showing help:" ; \
		make help --no-print-directory ; \
		exit -1; \
	else \
		echo "[INFO] - ENVIRONMENT: ${ENVIRONMENT}" ; \
	fi

check-app-var: # Check APP VAR
	@if [ ! ${APP} ] ; then \
                echo "[ERROR] APP VAR NOT SET!!!" ; \
                echo "-------------------------------------" ; \
                echo "Showing help:" ; \
                make help --no-print-directory ; \
                exit -1; \
        else \
                echo "[INFO] - APP: ${APP}" ; \
        fi

check-environment: check-environment-var # Check if environment ansible playbook exists for OCP Cluster
	@if [ ! -f "./${ENVIRONMENT}-ocp-cluster.yml" ] ; then \
		echo "[ERROR] - Environment playbook ${ENVIRONMENT}-ocp-cluster.yml DOES NOT EXISTS, CONSIDER CREATING IT!!" ; \
		echo "-------------------------------------" ; \
		echo "Showing help:" ; \
		make help --no-print-directory ; \
		exit -1; \
	fi

check-environment-app-exists: check-app-var check-environment # Check if an APP is defined on ansible playbook for OCP Cluster
	@if [ ${APP} != 'all' ] ; then \
		APP_EXISTS='$(shell grep role ${ENVIRONMENT}-ocp-cluster.yml | grep tags | grep "\<${APP}\>" | wc -l )'; \
		if [ $${APP_EXISTS} == 0 ] ; then \
			echo "[ERROR] - APP ${APP} is not defined for ENVIRONMENT ${ENVIRONMENT} on environment playbook ${ENVIRONMENT}-ocp-cluster.yml" ; \
			echo "-------------------------------------" ; \
			echo "Showing help:" ; \
			make help --no-print-directory ; \
			exit -1; \
		fi ; \
       fi	

list-environments: ## List available OCP clusters
	@echo "[INFO] - Available ENVIRONMENT OCP Clusters:" ; \
        echo "--------------------------------------------" ; \
        ls | grep "ocp-cluster.yml" | sed s/'-ocp-cluster.yml'//

list-apps: check-environment ## List available applications for a given OCP Cluster
	@echo "[INFO] - Available APPs defined on environment playbook ${ENVIRONMENT}-ocp-cluster.yml:" ; \
        echo "--------------------------------------------" ; \
        grep role ${ENVIRONMENT}-ocp-cluster.yml | grep tags | awk '{print $$7}' ; \
        echo "--------------------------------------------" ; \
        echo '[INFO] - Remember you can use special APP=all to deploy all applications defined for a given OCP Cluster'


create-environment-playbook: check-environment-var # Creates environment ansible playbook for OCP Cluster
	@echo "[INFO] - Checking if environment playbook ${ENVIRONMENT}-ocp-cluster.yml already exists..."
	@if [ ! -f "./${ENVIRONMENT}-ocp-cluster.yml" ] ; then \
		echo "[INFO] - Creating environment playbook: ${ENVIRONMENT}-ocp-cluster.yml" ; \
                envsubst < templates/environment-playbook-ocp-cluster.yml.tpl > ./${ENVIRONMENT}-ocp-cluster.yml ; \
        else \
                echo "[WARN] - Environment playbook ${ENVIRONMENT}-ocp-cluster.yml already exists, DOING NOTHING" ; \
        fi

create-environment-inventory: check-environment-var # Adds environment host to ansible inventory for OCP Cluster
	@echo "[INFO] - Checking if host ${ENVIRONMENT}-ocp-cluster at ansible inventory already exists..."
	@if  grep -q ${ENVIRONMENT}-ocp-cluster inventory ; then \
		echo "[WARN] - Ansible host ${ENVIRONMENT}-ocp-cluster at ansible inventory already exists, DOING NOTHING" ; \
	else \
		echo "[INFO] - Adding host ${ENVIRONMENT}-ocp-cluster to ansible inventory" ; \
		echo "${ENVIRONMENT}-ocp-cluster ansible_connection=local" >> ./inventory; \
	fi

create-environment-vars-file: check-environment-var # Creates empty environment vars file inside host_vars dir for OCP Cluster
	@echo "[INFO] - Checking if environment vars file host_vars/${ENVIRONMENT}-ocp-cluster/vars.yml already exists..."
	@if [ ! -f "./host_vars/${ENVIRONMENT}-ocp-cluster/vars.yml" ] ; then \
		echo "[INFO] - Creating environment vars file: host_vars/${ENVIRONMENT}-ocp-cluster/vars.yml" ; \
		mkdir -p ./host_vars/${ENVIRONMENT}-ocp-cluster; \
		envsubst < templates/environment-host-vars-ocp-cluster.yml.tpl > ./host_vars/${ENVIRONMENT}-ocp-cluster/vars.yml ; \
        else \
                echo "[WARN] - Environment vars file host_vars/${ENVIRONMENT}-ocp-cluster/ already exists, DOING NOTHING" ; \
        fi

create-environment-vault-password: check-environment-var # Create vault password on AWS Secret Manager Service for OCP Cluster
	@echo "[INFO] - Checking if VAULT_PASSWORD with SECRET_NAME ${ENVIRONMENT}-ocp-cluster-ansible-vault at AWS Secret Manager Service already exists..."
	@VAULT_PASSWORD='$(shell $(AWS_SECRET_RETRIEVER_COMMAND) get value ${ENVIRONMENT}-ocp-cluster-ansible-vault)'; \
	if [ $${VAULT_PASSWORD} == SECRET_NOT_FOUND ] ; then \
		echo "[INFO] - Creating VAULT_PASSWORD with SECRET_NAME ${ENVIRONMENT}-ocp-cluster-ansible-vault at AWS Secret Manager Service"; \
		SECURE_PASSWORD='$(shell openssl rand -base64 20)'; \
		$(AWS_SECRET_RETRIEVER_COMMAND) set --secret-name "${ENVIRONMENT}-ocp-cluster-ansible-vault" --secret-key "${ENVIRONMENT}-ocp-cluster-ansible-vault" --secret-value "$${SECURE_PASSWORD}" ; \
		echo "-------------------------------------" ; \
		echo "  SECRET_NAME: ${ENVIRONMENT}-ocp-cluster-ansible-vault" ; \
		echo "  KEY: ${ENVIRONMENT}-ocp-cluster-ansible-vault"; \
		echo "  VALUE: $${SECURE_PASSWORD}" ; \
		echo "-------------------------------------" ; \
		echo "[INFO] - And then, PLEASE ADD it also to other Secret Service (KeePass, ZohoVault...) as a FALLBACK of AWS Secret Manager Service" ;\
	else \
		echo "[WARN] - Environment VAULT_PASSWORD with SECRET_NAME ${ENVIRONMENT}-ocp-cluster-ansible-vault at AWS Secret Manager Service already exists, DOING NOTHING" ; \
	fi

create-environment: check-environment-var create-environment-playbook create-environment-inventory create-environment-vars-file create-environment-vault-password ## Create environment for OCP cluster

# Ansible vault management OCP Cluster targets

generate-vault-password: check-environment
	@echo "[INFO] - Obtaining VAULT_PASSWORD for ENVIRONMENT ${ENVIRONMENT} from AWS Secret Manager Service / SECRET_NAME: ${ENVIRONMENT}-ocp-cluster-ansible-vault..."
	@if [ -f vault/${ENVIRONMENT}-ocp-cluster.secret ] ;then rm vault/${ENVIRONMENT}-ocp-cluster.secret; fi; \
	VAULT_PASSWORD='$(shell $(AWS_SECRET_RETRIEVER_COMMAND) get value ${ENVIRONMENT}-ocp-cluster-ansible-vault)'; \
	if [ "$${VAULT_PASSWORD}" == SECRET_NOT_FOUND ] ; then \
		echo "[ERROR] - VAULT_PASSWORD for ENVIRONMENT ${ENVIRONMENT} on AWS Secret Manager Service NOT FOUND!! CONSIDER CREATING VAULT_PASSWORD FIRST ON AWS SECRET MANAGER!!" ; \
		exit -1 ; \
	else \
		echo "$${VAULT_PASSWORD}" > vault/${ENVIRONMENT}-ocp-cluster.secret ; \
	fi

create-vault: generate-vault-password ## Create vault secrets file for OCP Cluster using encryption password from AWS Secret Manager
	@echo "[INFO] - Creating vault secrets file host_vars/${ENVIRONMENT}-ocp-cluster/vault.yml..."
	@if [ -f host_vars/${ENVIRONMENT}-ocp-cluster/vault.yml ] ; then \
		rm vault/${ENVIRONMENT}-ocp-cluster.secret ; \
		echo "[ERROR] - Vault secrets file host_vars/${ENVIRONMENT}-ocp-cluster/vault.yml already exists, CONSIDER EDIT INSTEAD OF CREATE!! " ; \
	else \
		$(ANSIBLE_VAULT_COMMAND) create host_vars/${ENVIRONMENT}-ocp-cluster/vault.yml --vault-password-file vault/${ENVIRONMENT}-ocp-cluster.secret ; \
		rm vault/${ENVIRONMENT}-ocp-cluster.secret ; \
	fi

edit-vault: generate-vault-password ## Edit vault secrets file for OCP Cluster using encryption password from AWS Secret Manager
	@echo "[INFO] - Opening vault secrets file for host_vars/${ENVIRONMENT}-ocp-cluster/vault.yml..."
	@$(ANSIBLE_VAULT_COMMAND) edit host_vars/${ENVIRONMENT}-ocp-cluster/vault.yml --vault-password-file vault/${ENVIRONMENT}-ocp-cluster.secret ; \
	rm vault/${ENVIRONMENT}-ocp-cluster.secret

view-vault: generate-vault-password ## Show vault secrets file for OCP Cluster using encryption password from AWS Secret Manager
	@echo "[INFO] - Showing vault secrets file content for host_vars/${ENVIRONMENT}-ocp-cluster/vault.yml..."
	@$(ANSIBLE_VAULT_COMMAND) view host_vars/${ENVIRONMENT}-ocp-cluster/vault.yml --vault-password-file vault/${ENVIRONMENT}-ocp-cluster.secret ; \
	rm vault/${ENVIRONMENT}-ocp-cluster.secret

# Ansible OCP Cluster application deploy targets

deploy-app: check-environment-app-exists generate-vault-password ## Deploy specific application APP on OCP Cluster
	@echo "[INFO] - Ansible application ${APP} started for ENVIRONMENT ${ENVIRONMENT}:"
	@$(ANSIBLE_PLAYBOOK_COMMAND) -i inventory ${ENVIRONMENT}-ocp-cluster.yml --tags ${APP} ${ANSIBLE_NOLOG} -D ${ANSIBLE_DEBUG} ${ANSIBLE_DRYRUN} --vault-password-file vault/${ENVIRONMENT}-ocp-cluster.secret ; \
	if [ "$${?}" == 0 ] ; then \
		rm vault/${ENVIRONMENT}-ocp-cluster.secret ; \
		echo "[INFO] - Ansible application ${APP} execution finished for ENVIRONMENT ${ENVIRONMENT}"   ; \
	else \
		rm vault/${ENVIRONMENT}-ocp-cluster.secret ; \
		echo "[ERROR] - Ansible application ${APP} execution FAILED for ENVIRONMENT ${ENVIRONMENT}!!!" ; \
		exit -1 ; \
	fi

deploy-app-all: ## Deploy all applications (make deploy-app APP=all) on OCP Cluster
	@APP=all make deploy-app --no-print-directory

help: ## Print this help
	@echo "----------------------------------------------"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-46s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo "----------------------------------------------" ; \
        echo "# Execution examples:" ; \
        echo "- NORMAL:               make create-environment ENVIRONMENT=staging"; \
        echo "- NORMAL:               make create-vault ENVIRONMENT=staging"; \
        echo "- NORMAL:               make edit-vault ENVIRONMENT=staging"; \
        echo "- NORMAL:               make view-vault ENVIRONMENT=staging"; \
        echo "- NORMAL:               make deploy-app APP=hello-world ENVIRONMENT=staging"; \
        echo "- DRYRUN enabled:       make deploy-app APP=hello-world ENVIRONMENT=staging DRYRUN=true"; \
        echo "- DEBUG enabled:        make deploy-app APP=hello-world ENVIRONMENT=staging DEBUG=true"; \
        echo "- DRYRUN/DEBUG enabled: make deploy-app APP=hello-world ENVIRONMENT=staging DRYRUN=true DEBUG=true"; \
        echo "- NORMAL:               make deploy-app APP=all ENVIRONMENT=staging"; \
        echo "- NORMAL:               make deploy-app-all ENVIRONMENT=staging (same as make deploy-app APP=all)"; \
        echo "-----------------------------------------------" ;
