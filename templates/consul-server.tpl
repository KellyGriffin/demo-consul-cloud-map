#!/bin/bash
set -e

apt-get update && apt-get install -y unzip

# Get internal IP
LOCAL_IPV4=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

cd /tmp

# Add Go for debugging
wget https://dl.google.com/go/go1.13.4.linux-amd64.tar.gz -O ./go.tar.gz
tar -C /usr/local -xzf ./go.tar.gz

## Add go to the path
echo "export GOPATH=/home/ubuntu/go" >> /home/ubuntu/.bashrc
echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >> /home/ubuntu/.bashrc

# Fetch Consul
wget https://releases.hashicorp.com/consul/1.6.1/consul_1.6.1_linux_amd64.zip -O ./consul.zip
unzip ./consul.zip
mv ./consul /usr/local/bin

# Create the consul config
mkdir -p /etc/consul
cat << EOF > /etc/consul/config.hcl
data_dir = "/tmp/"
log_level = "DEBUG"
datacenter = "${dc}"
primary_datacenter = "${dc}"
server = true
bootstrap_expect = 1
ui = true
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"

ports {
  grpc = 8502
}
connect {
  enabled = true
}
enable_central_service_config = true
advertise_addr = "$${LOCAL_IPV4}"
# advertise_addr_wan = ""
# retry_join_wan = [""]

config_entries {
  bootstrap = [
    {
      kind = "proxy-defaults"
      name = "global"
      
      config {
        protocol = "http"
      }
      
      mesh_gateway = {
        mode = "local"
      }
    }
  ]
}
EOF

# Setup system D
cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description=Consul Server
After=syslog.target network.target
[Service]
ExecStart=/usr/local/bin/consul agent -config-file=/etc/consul/config.hcl
ExecStop=/bin/sleep 5
Restart=always
[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/consul.service

systemctl start consul.service

%{ if namespace_id != "" }
# Add Consul AWS 
wget https://releases.hashicorp.com/consul-aws/0.1.1/consul-aws_0.1.1_linux_amd64.zip -O consul-aws.zip
unzip consul-aws.zip
mv ./consul-aws /usr/local/bin

# Setup system D
cat << EOF > /etc/systemd/system/consul-aws.service
[Unit]
Description=Consul AWS Sync
After=syslog.target network.target
[Service]
ExecStart=/usr/local/bin/consul-aws sync-catalog -aws-namespace-id ${namespace_id} -to-aws -to-consul
ExecStop=/bin/sleep 5
Restart=always
Environment="AWS_REGION=${aws_region}"
[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/consul-aws.service

systemctl daemon-reload
systemctl start consul-aws.service

%{ endif }

systemctl daemon-reload
systemctl start consul.service