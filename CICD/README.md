# Application CICD definition

## Jenkinsfile

 * There is the [Jenkinsfile](Jenkinsfile) which defines how all deploy-app jenkins pipeline jobs are executed
 * There are 2 pipeline jobs for each OCP Cluster Environment:
    * deploy-app-dryrun:
        * Executes `deploy-app` target with var `DRYRUN=true` (dry-run mode on)
        * Ansible global syntax is checked
        * Configured data (on `host_vars/${ENVIRONMENT}-ocp-cluster/${APP}-vars.yml`) is sent to the OCP Cluster (it shows exactly which objects changes)
        * But finally it will not apply them on destination OCP Cluster (so CR values will not be updated)
    * deploy-app: 
        * Executes `deploy-app` target with var `DRYRUN=true` (dry-run mode on)
        * Ansible global syntax is checked
        * Configured data (on `host_vars/${ENVIRONMENT}-ocp-cluster/${APP}-vars.yml`) is sent to the OCP Cluster (it shows exactly which objects changes)
        * And finally it will apply them them on destination OCP Cluster (so CR values will be updated).
 * Each specific deploy-app jenkins pipeline job clones GitHub repository [slopezz/ansible-manage-k8s-apps](https://github.com/slopezz/ansible-manage-k8s-apps) on specific `BRANCH`, and executes exactly the same make target you can execute manually on your box, with the difference that execution on Jenkins slaves needs to remove pseudo tty on docker execution (`-t`), so it is uses VAR `CICD=true` to configure Docker execution command:
```bash
$ make deploy-app APP=hello-world ENVIRONMENT=dev CICD=true DRYRUN=false
```
 * There is an [example of the possible pipeline jobs denifition](example-pipeline-jobs-definition-jenkins.groovy) using previous Jenkinsfile, `jenkins.goovy` file should be stored on a repository (on the example is pointing to not existing repository `slopezz/example-repo-jenkins-jobs-definitions`)

## Deploy with Github Flow

* Imagine you want to deploy `APP=hello-world` on `ENVIRONMENT=dev`
* You create your own branch (a descriptive name is recommended):
```bash
$ git clone git@slopezz/ansible-manage-k8s-apps.git
$ git checkout -b deploy-hello-world-v2-dev
```
* You make changes on CR variables at file `host_vars/dev-ocp-cluster/hello-world-vars.yml`, for example updating image version, from `v1.0` to `v2.0`:
```
## FROM:
hello_world_cr:
  - name: "example1"
    state: "present"
    is_image_latest_tag: "1.0"
    is_image_tag: "1.0"
    is_image_name: "gcr.io/google-samples/hello-app:1.0"

## TO:
hello_world_cr:
  - name: "example1"
    state: "present"
    is_image_latest_tag: "2.0"
    is_image_tag: "2.0"
    is_image_name: "gcr.io/google-samples/hello-app:2.0"
```
* Then you open a Pull Request to `master` branch using template:
```
PR title: Deploy app hello-world version v2.0 on dev OCP Cluster

**General information**:

* **OCP Cluster Environment**: dev
* **Application**: hello-world

**Related issue(s)**

[GitHub #1234: Application giving timeouts](https://github.com/slopezz/ansible-manage-k8s-apps/issues/1234)

**Comments/Features**

* Application was giving timeouts after initialize
* It has been reduced the number of libraries loaded on app initialization
* It has been created new docker image `v2.0` to solve app initialization timeouts 

**GitHub Flow**

* Create branch and make changes on `host_vars/${ENVIRONMENT}-ocp-cluster/${APP}-vars.yml`
* Open PR to `master` branch and add 3 specific labels identifying a deploy of APP on ENVIRONMENT: `deploy`, `APP=${APP}`, `ENVIRONMENT=${ENVIRONMENT}`
* Jenkins pipeline job deploy-app-dryrun will be triggered
* Once deploy-app-dryrun check finishes OK, approve PR and add label `approved` (before merging PR to `master`)
* Jenkins pipeline job deploy-app will be triggered
* Once deploy-app check finishes OK, merge PR to `master` and delete branch
```
* And you need to add 3 specific labels used by Jenkins (deploy-app needed vars `APP` and `ENVIRONMENT` are obtained from Github Labels):
    * `deploy`
    * `ENVIRONMENT=dev`
    * `APP=hello-world`
* In maximum 5 minutes it will be triggered a Jenkins build which will execute the following dry-run:
```bash
$ make deploy-app APP=hello-world ENVIRONMENT=dev CICD=true DRYRUN=true 
```
* If previous build succeed you will be the corresponding OK status:
* Then someone will check PR (peer review):
    * If every thing is OK, `approve` PR before merging it
    * Add label `approved`
* In maximum 5 minutes it will be triggered a Jenkins which will execute a real deploy:
```bash
$ make deploy-app APP=hello-world ENVIRONMENT=dev CICD=true DRYRUN=false
```
* If previous build succeed you will be the corresponding OK status:
* Finally PR can be merged to `master`, and you can delete branch `deploy-hello-world-v2-dev`

## Deploy directly on Jenkins

* If by some reason you don't want to follow the Github Flow, at any time you could execute any of the 2 available pipeline jobs per OCP cluster environment directly on Jenkins.
* URL to locate both pipelines follow format:
    * https://your-jenkins-server.com/job/ocp-cluster/job/${ENVIROMENT}/job/deploy-app-dryrun/
    * https://your-jenkins-server.com/job/ocp-cluster/job/${ENVIROMENT}/job/deploy-app/
* For example, taking into account previous example to deploy branch `deploy-hello-world-v2-dev` for `APP=hello-world` on `ENVIRONMENT=dev`:
    * Go to https://your-jenkins-server.com/job/ocp-cluster/job/dev/job/deploy-app-dryrun/
    * Click on `Build with Parameters` button
    * `GITHUB_BRANCH`: Branch where code to deploy is located, for example `deploy-hello-world-v2-dev`
    * `APPLICATION`: Application name to deploy, for example APP `hello-world`
    * `OCP_CLUSTER_ENVIRONMENT`: OCP Cluster environment name, for example ENVIRONMENT `dev`
