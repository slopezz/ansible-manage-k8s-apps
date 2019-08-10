#!/usr/bin/env groovy

import jenkins.model.*
def instance = Jenkins.getInstance()

folder('ocp-cluster/dev') {
    displayName('OCP Cluster dev')
    description('OCP Cluster dev pipeline jobs')
}


pipelineJob('ocp-cluster/dev/deploy-app-dryrun') {
    quietPeriod(30)

    scm {
        github('slopezz/example-repo-jenkins-jobs-definitions')
    }

    properties {

        rebuild {
            autoRebuild()
        }

        disableConcurrentBuilds()
    }

    logRotator {
        artifactDaysToKeep(30)
        daysToKeep(30)
    }

    triggers {
        onPullRequest {
            setPreStatus()
            cancelQueued()
            abortRunning()
            mode {
                heavyHooksCron()
            }
            events {
                labelAdded("deploy\nENVIRONMENT=dev")
                skipLabelNotExists("deploy\nENVIRONMENT=dev")
                commit()
            }
        }
    }

    parameters {
        stringParam('GITHUB_BRANCH', 'master', 'Branch where code to deploy is located')
        stringParam('APPLICATION', 'example', 'Application name to deploy')
        stringParam('OCP_CLUSTER_ENVIRONMENT', 'dev', 'OCP Cluster environment name')
        stringParam('DRYRUN', 'true', 'Ansible dry-run enabled true/false')
        stringParam('AWS_ACCESS_KEY_ID', 'YOUR_ACCESS_KEY_AWS_SECRETS_MANAGER_READ', 'IAM user cicd-pipeline-user AWS Access Key Id')
        credentialsParam('AWS_SECRET_ACCESS_KEY'){
          type('org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImp')
          required()
          defaultValue('cicd_pipeline_user_AWS_ACCESS_KEY_ID')
          description('IAM user cicd-pipeline-user AWS Secret Access Key used to get secret value from AWS Secrets Manager service')
       }
    }

    definition {
        cpsScm {
          scm {
            git {
              remote {
                name('origin')
                github('slopezz/ansible-manage-k8s-apps', 'ssh')
                credentials('####SSH-CREDS-SECRET-ID#####') // jenkins
              }
              branch('master')
            }
            scriptPath('CICD/Jenkinsfile')
          }
        }
    }
}

pipelineJob('ocp-cluster/dev/deploy-app') {
    quietPeriod(30)

    scm {
        github('slopezz/example-repo-jenkins-jobs-definitions')
    }

    properties {

        rebuild {
            autoRebuild()
        }

        disableConcurrentBuilds()
    }

    logRotator {
        artifactDaysToKeep(30)
        daysToKeep(30)
    }

    triggers {
        onPullRequest {
            setPreStatus()
            cancelQueued()
            abortRunning()
            mode {
                heavyHooksCron()
            }
            events {
                labelAdded("deploy\nENVIRONMENT=dev\napproved")
                skipLabelNotExists("deploy\nENVIRONMENT=dev\napproved")
            }
        }
    }

    parameters {
        stringParam('GITHUB_BRANCH', 'master', 'Branch where code to deploy is located')
        stringParam('APPLICATION', 'example', 'Application name to deploy')
        stringParam('OCP_CLUSTER_ENVIRONMENT', 'dev', 'OCP Cluster environment name')
        stringParam('DRYRUN', 'false', 'Ansible dry-run enabled true/false')
        stringParam('AWS_ACCESS_KEY_ID', 'YOUR_ACCESS_KEY_AWS_SECRETS_MANAGER_READ', 'IAM user cicd-pipeline-user AWS Access Key Id')
        credentialsParam('AWS_SECRET_ACCESS_KEY'){
          type('org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImp')
          required()
          defaultValue('cicd_pipeline_user_AWS_ACCESS_KEY_ID')
          description('IAM user cicd-pipeline-user AWS Secret Access Key used to get secret value from AWS Secrets Manager service')
       }
    }

    definition {
        cpsScm {
          scm {
            git {
              remote {
                name('origin')
                github('slopezz/ansible-manage-k8s-apps', 'ssh')
                credentials('####SSH-CREDS-SECRET-ID#####') // jenkins
              }
              branch('master')
            }
            scriptPath('CICD/Jenkinsfile')
          }
        }
    }
}
