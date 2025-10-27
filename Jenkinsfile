pipeline {
  agent any

  environment {
    AWS_REGION = "ap-south-1"
    CLUSTER_NAME = "jenkins-eks-Cluster"
    IMAGE_TAG = "latest"
  }

  stages {

    stage('Checkout Code') {
      steps {
        echo "=== Checking out source code ==="
        checkout scm
      }
    }

    stage('Login to ECR') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: '5eb734ee-37a7-487b-a46c-9008ebcf9157']]) {
          sh '''
            set -e
            echo "=== Logging in to ECR ==="
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query "Account" --output text).dkr.ecr.${AWS_REGION}.amazonaws.com
          '''
        }
      }
    }

    stage('Build and Push Docker Image') {
      steps {
        sh '''
          set -e
          echo "=== Building Docker Image ==="

          ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
          ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/ecom-repo"

          echo "ECR_REPO=${ECR_REPO}" > ecr_repo.env

          docker build -t ${ECR_REPO}:${IMAGE_TAG} .
          docker push ${ECR_REPO}:${IMAGE_TAG}

          echo "✅ Image pushed successfully!"
        '''
      }
    }

    stage('Create or Verify EKS Cluster') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: '5eb734ee-37a7-487b-a46c-9008ebcf9157']]) {
          sh '''
            set -e
            echo "=== Checking if EKS cluster exists ==="

            if aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} >/dev/null 2>&1; then
              echo "✅ Cluster ${CLUSTER_NAME} already exists. Skipping creation."
            else
              echo "🚀 Creating new EKS cluster..."
              eksctl create cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --nodes 2 --node-type t3.medium
              echo "✅ Cluster ${CLUSTER_NAME} created successfully."
            fi
          '''
        }
      }
    }

    stage('Deploy to EKS') {
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: '5eb734ee-37a7-487b-a46c-9008ebcf9157']]) {
          sh '''
            #!/bin/bash
            set -e

            echo "=== Configuring kubectl ==="
            export KUBECONFIG=/var/lib/jenkins/.kube/config
            aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION} --kubeconfig $KUBECONFIG

            echo "=== Verifying EKS connection ==="
            kubectl get nodes

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
            kubectl rollout status deployment/ecom-deploy --timeout=300s || echo "⚠️ Rollout may still be in progress"

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
      echo "❌ Pipeline failed. Please check logs for details."
    }
    success {
      echo "🎉 Pipeline completed successfully!"
    }
  }
}
