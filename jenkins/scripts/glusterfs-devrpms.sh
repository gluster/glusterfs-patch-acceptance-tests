# 2015-04-24 JC Further stuff to try and kill leftover processes from aborted runs
sudo pkill -f regression.sh
sudo pkill -f run-tests.sh
sudo pkill -f prove
sudo pkill -f data-self-heal.t
sudo pkill -f mock
sudo pkill -f rpmbuild
sudo pkill -f glusterd
sudo pkill -f mkdir
##sudo umount -f /mnt/nfs/0
##sudo umount -f /mnt/nfs/1

## 2015-04-24 JC For some unknown reason, the above umount -f statements were causing the below to fail. (WTF!) so they're commented out for now
##               Instead, lets take an ultra-sleazy way to get /mnt/nfs/0 out of /etc/mnttab
##               ...and yeah, is about as wrong as it gets ;>
##sudo bash -c "grep -v '/mnt/nfs' /etc/mtab > /etc/mtab2"
##sudo bash -c "cat /etc/mtab2 > /etc/mtab"
##sudo rm -f /etc/mtab2

# Proceed with building the rpms
./autogen.sh || exit 1

./configure --enable-fusermount || exit 1

cd extras/LinuxRPM

make prep srcrpm || exit 1

CFGS="fedora-22-x86_64"
for rpmcfg in $CFGS ; do
    echo "---- mock rpm build $rpmcfg ----"
    sudo mock -r $rpmcfg --resultdir=${WORKSPACE}/RPMS/"%(dist)s"/"%(target_arch)s"/ --cleanup-after --rebuild glusterfs*src.rpm || exit 1
done



