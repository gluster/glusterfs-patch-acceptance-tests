set +x
rsync_pass="$(cut -c1-13 < ~/duffy.key)"
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$(cat $WORKSPACE/hosts) "echo $rsync_pass > ~/rsync.passwd"
ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$(cat $WORKSPACE/hosts) "chmod 0600 ~/rsync.passwd"

