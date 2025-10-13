#!/usr/bin/env bash
# Headless test VM for griefling - no display, SSH only
/nix/store/nk59c14nwf79bafmrsnnhndmpnrlplrv-qemu-10.1.0/bin/qemu-system-x86_64 \
    -name griefling-test,process=griefling-test \
    -machine q35,smm=off,vmport=off,accel=kvm \
    -global kvm-pit.lost_tick_policy=discard \
    -cpu host,topoext \
    -smp cores=2,threads=2,sockets=1 \
    -m 16G \
    -device virtio-balloon \
    -pidfile ./griefling-test.pid \
    -rtc base=utc,clock=host \
    -display none \
    -device virtio-rng-pci,rng=rng0 \
    -object rng-random,id=rng0,filename=/dev/urandom \
    -device virtio-net,netdev=nic \
    -netdev user,hostname=griefling-test,hostfwd=tcp::22221-:22,id=nic \
    -global driver=cfi.pflash01,property=secure,value=on \
    -drive if=pflash,format=raw,unit=0,file=/nix/store/52cw7nshri5y4sg2v7s90vilsk4c69s8-OVMF-202508-fd/FV/OVMF_CODE.fd,readonly=on \
    -drive if=pflash,format=raw,unit=1,file=./OVMF_VARS.fd \
    -device virtio-blk-pci,drive=SystemDisk \
    -drive id=SystemDisk,if=none,format=qcow2,file=griefling-test.qcow2 \
    -monitor unix:./griefling-test-monitor.socket,server,nowait \
    -serial unix:./griefling-test-serial.socket,server,nowait \
    -daemonize
