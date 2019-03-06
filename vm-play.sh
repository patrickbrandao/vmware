#!/bin/sh

get_vmid_by_name(){ vmname="$1"; vim-cmd vmsvc/getallvms | awk '{print $1"|"$2}' | egrep "^[0-9]+\|$vmname$" | cut -f1 -d'|'; }

name="$1"
[ "x$name" = "x" ] && exit 1

vmid=$(get_vmid_by_name "$name" 2>/dev/null)
[ "x$vmid" = "x" ] && exit 2

isoff=$(vim-cmd vmsvc/power.getstate $vmid | egrep 'Powered.off')

if [ "x$isoff" = "x" ]; then
	echo "#> VM ja esta ligada"
else
	echo "#> Ligando VM [$name] id $vmid"
	vim-cmd vmsvc/power.on $vmid
	sn="$?"
	[ "$sn" = "0" ] && echo "#> Sucesso."
	[ "$sn" = "0" ] || echo "#> Falhou, errno $sn"
fi
