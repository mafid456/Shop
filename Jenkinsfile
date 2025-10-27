pipeline {
  agent any

  environment {
    AWS_REGION     = 'ap-south-1'
    CLUSTER_NAME   = 'jenkins-eks-Cluster'
    ECR_REPO       = '503427798981.dkr.ecr.ap-south-1.amazonaws.com/ecom'
    IMAGE_TAG      = 'v1'
  }

  stages {

    // --------------------------------------------------
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

    // --------------------------------------------------
    stage('Login to AWS ECR') {
      steps {
        sh '''
          echo "=== Logging in to AWS ECR ==="
          aws ecr get-login-password --region ${AWS_REGION} | sudo docker login --username AWS --password-stdin ${ECR_REPO}
        '''
      }
    }

    // --------------------------------------------------
    stage('Build and Push Docker Image') {
      steps {
        sh '''
          echo "=== Checking if image already exists ==="
          IMAGE_EXISTS=$(aws ecr describe-images --repository-name ecom --image-ids imageTag=${IMAGE_TAG} --region ${AWS_REGION} --query 'imageDetails' --output text || true)

          if [ "$IMAGE_EXISTS" != "None" ] && [ -n "$IMAGE_EXISTS" ]; then
            echo "✅ Image already exists in ECR. Skipping build."
          else
            echo "=== Building Docker image ==="
            sudo docker build -t ${ECR_REPO}:${IMAGE_TAG} .
            echo "=== Pushing Docker image to ECR ==="
            sudo docker push ${ECR_REPO}:${IMAGE_TAG}
          fi
        '''
      }
    }

    // --------------------------------------------------
    stage('Create or Use EKS Cluster') {
      steps {
        sh '''
          echo "=== Checking if EKS cluster already exists ==="
          CLUSTER_STATUS=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --query 'cluster.status' --output text 2>/dev/null || true)

          if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
            echo "✅ EKS cluster already exists. Skipping creation."
          else
            echo "=== Creating new EKS cluster (this may take several minutes) ==="
            eksctl create cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --nodes 2
          fi
        '''
      }
    }

    // --------------------------------------------------
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
          kubectl rollout status deployment/ecom-deploy --timeout=300s || (kubectl describe deployment ecom-deploy && exit 1)

          echo "=== Applying Service ==="
          kubectl apply -f service.yaml

          echo "✅ Deployment complete!"
        '''
      }
    }
  }

  post {
    failure {
      echo "❌ Pipeline failed. Please check the logs above."
    }
    success {
      echo "🎉 Pipeline executed successfully!"
    }
  }
}
