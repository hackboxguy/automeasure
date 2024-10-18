#!/bin/sh
#before invoking this script
#ensure "sudo apt-get install argyll mpv" so that spotread binary and mpv are installed
#ensure --wfile=/path/to/wfile.png exists for required resolution for white color
#for --tempered=/path/to/tempered_binary ensure required tempered binary exists
###############################################################################
LOOPCOUNT="none" #for 1hour, 120 samples@30sec/sample
INTERVAL="none"
TEMPERED="none"
WFILE="none"
RFILE="none"
GFILE="none"
BFILE="none"
CFILE="none"
MFILE="none"
YFILE="none"
STARTUPIMG="none"
MEASUREONLY="no"
x=1
USAGE="usage: $0 --measureonly=yes/no --loop=count --interval=seconds --startupimg=white --tempered=/path/to/tempered --wfile=/pathto/w.png --rfile=/pathto/r.png --gfile=/pathto/g.png --bfile=/pathto/b.png"
NOARGS="yes"

MYPATH=$(pwd) #get the path via cmdline args
export LD_LIBRARY_PATH=$MYPATH/brbox/output/lib
###############################################################################
#this function prints out the color and temperature sample of a given primary(rgb/w)
Colour_Temp_Sample() #$1=pattern-file $2=Color-Prefix-to-print $3=/path/to/tempered $4=startup-pattern $5=mplayclt-path
{
    if [ $4 = "none" ]; then
        $5 --showimg=none --showimg=$1 > /dev/null
        sleep 2
    fi
    
    #lets take the time stamp
	DATE=$(date "+%D,%T")

	#if requested, take the sample of the temperature from the usb-temperature sensor 
	if [ $3 != "none" ]; then
		    TEMP=$(sudo $3 | awk '{print $4}')
    else
		    TEMP="N/A"
	fi

   	#read the color/brightness sensor(try 3 times before giving up)
	VAL=$(sudo spotread -x -O | grep Result | sed 's/ Result is //' | sed 's/XYZ://' | sed 's/Yxy://' | sed 's/,//')
    WORDS=$(echo "$VAL"|wc -c)
    if [ $WORDS = 1 ]; then #color sample failed, try again
            #echo "failed first read"
            sleep 3
            VAL=$(sudo spotread -x -O | grep Result | sed 's/ Result is //' | sed 's/XYZ://' | sed 's/Yxy://' | sed 's/,//')
            WORDS=$(echo "$VAL"|wc -c)
            if [ $WORDS = 1 ]; then #color sample failed, try again
                #echo "failed second read as well!!! wods=$WORDS"
                sleep 5
                VAL=$(sudo spotread -x -O | grep Result | sed 's/ Result is //' | sed 's/XYZ://' | sed 's/Yxy://' | sed 's/,//')
            fi
    fi

	#fetch individual values to the corresponding variables 
	XVAL=$(echo $VAL | awk '{print $1}')
    YVAL=$(echo $VAL | awk '{print $2}')
    ZVAL=$(echo $VAL | awk '{print $3}')
    YCVAL=$(echo $VAL | awk '{print $4}')
    xVAL=$(echo $VAL | awk '{print $5}')
    yVAL=$(echo $VAL | awk '{print $6}')
    
    #print out the sampled temperature and color/brightness data 
	echo "$DATE,$TEMP,$2,$XVAL,$YVAL,$ZVAL,$YCVAL,$xVAL,$yVAL"
	return 0
}

##############parse the arguments################################
optspec=":h-:"
while getopts "$optspec" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                    loop=*) #count
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        [ ! -z $LOOPCOUNT ] && LOOPCOUNT=${val}
                        NOARGS="no"
                        ;;
                    interval=*) #image-version
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        [ ! -z $INTERVAL ] && INTERVAL=${val}
                        NOARGS="no"
                        ;;
                    tempered=*) #/path/to/tempered
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        [ ! -z $TEMPERED ] && TEMPERED=${val}
                        NOARGS="no"
                        ;;
                    wfile=*) #yes/no
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        [ ! -z $WFILE ] && WFILE=${val}
                        NOARGS="no"
                        ;;
                    rfile=*) #yes/no
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        #MKIMAGE=${val}
                        [ ! -z $RFILE ] && RFILE=${val}
                        NOARGS="no"
                        ;;
                    gfile=*) #yes/no
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        [ ! -z $GFILE ] && GFILE=${val}
                        NOARGS="no"
                        ;;
                    bfile=*) #yes/no
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        [ ! -z $BFILE ] && BFILE=${val}
                        NOARGS="no"
                        ;;
                    startupimg=*) #white/red/green/cyan/magenta/yellow
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        [ ! -z $STARTUPIMG ] && STARTUPIMG=${val}
                        NOARGS="no"
                        ;;
                    measureonly=*) #yes/no
                        val=${OPTARG#*=}
                        opt=${OPTARG%=$val}
                        [ ! -z $MEASUREONLY ] && MEASUREONLY=${val}
                        NOARGS="no"
                        ;;

                *)
                    if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                        echo "Unknown option:"
                        echo -n "${USAGE}";echo ""
                        exit 1
                    fi
                    ;;
            esac;;
        h)
                echo -n "${USAGE}";echo ""
                exit 0
            ;;
        *)
                echo "Unknown option:"
                echo -n "${USAGE}";echo ""
                exit 1
            ;;
    esac
done

if [ ${NOARGS} = "yes" ] ; then
    echo -n "${USAGE}";echo ""
    exit 0
fi

TEMPEREDPATH="$MYPATH/Output/usb-tempered/utils/$TEMPERED"
MPLAYCLT="$MYPATH/brbox/output/bin/mplayclt"
WFILEPATH="$MYPATH/patterns/$WFILE"
RFILEPATH="$MYPATH/patterns/$RFILE"
GFILEPATH="$MYPATH/patterns/$GFILE"
BFILEPATH="$MYPATH/patterns/$BFILE"

#if valid files doesnt exists, then dont access them
[ ! -f  $TEMPEREDPATH  ] && TEMPEREDPATH="none" 
[ ! -f  $MPLAYCLT  ] && MPLAYCLT="none" 
[ ! -f  $WFILEPATH  ] && WFILEPATH="none" 
[ ! -f  $RFILEPATH  ] && RFILEPATH="none" 
[ ! -f  $GFILEPATH  ] && GFILEPATH="none" 
[ ! -f  $BFILEPATH  ] && BFILEPATH="none" 

#TODO: check if spotread exists
if [ $MEASUREONLY = "no" ]; then
    if [ $STARTUPIMG != "none" ]; then
            $MPLAYCLT --showimg=none --showimg="$WFILEPATH" > /dev/null
            sleep 2
    fi
fi

#lets output the heading for csv file
echo "DATE,TIME,temp,Sampled-Color,X,Y,Z,Y,x,y"
while [ $x -le $LOOPCOUNT ]; do

	if [ $WFILE != "none" ]; then
        Colour_Temp_Sample $WFILEPATH W $TEMPEREDPATH $STARTUPIMG $MPLAYCLT
		[ $? != 0 ] && exit 0
	fi
	
	if [ $RFILE != "none" ]; then
        Colour_Temp_Sample $RFILEPATH R $TEMPEREDPATH $STARTUPIMG $MPLAYCLT
		[ $? != 0 ] && exit 0
	fi

	if [ $GFILE != "none" ]; then
        Colour_Temp_Sample $GFILEPATH G $TEMPEREDPATH $STARTUPIMG $MPLAYCLT
		[ $? != 0 ] && exit 0
	fi
	
	if [ $BFILE != "none" ]; then
        Colour_Temp_Sample $BFILEPATH B $TEMPEREDPATH $STARTUPIMG $MPLAYCLT
		[ $? != 0 ] && exit 0
	fi
	
    #wait between measurements if asked
    if [ $INTERVAL != "none" ]; then
        sleep $INTERVAL
    fi
	x=$(($x+1))
done

#after completing the loop, remove the pattern
if [ $MEASUREONLY = "no" ]; then
    $MPLAYCLT --showimg=none > /dev/null
fi
