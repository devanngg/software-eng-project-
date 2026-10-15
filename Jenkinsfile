pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform operation. Apply and destroy require the approval gate below.')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'test', 'prod'], description: 'Deployment environment and Terraform state namespace')
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region used by the EKS stack')
        string(name: 'TF_STATE_BUCKET', defaultValue: '', description: 'Existing S3 bucket for Terraform state')
    }

    environment {
        AWS_DEFAULT_REGION = "${params.AWS_REGION}"
        TF_IN_AUTOMATION = 'true'
        TF_INPUT = 'false'
        CLUSTER_NAME = "my-eks-cluster-${params.ENVIRONMENT}"
        TF_VARS_FILE = "variables/${params.ENVIRONMENT}.tfvars"
        TF_STATE_KEY = "eks/${params.ENVIRONMENT}/terraform.tfstate"
    }

    stages {
        stage('Validate inputs') {
            steps {
                script {
                    if (!params.TF_STATE_BUCKET?.trim()) {
                        error('Set TF_STATE_BUCKET to an existing, versioned S3 bucket before running this pipeline.')
                    }
                }
                sh 'aws sts get-caller-identity'
            }
        }

        stage('Terraform init and validate') {
            steps {
                sh 'terraform fmt -check -recursive'
                dir('tf-aws-eks') {
                    sh '''terraform init -input=false \\
                      -backend-config="bucket=${TF_STATE_BUCKET}" \\
                      -backend-config="key=${TF_STATE_KEY}" \\
                      -backend-config="region=${AWS_DEFAULT_REGION}" \\
                      -backend-config="encrypt=true" \\
                      -backend-config="use_lockfile=true"'''
                    sh 'terraform validate'
                }
            }
        }

        stage('Security scan') {
            steps {
                sh 'trivy config --exit-code 1 --severity HIGH,CRITICAL --skip-dirs .terraform .'
            }
        }

        stage('Terraform plan') {
            steps {
                dir('tf-aws-eks') {
                    script {
                        if (params.ACTION == 'destroy') {
                            sh 'terraform plan -destroy -input=false -var-file=${TF_VARS_FILE} -var="aws_region=${AWS_DEFAULT_REGION}" -out=tfplan'
                        } else {
                            sh 'terraform plan -input=false -var-file=${TF_VARS_FILE} -var="aws_region=${AWS_DEFAULT_REGION}" -out=tfplan'
                        }
                    }
                }
            }
        }

        stage('Approve infrastructure change') {
            when { expression { params.ACTION in ['apply', 'destroy'] } }
            steps {
                input message: "Proceed with Terraform ${params.ACTION} in ${params.AWS_REGION}?", ok: 'Proceed'
            }
        }

        stage('Apply infrastructure') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                dir('tf-aws-eks') {
                    sh 'terraform apply -input=false -auto-approve tfplan'
                }
            }
        }

        stage('Deploy NGINX') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_DEFAULT_REGION"
                      kubectl apply -f manifest/namespace.yaml
                      kubectl apply -n eks-nginx-app -f manifest/site.yaml -f manifest/deployment.yaml -f manifest/service.yaml
                      kubectl wait --for=condition=available deployment/nginx -n eks-nginx-app --timeout=5m
                      kubectl rollout status deployment/nginx -n eks-nginx-app --timeout=5m'''
            }
        }

        stage('Destroy infrastructure') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
                dir('tf-aws-eks') {
                    sh 'terraform apply -input=false -auto-approve tfplan'
                }
            }
        }
    }
}
