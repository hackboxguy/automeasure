#!/bin/sh
#./setup.sh -t 14.6 
USAGE="usage:$0 -r <disp_resolution> -p <optional_create_patterns_only>"
DISP_RES="none"
PATTERNS_ONLY="none"
while getopts r:p f
do
	case $f in
	r) DISP_RES=$OPTARG ;;
	p) PATTERNS_ONLY="yes" ;;
	esac
done

if [ $# -lt 2  ]; then
	echo $USAGE
	exit 1
fi

[ $DISP_RES = "none" ] && echo "missing display-resolution -r arg!" && exit 1

MYPATH=$(pwd)

if [ $PATTERNS_ONLY = "yes" ]; then
	printf "Creating png pattern files............................... "
	mkdir -p $MYPATH/patterns
	convert -size "$DISP_RES" xc:rgb\(255,255,255\) $MYPATH/patterns/white.png
	convert -size "$DISP_RES" xc:rgb\(255,000,000\) $MYPATH/patterns/red.png
	convert -size "$DISP_RES" xc:rgb\(000,255,000\) $MYPATH/patterns/green.png
	convert -size "$DISP_RES" xc:rgb\(000,000,255\) $MYPATH/patterns/blue.png
	convert -size "$DISP_RES" xc:rgb\(000,255,255\) $MYPATH/patterns/cyan.png
	convert -size "$DISP_RES" xc:rgb\(255,000,255\) $MYPATH/patterns/magenta.png
	convert -size "$DISP_RES" xc:rgb\(255,255,000\) $MYPATH/patterns/yellow.png
	test 0 -eq $? && echo "[OK]" || echo "[FAIL]"
	exit 0
fi

#pattern creation doesnt require root access, but next in the next steps like apt-get we need to be root
if [ $(id -u) -ne 0 ]; then
        echo "Please run setup as root ==> sudo ./setup.sh -n $SLAVE_NUM"
        exit
fi
#exit 0

#install dependencies
printf "Installing dependencies ................................ "
DEBIAN_FRONTEND=noninteractive apt-get update --fix-missing < /dev/null > /dev/null
DEBIAN_FRONTEND=noninteractive apt-get install -qq argyll libhidapi-dev imagemagick cmake git libjson-c-dev fim < /dev/null > /dev/null
test 0 -eq $? && echo "[OK]" || echo "[FAIL]"

printf "Configuring automeasure components...................... "
cmake -H. -BOutput -DCMAKE_INSTALL_PREFIX=$MYPATH/brbox/output -DINSTALL_CLIENT=ON -DAUTO_SVN_VERSION=OFF 1>/dev/null 2>/dev/null
test 0 -eq $? && echo "[OK]" || echo "[FAIL]"

printf "Building automeasure.................................... "
cmake --build Output -- install -j$(nproc) 1>/dev/null 2>/dev/null
test 0 -eq $? && echo "[OK]" || echo "[FAIL]"

printf "Enabling pattern-player service......................... "
#TODO, replace path in patternplayer.service
sed -i "s|/home/pi/automeasure|$MYPATH|g" patternplayer.service
systemctl enable $MYPATH/patternplayer.service 1>/dev/null 2>/dev/null
systemctl start patternplayer.service 1>/dev/null 2>/dev/null
test 0 -eq $? && echo "[OK]" || echo "[FAIL]"

printf "Enabling automeasure service............................ "
sed -i "s|/home/pi/automeasure|$MYPATH|g" automeasure.service
sed -i "s|/home/pi/automeasure|$MYPATH|g" measure.sh
systemctl enable $MYPATH/automeasure.service 1>/dev/null 2>/dev/null
systemctl start automeasure.service 1>/dev/null 2>/dev/null
test 0 -eq $? && echo "[OK]" || echo "[FAIL]"

printf "Creating png pattern files............................. "
mkdir -p $MYPATH/patterns
#if [ $DISP_TYPE = "1920x1080" ]; then
#elif [ $DISP_TYPE = "14.6" ]; then
#fi
convert -size "$DISP_RES" xc:rgb\(255,255,255\) $MYPATH/patterns/white.png
convert -size "$DISP_RES" xc:rgb\(255,000,000\) $MYPATH/patterns/red.png
convert -size "$DISP_RES" xc:rgb\(000,255,000\) $MYPATH/patterns/green.png
convert -size "$DISP_RES" xc:rgb\(000,000,255\) $MYPATH/patterns/blue.png
convert -size "$DISP_RES" xc:rgb\(000,255,255\) $MYPATH/patterns/cyan.png
convert -size "$DISP_RES" xc:rgb\(255,000,255\) $MYPATH/patterns/magenta.png
convert -size "$DISP_RES" xc:rgb\(255,255,000\) $MYPATH/patterns/yellow.png
test 0 -eq $? && echo "[OK]" || echo "[FAIL]"

sync
printf "Installation complete, reboot the system................ \n"
