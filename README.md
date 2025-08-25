# Terraform AWS Client VPN Module

A Terraform module that creates an AWS Client VPN endpoint with automatic certificate generation and client configuration.

## Features

- Automatic SSL certificate generation for server and client authentication
- AWS Client VPN endpoint creation with certificate-based authentication
- Network association with specified subnets
- Authorization rules for VPC access
- Automatic client configuration file generation (.ovpn)
- Route optimization for VPC-only traffic

## Prerequisites

- Terraform >= 0.12
- AWS CLI configured with appropriate permissions
- OpenSSL installed on the local machine

## Usage

```hcl
module "client_vpn" {
  source = "./terraform-aws-clientvpn"

  vpc_id            = "vpc-xxxxxxxxx"
  vpc_cidr_block    = "10.0.0.0/16"
  subnet_ids        = ["subnet-xxxxxxxxx", "subnet-yyyyyyyyy"]
  client_cidr_block = "10.1.0.0/16"
  build_folder      = ".build/clientvpn"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vpc_id | The VPC ID to create ClientVPN endpoint | `string` | n/a | yes |
| subnet_ids | The list of subnet IDs to be associated with ClientVPN endpoint | `list(string)` | n/a | yes |
| vpc_cidr_block | The CIDR block of the VPC, used to split traffic | `string` | n/a | yes |
| client_cidr_block | The CIDR block of the ClientVPN | `string` | n/a | yes |
| build_folder | The build folder that stores generated client certificate | `string` | `.build/clientvpn` | no |

## Outputs

The module generates:
- SSL certificates (CA, server, and client) in the specified build folder
- Client VPN configuration file (.ovpn) ready for use with OpenVPN clients

## What Gets Created

1. **SSL Certificates**: CA, server, and client certificates with proper extensions
2. **ACM Certificates**: Server and client certificates uploaded to AWS Certificate Manager
3. **Client VPN Endpoint**: AWS Client VPN endpoint with certificate authentication
4. **Network Associations**: Associates the VPN endpoint with specified subnets
5. **Authorization Rules**: Allows access to the VPC CIDR block
6. **Client Configuration**: Ready-to-use .ovpn file with optimized settings

## Client Configuration

The module automatically generates an OpenVPN configuration file with:
- Optimized MTU settings (1400) and MSS fix (1360)
- Route-nopull configuration to prevent pulling all routes
- Specific route for VPC CIDR only
- Embedded client certificates

## Example

```hcl
module "client_vpn" {
  source = "./terraform-aws-clientvpn"

  vpc_id            = "vpc-0c58e7039aca111a9"
  vpc_cidr_block    = "10.0.0.0/16"
  subnet_ids        = ["subnet-0d9173288ff52e115"]
  client_cidr_block = "10.1.0.0/16"
}
```

## Using the VPN Client

After running `terraform apply`, the module generates a `.ovpn` configuration file in your build folder.

1. Install an OpenVPN client software on your device
2. Import the generated `.ovpn` file into your OpenVPN client
3. Connect to the VPN through your client

## Notes

- The client configuration file will be created at `{build_folder}/client-vpn-{region}-{random}.ovpn`
- Certificates are valid for 10 years (3650 days)
- The module uses certificate-based authentication (mutual TLS)
- Only VPC traffic is routed through the VPN (split tunneling)

## Cleanup

When destroying the infrastructure, the build folder and certificates will remain on your local machine. You may want to clean them up manually if needed.