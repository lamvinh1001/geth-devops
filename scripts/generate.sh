#!/bin/bash
# Complete Ansible Configuration for Monitoring Setup
# Based on your Terraform outputs

# Create directory structure
mkdir -p ansible/{inventory,playbooks,roles,group_vars}
mkdir -p ansible/roles/{node_exporter,prometheus,grafana}/{tasks,handlers,templates,files,vars,defaults}

# =============================================================================
# ANSIBLE CONFIGURATION
# =============================================================================

cat > ansible/ansible.cfg << 'EOF'
[defaults]
inventory = inventory/hosts.yml
private_key_file = ~/.ssh/ethereum-devops-ssh-key.pem
host_key_checking = False
remote_user = ubuntu
gathering = smart
fact_caching = memory
stdout_callback = yaml
pipelining = True
forks = 10
timeout = 30
retry_files_enabled = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
control_path_dir = /tmp/.ansible-cp
control_path = %(directory)s/%%h-%%p-%%r
EOF

# =============================================================================
# INVENTORY CONFIGURATION
# =============================================================================

cat > ansible/inventory/hosts.yml << 'EOF'
---
all:
  vars:
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    ansible_python_interpreter: /usr/bin/python3

geth_nodes:
  hosts:
    geth-1:
      ansible_host: 10.0.1.36
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q ubuntu@54.255.190.26 -i ~/.ssh/ethereum-devops-ssh-key.pem"'
  vars:
    node_role: geth

monitoring:
  hosts:
    prometheus-grafana:
      ansible_host: 54.169.158.134
  vars:
    node_role: monitoring

bastion:
  hosts:
    bastion-host:
      ansible_host: 54.255.190.26
  vars:
    node_role: bastion
EOF

# =============================================================================
# GROUP VARIABLES
# =============================================================================

cat > ansible/group_vars/all.yml << 'EOF'
---
# Common variables
ansible_ssh_private_key_file: ~/.ssh/ethereum-devops-ssh-key.pem
ansible_user: ubuntu

# Monitoring versions
node_exporter_version: "1.7.0"
prometheus_version: "2.48.1"
grafana_version: "10.2.3"

# Network configuration
prometheus_port: 9090
grafana_port: 3000
node_exporter_port: 9100

# Prometheus configuration
prometheus_config_dir: /etc/prometheus
prometheus_data_dir: /var/lib/prometheus
prometheus_user: prometheus

# Grafana configuration
grafana_config_dir: /etc/grafana
grafana_data_dir: /var/lib/grafana
grafana_user: grafana

# Node Exporter configuration
node_exporter_user: node_exporter
EOF

cat > ansible/group_vars/geth_nodes.yml << 'EOF'
---
# Geth nodes specific variables
install_node_exporter: true
node_exporter_enabled_collectors:
  - systemd
  - textfile
  - filesystem
  - cpu
  - diskstats
  - loadavg
  - meminfo
  - netdev
  - netstat
  - stat
  - time
  - uname
EOF

cat > ansible/group_vars/monitoring.yml << 'EOF'
---
# Monitoring server specific variables
install_prometheus: true
install_grafana: true

# Prometheus targets (based on your infrastructure)
prometheus_targets:
  - job_name: 'node-exporter'
    static_configs:
      - targets:
          - '10.0.1.36:9100'  # geth-1 node

# Grafana admin credentials
grafana_admin_user: admin
grafana_admin_password: admin123  # Change this in production
EOF

# =============================================================================
# MAIN PLAYBOOK
# =============================================================================

cat > ansible/playbooks/monitoring.yml << 'EOF'
---
- name: Setup Node Exporter on Geth Nodes
  hosts: geth_nodes
  become: yes
  roles:
    - node_exporter
  tags:
    - node_exporter
    - geth

- name: Setup Prometheus and Grafana
  hosts: monitoring
  become: yes
  roles:
    - prometheus
    - grafana
  tags:
    - monitoring
    - prometheus
    - grafana
EOF

# =============================================================================
# NODE EXPORTER ROLE
# =============================================================================

cat > ansible/roles/node_exporter/defaults/main.yml << 'EOF'
---
node_exporter_version: "1.7.0"
node_exporter_port: 9100
node_exporter_user: node_exporter
node_exporter_group: node_exporter
node_exporter_binary_path: /usr/local/bin/node_exporter
node_exporter_config_dir: /etc/node_exporter
node_exporter_textfile_dir: /var/lib/node_exporter/textfile_collector
EOF

cat > ansible/roles/node_exporter/tasks/main.yml << 'EOF'
---
- name: Create node_exporter group
  group:
    name: "{{ node_exporter_group }}"
    system: yes

- name: Create node_exporter user
  user:
    name: "{{ node_exporter_user }}"
    group: "{{ node_exporter_group }}"
    system: yes
    shell: /bin/false
    home: /var/lib/node_exporter
    create_home: no

- name: Create node_exporter directories
  file:
    path: "{{ item }}"
    state: directory
    owner: "{{ node_exporter_user }}"
    group: "{{ node_exporter_group }}"
    mode: '0755'
  loop:
    - /var/lib/node_exporter
    - "{{ node_exporter_textfile_dir }}"

- name: Download node_exporter
  get_url:
    url: "https://github.com/prometheus/node_exporter/releases/download/v{{ node_exporter_version }}/node_exporter-{{ node_exporter_version }}.linux-amd64.tar.gz"
    dest: /tmp/node_exporter.tar.gz
    mode: '0644'

- name: Extract node_exporter
  unarchive:
    src: /tmp/node_exporter.tar.gz
    dest: /tmp
    remote_src: yes
    creates: "/tmp/node_exporter-{{ node_exporter_version }}.linux-amd64"

- name: Copy node_exporter binary
  copy:
    src: "/tmp/node_exporter-{{ node_exporter_version }}.linux-amd64/node_exporter"
    dest: "{{ node_exporter_binary_path }}"
    owner: root
    group: root
    mode: '0755'
    remote_src: yes

- name: Create node_exporter systemd service
  template:
    src: node_exporter.service.j2
    dest: /etc/systemd/system/node_exporter.service
    owner: root
    group: root
    mode: '0644'
  notify:
    - reload systemd
    - restart node_exporter

- name: Enable and start node_exporter service
  systemd:
    name: node_exporter
    enabled: yes
    state: started
    daemon_reload: yes

- name: Verify node_exporter is running
  uri:
    url: "http://localhost:{{ node_exporter_port }}/metrics"
    method: GET
    timeout: 10
  register: node_exporter_check
  retries: 3
  delay: 5
EOF

cat > ansible/roles/node_exporter/templates/node_exporter.service.j2 << 'EOF'
[Unit]
Description=Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User={{ node_exporter_user }}
Group={{ node_exporter_group }}
ExecReload=/bin/kill -HUP $MAINPID
ExecStart={{ node_exporter_binary_path }} \
    --web.listen-address=0.0.0.0:{{ node_exporter_port }} \
    --collector.textfile.directory={{ node_exporter_textfile_dir }}

SyslogIdentifier=node_exporter
Restart=always
RestartSec=1
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

cat > ansible/roles/node_exporter/handlers/main.yml << 'EOF'
---
- name: reload systemd
  systemd:
    daemon_reload: yes

- name: restart node_exporter
  systemd:
    name: node_exporter
    state: restarted
EOF

# =============================================================================
# PROMETHEUS ROLE
# =============================================================================

cat > ansible/roles/prometheus/defaults/main.yml << 'EOF'
---
prometheus_version: "2.48.1"
prometheus_port: 9090
prometheus_user: prometheus
prometheus_group: prometheus
prometheus_config_dir: /etc/prometheus
prometheus_data_dir: /var/lib/prometheus
prometheus_binary_path: /usr/local/bin/prometheus
prometheus_retention_time: "30d"
prometheus_retention_size: "10GB"
EOF

cat > ansible/roles/prometheus/tasks/main.yml << 'EOF'
---
- name: Create prometheus group
  group:
    name: "{{ prometheus_group }}"
    system: yes

- name: Create prometheus user
  user:
    name: "{{ prometheus_user }}"
    group: "{{ prometheus_group }}"
    system: yes
    shell: /bin/false
    home: "{{ prometheus_data_dir }}"
    create_home: no

- name: Create prometheus directories
  file:
    path: "{{ item }}"
    state: directory
    owner: "{{ prometheus_user }}"
    group: "{{ prometheus_group }}"
    mode: '0755'
  loop:
    - "{{ prometheus_config_dir }}"
    - "{{ prometheus_data_dir }}"
    - "{{ prometheus_config_dir }}/rules"

- name: Download prometheus
  get_url:
    url: "https://github.com/prometheus/prometheus/releases/download/v{{ prometheus_version }}/prometheus-{{ prometheus_version }}.linux-amd64.tar.gz"
    dest: /tmp/prometheus.tar.gz
    mode: '0644'

- name: Extract prometheus
  unarchive:
    src: /tmp/prometheus.tar.gz
    dest: /tmp
    remote_src: yes
    creates: "/tmp/prometheus-{{ prometheus_version }}.linux-amd64"

- name: Copy prometheus binaries
  copy:
    src: "/tmp/prometheus-{{ prometheus_version }}.linux-amd64/{{ item }}"
    dest: "/usr/local/bin/{{ item }}"
    owner: root
    group: root
    mode: '0755'
    remote_src: yes
  loop:
    - prometheus
    - promtool

- name: Copy prometheus console files
  copy:
    src: "/tmp/prometheus-{{ prometheus_version }}.linux-amd64/{{ item }}"
    dest: "{{ prometheus_config_dir }}/{{ item }}"
    owner: "{{ prometheus_user }}"
    group: "{{ prometheus_group }}"
    mode: '0644'
    remote_src: yes
  loop:
    - consoles
    - console_libraries

- name: Create prometheus configuration
  template:
    src: prometheus.yml.j2
    dest: "{{ prometheus_config_dir }}/prometheus.yml"
    owner: "{{ prometheus_user }}"
    group: "{{ prometheus_group }}"
    mode: '0644'
  notify:
    - restart prometheus

- name: Create prometheus systemd service
  template:
    src: prometheus.service.j2
    dest: /etc/systemd/system/prometheus.service
    owner: root
    group: root
    mode: '0644'
  notify:
    - reload systemd
    - restart prometheus

- name: Enable and start prometheus service
  systemd:
    name: prometheus
    enabled: yes
    state: started
    daemon_reload: yes

- name: Wait for prometheus to start
  wait_for:
    port: "{{ prometheus_port }}"
    host: "0.0.0.0"
    delay: 10
    timeout: 60

- name: Verify prometheus is running
  uri:
    url: "http://localhost:{{ prometheus_port }}/-/healthy"
    method: GET
    timeout: 10
  register: prometheus_check
  retries: 3
  delay: 5
EOF

cat > ansible/roles/prometheus/templates/prometheus.yml.j2 << 'EOF'
# Prometheus configuration file
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "{{ prometheus_config_dir }}/rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:{{ prometheus_port }}']

  - job_name: 'node-exporter'
    static_configs:
      - targets:
{% for host in groups['geth_nodes'] %}
          - '{{ hostvars[host]['ansible_host'] }}:{{ node_exporter_port }}'
{% endfor %}
    scrape_interval: 10s
    metrics_path: /metrics
EOF

cat > ansible/roles/prometheus/templates/prometheus.service.j2 << 'EOF'
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target

[Service]
Type=simple
User={{ prometheus_user }}
Group={{ prometheus_group }}
ExecReload=/bin/kill -HUP $MAINPID
ExecStart={{ prometheus_binary_path }} \
  --config.file={{ prometheus_config_dir }}/prometheus.yml \
  --storage.tsdb.path={{ prometheus_data_dir }} \
  --web.console.templates={{ prometheus_config_dir }}/consoles \
  --web.console.libraries={{ prometheus_config_dir }}/console_libraries \
  --web.listen-address=0.0.0.0:{{ prometheus_port }} \
  --web.external-url=http://{{ ansible_host }}:{{ prometheus_port }}/ \
  --storage.tsdb.retention.time={{ prometheus_retention_time }} \
  --storage.tsdb.retention.size={{ prometheus_retention_size }}

SyslogIdentifier=prometheus
Restart=always
RestartSec=1
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

cat > ansible/roles/prometheus/handlers/main.yml << 'EOF'
---
- name: reload systemd
  systemd:
    daemon_reload: yes

- name: restart prometheus
  systemd:
    name: prometheus
    state: restarted
EOF

# =============================================================================
# GRAFANA ROLE
# =============================================================================

cat > ansible/roles/grafana/defaults/main.yml << 'EOF'
---
grafana_version: "10.2.3"
grafana_port: 3000
grafana_user: grafana
grafana_group: grafana
grafana_config_dir: /etc/grafana
grafana_data_dir: /var/lib/grafana
grafana_log_dir: /var/log/grafana
grafana_admin_user: admin
grafana_admin_password: admin123
EOF

cat > ansible/roles/grafana/tasks/main.yml << 'EOF'
---
- name: Install required packages
  apt:
    name:
      - apt-transport-https
      - software-properties-common
      - wget
    state: present
    update_cache: yes

- name: Add Grafana GPG key
  apt_key:
    url: https://apt.grafana.com/gpg.key
    state: present

- name: Add Grafana repository
  apt_repository:
    repo: "deb https://apt.grafana.com stable main"
    state: present

- name: Install Grafana
  apt:
    name: grafana
    state: present
    update_cache: yes

- name: Create grafana directories
  file:
    path: "{{ item }}"
    state: directory
    owner: "{{ grafana_user }}"
    group: "{{ grafana_group }}"
    mode: '0755'
  loop:
    - "{{ grafana_data_dir }}"
    - "{{ grafana_log_dir }}"
    - "{{ grafana_data_dir }}/dashboards"
    - "{{ grafana_data_dir }}/plugins"

- name: Configure Grafana
  template:
    src: grafana.ini.j2
    dest: "{{ grafana_config_dir }}/grafana.ini"
    owner: root
    group: "{{ grafana_group }}"
    mode: '0640'
  notify:
    - restart grafana

- name: Create Grafana provisioning directories
  file:
    path: "{{ grafana_config_dir }}/provisioning/{{ item }}"
    state: directory
    owner: root
    group: "{{ grafana_group }}"
    mode: '0755'
  loop:
    - datasources
    - dashboards

- name: Configure Prometheus datasource
  template:
    src: prometheus-datasource.yml.j2
    dest: "{{ grafana_config_dir }}/provisioning/datasources/prometheus.yml"
    owner: root
    group: "{{ grafana_group }}"
    mode: '0644'
  notify:
    - restart grafana

- name: Configure dashboard provider
  template:
    src: dashboard-provider.yml.j2
    dest: "{{ grafana_config_dir }}/provisioning/dashboards/default.yml"
    owner: root
    group: "{{ grafana_group }}"
    mode: '0644'
  notify:
    - restart grafana

- name: Copy Node Exporter dashboard
  copy:
    src: node-exporter-dashboard.json
    dest: "{{ grafana_data_dir }}/dashboards/node-exporter-dashboard.json"
    owner: "{{ grafana_user }}"
    group: "{{ grafana_group }}"
    mode: '0644'

- name: Enable and start Grafana service
  systemd:
    name: grafana-server
    enabled: yes
    state: started
    daemon_reload: yes

- name: Wait for Grafana to start
  wait_for:
    port: "{{ grafana_port }}"
    host: "0.0.0.0"
    delay: 10
    timeout: 60

- name: Verify Grafana is running
  uri:
    url: "http://localhost:{{ grafana_port }}/api/health"
    method: GET
    timeout: 10
  register: grafana_check
  retries: 3
  delay: 5
EOF

cat > ansible/roles/grafana/templates/grafana.ini.j2 << 'EOF'
[DEFAULT]
instance_name = ${HOSTNAME}

[paths]
data = {{ grafana_data_dir }}
logs = {{ grafana_log_dir }}
plugins = {{ grafana_data_dir }}/plugins
provisioning = {{ grafana_config_dir }}/provisioning

[server]
protocol = http
http_addr = 0.0.0.0
http_port = {{ grafana_port }}
domain = {{ ansible_host }}
root_url = http://{{ ansible_host }}:{{ grafana_port }}/

[database]
type = sqlite3
path = {{ grafana_data_dir }}/grafana.db

[session]
provider = file
provider_config = sessions

[analytics]
reporting_enabled = false
check_for_updates = false

[security]
admin_user = {{ grafana_admin_user }}
admin_password = {{ grafana_admin_password }}
secret_key = SW2YcwTIb9zpOOhoPsMm
disable_gravatar = true

[users]
allow_sign_up = false
allow_org_create = false
auto_assign_org = true
auto_assign_org_role = Viewer
default_theme = dark

[auth.anonymous]
enabled = false

[log]
mode = console file
level = info
format = text

[log.console]
level = info
format = text

[log.file]
level = info
format = text
log_rotate = true
max_lines = 1000000
max_size_shift = 28
daily_rotate = true
max_days = 7
EOF

cat > ansible/roles/grafana/templates/prometheus-datasource.yml.j2 << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:{{ prometheus_port }}
    isDefault: true
    editable: true
EOF

cat > ansible/roles/grafana/templates/dashboard-provider.yml.j2 << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: {{ grafana_data_dir }}/dashboards
EOF

cat > ansible/roles/grafana/handlers/main.yml << 'EOF'
---
- name: restart grafana
  systemd:
    name: grafana-server
    state: restarted
EOF

# Create Node Exporter Dashboard JSON
cat > ansible/roles/grafana/files/node-exporter-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Node Exporter Dashboard",
    "tags": ["node-exporter"],
    "style": "dark",
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "Memory Usage %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Disk Usage",
        "type": "stat",
        "targets": [
          {
            "expr": "(1 - (node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"})) * 100",
            "legendFormat": "Disk Usage %"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Network Traffic",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(node_network_receive_bytes_total{device!=\"lo\"}[5m])",
            "legendFormat": "{{device}} - Received"
          },
          {
            "expr": "rate(node_network_transmit_bytes_total{device!=\"lo\"}[5m])",
            "legendFormat": "{{device}} - Transmitted"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "bytes"
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
EOF

# =============================================================================
# DEPLOYMENT SCRIPTS
# =============================================================================

cat > ansible/deploy-monitoring.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting monitoring deployment..."

# Check if private key exists
if [ ! -f ~/.ssh/ethereum-devops-ssh-key.pem ]; then
    echo "❌ SSH private key not found at ~/.ssh/ethereum-devops-ssh-key.pem"
    echo "Please retrieve it from AWS Secrets Manager and place it there with proper permissions (600)"
    exit 1
fi

# Set correct permissions for SSH key
chmod 600 ~/.ssh/ethereum-devops-ssh-key.pem

# Test connectivity to bastion
echo "🔍 Testing bastion connectivity..."
if ! ssh -i ~/.ssh/ethereum-devops-ssh-key.pem -o ConnectTimeout=10 ubuntu@54.255.190.26 'echo "Bastion accessible"'; then
    echo "❌ Cannot connect to bastion host"
    exit 1
fi

# Test connectivity to geth node through bastion
echo "🔍 Testing geth node connectivity through bastion..."
if ! ssh -i ~/.ssh/ethereum-devops-ssh-key.pem -o ConnectTimeout=10 -o ProxyCommand="ssh -W %h:%p -q ubuntu@54.255.190.26 -i ~/.ssh/ethereum-devops-ssh-key.pem" ubuntu@10.0.1.36 'echo "Geth node accessible"'; then
    echo "❌ Cannot connect to geth node through bastion"
    exit 1
fi

echo "✅ Connectivity tests passed"

# Run Ansible playbook
echo "🎭 Running Ansible playbook..."
ansible-playbook -i inventory/hosts.yml playbooks/monitoring.yml -v

echo "🎉 Monitoring deployment completed!"
echo ""
echo "📊 Access your monitoring:"
echo "   Prometheus: http://54.169.158.134:9090"
echo "   Grafana:    http://54.169.158.134:3000 (admin/admin123)"
echo ""
echo "🔍 Verify services:"
echo "   Node Exporter metrics: curl http://10.0.1.36:9100/metrics (through bastion)"
echo "   Prometheus targets: http://54.169.158.134:9090/targets"
EOF

chmod +x ansible/deploy-monitoring.sh

# Create a verification script
cat > ansible/verify-monitoring.sh << 'EOF'
#!/bin/bash

echo "🔍 Verifying monitoring setup..."

# Check Prometheus
echo "Checking Prometheus..."
if curl -s http://54.169.158.134:9090/-/healthy | grep -q "Prometheus is Healthy"; then
    echo "✅ Prometheus is healthy"
else
    echo "❌ Prometheus is not healthy"
fi

# Check Grafana
echo "Checking Grafana..."
if curl -s http://54.169.158.134:3000/api/health | grep -q "ok"; then
    echo "✅ Grafana is healthy"
else
    echo "❌ Grafana is not healthy"
fi

# Check targets in Prometheus
echo "Checking Prometheus targets..."
curl -s http://54.169.158.134:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .job, health: .health, lastScrape: .lastScrape}'

echo ""
echo "🎯 Monitoring URLs:"
echo "   Prometheus: http://54.169.158.134:9090"
echo "   Grafana:    http://54.169.158.134:3000"
echo "   Targets:    http://54.169.158.134:9090/targets"
EOF

chmod +x ansible/verify-monitoring.sh

echo "✅ Ansible monitoring setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Retrieve SSH private key from AWS Secrets Manager:"
echo "   aws secretsmanager get-secret-value --secret-id ethereum-devops-ssh-private-key --query SecretString --output text > ~/.ssh/ethereum-devops-ssh-key.pem"
echo ""
echo "2. Run the deployment:"
echo "   cd ansible && ./deploy-monitoring.sh"
echo ""
echo "3. Verify the setup:"
echo "   cd ansible && ./verify-monitoring.sh"