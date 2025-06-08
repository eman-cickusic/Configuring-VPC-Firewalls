#!/bin/bash

# GCP VPC Firewall Configuration Script
# This script configures firewall rules for the VPC lab

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed"
        exit 1
    fi
    
    # Check if networks exist
    if ! gcloud compute networks describe mynetwork &> /dev/null; then
        print_error "mynetwork does not exist. Run setup.sh first."
        exit 1
    fi
    
    print_status "Prerequisites check passed!"
}

# Get Cloud Shell external IP
get_external_ip() {
    print_step "Getting Cloud Shell external IP address..."
    EXTERNAL_IP=$(curl -s https://api.ipify.org)
    
    if [ -z "$EXTERNAL_IP" ]; then
        print_error "Failed to get external IP address"
        exit 1
    fi
    
    print_status "External IP address: $EXTERNAL_IP"
}

# Create SSH firewall rule
create_ssh_rule() {
    print_step "Creating SSH firewall rule for Cloud Shell access..."
    
    gcloud compute firewall-rules create \
        mynetwork-ingress-allow-ssh-from-cs \
        --network=mynetwork \
        --action=ALLOW \
        --direction=INGRESS \
        --rules=tcp:22 \
        --source-ranges=$EXTERNAL_IP \
        --target-tags=lab-ssh \
        --description="Allow SSH from Cloud Shell IP"
    
    print_status "SSH firewall rule created successfully!"
}

# Add network tags to instances
add_network_tags() {
    print_step "Adding lab-ssh tags to instances..."
    
    # Get zones from instances
    ZONE_1=$(gcloud compute instances list --filter="name:mynet-vm-1" --format="value(zone)" | sed 's|.*/||')
    ZONE_2=$(gcloud compute instances list --filter="name:mynet-vm-2" --format="value(zone)" | sed 's|.*/||')
    
    if [ -z "$ZONE_1" ] || [ -z "$ZONE_2" ]; then
        print_error "Could not determine instance zones"
        exit 1
    fi
    
    gcloud compute instances add-tags mynet-vm-1 \
        --zone=$ZONE_1 \
        --tags=lab-ssh
    
    gcloud compute instances add-tags mynet-vm-2 \
        --zone=$ZONE_2 \
        --tags=lab-ssh
    
    print_status "Network tags added successfully!"
}

# Create internal ICMP rule
create_icmp_rule() {
    print_step "Creating internal ICMP firewall rule..."
    
    gcloud compute firewall-rules create \
        mynetwork-ingress-allow-icmp-internal \
        --network=mynetwork \
        --action=ALLOW \
        --direction=INGRESS \
        --rules=icmp \
        --source-ranges=10.128.0.0/9 \
        --description="Allow ICMP between internal instances"
    
    print_status "Internal ICMP rule created successfully!"
}

# Test SSH connectivity
test_ssh_connectivity() {
    print_step "Testing SSH connectivity..."
    
    ZONE_2=$(gcloud compute instances list --filter="name:mynet-vm-2" --format="value(zone)" | sed 's|.*/||')
    
    print_status "Attempting SSH connection to mynet-vm-2..."
    print_warning "This will open an SSH session. Type 'exit' to return to this script."
    
    gcloud compute ssh qwiklabs@mynet-vm-2 --zone=$ZONE_2 || {
        print_warning "SSH connection failed or was terminated by user"
    }
}

# Create priority-based rules (demonstration)
create_priority_rules() {
    print_step "Creating priority-based firewall rules for demonstration..."
    
    # Create deny rule with high priority (low number)
    print_status "Creating high-priority ICMP deny rule..."
    gcloud compute firewall-rules create \
        mynetwork-ingress-deny-icmp-all \
        --network=mynetwork \
        --action=DENY \
        --direction=INGRESS \
        --rules=icmp \
        --priority=500 \
        --description="Deny all ICMP traffic (high priority)"
    
    print_warning "ICMP traffic is now blocked due to high-priority deny rule"
    
    # Update priority to demonstrate priority changes
    print_status "Updating deny rule priority to 2000..."
    gcloud compute firewall-rules update \
        mynetwork-ingress-deny-icmp-all \
        --priority=2000
    
    print_status "ICMP traffic should now work again (allow rule has higher priority)"
}

# Create egress rule
create_egress_rule() {
    print_step "Creating egress firewall rule..."
    
    gcloud compute firewall-rules create \
        mynetwork-egress-deny-icmp-all \
        --network=mynetwork \
        --action=DENY \
        --direction=EGRESS \
        --rules=icmp \
        --priority=10000 \
        --description="Deny all outbound ICMP traffic"
    
    print_warning "Egress ICMP traffic is now blocked"
}

# List all firewall rules
list_firewall_rules() {
    print_step "Listing all firewall rules for mynetwork..."
    
    echo -e "\n${GREEN}Firewall Rules for mynetwork:${NC}"
    gcloud compute firewall-rules list --filter="network:mynetwork" \
        --format="table(name,direction,priority,sourceRanges:label=SRC_RANGES,allowed[].map().firewall_rule().list():label=ALLOW,targetTags:label=TARGET_TAGS)"
}

# Interactive menu
show_menu() {
    echo -e "\n${BLUE}=== Firewall Configuration Menu ===${NC}"
    echo "1. Create SSH access rule"
    echo "2. Create internal ICMP rule"  
    echo "3. Test SSH connectivity"
    echo "4. Create priority demonstration rules"
    echo "5. Create egress rule"
    echo "6. List all firewall rules"
    echo "7. Run all configurations"
    echo "8. Exit"
    echo -n "Choose an option [1-8]: "
}

# Interactive mode
interactive_mode() {
    print_status "Starting interactive firewall configuration..."
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                get_external_ip
                create_ssh_rule
                add_network_tags
                ;;
            2)
                create_icmp_rule
                ;;
            3)
                test_ssh_connectivity
                ;;
            4)
                create_priority_rules
                ;;
            5)
                create_egress_rule
                ;;
            6)
                list_firewall_rules
                ;;
            7)
                run_all_configurations
                ;;
            8)
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-8."
                ;;
        esac
        
        echo -e "\nPress Enter to continue..."
        read -r
    done
}

# Run all configurations
run_all_configurations() {
    print_status "Running all firewall configurations..."
    
    get_external_ip
    create_ssh_rule
    add_network_tags
    create_icmp_rule
    create_priority_rules
    create_egress_rule
    list_firewall_rules
    
    print_status "All firewall configurations completed!"
}

# Main execution
main() {
    print_status "Starting GCP VPC Firewall Configuration..."
    
    check_prerequisites
    
    # Check command line arguments
    if [ "$1" = "--all" ] || [ "$1" = "-a" ]; then
        run_all_configurations
    elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "Usage: $0 [--all|-a] [--help|-h]"
        echo "  --all, -a    Run all configurations automatically"
        echo "  --help, -h   Show this help message"
        echo "  (no args)    Run in interactive mode"
        exit 0
    else
        interactive_mode
    fi
}

# Run main function
main "$@"