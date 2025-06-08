#!/bin/bash

# GCP VPC Firewall Configuration Lab - Setup Script
# This script automates the creation of VPC networks, subnets, and VM instances

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required variables are set
check_variables() {
    if [ -z "$PROJECT_ID" ]; then
        print_error "PROJECT_ID environment variable is not set"
        print_warning "Please set PROJECT_ID: export PROJECT_ID=your-project-id"
        exit 1
    fi
    
    if [ -z "$ZONE_1" ]; then
        ZONE_1="us-central1-a"
        print_warning "ZONE_1 not set, using default: $ZONE_1"
    fi
    
    if [ -z "$ZONE_2" ]; then
        ZONE_2="us-central1-b"  
        print_warning "ZONE_2 not set, using default: $ZONE_2"
    fi
    
    if [ -z "$REGION" ]; then
        REGION="us-central1"
        print_warning "REGION not set, using default: $REGION"
    fi
}

# Set up gcloud configuration
setup_gcloud() {
    print_status "Setting up gcloud configuration..."
    gcloud config set project $PROJECT_ID
    gcloud config set compute/zone $ZONE_1
    gcloud config set compute/region $REGION
    
    print_status "Current gcloud configuration:"
    gcloud config list
}

# Create VPC networks
create_networks() {
    print_status "Creating VPC networks..."
    
    # Create auto-mode network
    print_status "Creating mynetwork (auto-mode)..."
    gcloud compute networks create mynetwork --subnet-mode=auto
    
    # Create custom network
    print_status "Creating privatenet (custom-mode)..."
    gcloud compute networks create privatenet --subnet-mode=custom
}

# Create subnets
create_subnets() {
    print_status "Creating custom subnet..."
    gcloud compute networks subnets create privatesubnet \
        --network=privatenet \
        --region=$REGION \
        --range=10.0.0.0/24 \
        --enable-private-ip-google-access
}

# Create VM instances
create_instances() {
    print_status "Creating VM instances..."
    
    # Default network instance
    print_status "Creating default-vm-1..."
    gcloud compute instances create default-vm-1 \
        --machine-type=e2-micro \
        --zone=$ZONE_1 \
        --network=default \
        --no-user-output-enabled
    
    # MyNetwork instances
    print_status "Creating mynet-vm-1..."
    gcloud compute instances create mynet-vm-1 \
        --machine-type=e2-micro \
        --zone=$ZONE_1 \
        --network=mynetwork \
        --no-user-output-enabled
    
    print_status "Creating mynet-vm-2..."
    gcloud compute instances create mynet-vm-2 \
        --machine-type=e2-micro \
        --zone=$ZONE_2 \
        --network=mynetwork \
        --no-user-output-enabled
    
    # PrivateNet instances
    print_status "Creating privatenet-bastion..."
    gcloud compute instances create privatenet-bastion \
        --machine-type=e2-micro \
        --zone=$ZONE_1 \
        --subnet=privatesubnet \
        --can-ip-forward \
        --no-user-output-enabled
    
    print_status "Creating privatenet-vm-1..."
    gcloud compute instances create privatenet-vm-1 \
        --machine-type=e2-micro \
        --zone=$ZONE_1 \
        --subnet=privatesubnet \
        --no-user-output-enabled
}

# List created resources
list_resources() {
    print_status "Listing created resources..."
    
    echo -e "\n${GREEN}VPC Networks:${NC}"
    gcloud compute networks list
    
    echo -e "\n${GREEN}Subnets:${NC}"
    gcloud compute networks subnets list
    
    echo -e "\n${GREEN}VM Instances:${NC}"
    gcloud compute instances list
    
    echo -e "\n${GREEN}Firewall Rules:${NC}"
    gcloud compute firewall-rules list
}

# Main execution
main() {
    print_status "Starting GCP VPC Firewall Lab Setup..."
    
    check_variables
    setup_gcloud
    create_networks
    create_subnets
    create_instances
    list_resources
    
    print_status "Setup completed successfully!"
    print_warning "Next steps:"
    echo "1. Run the firewall configuration script: ./configure-firewall.sh"
    echo "2. Follow the testing procedures in the README.md"
    echo "3. Don't forget to clean up resources when done: ./cleanup.sh"
}

# Run main function
main "$@"