pipeline {
  agent any

  environment {
    AWS_REGION     = 'ap-south-1'
    CLUSTER_NAME   = 'jenkins-eks-Cluster'
    NODE_TYPE      = 't3.medium'
    NODE_COUNT     = '2'
    REPO_NAME      = 'ecom-app-repo'
    IMAGE_TAG      = 'v1'
    AWS_CREDS      = 'AWS'
  }

  stages {

    stage('Install Dependencies') {
      steps {
        sh ''' 
          echo "=== Installing required dependencies ==="
          
          echo "Installing AWS CLI v2..."
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip -o awscliv2.zip
          sudo ./aws/install || true
          aws --version

          echo "Installing eksctl..."
          curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
          sudo mv /tmp/eksctl /usr/local/bin
          eksctl version

          echo "Installing kubectl..."
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
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
            aws ecr create-repository --repository-name ${REPO_NAME} --region ${AWS_REGION} || echo "Repository already exists"
          '''
        }
      }
    }

    stage('Build and Push Docker Image') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDS}"]]) {
          sh '''#!/bin/bash
            set -e
            ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
            ECR_REPO=$ACCOUNT_ID.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}

            echo "=== Logging in to ECR ==="
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin $ECR_REPO

            echo "=== Building and pushing Docker image ==="
            docker build -t ${REPO_NAME}:${IMAGE_TAG} .
            docker tag ${REPO_NAME}:${IMAGE_TAG} $ECR_REPO:${IMAGE_TAG}
            docker push $ECR_REPO:${IMAGE_TAG}

            echo "ECR_REPO=$ECR_REPO" > ecr_repo.env
          '''
        }
      }
    }

    stage('Create or Use Existing EKS Cluster') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDS}"]]) {
          sh '''#!/bin/bash
            set -e
            echo "=== Checking if EKS Cluster ${CLUSTER_NAME} exists ==="
            CLUSTER_EXISTS=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --query "cluster.status" --output text 2>/dev/null || echo "NOTFOUND")

            if [ "$CLUSTER_EXISTS" = "NOTFOUND" ]; then
              echo "Cluster not found. Creating EKS Cluster ${CLUSTER_NAME}..."
              eksctl create cluster \
                --name ${CLUSTER_NAME} \
                --region ${AWS_REGION} \
                --nodegroup-name standard-workers \
                --node-type ${NODE_TYPE} \
                --nodes ${NODE_COUNT} \
                --nodes-min 1 \
                --nodes-max 3 \
                --managed \
                --with-oidc
            else
              echo "Cluster ${CLUSTER_NAME} already exists. Using existing cluster."
            fi
          '''
        }
      }
    }

    stage('Deploy to EKS') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "${AWS_CREDS}"]]) {
          sh '''#!/bin/bash
            set -e
            echo "=== Configuring kubectl ==="
            aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}

            echo "=== Loading ECR repo info ==="
            source ecr_repo.env

            echo "=== Deploying application ==="
            if kubectl get deployment ecom-deploy >/dev/null 2>&1; then
              echo "Updating existing deployment..."
              kubectl set image deployment/ecom-deploy ecom-container=${ECR_REPO}:${IMAGE_TAG} --record
            else
              echo "Creating new deployment..."
              kubectl apply -f deployment.yaml
            fi

            echo "=== Waiting for rollout to complete ==="
            kubectl rollout status deployment/ecom-deploy --timeout=300s

            echo "=== Applying Service ==="
            kubectl apply -f service.yaml

            echo "✅ Deployment complete!"
          '''
        }
      }
    }
  }

  post {
    success {
      echo "✅ Application successfully built, pushed, and deployed to EKS!"
    }
    failure {
      echo "❌ Deployment failed. Please check the Jenkins logs."
    }
  }
}
