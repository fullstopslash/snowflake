#!/usr/bin/env bash
# Test VM for griefling with Hyprland
/nix/store/nk59c14nwf79bafmrsnnhndmpnrlplrv-qemu-10.1.0/bin/qemu-system-x86_64 \
    -name griefling-test,process=griefling-test \
    -machine q35,smm=off,vmport=off,accel=kvm \
    -global kvm-pit.lost_tick_policy=discard \
    -cpu host,topoext \
    -smp cores=2,threads=2,sockets=1 \
    -m 8G \
    -device virtio-balloon \
    -pidfile ./griefling-test.pid \
    -rtc base=utc,clock=host \
    -vga none \
    -device virtio-vga-gl,xres=1920,yres=1080 \
    -display sdl,gl=on \
    -device virtio-rng-pci,rng=rng0 \
    -object rng-random,id=rng0,filename=/dev/urandom \
    -device qemu-xhci,id=spicepass \
    -device usb-ehci,id=input \
    -device usb-kbd,bus=input.0 \
    -k en-us \
    -device usb-tablet,bus=input.0 \
    -audiodev alsa,id=audio0 \
    -device intel-hda \
    -device hda-micro,audiodev=audio0 \
    -device virtio-net,netdev=nic \
    -netdev user,hostname=griefling-test,hostfwd=tcp::22221-:22,id=nic \
    -global driver=cfi.pflash01,property=secure,value=on \
    -drive if=pflash,format=raw,unit=0,file=/nix/store/52cw7nshri5y4sg2v7s90vilsk4c69s8-OVMF-202508-fd/FV/OVMF_CODE.fd,readonly=on \
    -drive if=pflash,format=raw,unit=1,file=./OVMF_VARS.fd \
    -drive media=cdrom,index=0,file=result/iso/nixos-minimal-25.05.20250724.3ff0e34-x86_64-linux.iso \
    -device virtio-blk-pci,drive=SystemDisk \
    -drive id=SystemDisk,if=none,format=qcow2,file=griefling-test.qcow2 \
    -monitor unix:./griefling-test-monitor.socket,server,nowait \
    -serial unix:./griefling-test-serial.socket,server,nowait 2>/dev/null

