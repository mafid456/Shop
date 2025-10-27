pipeline {
  agent any

  environment {
    AWS_REGION = 'ap-south-1'
    CLUSTER_NAME = 'jenkins-eks-Cluster'
    ECR_REPO = '503427798981.dkr.ecr.ap-south-1.amazonaws.com/ecom-repo'
    IMAGE_TAG = 'latest'
  }

  stages {

    stage('Install Dependencies') {
      steps {
        sh '''
          echo "=== Installing required dependencies ==="

          if [ -f /etc/debian_version ]; then
            echo "Detected Debian/Ubuntu system"
            sudo apt-get update -y
            sudo apt-get install -y unzip curl apt-transport-https ca-certificates gnupg lsb-release

            echo "Installing AWS CLI v2..."
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip -o awscliv2.zip
            sudo ./aws/install || true
            aws --version || echo "AWS CLI installation failed"

            echo "Installing Docker..."
            sudo apt-get install -y docker.io
            sudo systemctl enable docker || true
            sudo systemctl start docker || true
            sudo usermod -aG docker jenkins || true

            echo "Installing kubectl..."
            sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
            echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
            sudo apt-get update -y
            sudo apt-get install -y kubectl

          elif [ -f /etc/redhat-release ]; then
            echo "Detected RHEL/CentOS system"
            sudo yum install -y unzip curl docker
            sudo systemctl enable docker || true
            sudo systemctl start docker || true
            sudo usermod -aG docker jenkins || true

            echo "Installing AWS CLI v2..."
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip -o awscliv2.zip
            sudo ./aws/install || true
            aws --version || echo "AWS CLI installation failed"

            echo "Installing kubectl..."
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
          fi

          echo "✅ Dependency installation complete."
        '''
      }
    }

    stage('Login to AWS ECR') {
      steps {
        sh '''
          echo "=== Logging in to AWS ECR ==="
          aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}
        '''
      }
    }

    stage('Build & Push Docker Image') {
      steps {
        script {
          def imageExists = sh(
            script: "aws ecr describe-images --repository-name ecom-repo --image-ids imageTag=${IMAGE_TAG} --region ${AWS_REGION} >/dev/null 2>&1",
            returnStatus: true
          ) == 0

          if (imageExists) {
            echo "🟡 Image '${IMAGE_TAG}' already exists in ECR. Skipping build."
          } else {
            sh '''
              echo "=== Building and pushing Docker image ==="
              docker build -t ${ECR_REPO}:${IMAGE_TAG} .
              docker push ${ECR_REPO}:${IMAGE_TAG}
            '''
          }
        }
      }
    }

    stage('Create or Use EKS Cluster') {
      steps {
        script {
          def clusterExists = sh(
            script: "aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} >/dev/null 2>&1",
            returnStatus: true
          ) == 0

          if (clusterExists) {
            echo "🟡 Cluster '${CLUSTER_NAME}' already exists. Skipping creation."
          } else {
            sh '''
              echo "=== Creating EKS Cluster ==="
              eksctl create cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --nodes 2 --node-type t3.medium --managed
            '''
          }
        }
      }
    }

    stage('Deploy to EKS') {
      steps {
        sh '''
          echo "=== Configuring kubectl ==="
          aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}

          echo "=== Deploying application ==="
          if kubectl get deployment ecom-deploy >/dev/null 2>&1; then
            echo "Updating existing deployment..."
            kubectl set image deployment/ecom-deploy ecom-container=${ECR_REPO}:${IMAGE_TAG} --record
          else
            echo "Creating new deployment..."
            kubectl apply -f deployment.yaml
          fi

          echo "=== Waiting for rollout to complete ==="
          kubectl rollout status deployment/ecom-deploy --timeout=300s || {
            echo "⚠️ Rollout failed or timed out. Showing pods for debugging:"
            kubectl get pods -o wide
            kubectl describe pods | tail -n 50
            exit 1
          }

          echo "=== Applying Service ==="
          kubectl apply -f service.yaml

          echo "✅ Deployment complete!"
        '''
      }
    }
  }

  post {
    always {
      echo "Pipeline completed (success or fail)."
    }
    success {
      echo "✅ Pipeline succeeded!"
    }
    failure {
      echo "❌ Pipeline failed. Check the Jenkins logs for details."
    }
  }
}
