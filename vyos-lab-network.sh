#!/bin/sh

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
echo "# Students list:"
echo "# - numlist: $numlist"
echo "# - num2list: $num2list"
echo "# - numflist: $numflist"

# Criar vSwitch para cada aluno
for num in $num2list; do
  sw=vStudent-T$group2-A$num
  echo "# vSwitch: $sw"
  echo "esxcli network vswitch standard add --vswitch-name=$sw"
  echo "esxcli network vswitch standard set --vswitch-name=$sw --mtu=9000"
  echo "esxcli network vswitch standard policy security set --vswitch-name=$sw --allow-mac-change yes --allow-promiscuous yes"
  echo
  echo "# = Port-group trunk:"
  echo "    esxcli network vswitch standard portgroup add --portgroup-name=$sw-Net1 --vswitch-name=$sw"
  echo "    esxcli network vswitch standard portgroup set -p $sw-Net1 --vlan-id 4095"
  echo
  echo "# = local-connections:"
  echo "    esxcli network vswitch standard portgroup add --portgroup-name=$sw-Net2 --vswitch-name=$sw"
  echo "    esxcli network vswitch standard portgroup set -p $sw-Net2 --vlan-id 2"
  echo
  echo
done


#-
