#!/bin/bash

# Create MySQL client config file
cat > ~/.my.cnf <<EOF
[client]
user=root
password=rootpassword
EOF
chmod 600 ~/.my.cnf

echo "Checking replication..."
sleep 10
status=$(mysql -h mysql-replica --table -e "SHOW SLAVE STATUS\G;" 2>/dev/null) || {
  echo "❌ Failed to get slave status"
  exit 1
}
io=$(echo "$status" | grep -o "Slave_IO_Running: Yes" || echo "No")
sql=$(echo "$status" | grep -o "Slave_SQL_Running: Yes" || echo "No")

if [ "$io" = "Slave_IO_Running: Yes" ] && [ "$sql" = "Slave_SQL_Running: Yes" ]; then
  echo "✅ Replication OK"
else
  echo "❌ Replication failed (IO: $io, SQL: $sql)"
  echo "Full slave status:"
  echo "$status"
  exit 1
fi

echo "Testing data sync..."
# Use a fixed test ID rather than creating a new one each time
test_id="verify_sync_test"

# Delete the test record if it exists
mysql -h mysql-primary testdb -e "DELETE FROM sample_data WHERE name='$test_id';"

# Insert the test record
mysql -h mysql-primary testdb -e "INSERT INTO sample_data (name, value) VALUES ('$test_id', 999);"
sleep 2

# Check if it was replicated
count=$(mysql -h mysql-replica --table testdb -e "SELECT COUNT(*) FROM sample_data WHERE name='$test_id'" | grep -o '[0-9]\+' || echo "0")
[ "$count" = "1" ] && echo "✅ Data sync OK" || { echo "❌ Data sync failed (Count: $count)"; exit 1; }

echo "-> Environment setup complete! Run ./cleanup.sh to teardown the environment."