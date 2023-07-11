#!/bin/bash

# A script that creates a new EC2 instance using the AWS CLI and then connects to using SSH

# Requirements:
# - the script needs to be stored in /.aws
# - there need to be configured IAM users 
# - the security group selected needs to allow SSH
# - the key selected needs to be in /.aws

# Prints out all IAM configured profiles
print_out_configured_profiles() {
	echo "Configured profiles:"
	configured_IAM_profiles=($(aws configure list-profiles))
    for i in "${configured_IAM_profiles[@]}"
    do
        echo "$i"
    done
}

# Allows the user to select a profile
check_profile() {
    local profile_exists=false
    while [[ "$profile_exists" = false ]];  do
        print_out_configured_profiles
        read -p "Enter the profile you want to use: " selected_profile
        for i in "${configured_IAM_profiles[@]}"
        do
            if [[ "$selected_profile" == "$i" ]]; then
                profile_exists=true
                echo "Profile exists"
                break
            else
                echo "Profile does not exist"
                continue
            fi
        done
    done
}

# Prints out all key names
print_out_keys() {
	echo "Key pairs:"
	key_names=($(aws ec2 describe-key-pairs --query 'KeyPairs[].KeyName' --output text --profile $selected_profile))
    for i in "${key_names[@]}"
    do
        echo "$i"
    done
}

# Allows a user to select a key
check_key() {
    local key_exists=false
    while [[ "$key_exists" = false ]];  do
        print_out_keys
        read -p "Enter the key you want to use: " selected_key
        for i in "${key_names[@]}"
        do
            if [[ "$selected_key" == "$i" ]]; then
                key_exists=true
                echo "Key exists"
                break
            else
                echo "Key does not exist"
                continue
            fi
        done
    done
}

# Prints out all security groups
print_out_security_groups() {
	echo "Security groups:"
	security_groups=($(aws ec2 describe-security-groups --query 'SecurityGroups[].GroupId' --output text --profile $selected_profile))
    for i in "${security_groups[@]}"
    do
        echo "$i"
    done
}

# Allows a user to select a security group
check_security_group() {
    local security_group_exists=false
    while [[ "$security_group_exists" = false ]];  do
        print_out_security_groups
        read -p "Enter the security group you want to use: " selected_security_group
        for i in "${security_groups[@]}"
        do
            if [[ "$selected_security_group" == "$i" ]]; then
                security_group_exists=true
                echo "Security group exists"
                break
            else
                echo "Security group does not exist"
                continue
            fi
        done
    done
}

# Creates an EC2 intance
create_ec2_instance() {
    ec2_instance_id=($(aws ec2 run-instances --image-id ami-04e601abe3e1a910f --count 1 --instance-type t2.micro --key-name "$selected_key" \
    --security-group-ids "$selected_security_group" --profile "$selected_profile" --query 'Instances[0].InstanceId' --output text))
}

# Checks the EC2 instance status
check_ec2_instance() {
    local ec2_instance_status=false
    while [[ "$ec2_instance_status" = false ]]; do
        local var1=$(aws ec2 describe-instance-status --instance-ids "$ec2_instance_id" --profile "$selected_profile" \
        --query 'InstanceStatuses[].InstanceStatus[].Status' --output text)

        local var2=$(aws ec2 describe-instance-status --instance-ids "$ec2_instance_id" --profile "$selected_profile" \
        --query 'InstanceStatuses[].SystemStatus[].Status' --output text)

        if [[ $var1 == "ok" && $var2 == "ok" ]]; then
            ec2_instance_status=true
            echo "Status checks passed"
        else
            echo "Initializing status checks..."
            sleep 15s
        fi
    done
}

# Connects to the EC2 instance created using SSH
connect_ec2_instance() {
    echo "Using SSH to connect to the instance created"
    ec2_instance_publicDNSname=($(aws ec2 describe-instances --instance-ids "$ec2_instance_id" \
    --profile "$selected_profile" --query 'Reservations[].Instances[].PublicDnsName' --output text))
    ssh -i "./${selected_key}.pem" "ubuntu@${ec2_instance_publicDNSname}"
}


check_profile
check_key
check_security_group
create_ec2_instance
check_ec2_instance
connect_ec2_instance