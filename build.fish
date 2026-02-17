#!/usr/bin/fish

if fish_is_root_user
    cp -r home archiso/airootfs/root/
    mkarchiso -v -r -w /tmp/archiso-tmp -o ./build ./archiso
    rm -rf archiso/airoofs/root/home
else
    printf "Run from root user\n"
end
