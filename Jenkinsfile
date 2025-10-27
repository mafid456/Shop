pipeline {
  agent any

  environment {
    AWS_REGION = "ap-south-1"
    CLUSTER_NAME = "jenkins-eks-Cluster"
    IMAGE_TAG = "latest"
    REPO_NAME = "ecom-repo"
    ECR_REPO = "503427798981.dkr.ecr.ap-south-1.amazonaws.com/${REPO_NAME}"
    KUBECONFIG = "/var/lib/jenkins/.kube/config"
  }

  stages {

    stage('Install Dependencies') {
      steps {
        sh '''
          echo "=== Installing required dependencies ==="
          if [ -f /etc/debian_version ]; then
            echo "Detected Debian/Ubuntu system"
            sudo apt-get update -y
            sudo apt-get install -y awscli docker.io kubectl
          elif [ -f /etc/redhat-release ]; then
            echo "Detected RHEL/CentOS system"
            sudo yum install -y awscli docker kubectl
          fi
          sudo usermod -aG docker jenkins || true
          sudo systemctl enable docker || true
          sudo systemctl start docker || true
        '''
      }
    }

    stage('Create EKS Cluster (if not exists)') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: '5eb734ee-37a7-487b-a46c-9008ebcf9157']]) {
          sh '''
            echo "=== Checking EKS cluster ==="
            if aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} >/dev/null 2>&1; then
              echo "✅ EKS cluster '${CLUSTER_NAME}' already exists. Skipping creation."
            else
              echo "🚀 Creating EKS cluster '${CLUSTER_NAME}'..."
              eksctl create cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --nodes 2 --managed
              echo "✅ Cluster created successfully!"
            fi
          '''
        }
      }
    }

    stage('Login to ECR') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: '5eb734ee-37a7-487b-a46c-9008ebcf9157']]) {
          sh '''
            echo "=== Logging in to ECR ==="
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin 503427798981.dkr.ecr.${AWS_REGION}.amazonaws.com
          '''
        }
      }
    }

    stage('Build and Push Docker Image (if not exists)') {
      steps {
        sh '''
          echo "=== Checking if image already exists in ECR ==="
          IMAGE_EXISTS=$(aws ecr describe-images --repository-name ${REPO_NAME} --region ${AWS_REGION} --query "imageDetails[?imageTags[?contains(@, '${IMAGE_TAG}')]]" --output text || true)

          if [ -n "$IMAGE_EXISTS" ]; then
            echo "✅ Image ${ECR_REPO}:${IMAGE_TAG} already exists. Skipping build and push."
          else
            echo "=== Building Docker image ==="
            docker build -t ${ECR_REPO}:${IMAGE_TAG} .
            echo "=== Pushing image to ECR ==="
            docker push ${ECR_REPO}:${IMAGE_TAG}
            echo "✅ Image pushed successfully!"
          fi

          echo "ECR_REPO=${ECR_REPO}" > ecr_repo.env
          echo "IMAGE_TAG=${IMAGE_TAG}" >> ecr_repo.env
        '''
      }
    }

    stage('Deploy to EKS') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: '5eb734ee-37a7-487b-a46c-9008ebcf9157']]) {
          sh '''#!/bin/bash
            set -e
            echo "=== Configuring kubectl ==="
            export KUBECONFIG=${KUBECONFIG}
            aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION} --kubeconfig $KUBECONFIG

            echo "=== Verifying EKS Connection ==="
            if ! kubectl get nodes >/dev/null 2>&1; then
              echo "❌ Unable to connect to EKS cluster. Exiting."
              exit 1
            fi
            echo "✅ EKS cluster connection verified."

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
            kubectl rollout status deployment/ecom-deploy --timeout=300s || echo "⚠️ Rollout may not be complete yet"

            echo "=== Applying Service ==="
            kubectl apply -f service.yaml

            echo "✅ Deployment complete!"
          '''
        }
      }
    }
  }

  post {
    failure {
      echo "❌ Pipeline failed. Check logs above for errors."
    }
    success {
      echo "🎉 Pipeline executed successfully!"
    }
  }
}
