# Requires: Minikube, Docker, and Kubectl installed and accessible in the path.

# --- Configuration ---
$DeploymentFile = ".\math-deployment.yaml"
$ConfigFile = ".\math-config.yaml"
$ContainerImage = "mathcontainer:latest"
$DeploymentName = "math-calculator-deployment" # Name of your Deployment in the YAML
$ServiceName = "math-calculator-service" # Name of your Service in the YAML

# --- Docker Check and Build ---
Write-Host "1. Checking for Docker image: $($ContainerImage)..."
$ImageExists = docker images -q $ContainerImage
if (-not $ImageExists) {
    Write-Host "   Image not found. Building $ContainerImage..."
    docker build -t $ContainerImage .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker build failed. Exiting."
        exit 1
    }
} else {
    Write-Host "   Image $ContainerImage found locally."
}

# --- Start Minikube (Conditional) ---
Write-Host "`n2. Checking Minikube status..."

# Run minikube status and suppress normal output, check exit code
minikube status -f "{{.Host}}" 2>$null
if ($LASTEXITCODE -ne 0) {
    # If the exit code is non-zero, minikube is likely stopped or not running
    Write-Host "   Minikube is not running. Starting Minikube..."
    minikube start
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Minikube failed to start. Exiting."
        exit 1
    }
} else {
    Write-Host "   Minikube is already running."
}

# --- Load Image into Minikube's Environment ---
Write-Host "`n3. Loading image $($ContainerImage) into Minikube's Docker daemon..."
minikube image load $ContainerImage
if ($LASTEXITCODE -ne 0) {
    Write-Error "Image load failed. Exiting."
    exit 1
}

# --- Apply Kubernetes Resources ---
Write-Host "`n4. Applying Kubernetes resources..."
kubectl apply -f $ConfigFile
if ($LASTEXITCODE -ne 0) {
    Write-Error "Config application failed. Exiting."
    exit 1
}
kubectl apply -f $DeploymentFile
if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment application failed. Exiting."
    exit 1
}

# --- Wait for Deployment Rollout (Ensures Pods are Running) ---
Write-Host "`n5. Waiting for deployment '$($DeploymentName)' to be ready (up to 120 seconds)..."
kubectl rollout status deployment/$DeploymentName --timeout="120s"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment rollout failed or timed out. Exiting."
    exit 1
}

# --- Verify Pod Status ---
Write-Host "`n6. Verifying Pod status (should show 2 Running pods):"
kubectl get pods

# --- Get Service URL and Open Browser (NEW LOGIC) ---
Write-Host "`n7. Retrieving the service URL for $($ServiceName)..."

# Use 'minikube service list' and filter for the ServiceName
$ServiceInfo = minikube service list | Select-String $ServiceName
if (-not $ServiceInfo) {
    Write-Error "Failed to find service '$($ServiceName)' in the list. Exiting."
    exit 1
}

# The service list output is often space-separated: NAME, NAMESPACE, URL, TARGET-PORT, etc.
# The URL column is often the 3rd or 4th piece of data when the service is exposed.
# If the URL column is blank (common for NodePort services), we look for the NodePort.
# Let's get the Minikube IP first.
$MinikubeIp = minikube ip
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get Minikube IP. Exiting."
    exit 1
}

# Get the NodePort (the external port for the service)
# This assumes your service is type NodePort, which is standard for minikube service exposure.
$NodePort = kubectl get service $ServiceName -o=jsonpath='{.spec.ports[0].nodePort}'
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($NodePort)) {
    Write-Error "Failed to get NodePort for service '$($ServiceName)'. Is the service type NodePort?"
    exit 1
}

$ServiceUrl = "http://$($MinikubeIp):$($NodePort)"
$FinalUrl = "$ServiceUrl/ui"

Write-Host "Minikube IP: $($MinikubeIp)"
Write-Host "NodePort: $($NodePort)"
Write-Host "Service Base URL: $($ServiceUrl)"
Write-Host "Opening browser to: $($FinalUrl)..."

# Use Start-Process to open the URL in the default web browser on Windows
Start-Process $FinalUrl

Write-Host "`nDeployment complete. Check your browser for the MathOps UI."