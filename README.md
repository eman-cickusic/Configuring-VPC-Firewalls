# Configuring VPC Firewalls

This repository contains the complete implementation and documentation for configuring Virtual Private Cloud (VPC) networks and firewall rules in Google Cloud Platform.

## Video 

https://youtu.be/3xC4xfAwOy8

## Overview  

This lab demonstrates how to create and manage VPC networks, configure firewall rules, and control network traffic between instances. The project covers both automatic and custom VPC networks, investigating default firewall behavior, and implementing custom ingress/egress rules with priority management.

## Lab Objectives

- Create an auto-mode network, a custom-mode network, and associated subnetworks
- Investigate firewall rules in the default network and then delete the default network
- Use features of firewall rules for more precise and flexible control of connections
- Understand firewall rule priorities and their impact on traffic flow
- Configure both ingress and egress firewall rules

## Architecture

The lab creates the following network infrastructure:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Default Net   │    │   MyNetwork     │    │   PrivateNet    │
│                 │    │   (Auto-mode)   │    │   (Custom-mode) │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│  default-vm-1   │    │   mynet-vm-1    │    │ privatenet-vm-1 │
│                 │    │   mynet-vm-2    │    │privatenet-bastion│
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Prerequisites

- Google Cloud Platform account
- Access to Google Cloud Console
- Google Cloud Shell access
- Basic understanding of networking concepts

## Files in This Repository

- `README.md` - This documentation file
- `setup-networks.sh` - Script to create VPC networks and instances
- `setup-firewall-rules.sh` - Script to configure firewall rules
- `cleanup.sh` - Script to clean up resources
- `test-connectivity.sh` - Script to test network connectivity
- `lab-instructions.md` - Detailed step-by-step instructions

## Quick Start

1. **Clone this repository:**
   ```bash
   git clone https://github.com/yourusername/gcp-vpc-firewall-lab.git
   cd gcp-vpc-firewall-lab
   ```

2. **Set up your Google Cloud environment:**
   ```bash
   # Authenticate with Google Cloud
   gcloud auth login
   
   # Set your project ID
   export PROJECT_ID=your-project-id
   gcloud config set project $PROJECT_ID
   ```

3. **Run the setup scripts:**
   ```bash
   # Make scripts executable
   chmod +x *.sh
   
   # Create networks and instances
   ./setup-networks.sh
   
   # Configure firewall rules
   ./setup-firewall-rules.sh
   ```

4. **Test connectivity:**
   ```bash
   ./test-connectivity.sh
   ```

## Detailed Implementation

### Task 1: Create VPC Networks and Instances

The lab creates three types of networks:

1. **Default Network** - Pre-configured with standard firewall rules
2. **Auto-mode Network (mynetwork)** - Automatically creates subnets in each region
3. **Custom Network (privatenet)** - Manually configured subnets

```bash
# Create auto-mode network
gcloud compute networks create mynetwork --subnet-mode=auto

# Create custom network
gcloud compute networks create privatenet --subnet-mode=custom

# Create custom subnet
gcloud compute networks subnets create privatesubnet \
--network=privatenet --region=us-central1 \
--range=10.0.0.0/24 --enable-private-ip-google-access
```

### Task 2: Investigate Default Network

The default network comes with four pre-configured firewall rules:
- `default-allow-icmp` - Allows ICMP traffic
- `default-allow-internal` - Allows internal communication
- `default-allow-rdp` - Allows RDP traffic (port 3389)
- `default-allow-ssh` - Allows SSH traffic (port 22)

### Task 3: Custom Network Behavior

Unlike the default network, custom networks have no ingress rules by default, meaning:
- All incoming traffic is blocked
- Only outgoing traffic is allowed
- SSH access requires custom firewall rules

### Task 4: Custom Ingress Firewall Rules

Key concepts demonstrated:

1. **Target Tags** - Apply rules to specific instances
2. **Source Ranges** - Control which IP addresses can access resources
3. **Stateful Firewalls** - Return traffic is automatically allowed

```bash
# Allow SSH from Cloud Shell IP
gcloud compute firewall-rules create \
mynetwork-ingress-allow-ssh-from-cs \
--network mynetwork --action ALLOW --direction INGRESS \
--rules tcp:22 --source-ranges $CLOUD_SHELL_IP --target-tags=lab-ssh

# Allow ICMP between internal instances
gcloud compute firewall-rules create \
mynetwork-ingress-allow-icmp-internal --network \
mynetwork --action ALLOW --direction INGRESS --rules icmp \
--source-ranges 10.128.0.0/9
```

### Task 5: Firewall Rule Priority

Firewall rules are evaluated based on priority (0-65535, lower numbers = higher priority):
- Default priority: 1000
- Rules are evaluated from lowest to highest priority
- First matching rule is applied

```bash
# Create deny rule with high priority (500)
gcloud compute firewall-rules create \
mynetwork-ingress-deny-icmp-all --network \
mynetwork --action DENY --direction INGRESS --rules icmp \
--priority 500
```

### Task 6: Egress Firewall Rules

Demonstrates that both ingress AND egress rules must allow traffic:

```bash
# Block outgoing ICMP traffic
gcloud compute firewall-rules create \
mynetwork-egress-deny-icmp-all --network \
mynetwork --action DENY --direction EGRESS --rules icmp \
--priority 10000
```

## Testing and Validation

### SSH Connectivity Test
```bash
# Test SSH to instances with proper tags
gcloud compute ssh qwiklabs@mynet-vm-1 --zone us-central1-a
gcloud compute ssh qwiklabs@mynet-vm-2 --zone us-central1-b
```

### ICMP (Ping) Connectivity Test
```bash
# Test internal ping between instances
ping mynet-vm-2.us-central1-b.c.PROJECT_ID.internal
```

### External IP Test
```bash
# Test ping to external IP (should fail with internal-only rules)
ping EXTERNAL_IP_OF_INSTANCE
```

## Key Learning Points

1. **Default vs Custom Networks**: Default networks have permissive firewall rules, custom networks start with deny-all
2. **Firewall Rule Components**: Direction, Action, Protocol/Port, Source/Target, Priority
3. **Stateful Nature**: Return traffic is automatically allowed for established connections
4. **Priority Evaluation**: Lower priority numbers take precedence
5. **Ingress vs Egress**: Both directions must be explicitly allowed
6. **Target Tags**: Provide granular control over which instances rules apply to

## Security Best Practices

- Delete default networks in production environments
- Use principle of least privilege for firewall rules
- Implement specific source ranges instead of 0.0.0.0/0
- Use target tags for granular instance targeting
- Regularly audit and review firewall rules
- Monitor network traffic and access patterns

## Troubleshooting

### Common Issues

1. **SSH Connection Fails**
   - Verify firewall rule allows your source IP
   - Check if instance has proper network tags
   - Ensure rule priority allows the connection

2. **Ping Not Working**
   - Check both ingress and egress ICMP rules
   - Verify source ranges include the source IP
   - Check rule priorities for conflicts

3. **External IP Ping Fails**
   - Expected behavior when using internal-only firewall rules
   - External IP traffic is NATed and appears from different source

### Debugging Commands

```bash
# List all firewall rules for a network
gcloud compute firewall-rules list --filter="network:mynetwork"

# Describe specific firewall rule
gcloud compute firewall-rules describe RULE_NAME

# Check instance tags
gcloud compute instances describe INSTANCE_NAME --zone=ZONE

# Get external IP of Cloud Shell
curl -s https://api.ipify.org
```

## Cleanup

To avoid ongoing charges, clean up resources when done:

```bash
./cleanup.sh
```

Or manually:
```bash
# Delete instances
gcloud compute instances delete mynet-vm-1 mynet-vm-2 privatenet-vm-1 privatenet-bastion

# Delete firewall rules
gcloud compute firewall-rules delete mynetwork-ingress-allow-ssh-from-cs
gcloud compute firewall-rules delete mynetwork-ingress-allow-icmp-internal

# Delete networks
gcloud compute networks delete mynetwork privatenet
```

## Additional Resources

- [Google Cloud VPC Documentation](https://cloud.google.com/vpc/docs)
- [Firewall Rules Overview](https://cloud.google.com/vpc/docs/firewalls)
- [VPC Network Pricing](https://cloud.google.com/vpc/network-pricing)
- [Best Practices for VPC Design](https://cloud.google.com/vpc/docs/best-practices)

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Note**: This lab is designed for educational purposes. Always follow your organization's security policies and Google Cloud best practices in production environments.
