#!/bin/bash

[ -n  "$1" ] || { echo "args error!";exit -1;}
procName=$1

[ `ps -e c -o cmd | grep $procName | wc -l` -eq 1 ] || { echo "not found process or process not only!";exit -1;}
pid=`ps -e c -o pid,cmd | grep $procName | awk '{print $1}'`

#间隔时间(s)
interval=1
#日志文件
logFileName=p"$pid"_t`date +%m%d%H%M%S`.csv
#磁盘IO单位
diskUnitName=MB
diskUnit=$((1024*1024))
#监控网卡名
netCardName=eth0

#rchar wchar rbytes wbytes
tmp_diskIO_array=(0 0 0 0)
#net_in net_out
tmp_netIO_array=(0 0)
function initLogFile() {
    echo "Time,PID,%CPU,%MEM,VSZ,RSS,rchar($diskUnitName),wchar($diskUnitName),rbytes($diskUnitName),wbytes($diskUnitName),netIN(MB),netOUT(MB),used(MB),buffers(MB),cached(MB)" > $logFileName
}
function log() {
    echo $1  >> $logFileName
}
function getDiskIO() {
    diskIO=`cat /proc/$pid/io`
    disk_arr=(`echo $diskIO | awk '{print $2,$4,$10,$12}'`)
#    rchar=`echo $diskIO | awk '{print $2}'`
#    wchar=`echo $diskIO | awk '{print $4}'`
#    rbytes=`echo $diskIO | awk '{print $10}'`
#    wbytes=`echo $diskIO | awk '{print $12}'`
#    arr=($rchar $wchar $rbytes $wbytes)
    echo ${disk_arr[*]}
}
function calculateDisk() {
   awk 'BEGIN{printf "%.2f\n",(('$1'-'$2')/'$diskUnit')}' 
}
function calculateNet() {
    awk 'BEGIN{printf "%.2f\n",(('$1'-'$2')/1024/1024)}' 
}
function getNetIO() {
    netIO=`ifconfig $netCardName | sed -n 8p`
    net_arr=(`echo $netIO | awk '{print $2}' | cut -d ":" -f 2 ` \  #net IN
             `echo $netIO | awk '{print $6}' | cut -d ":" -f 2 ` )  #net OUT
    echo ${net_arr[*]}
}
function getSysMemIO() {
    sysMemIO=`free -m`
    sysMem_arr=(`echo $sysMemIO | awk '{print $9,$16,$17}'`) #used,buffers,cached
    echo ${sysMem_arr[*]}
}
function getMemIO() {
    memIO=`cat /proc/$pid/status`
    #VmSzie    VmRSS    VmData    VmStk    VmExe    VmLib
    #虚拟内存  物理内存 数据段    栈       代码段   共享库代码段
    mem_arr=(`echo $memIO | awk '{print $34,$43,$46,$49,$52,$55}'`) 
}
initLogFile
while true
do
    diskIO_array=(`getDiskIO`)
    netIO_array=(`getNetIO`)
    log "`date +%H-%M-%S`, \
	     `ps -p $pid u | sed -n 2p | awk '{print $2,$3,$4,$5,$6}' | sed 's/ /,/g'`, \
         `calculateDisk ${diskIO_array[0]} ${tmp_diskIO_array[0]}`, \
         `calculateDisk ${diskIO_array[1]} ${tmp_diskIO_array[1]}`, \
         `calculateDisk ${diskIO_array[2]} ${tmp_diskIO_array[2]}`, \
         `calculateDisk ${diskIO_array[3]} ${tmp_diskIO_array[3]}`, \
         `calculateNet ${netIO_array[0]} ${tmp_netIO_array[0]}`,    \
         `calculateNet ${netIO_array[1]} ${tmp_netIO_array[1]}`,    \
         `getSysMemIO | sed 's/ /,/g'`    "
    sleep $interval
    tmp_diskIO_array=(${diskIO_array[*]})
    tmp_netIO_array=(${netIO_array[*]})
done
