#----------------------------------------------
#
# scripted install of weewx with rtldavis driver set to US units
#
# tested on debian-12 based Raspi OS
# with a rtl-sdr.com RTL2832U dongle
#
# last modified
#   2024-1002 - no 1.15 dpkg in deb12, install local go manually
#   2024-0323 - update to v5 weewx, pin golang version to 1.15
#   2022-0722 - original
#
#----------------------------------------------
# credits - thanks to another weewx user noticing that golang-1.15 still works
#           which was buried in their attachments in 
#            https://groups.google.com/g/weewx-user/c/bGiQPuOljqs/m/Mrvwe50UCQAJ
#----------------------------------------------

# set these to 1 to run that block of code below

INSTALL_PREREQS=1          # package prerequisites to build the software
INSTALL_WEEWX=1            # weewx itself
INSTALL_LIBRTLSDR=1        # librtlsdr software
INSTALL_RTLDAVIS=1         # weewx rtldavis driver
RUN_WEEWX_AT_BOOT=1        # enable weewx in systemctl to startup at boot

#----------------------------------------------
#
# install required packages to enable building/running the software suite
# some of these might actually not be needed for v5 pip installations in a venv
# but I'll leave them here just in case
#

if [ "x${INSTALL_PREREQS}" = "x1" ]
then
    echo ".......installing prereqs..........."
    sudo apt-get update 
    sudo apt-get -y install python3-configobj python3-pil python3-serial python3-usb python3-pip python3-ephem python3-cheetah
fi

#-----------------------------------------------
#
# install weewx via the pip method
# and also nginx and hook them together
# then stop weewx (for now) so we can reconfigure it
#
# rather than duplicate the code here, this calls my other repo
# with the end-to-end script for this that can run standalone
#
# if piping wget to bash concerns you, please read the code there
# which hopefully is clear enough to put your mind at ease

if [ "x${INSTALL_WEEWX}" = "x1" ]
then
  wget -qO - https://raw.githubusercontent.com/vinceskahan/weewx-pipinstall/main/install-v5pip.sh | bash
  sudo systemctl stop weewx
fi

#-----------------------------------------------
#
# install rtldavis (ref:https://github.com/lheijst/rtldavis)
#
# changes - on debian-11 raspi we set the cmake option below to =OFF
#           rather than using the instructions in the older link above so that
#           we suppress librtlsdr writing a conflicting udev rules file into place
#
# you might need to edit the udev rule below if you have different tuner hardware
# so you might want to plug it in and run 'lsusb' and check the vendor and product values
# before proceeding
#

if [ "x${INSTALL_LIBRTLSDR}" = "x1" ]
then
    echo ".......installing librtlsdr........."
    sudo apt-get -y install git cmake librtlsdr-dev golang

    # set up udev rules
    #
    # for my system with 'lsusb' output containing:
    #    Bus 001 Device 003: ID 0bda:2838 Realtek Semiconductor Corp. RTL2838 DVB-T

    echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="2838", GROUP="adm", MODE="0666", SYMLINK+="rtl_sdr"' > /tmp/udevrules
    sudo mv /tmp/udevrules /etc/udev/rules.d/20.rtsdr.rules

    # get librtlsdr
    cd /home/pi
    if [ -d librtlsdr ]
    then
      rm -rf librtlsdr
    fi

    # install librtlsdr
    cd
    git clone https://github.com/steve-m/librtlsdr.git librtlsdr
    cd librtlsdr
    mkdir build
    cd build
    cmake ../ -DINSTALL_UDEV_RULES=OFF -DDETACH_KERNEL_DRIVER=ON
    make
    sudo make install
    sudo ldconfig

    # use the system go to install the proper local version of go
    cd
    go install golang.org/dl/go1.15@latest
    go/bin/go1.15 download

    # add to .profile for future
    #    'source ~/.profile' to catch up interactively
    GO_INFO_FOUND=`grep CONFIGURE_GO_SETTINGS ~/.profile | wc -l | awk '{print $1}'`
    if [ "x${GO_INFO_FOUND}" = "x0"  ]
    then
        echo ''                                                   >> ~/.profile
        echo '### CONFIGURE_GO_SETTINGS for rtdavis installation' >> ~/.profile
        echo GOPATH=/home/pi/go >> ~/.profile
        echo GOROOT=/home/pi/sdk/go1.15 >> ~/.profile
        export PATH=$PATH:$GOROOT/bin:$GOPATH/bin >> ~/.profile
    fi

    # for running here
    GOPATH=/home/pi/go
    GOROOT=/home/pi/sdk/go1.15
    export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
    hash -r

    # we pin golang to < 1.16 so Luc's instructions still work ok for
    # grabbing his code and building the resulting rtldavis binary
    # from source the old way.  Note however that this does not link that
    # version into the normal $PATH, so you need to call it with its full path
    #
    # the export PATH above 'might' work but we'll use full paths to be safe

    # install luc's code
    /home/pi/go/bin/go1.15 get -v github.com/lheijst/rtldavis
    cd go/src/github.com/lheijst/rtldavis/
    git submodule init
    git submodule update
    /home/pi/go/bin/go1.15 install -v .

    # for US users, to test rtldavis, run:
    #    $GOPATH/bin/rtldavis -tf US
    #
    # if you get device busy errors, add to the modprobe blacklisted modules
    # (doing this requires a reboot for the blacklist to take effect)
    #
    # again, for lsb output containing:
    #   Bus 001 Device 003: ID 0bda:2838 Realtek Semiconductor Corp. RTL2838 DVB-T
    #
    echo "blacklist dvb_usb_rtl28xxu" > /tmp/blacklist
    sudo cp /tmp/blacklist /etc/modprobe.d/blacklist_dvd_usb_rtl28xxu
    #
    # then reboot and try 'rtldavis -tf US' again
    #
    # ref: https://forums.raspberrypi.com/viewtopic.php?t=81731
    #

fi

#-----------------------------------------------
#
# install the rtldavis weewx driver
# this assumes you did a venv pip installation

if [ "x${INSTALL_RTLDAVIS}" = "x1" ]
then
    echo ".......installing rtldavis.........."
    source /home/pi/weewx-venv/bin/activate
    weectl extension install -y https://github.com/lheijst/weewx-rtldavis/archive/master.zip
    weectl station reconfigure --driver=user.rtldavis --no-prompt

    # remove the template instruction from the config file
    echo "editing options..."
    sudo sed -i -e s/\\[options\\]// /home/pi/weewx-data/weewx.conf

    # US frequencies and imperial units
    echo "editing US settings..."
    sed -i -e s/frequency\ =\ EU/frequency\ =\ US/             /home/pi/weewx-data/weewx.conf
    sed -i -e s/rain_bucket_type\ =\ 1/rain_bucket_type\ =\ 0/ /home/pi/weewx-data/weewx.conf

    # we install rtldavis to a different place than Luc so patch the "cmd =" line
    sed -i -e s:/home/pi/work/bin/rtldavis:/home/pi/go/bin/rtldavis: /home/pi/weewx-data/weewx.conf

    # for very verbose logging of readings
    echo "editing debug..."
    sed -i -e s/debug_rtld\ =\ 2/debug_rtld\ =\ 3/             /home/pi/weewx-data/weewx.conf

fi

#-----------------------------------------------

if [ "x${RUN_WEEWX_AT_BOOT}" = "x1" ]
then
    # enable weewx for next reboot
    sudo systemctl enable weewx
fi

#-----------------------------------------------
#
# at this point you can run 'sudo systemctl start weewx' to start weewx using the installed driver
# be sure to 'sudo tail -f /var/log/syslog' to watch progress (^C to exit)
#
# patience is required - on a pi4 running a RTL-SDR.COM RTL2832U dongle,
#    it takes over a minute for it to acquire the signal
#
# you might want to set the various driver debug settings to 0
# after you get it working to quiet things down especially if
# you use debug=1 for other reasons in your weewx configuration
#
# if you want to run 'rtldavis' as a non-privileged user, you should reboot here
#
#-----------------------------------------------

