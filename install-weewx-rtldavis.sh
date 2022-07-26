#----------------------------------------------
#
# scripted install of weewx with rtldavis driver
# set to US units
#
# tested on debian-11 based Raspi OS
# with a rtl-sdr.com RTL2832U dongle
#
# last modified - 2022-0722
#
#----------------------------------------------

# set these to 1 to run that block of code below

INSTALL_PREREQS=1          # package prerequisites to build the software
INSTALL_WEEWX=1            # weewx itself
INSTALL_NGINX=1            # webserver for weewx
INSTALL_LIBRTLSDR=1        # librtlsdr software
INSTALL_RTLDAVIS=1         # weewx rtldavis driver
RUN_WEEWX_AT_BOOT=1        # enable weewx in systemctl to startup at boot

#----------------------------------------------
#
# install required packages to enable building/running the software suite

if [ "x${INSTALL_PREREQS}" = "x1" ]
then
    echo ".......installing prereqs..........."
    sudo apt-get update 
    sudo apt-get -y install python3-configobj python3-pil python3-serial python3-usb python3-pip python3-ephem python3-cheetah
    sudo apt-get -y install golang git cmake librtlsdr-dev
fi

#-----------------------------------------------
#
# install weewx (ref: https://weewx.com/docs/setup.htm)

if [ "x${INSTALL_WEEWX}" = "x1" ]
then
    echo ".......installing weewx............."
    wget https://weewx.com/downloads/released_versions/weewx-4.8.0.tar.gz -O weewx-4.8.0.tar.gz
    tar zxvf weewx-4.8.0.tar.gz 
    cd weewx-4.8.0/
    python3 setup.py build
    sudo python3 setup.py install --no-prompt
    sudo cp /home/weewx/util/systemd/weewx.service /etc/systemd/system

    # we set debug=1 so later the driver will syslog the RF it sees
    #  - you can later set it to 0 and restart weewx to quiet logging down
    sudo sed -i 's|debug = 0|debug=1|' /home/weewx/weewx.conf

    # optionally install a webserver and hook into weewx
    #   - the resulting URL will be http://<ip_address>/weewx
    if [ "x${INSTALL_NGINX}" = "x1" ]
    then
        sudo apt-get install -y nginx sqlite
        sudo ln -s /home/weewx/public_html /var/www/html/weewx
    fi
fi

#-----------------------------------------------
#
# install rtldavis (ref:https://github.com/lheijst/rtldavis)
#
# changes - on debian-11 raspi we set the cmake option below to =OFF
#           rather than using the instructions in the older link above so that
#           we suppress librtlsdr writing a conflicting udev rules file into place
#

if [ "x${INSTALL_LIBRTLSDR}" = "x1" ]
then
    echo ".......installing librtlsdr........."

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
    git clone https://github.com/steve-m/librtlsdr.git librtlsdr
    cd librtlsdr
    mkdir build
    cd build
    cmake ../ -DINSTALL_UDEV_RULES=OFF -DDETACH_KERNEL_DRIVER=ON
    make
    sudo make install
    sudo ldconfig

    # add to .profile for future
    #    'source ~/.profile' to catch up interactively
    GO_INFO_FOUND=`grep CONFIGURE_GO_SETTINGS ~/.profile | wc -l | awk '{print $1}'`
    if [ "x${GO_INFO_FOUND}" = "x0"  ]
    then
        echo ''                                                   >> ~/.profile
        echo '### CONFIGURE_GO_SETTINGS for rtdavis installation' >> ~/.profile
        echo 'export GOROOT=/usr/lib/go'                          >> ~/.profile
        echo 'export GOPATH=$HOME/work'                           >> ~/.profile
        echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin'          >> ~/.profile
    fi

    # for running here
    export GOROOT=/usr/lib/go
    export GOPATH=$HOME/work
    export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

    # get rtldavis the hard way - this does not work
    cd /home/pi
    go get -v github.com/lheijst/rtldavis
    cd $GOPATH/src/github.com/lheijst/rtldavis
    git submodule init
    git submodule update
    go install -v .

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

if [ "x${INSTALL_RTLDAVIS}" = "x1" ]
then
    echo ".......installing rtldavis.........."
    cd /home/pi
    sudo wget -O weewx-rtldavis-master.zip https://github.com/lheijst/weewx-rtldavis/archive/master.zip
    sudo /home/weewx/bin/wee_extension --install weewx-rtldavis-master.zip
    sudo /home/weewx/bin/wee_config --reconfigure --driver=user.rtldavis --no-prompt

    # remove the template instruction from the config file
    echo "editing options..."
    sudo sed -i -e s/\\[options\\]// /home/weewx/weewx.conf

    # US frequencies and imperial units
    echo "editing US settings..."
    sudo sed -i -e s/frequency\ =\ EU/frequency\ =\ US/             /home/weewx/weewx.conf
    sudo sed -i -e s/rain_bucket_type\ =\ 1/rain_bucket_type\ =\ 0/ /home/weewx/weewx.conf

    # for very verbose logging of readings
    echo "editing debug..."
    sudo sed -i -e s/debug_rtld\ =\ 2/debug_rtld\ =\ 3/             /home/weewx/weewx.conf

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
