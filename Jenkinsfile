stage('Install Dependencies') {
  steps {
    sh ''' 
      echo "=== Installing required dependencies ==="
      apt-get update -y
      apt-get install -y unzip curl docker.io

      echo "Installing AWS CLI v2..."
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip -o awscliv2.zip
      ./aws/install || true
      aws --version

      echo "Installing eksctl..."
      curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
      mv /tmp/eksctl /usr/local/bin
      eksctl version

      echo "Installing kubectl..."
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
      kubectl version --client
    '''
  }
}
