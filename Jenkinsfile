pipeline {
    agent any
    
    environment {
        TF_VERSION = '1.3.0'
        AWS_REGION = 'us-east-1'
        AWS_CREDENTIALS = credentials('aws-credentials')
    }
    
    parameters {
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform action to perform'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Security Scan') {
            parallel {
                stage('Trivy Scan') {
                    steps {
                        script {
                            sh '''
                                docker run --rm -v $(pwd):/workspace aquasec/trivy:latest config /workspace/eks-terraform/ \
                                --exit-code 1 --format table
                            '''
                        }
                    }
                }
                
                stage('Checkov Scan') {
                    steps {
                        script {
                            sh '''
                                docker run --rm -v $(pwd):/workspace bridgecrew/checkov:latest \
                                --directory /workspace/eks-terraform/ \
                                --framework terraform \
                                --soft-fail \
                                --output cli
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir('eks-terraform') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh '''
                            terraform init
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Validate') {
            steps {
                dir('eks-terraform') {
                    sh 'terraform validate'
                }
            }
        }
        
        stage('Terraform Format Check') {
            steps {
                dir('eks-terraform') {
                    sh 'terraform fmt -check'
                }
            }
        }
        
        stage('Terraform Plan') {
            when {
                anyOf {
                    params.ACTION == 'plan'
                    params.ACTION == 'apply'
                }
            }
            steps {
                dir('eks-terraform') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh '''
                            terraform plan -var-file="dev.tfvars" -out=tfplan
                            terraform show -json tfplan > plan.json
                        '''
                    }
                }
                archiveArtifacts artifacts: 'eks-terraform/plan.json', fingerprint: true
            }
        }
        
        stage('Terraform Apply') {
            when {
                allOf {
                    params.ACTION == 'apply'
                    branch 'main'
                }
            }
            steps {
                dir('eks-terraform') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh '''
                            terraform apply -var-file="dev.tfvars" -auto-approve
                        '''
                    }
                }
            }
        }
        
        stage('Update Kubeconfig') {
            when {
                allOf {
                    params.ACTION == 'apply'
                    branch 'main'
                }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh '''
                        aws eks update-kubeconfig --region ${AWS_REGION} --name my-dev-eks-cluster
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            when {
                allOf {
                    params.ACTION == 'apply'
                    branch 'main'
                }
            }
            steps {
                sh '''
                    kubectl get nodes
                    kubectl get pods -A
                '''
            }
        }
        
        stage('Wait Before Auto-Destroy') {
            when {
                allOf {
                    params.ACTION == 'apply'
                    branch 'main'
                }
            }
            steps {
                script {
                    echo 'Waiting 5 minutes before auto-destroy...'
                    sleep(300)
                }
            }
        }
        
        stage('Auto-Destroy After Apply') {
            when {
                allOf {
                    params.ACTION == 'apply'
                    branch 'main'
                }
            }
            steps {
                dir('eks-terraform') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh '''
                            terraform destroy -var-file="dev.tfvars" -auto-approve
                        '''
                    }
                }
            }
        }
        
        stage('Manual Destroy') {
            when {
                params.ACTION == 'destroy'
            }
            steps {
                dir('eks-terraform') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh '''
                            terraform destroy -var-file="dev.tfvars" -auto-approve
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}