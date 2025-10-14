#!/usr/bin/env nix-shell
#!nix-shell -i bash -p qemu
# Headless test VM for griefling - no display, SSH only

cd "$(dirname "$0")/.." || exit 1
mkdir -p quickemu

qemu-system-x86_64 \
    -name griefling-test,process=griefling-test \
    -machine q35,smm=off,vmport=off,accel=kvm \
    -global kvm-pit.lost_tick_policy=discard \
    -cpu host,topoext \
    -smp cores=2,threads=2,sockets=1 \
    -m 16G \
    -device virtio-balloon \
    -pidfile ./quickemu/griefling-test.pid \
    -rtc base=utc,clock=host \
    -display none \
    -device virtio-rng-pci,rng=rng0 \
    -object rng-random,id=rng0,filename=/dev/urandom \
    -device virtio-net,netdev=nic \
    -netdev user,hostname=griefling-test,hostfwd=tcp::22221-:22,id=nic \
    -global driver=cfi.pflash01,property=secure,value=on \
    -drive if=pflash,format=raw,unit=0,file=/nix/store/52cw7nshri5y4sg2v7s90vilsk4c69s8-OVMF-202508-fd/FV/OVMF_CODE.fd,readonly=on \
    -drive if=pflash,format=raw,unit=1,file=./quickemu/griefling-OVMF_VARS.fd \
    -device virtio-blk-pci,drive=SystemDisk \
    -drive id=SystemDisk,if=none,format=qcow2,file=./quickemu/griefling-test.qcow2 \
    -monitor unix:./quickemu/griefling-test-monitor.socket,server,nowait \
    -serial unix:./quickemu/griefling-test-serial.socket,server,nowait \
    -daemonize
