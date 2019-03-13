#!/bin/sh

_abort(){ echo; echo "# ABORTADO $@"; echo; exit 9; }
_get_vmx_opt(){ egrep "$2" "$1" | head -1 | cut -f2 -d'"'; }
_rand_md5(){ head -c 100 /dev/urandom  | md5sum | awk '{print $1}'; }
get_vmid_by_name(){ vmname="$1"; vim-cmd vmsvc/getallvms | awk '{print $1"|"$2}' | egrep "^[0-9]+\|$vmname$" | cut -f1 -d'|'; }
_renew_uuid(){
  # Identidade e localizacao da VM
  tmp=$(_rand_md5)
  a0=$(echo $tmp | cut -b16-17); a1=$(echo $tmp | cut -b18-19)               
  a2=$(echo $tmp | cut -b20-21); a3=$(echo $tmp | cut -b22-23)
  a4=$(echo $tmp | cut -b24-25); a5=$(echo $tmp | cut -b26-27)
  b0=$(echo $tmp | cut -b1-2); b1=$(echo $tmp | cut -b3-4)
  b2=$(echo $tmp | cut -b5-6); b3=$(echo $tmp | cut -b7-8)
  b4=$(echo $tmp | cut -b9-10); b5=$(echo $tmp | cut -b11-12)
  b6=$(echo $tmp | cut -b13-14); b7=$(echo $tmp | cut -b15-16)
  dstuuidbios=$(echo "56 4d $a0 $a1 $a2 $a3 $a4 $a5-$b1 $b2 $b3 $b4 $b5 $b6 $b7")
  echo "$dstuuidbios"
}

#
# Gerar comandos para criar laboratorio de turma do curso VyOS TOTAL
#
# Turma:
group="$1"
[ "x$group" = "x" ] && group=1
group2="$group"
[ "$group" -lt 10 ] && group2="0$group"
echo "# Group:"
echo "# - group: $group"
echo "# - group2: $group2"

# Criar lista numerada de alunos de 01 a 99
students="$2"
[ "x$students" = "x" ] && students=2
numlist=""
num2list=""
numflist=""
for n in $(seq 1 1 $students); do
  num2="$n"
  [ "$n" -lt 10 ] && num2="0$n"
  numlist="$numlist $n"
  num2list="$num2list $num2"
  numflist="$numflist $n:$num2"
done
#echo "# Students list:"
#echo "# - numlist: $numlist"
#echo "# - num2list: $num2list"
#echo "# - numflist: $numflist"

# Criar R1 e R2 de todos os alunos
# Sequencias a serem trocadas no VMX:
#> zz : numero da turma/grupo (01, 02, 03, 04, ...)
#> yy : numero do aluno (01 a 99)
#> ww : numero do roteador (R1, R2, R3, ...)
#> xx : numero do roteador (numerico, 01, 02, 03, ...)
#> ttt : numero do aluno com 3 digitos (001 a 999)
#> xyz : nome da VM
#

# definicoes
storage="/vmfs/volumes/datastore2"
vhd="/vmfs/volumes/datastore1/VHDs/vyos.vmdk"
vmxr1="/vmfs/volumes/datastore1/VMXs/vyos-r1.vmx"
vmxr2="/vmfs/volumes/datastore1/VMXs/vyos-r2.vmx"
vmxr3="/vmfs/volumes/datastore1/VMXs/vyos-r3.vmx"

[ -d "$storage" ] || _abort "STORAGE $storage nao existe"
[ -f "$vhd" ] || _abort "VHD $vhd nao existe"
[ -f "$vmxr1" ] || _abort "Arquivo VMX $vmxr1 nao existe"
[ -f "$vmxr2" ] || _abort "Arquivo VMX $vmxr2 nao existe"
[ -f "$vmxr3" ] || _abort "Arquivo VMX $vmxr3 nao existe"

# - Copiar VHD e gerar VM
for x in $numflist; do
  n1=$(echo $x | cut -f1 -d:)
  n2=$(echo $x | cut -f2 -d:)
  n3=$(echo $x | cut -f3 -d:)
  echo "# Turma $group Aluno $n2"
  echo "echo '# Turma $group Aluno $n2'"

# Definicoes do R1
  name_r1="VyOS-T$group2-A$n2-R1"
  vm_dir_r1="$storage/$name_r1"
  vhd_r1="$vm_dir_r1/sda.vmdk"
  vmx_r1="$vm_dir_r1/$name_r1.vmx"
  uuid_r1=$(_renew_uuid $vmxr1)

# Definicoes do R2
  name_r2="VyOS-T$group2-A$n2-R2"
  vm_dir_r2="$storage/$name_r2"
  vhd_r2="$vm_dir_r2/sda.vmdk"
  vmx_r2="$vm_dir_r2/$name_r2.vmx"
  uuid_r2=$(_renew_uuid $vmxr2)

# Definicoes do R3
  name_r3="VyOS-T$group2-A$n2-R3"
  vm_dir_r3="$storage/$name_r3"
  vhd_r3="$vm_dir_r3/sda.vmdk"
  vmx_r3="$vm_dir_r3/$name_r3.vmx"
  uuid_r3=$(_renew_uuid $vmxr3)

  #----------------------------------------- R1
  echo "# - R1"
  echo "# -> name_r1......: $name_r1"
  echo "# -> vm_dir_r1....: $vm_dir_r1"
  echo "# -> vhd_r1.......: $vhd_r1"
  echo "# -> vmx_r1.......: $vmx_r1"
  echo "# -> uuid_r1......: $uuid_r1"
  echo "mkdir -p $vm_dir_r1"
  echo

  # - R1 - Clonar VHD
  echo "# - R1 - VHD"
  [ -f "$vhd_r1" ] && echo "# VHD R1 ja existe: $vhd_r1"
  [ -f "$vhd_r1" ] || echo "vmkfstools -i $vhd $vhd_r1"
  echo

  # - R1 - Gerar VMX
  echo "# - R1 - VMX"
  [ -f "$vmx_r1" ] && echo "# VMX R1 ja existe: $vmx_r1"
  [ -f "$vmx_r1" ] || echo "cat $vmxr1 | sed 's#abcd#$uuid_r1#g; s#xyz#$name_r1#g; s#xx#01#g; s#zz#$group2#g; s#yy#$n2#g; s#ww#R1#g; s#ttt#$n3#g;' > $vmx_r1"
  echo

  # - R1 - Registrar
  echo "# - R1 - Registrar"
  echo "vmid=\$(vim-cmd solo/registervm $vmx_r1)"
  echo 'vim-cmd vmsvc/power.on $vmid'
  echo
  echo

  #----------------------------------------- R2
  echo "# - R2"
  echo "# -> name_r2......: $name_r2"
  echo "# -> vm_dir_r2....: $vm_dir_r2"
  echo "# -> vhd_r2.......: $vhd_r2"
  echo "# -> vmx_r2.......: $vmx_r2"
  echo "# -> uuid_r2......: $uuid_r2"
  echo "mkdir -p $vm_dir_r2"
  echo

  # - R2 - Clonar VHD
  echo "# - R2 - VHD"
  [ -f "$vhd_r2" ] && echo "# VHD R2 ja existe: $vhd_r2"
  [ -f "$vhd_r2" ] || echo "vmkfstools -i $vhd $vhd_r2"
  echo

  # - R2 - Gerar VMX
  echo "# - R2 - VMX"
  [ -f "$vmx_r2" ] && echo "# VMX R2 ja existe: $vmx_r2"
  [ -f "$vmx_r2" ] || echo "cat $vmxr2 | sed 's#abcd#$uuid_r2#g; s#xyz#$name_r2#g; s#xx#01#g; s#zz#$group2#g; s#yy#$n2#g; s#ww#R1#g; s#ttt#$n3#g;' > $vmx_r2"
  echo

  # - R2 - Registrar
  echo "# - R2 - Registrar"
  echo "vmid=\$(vim-cmd solo/registervm $vmx_r2)"
  echo 'vim-cmd vmsvc/power.on $vmid'
  echo
  echo

  #----------------------------------------- R3
  echo "# - R3"
  echo "# -> name_r3......: $name_r2"
  echo "# -> vm_dir_r3....: $vm_dir_r2"
  echo "# -> vhd_r3.......: $vhd_r2"
  echo "# -> vmx_r3.......: $vmx_r2"
  echo "# -> uuid_r3......: $uuid_r2"
  echo "mkdir -p $vm_dir_r3"
  echo

  # - R3 - Clonar VHD
  echo "# - R3 - VHD"
  [ -f "$vhd_r3" ] && echo "# VHD R3 ja existe: $vhd_r3"
  [ -f "$vhd_r3" ] || echo "vmkfstools -i $vhd $vhd_r3"
  echo

  # - R3 - Gerar VMX
  echo "# - R3 - VMX"
  [ -f "$vmx_r3" ] && echo "# VMX R3 ja existe: $vmx_r3"
  [ -f "$vmx_r3" ] || echo "cat $vmxr3 | sed 's#abcd#$uuid_r3#g; s#xyz#$name_r3#g; s#xx#01#g; s#zz#$group2#g; s#yy#$n2#g; s#ww#R1#g; s#ttt#$n3#g;' > $vmx_r3"
  echo

  # - R3 - Registrar
  echo "# - R3 - Registrar"
  echo "vmid=\$(vim-cmd solo/registervm $vmx_r3)"
  echo 'vim-cmd vmsvc/power.on $vmid'
  echo
  echo

done

