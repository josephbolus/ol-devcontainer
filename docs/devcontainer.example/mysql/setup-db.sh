#!/bin/bash
set -e

log() { echo "[$(date +%H:%M:%S)] $1"; }

# Create MySQL client config file
cat > ~/.my.cnf <<EOF
[client]
user=root
password=rootpassword
EOF
chmod 600 ~/.my.cnf  # Restrict permissions

wait_for_db() {
  local host=$1
  local retries=10
  local count=0
  until mysql -h "$host" -e "SELECT 1;" >/dev/null; do
    ((count++))
    if [ $count -ge $retries ]; then
      log "ERROR: $host not ready after $retries attempts"
      exit 1
    fi
    log "Waiting for $host... (attempt $count/$retries)"
    sleep 2
  done
  log "$host is ready"
}

log "Setting up..."
sleep 10
log "Waiting for mysql-primary"
wait_for_db mysql-primary

log "Waiting for mysql-replica"
wait_for_db mysql-replica

log "Verifying server IDs..."
primary_id=$(mysql -h mysql-primary -e "SHOW VARIABLES LIKE 'server_id'\G;" | grep -oP "Value: \K\d+")
replica_id=$(mysql -h mysql-replica -e "SHOW VARIABLES LIKE 'server_id'\G;" | grep -oP "Value: \K\d+")
log "Primary server_id: $primary_id"
log "Replica server_id: $replica_id"
if [ "$primary_id" = "$replica_id" ]; then
  log "ERROR: Server IDs are identical ($primary_id)"
  exit 1
fi

log "Fetching primary master status before setup..."
status=$(mysql -h mysql-primary -e "SHOW MASTER STATUS\G;" 2>/dev/null) || { log "ERROR: Failed to get master status"; exit 1; }
log_file=$(echo "$status" | grep -oP "File: \K.*" || echo "")
position=$(echo "$status" | grep -oP "Position: \K\d+" || echo "")
if [ -z "$log_file" ] || [ -z "$position" ]; then
  log "ERROR: Could not parse master status (File: $log_file, Position: $position)"
  exit 1
fi
log "Master status - File: $log_file, Position: $position"

log "Configuring replica..."
mysql -h mysql-replica <<EOF || { log "ERROR: Failed to configure replica"; exit 1; }
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='mysql-primary',
  MASTER_USER='repl',
  MASTER_PASSWORD='replpassword',
  MASTER_LOG_FILE='$log_file',
  MASTER_LOG_POS=$position;
START SLAVE;
EOF

log "Setting up replication user and test table on primary..."
mysql -h mysql-primary <<EOF || { log "ERROR: Failed to setup primary"; exit 1; }
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'replpassword';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;

USE testdb;
CREATE TABLE IF NOT EXISTS sample_data (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100),
  value INT
);
INSERT IGNORE INTO sample_data (name, value) VALUES ('test1', 100);
EOF

log "Waiting for replication to stabilize..."
sleep 10

log "Setup complete! Primary: mysql-primary:3306, Replica: mysql-replica:3307"