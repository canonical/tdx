
#!/bin/bash
qemu-system-x86_64 -cpu host -smp 16,sockets=1 -accel kvm -nographic -nodefaults -no-user-config -m 160G -bios /usr/share/ovmf/OVMF.fd -serial stdio -object "{'qom-type': 'tdx-guest', 'id': 'tdx'}" -machine q35,kernel_irqchip=split,confidential-guest-support=tdx -drive file=/tmp/tdxtest-default-l1e07rqw/image.qcow2,if=none,id=virtio-disk0 -device virtio-blk-pci,drive=virtio-disk0 -pidfile /tmp/tdxtest-default-l1e07rqw/qemu.pid -monitor unix:/tmp/tdxtest-default-l1e07rqw/monitor.sock,server,nowait -qmp unix:/tmp/tdxtest-default-l1e07rqw/qmp.sock,server=on,wait=off -device virtio-net-pci,netdev=nic0_td -netdev user,id=nic0_td,hostfwd=tcp::41957-:22 -D /tmp/tdxtest-default-l1e07rqw/qemu-log.txt 
