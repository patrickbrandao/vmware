#!/bin/sh

#
# - Criar vswitchs padrao de todos os labs
#

# vSwitch de VPS de gerencia em Docker
  echo "# vSwitch: vDocker"
  echo "esxcli network vswitch standard add --vswitch-name=vDocker"
  echo "esxcli network vswitch standard set --vswitch-name=vDocker --mtu=9000"
  echo "    esxcli network vswitch standard portgroup add --portgroup-name=vDocker-Trunk --vswitch-name=vDocker"
  echo "    esxcli network vswitch standard portgroup set -p vDocker-Trunk --vlan-id 4095"
  echo
  echo

# vSwitch dos clientes PPPoE simulados
  echo "# vSwitch: vClients"
  echo "esxcli network vswitch standard add --vswitch-name=vClients"
  echo "esxcli network vswitch standard set --vswitch-name=vClients --mtu=9000"
  echo "    esxcli network vswitch standard portgroup add --portgroup-name=vClients-Trunk --vswitch-name=vClients"
  echo "    esxcli network vswitch standard portgroup set -p vClients-Trunk --vlan-id 4095"
  echo
  echo

# vSwitch dos links
  echo "# vSwitch: Links"
  echo "esxcli network vswitch standard add --vswitch-name=Links"
  echo "esxcli network vswitch standard set --vswitch-name=Links --mtu=9000"
  echo "    esxcli network vswitch standard portgroup add --portgroup-name=Links-Trunk --vswitch-name=Links"
  echo "    esxcli network vswitch standard portgroup set -p Links-Trunk --vlan-id 4095"
  echo
  echo

# vSwitch do IX-SP
  echo "# vSwitch: IX-SP"
  echo "esxcli network vswitch standard add --vswitch-name=IX-SP"
  echo "esxcli network vswitch standard set --vswitch-name=IX-SP --mtu=9000"
  echo "    esxcli network vswitch standard portgroup add --portgroup-name=IX-SP-Trunk --vswitch-name=IX-SP"
  echo "    esxcli network vswitch standard portgroup set -p IX-SP-Trunk --vlan-id 4095"
  echo
# vSwitch do IX-RJ
  echo "# vSwitch: IX-RJ"
  echo "esxcli network vswitch standard add --vswitch-name=IX-RJ"
  echo "esxcli network vswitch standard set --vswitch-name=IX-RJ --mtu=9000"
  echo "    esxcli network vswitch standard portgroup add --portgroup-name=IX-RJ-Trunk --vswitch-name=IX-RJ"
  echo "    esxcli network vswitch standard portgroup set -p IX-RJ-Trunk --vlan-id 4095"
  echo
