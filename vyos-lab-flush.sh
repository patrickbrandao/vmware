#!/bin/sh

#
# Limpar laboratorio de treinamento vyos
#

# 1 - Listar todos os port-groups Student
echo "# - Listando portgroups..."
esxcli network vswitch standard portgroup list | egrep -v 'Active.Clients' | grep -v '^----' | grep Student > /tmp/pglist
pgc=$(cat /tmp/pglist | wc -l)
echo "# - Student Port-groups: $pgc"
echo "# - Listando portgroups sem uso"
cat /tmp/pglist | awk '{print $1"|"$2"|"$3"|"$4}' | egrep '\|0|[0-9]+$' > /tmp/unused-pglist
upgc=$(cat /tmp/unused-pglist | wc -l)
echo "# - Unused Port-groups: $upgc"

# 2 - Apagar os port-groups Student
echo "# Apagando port-groups"
for reg in $(cat /tmp/unused-pglist); do
  pgn=$(echo $reg | cut -f1 -d'|')
  vsw=$(echo $reg | cut -f2 -d'|')
  vmc=$(echo $reg | cut -f3 -d'|')
  vid=$(echo $reg | cut -f4 -d'|')
  echo "# -- vSwitch [$vsw] port-group [$pgn] vms[$vmc] vlan-id[$vid]"
  echo "echo '# Apagando vSwitch [$vsw] port-group [$pgn] vms[$vmc] vlan-id[$vid]'"
  echo "esxcli network vswitch standard portgroup remove --portgroup-name='$pgn' --vswitch-name=$vsw"
  echo
done

# 3 - Apagar vSwitchs de Students
echo "# Apagando vswitchs"
vswStudent=$(esxcli network vswitch standard list | egrep 'Name:.*Student' | cut -f2 -d: | sort)
vswUnused=$(cat /tmp/unused-pglist | cut -f2 -d'|' | sort -u)
vswlist="$vswStudent $vswUnused"
for vsw in $vswlist; do
  echo "# -- vSwitch [$vsw]"
  echo "echo '# Apagando vSwitch [$vsw]'"
  echo "esxcli network vswitch standard remove --vswitch-name=$vsw"
  echo
done

# Fim
exit



# Comandos:
# - Lista vswitchs:
#   esxcli network vswitch standard list
#   esxcfg-vswitch --list
#   esxcli network vswitch standard list | grep 'Name:' | cut -f2 -d: | sort
#   vswitchlist=$(esxcli network vswitch standard list | grep 'Name:' | cut -f2 -d: | sort)
#
# - Listar portgroups (coluna 1: portgroup, coluna 2: vswitch, coluna 3: VMs conectadas, coluna 4: vlan-id):
#   esxcli network vswitch standard portgroup list
#   esxcli network vswitch standard portgroup list | egrep -v 'Active.Clients' | grep -v '^----' | awk '{print $1"|"$2"|"$3}'
#   pglist=$(esxcli network vswitch standard portgroup list | egrep -v 'Active.Clients' | grep -v '^----' | awk '{print $1"|"$2"|"$3}')
#
# - Listar portgroups em um vswitch (nome do vswitch de exemplo: vSwitch0):
#   ?
#   ?
#  esxcli network vswitch standard list


#-
#
