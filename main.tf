resource "random_string" "random" {
  length  = 8
  upper   = false
  special = false
}

resource "null_resource" "generate_certs" {
  provisioner "local-exec" {
    command = <<-EOT
      rm -rf ${var.build_folder}
      mkdir -p ${var.build_folder}
      cd ${var.build_folder}
      openssl genrsa -out ca.key 2048
      openssl req -new -x509 -days 3560 -key ca.key -out ca.crt -subj "/CN=ca"
      openssl genrsa -out server.key 2048
      openssl req -new -key server.key -out server.csr -subj "/CN=server.vpn.dev" -addext "keyUsage = digitalSignature,keyEncipherment" -addext "extendedKeyUsage = serverAuth"
      echo "keyUsage=digitalSignature,keyEncipherment" > server.ext
      echo "extendedKeyUsage=serverAuth" >> server.ext
      openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -extfile server.ext
      openssl genrsa -out client.key 2048
      openssl req -new -key client.key -out client.csr -subj "/CN=client.vpn.dev" -addext "keyUsage = digitalSignature,keyEncipherment" -addext "extendedKeyUsage = clientAuth"
      echo "keyUsage=digitalSignature,keyEncipherment" > client.ext
      echo "extendedKeyUsage=clientAuth" >> client.ext
      openssl x509 -req -days 3650 -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -extfile client.ext
    EOT
  }
}

data "local_file" "ca_cert" {
  filename   = "${var.build_folder}/ca.crt"
  depends_on = [null_resource.generate_certs]
}

data "local_file" "server_key" {
  filename   = "${var.build_folder}/server.key"
  depends_on = [null_resource.generate_certs]
}

data "local_file" "server_cert" {
  filename   = "${var.build_folder}/server.crt"
  depends_on = [null_resource.generate_certs]
}

data "local_file" "client_key" {
  filename   = "${var.build_folder}/client.key"
  depends_on = [null_resource.generate_certs]
}

data "local_file" "client_cert" {
  filename   = "${var.build_folder}/client.crt"
  depends_on = [null_resource.generate_certs]
}

data "aws_region" "current" {}

resource "aws_acm_certificate" "server" {
  certificate_body  = data.local_file.server_cert.content
  private_key       = data.local_file.server_key.content
  certificate_chain = data.local_file.ca_cert.content
}

resource "aws_acm_certificate" "client" {
  certificate_body  = data.local_file.client_cert.content
  private_key       = data.local_file.client_key.content
  certificate_chain = data.local_file.ca_cert.content
}

locals {
  client_vpn_file = "${var.build_folder}/client-vpn-${data.aws_region.current.region}-${random_string.random.result}.ovpn"
  vpc_base        = cidrhost(var.vpc_cidr_block, 0)
  vpc_mask        = cidrnetmask(var.vpc_cidr_block)
}

resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = "Client VPN Endpoint"
  server_certificate_arn = aws_acm_certificate.server.arn
  client_cidr_block      = var.client_cidr_block
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client.arn
  }
  connection_log_options {
    enabled = false
  }

  vpc_id = var.vpc_id
}

resource "aws_ec2_client_vpn_network_association" "main" {
  count                  = length(var.subnet_ids)
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = var.subnet_ids[count.index]
}

resource "aws_ec2_client_vpn_authorization_rule" "main" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = var.vpc_cidr_block
  authorize_all_groups   = true
}

resource "null_resource" "get_cliet_config" {
  triggers = {
    client_vpn_file = local.client_vpn_file
    vpc_base        = local.vpc_base
    vpc_mask        = local.vpc_mask
    endpoint_id     = aws_ec2_client_vpn_endpoint.main.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 export-client-vpn-client-configuration --region ${data.aws_region.current.region} \
        --client-vpn-endpoint-id ${self.triggers.endpoint_id} \
        --output text > ${self.triggers.client_vpn_file}

      sed -i '' '/^verb 3$/a\
tun-mtu 1400\
mssfix 1360\
route-nopull\
route ${self.triggers.vpc_base} ${self.triggers.vpc_mask}\
' ${self.triggers.client_vpn_file}
      echo "" >> ${self.triggers.client_vpn_file}
      echo "<cert>" >> ${self.triggers.client_vpn_file}
      cat ${var.build_folder}/client.crt >> ${self.triggers.client_vpn_file}
      echo "</cert>" >> ${self.triggers.client_vpn_file}
      echo "<key>" >> ${self.triggers.client_vpn_file}
      cat ${var.build_folder}/client.key >> ${self.triggers.client_vpn_file}
      echo "</key>" >> ${self.triggers.client_vpn_file}
    EOT
  }

  depends_on = [
    aws_ec2_client_vpn_network_association.main,
    aws_ec2_client_vpn_authorization_rule.main
  ]
}
