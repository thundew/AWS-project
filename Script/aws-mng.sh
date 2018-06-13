#!/bin/bash
VPC_NAME="CastVPC"
VPC_CIDR="10.0.0.0/16"
SUBNET_PUBLIC_CIDR="10.0.10.0/24"
SUBNET_PUBLIC_NAME="PublicCast"
SUBNET_PRIVATE_CIDR="10.0.20.0/24"
SUBNET_PRIVATE_NAME="PrivateCast"

#echo "Select neccesary:"
#echo "1 Create a network Stack"
#echo "2 Delete all"
#echo "3 Exit"
#read doing
case $1 in

create)
  case $2 in 
  vpc)
  #Creating of VPC
  VPC_ID=$(aws ec2 create-vpc \
   --cidr-block $VPC_CIDR \
   --query 'Vpc.{VpcId:VpcId}' \
   --output text)

  # Add Name tag to VPC
  aws ec2 create-tags \
    --resources $VPC_ID \
    --tags "Key=Name,Value=$VPC_NAME" \

  # Create Public Subnet
  SUBNET_PUBLIC_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $SUBNET_PUBLIC_CIDR \
    --query 'Subnet.{SubnetId:SubnetId}' \
    --output text)

  # Add Name tag to Public Subnet
  aws ec2 create-tags \
      --resources $SUBNET_PUBLIC_ID \
      --tags "Key=Name,Value=$SUBNET_PUBLIC_NAME" \

  # Create Private Subnet
  SUBNET_PRIVATE_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $SUBNET_PRIVATE_CIDR \
    --query 'Subnet.{SubnetId:SubnetId}' \
    --output text)

  # Add Name tag to Private Subnet
  aws ec2 create-tags \
    --resources $SUBNET_PRIVATE_ID \
    --tags "Key=Name,Value=$SUBNET_PRIVATE_NAME"
  echo "Comlete Creating of network"

  # Create Internet gateway
  IGW_ID=$(aws ec2 create-internet-gateway \
    --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' \
    --output text)

  # Attach Internet gateway to your VPC
  aws ec2 attach-internet-gateway \
    --vpc-id $VPC_ID \
    --internet-gateway-id $IGW_ID

  # Create Route Table
  ROUTE_TABLE_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --query 'RouteTable.{RouteTableId:RouteTableId}' \
    --output text)

  # Create route to Internet Gateway
  RESULT=$(aws ec2 create-route \
    --route-table-id $ROUTE_TABLE_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID)

  # Associate Public Subnet with Route Table
  RESULT=$(aws ec2 associate-route-table  \
    --subnet-id $SUBNET_PUBLIC_ID \
    --route-table-id $ROUTE_TABLE_ID)

  # Enable Auto-assign Public IP on Public Subnet
  aws ec2 modify-subnet-attribute \
    --subnet-id $SUBNET_PUBLIC_ID \
    --map-public-ip-on-launch

  # Allocate Elastic IP Address for NAT Gateway
  EIP_ALLOC_ID=$(aws ec2 allocate-address \
    --domain vpc \
    --query '{AllocationId:AllocationId}' \
    --output text)

  # Create NAT Gateway
  NAT_GW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $SUBNET_PUBLIC_ID \
    --allocation-id $EIP_ALLOC_ID \
    --query 'NatGateway.{NatGatewayId:NatGatewayId}' \
    --output text)

   echo " NAT Gateway ID '$NAT_GW_ID' is now AVAILABLE "

  # Create route to NAT Gateway
  MAIN_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
    --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true \
    --query 'RouteTables[*].{RouteTableId:RouteTableId}' \
    --output text)

  RESULT=$(aws ec2 create-route \
    --route-table-id $MAIN_ROUTE_TABLE_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $NAT_GW_ID)
  echo "Comlete Internet Stack"

  # Run instances 1 Public
  INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-14c5486b \
  --count 2 \
  --instance-type t2.micro \
  --key-name CastVirginia \
  --subnet-id $SUBNET_PUBLIC_ID \
  --query 'Instance.{InstanceId:InstanceId}'\
  --output text)

  # Run instances 2 Private
  INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-14c5486b \
  --count 1 \
  --instance-type t2.micro \
  --key-name CastVirginia \
  --subnet-id $SUBNET_PRIVATE_ID \
  --query 'Instance.{InstanceId:InstanceId}'\
  --output text)
  echo "Launched instances"
  ;;

#  2)
#  aws ec2 terminate-instances\
#  --instance-ids $(aws ec2 describe-instances\
#  --filters  "Name=instance-state-name,Values=pending,running,stopped,stopping"\
#  --query "Reservations[].Instances[].[InstanceId]"\
#  --output text | tr '\n' ' ')
#
#  aws ec2 delete-nat-gateway\
#  --nat-gateway-id $(aws ec2 describe-nat-gateways\
#  --query 'NatGateways[*].{NatGatewayId:NatGatewayId}' \
#  --output text)
#
#  aws ec2 disassociate-address\
#  --association-id $(aws ec2 describe-addresses\
#  --filters "Name=domain,Values=vpc"\
#  --query 'Addresses[*].{AllocationId:AllocationId}'\
#  --output text)
#
#  aws ec2 release-address\
#  --allocation-id $(aws ec2 describe-addresses\
#  --filters "Name=domain,Values=vpc"\
#  --query 'Addresses[*].{AllocationId:AllocationId}'\
#  --output text)
#
#  aws ec2 detach-internet-gateway \
#  --internet-gateway-id $(aws ec2 describe-internet-gateways \
#  --query 'InternetGateways[*].{InternetGatewayId:InternetGatewayId}' \
#  --output text)\
#  --vpc-id $(aws ec2 describe-vpcs\
#  --query 'Vpcs[1].{VpcId:VpcId}'\
#  --output text)
#
#  aws ec2 delete-internet-gateway\
#  --internet-gateway-id $(aws ec2 describe-internet-gateways \
#  --query 'InternetGateways[*].{InternetGatewayId:InternetGatewayId}' \
#  --output text)
#
#  aws ec2 delete-route-table\
#  --route-table-id $(aws ec2 describe-route-tables \
#  --query 'RouteTables[*].{RouteTableId:RouteTableId}'\
#  --output text)
#
#  aws ec2 delete-vpc\
#  --vpc-id $(aws ec2 describe-vpcs\
#  --query 'Vpcs[1].{VpcId:VpcId}'\
#  --output text)
#  echo "Sector clear :)"
#  ;;

  exit )
  exit 0
  echo "Bye Bye"
  ;;

  *) echo "Incorrect Value"

  esac
