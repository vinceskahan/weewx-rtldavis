
## Scripted install of weewx using the rtldavis driver

FWIW, I found the rtldavis installation repos and instructions very difficult to follow,
and there were also some errors for current raspi os debian-11 versions as well as edits
needed if you are a US user.   This script worked for me.

The key is pinning your go version to < 1.16 due to breaking changes from the go project
upstream.  Luc's instructions are written to the <= 1.15 versions of go.

Pointers to the reference documents and commentary for what I changed vs. those
instructions is in the code.

Usage - if you set the variables at the top of the script to '1' it will run that block. 
  Set to '0' or comment out to suppress running that block of code.  
  Hopefully it should be reasonably obvious.

Notes:
======
 - this assumes you run v5 via the 'pip' installation mechanism.
       I'm not planning to support the dpkg variant with this repo.

 - the 'install weewx' variable calls a different standalone script that
       installs and configures nginx and integrates the two. Again this
       does the 'pip' installation method for weewx

 - code assumes it is run as user 'pi' on a raspi of course, which is
       hardcoded throughout.

 - since go1.15 is no longer available in debian12 default repos, this script
       now installs a 'local' copy of go under /home/pi/go/bin and also
       installs rtldavis there.

 - the default weewx.conf that this installs has 'very' (like 'VERY') verbose
       logging enabled for rtldavis.  You'll almost certainly want to dial that
       back after you get things working.  See the driver section in weewx.conf
       for details.
        
