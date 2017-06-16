# get-node-to-ansible.sh
# A script that provisions nodes and writes them to an Ansible inventory file
set +x
NODE_COUNT=${NODE_COUNT:-1}
ANSIBLE_HOSTS=${ANSIBLE_HOSTS:-$WORKSPACE/hosts}
SSID_FILE=${SSID_FILE:-$WORKSPACE/cico-ssid}
RELEASE=${RELEASE:-7}

# Write the header of the hosts file
cat << EOF > ${ANSIBLE_HOSTS}
localhost ansible_connection=local

[gluster_nodes]
EOF

# Get nodes
nodes=$(cico -q node get --count ${NODE_COUNT} --release $RELEASE --column hostname --column ip_address --column comment -f value)

# Write nodes to inventory file and persist the SSID separately for simplicity
touch ${SSID_FILE}
IFS=$'\n'
for node in ${nodes}
do
    host=$(echo "${node}" |cut -f1 -d " ")
    address=$(echo "${node}" |cut -f2 -d " ")
    ssid=$(echo "${node}" |cut -f3 -d " ")

    line="${host} ansible_host=${address} ansible_user=root cico_ssid=${ssid}"
    echo "${line}" >> ${ANSIBLE_HOSTS}

    # Write unique SSIDs to the SSID file
    if ! grep -q ${ssid} ${SSID_FILE}; then
        echo ${ssid} >> ${SSID_FILE}
    fi
done
