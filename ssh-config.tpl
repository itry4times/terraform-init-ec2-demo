cat << EOF >> ~/.ssh/config
Host ${hostname}
  HostName ${host_ip}
  User ${user}
  ServerAliveInterval 120
EOF