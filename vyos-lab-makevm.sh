#!/bin/sh

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
# - Copiar VHD de todos
storage="/vmfs/volumes/SSD"
vhd="/vmfs/volumes/SSD/VHDs/vyos-1.2.0-crux.vmdk"
vmxr1="/vmfs/volumes/SSD/VMXs/VyOS-R1.vmx"
vmxr2="/vmfs/volumes/SSD/VMXs/VyOS-R2.vmx"
for x in $numflist; do
  n1=$(echo $x | cut -f1 -d:)
  n2=$(echo $x | cut -f2 -d:)
  n3=$(echo $x | cut -f3 -d:)
  echo "# Turma $group Aluno $n2"
  # Criar pasta da VM R1
  name_r1="VyOS-T$group2-A$n2-R1"
  vm_dir_r1="$storage/$name_r1"
  vhd_r1="$vm_dir_r1/sda.vmdk"
  vmx_r1="$vm_dir_r1/$name_r1.vmx"
  uuid_r1=$(_renew_uuid $vmxr1)

  #- name_r2="VyOS-T$group2-A$n2-R2"
  #- vm_dir_r2="$storage/$name_r2"
  #- vhd_r2="$vm_dir_r2/sda.vmdk"
  #- vmx_r2="$vm_dir_r2/$name_r2.vmx"
  #- uuid_r2=$(_renew_uuid $vmxr2)

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
  echo "vim-cmd solo/registervm $vmx_r1"
  echo
  echo

done

