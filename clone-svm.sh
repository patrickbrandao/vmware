#!/bin/sh

#
# 
#
#
_abort(){ echo; echo "$@"; echo; exit 1; }
_srcvm_opt(){ egrep "$1" "$srccfg" | head -1 | cut -f2 -d'"'; }
_rand_md5(){ head -c 100 /dev/urandom  | md5sum | awk '{print $1}'; }

# Maquina original:
srcvm="$1"
srccfg="$srcvm/$srcvm.vmx"

# Maquina destino:
dstvm="$2"
dstcfg="$dstvm/$dstvm.vmx"

# ID de VM para MACs:
vmid="$3"

# MACs:
basemac="00:fa:fa:fa:00"
newmac="00:fa:fa:fa:$1"

# Critica basica
[ "x$srcvm" = "x" ] && _abort "Informe a vm de origem (arg 1)"
[ "x$dstvm" = "x" ] && _abort "Informe a vm de destino (arg 2)"
[ "x$vmid" = "x" ] && _abort "Informe o ID da nova vm (arg 3)"

# Info: 
echo
echo "- VMID...........: $vmid"
echo "- VM de origem...: $srcvm"
echo "              cfg: $srccfg"
echo "- VM de destino..: $dstvm"
echo "              cfg: $dstcfg"
echo

# Identidade e localizacao da VM
srcuuidbios=$(_srcvm_opt "uuid.bios")
p1=$(echo $srcuuidbios | cut -f1,2 -d' ')
tmp=$(_rand_md5)
a0=$(echo $tmp | cut -b16-17); a1=$(echo $tmp | cut -b18-19)               
a2=$(echo $tmp | cut -b20-21); a3=$(echo $tmp | cut -b22-23)
a4=$(echo $tmp | cut -b24-25); a5=$(echo $tmp | cut -b26-27)
b0=$(echo $tmp | cut -b1-2); b1=$(echo $tmp | cut -b3-4)
b2=$(echo $tmp | cut -b5-6); b3=$(echo $tmp | cut -b7-8)
b4=$(echo $tmp | cut -b9-10); b5=$(echo $tmp | cut -b11-12)
b6=$(echo $tmp | cut -b13-14); b7=$(echo $tmp | cut -b15-16)
dstuuidbios=$(echo "$p1 $a0 $a1 $a2 $a3 $a4 $a5-$b1 $b2 $b3 $b4 $b5 $b6 $b7")
echo "- SRC UUID ......: $srcuuidbios"
echo "- DST UUID ......: $dstuuidbios"
echo

# Descobrir a base do MAC:
mac0=$(cat $srccfg | egrep 'ethernet0.address......:'  | cut -f2 -d'"')
srcbasemac=$(echo $mac0 | cut -f1,2,3,4,5 -d:)
dstbasemac=$(echo $mac0 | cut -f1,2,3,4 -d:)

# Colocar id da vm na base do MAC:
hid="$vmid"
tmp=$(echo -n $hid | wc -c)
[ "$tmp" = "1" ] && hid="0$vmid"
dstbasemac="$dstbasemac:$hid"

echo "- MAC ether 0....: $mac0"
echo "- SRC MAC base...: $srcbasemac"
echo "- DST MAC base...: $dstbasemac"
echo

# Informacoes sobre o HD
srchd=$(cat $srccfg | grep scsi0:0.fileName | cut -f2 -d'"')
dsthd=$(echo $srchd | sed "s#$srcvm#$dstvm#g")
echo "- vHD src........: $srchd"
echo "- vHD dst........: $dsthd"
echo

#=================== INICIAR CLONAGEM ===================
# criar nova pasta
echo "  > Criando pasta: [$dstvm]"
mkdir $dstvm

# copiar config
echo "  > Criando config"
cp $srccfg $dstcfg

# trocar nome
echo "  > Novo nome"
sed -i "s#$srcvm#$dstvm#g" $dstcfg

# trocar uuid
echo "  > Novo UUID: $dstuuidbios"
sed -i "s#$srcuuidbios#$dstuuidbios#g" $dstcfg

# trocar base do mac
echo "  > Novo MAC: $newmac"
sed -i "s#$srcbasemac#$dstbasemac#g" $dstcfg

# copiar hd
echo "  > Copiando VMDK: [$srchd] => [$dsthd]"
vmkfstools -i $srcvm/$srchd $dstvm/$dsthd

# Registrar VM
newvmpath=$(readlink -f $dstcfg)
echo "  > Registrando $newvmpath"
vim-cmd solo/registervm "$newvmpath"

echo "  > Concluido: $dstvm"


