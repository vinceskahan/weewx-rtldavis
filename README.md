
## Scripted install of weewx using the rtldavis driver

FWIW, I found the rtldavis installation repos and instructions very difficult to follow, and there were also some errors for current raspi os debian-11 versions as well as edits needed if you are a US user.   This script worked for me.

Pointers to the reference documents and commentary for what I changed vs. those instructions is in the code.

Usage - if you set the variables at the top of the script to '1' it will run that block.  Set to '0' or comment out to suppress running that block of code.  Hopefully it should be reasonably obvious.

(tested on a pi4 running the 2022-04-04 32bit raspi os lite according to /boot/issue)
