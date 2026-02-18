#!/usr/bin/fish

if fish_is_root_user;   mkarchiso -v -r -w /tmp/archiso-tmp -o ./build ./archiso
else;                   printf "Run from root user\n"
end
