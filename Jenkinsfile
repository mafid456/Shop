pipeline {
  agent any

  environment {
    AWS_REGION     = 'ap-south-1'
    CLUSTER_NAME   = 'jenkins-eks-Cluster'
    NODE_TYPE      = 't3.medium'
    NODE_COUNT     = '2'
    REPO_NAME      = 'Ecom-app-Repo'
    IMAGE_TAG      = 'V1'
    AWS_CREDS      = 'AWS'
  }

  stages {

    stage('Install Dependencies') {
      steps {
        sh ''' 
          echo "=== Installing required dependencies ==="
          
          # Update package list and install required packages
          apt-get update -y || true
          apt-get install -y unzip curl docker.io || true

          echo "=== Installing AWS CLI v2 ==="
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip -o awscliv2.zip
          ./aws/install || true
          aws --version

          echo "=== Installing eksctl ==="
          curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
          mv /tmp/eksctl /usr/local/bin
          eksctl version

          echo "=== Installing kubectl ==="
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
          kubectl version --client
        '''
      }
    }

    stage('Configure AWS Credentials') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDS}"]]) {
          sh '''
            echo "=== Configuring AWS CLI ==="
            mkdir -p ~/.aws
            cat <<EOF > ~/.aws/config
[default]
region = ${AWS_REGION}
output = json
EOF

            cat <<EOF > ~/.aws/credentials
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF

            echo "AWS Identity:"
            aws sts get-caller-identity
          '''
        }
      }
    }

    stage('Create ECR Repository') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDS}"]]) {
          sh '''
            echo "=== Creating ECR Repository ${REPO_NAME} ==="
            aws ecr create-repository --repository-name ${REPO_NAME} --region ${AWS_REGION} || true
          '''
        }
      }
    }

    stage('Build and Push Docker Image') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDS}"]]) {
          sh '''
            ACCOUNT_ID=$(aws sts get-caller-identity --query "_
