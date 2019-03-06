#!/bin/sh

_abort(){ echo; echo $@; echo; exit 1; }
get_vmid_by_name(){ vmname="$1"; vim-cmd vmsvc/getallvms | awk '{print $1"|"$2}' | egrep "^[0-9]+\|$vmname$" | cut -f1 -d'|'; }

name="$1"
[ "x$name" = "x" ] && exit 1

vmid=$(get_vmid_by_name "$name" 2>/dev/null)
[ "x$vmid" = "x" ] && _abort "#> Erro ao obter vmid"

# Filtrar status de ligado
temp=$(vim-cmd vmsvc/power.getstate $vmid | grep Powered.on)

if [ "x$temp" = "x" ]; then
	echo "#> VM ja esta desligada"
else
	echo "#> Desligando VM [$name] id $vmid"
	vim-cmd vmsvc/power.shutdown $vmid
	sn="$?"
	[ "$sn" = "0" ] && echo "#> Sucesso."
	[ "$sn" = "0" ] || echo "#> Falhou, errno $sn"
fi
