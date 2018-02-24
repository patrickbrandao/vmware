#!/bin/sh
#
#
#=======================================================================================================================================
#
#
# Adicionar VM padrao para vRouter no VMWare ESXI 6.5
# Autor: Patrick Brandao <patrickbrandao@gmail.com>
# Copyright: Todos os direitos reservados 2006-2018
#
# Use a ajuda:
#
#    ./esxi-vm-add.sh --help
#
# Exemplo:
#    ./esxi-vm-add.sh
#		00:ca:fe iso=/vmfs/volumes/HD2/ISOs/tmsoft-vrouter-2.0-20171019-1705.iso netfind=trunk name=vRouter-01 vmid=1
#
# MACs OID:
#	Cisco:
# 		00:A2:89
# 		00:2c:c8
# 		00:0c:41
#	Juniper Networks
#		00:05:85
#		00:10:DB
#		00:12:1E
#		00:14:F6
#		00:17:CB
#		00:19:E2
#
# Criacao em passa (9 vRouters):
# TOTAL=9
# for id in $(seq 1 1 $TOTAL); do /tmp/esxi-vm-add.sh iso=auto 00:ca:fe netfind=trunk vmid=$id name=vRouter-0$id; done
#
#
# Exemplo 1, servidor com 24 nucleos e 32 gb de RAM:
#       /tmp/esxi-vm-add.sh 00:21:59 iso=auto netfind=trunk name=vPPPoE-01 vmid=1 affinity=0,1,2,3,4,5 cpus=6 memory=4096 hdsize=20
#       /tmp/esxi-vm-add.sh 00:21:59 iso=auto netfind=trunk name=vPPPoE-02 vmid=2 affinity=6,7,8,9,10,11 cpus=6 memory=4096 hdsize=20
#       /tmp/esxi-vm-add.sh 00:21:59 iso=auto netfind=trunk name=vPPPoE-03 vmid=3 affinity=12,13,14,15,16,17 cpus=6 memory=4096 hdsize=20
#
#       /tmp/esxi-vm-add.sh 00:05:85 iso=auto netfind=trunk name=vDNS-01 vmid=11 affinity=18,19,20,21 cpus=4 memory=2048 hdsize=20
#       /tmp/esxi-vm-add.sh 00:05:85 iso=auto netfind=trunk name=vDNS-02 vmid=12 affinity=18,19,20,21 cpus=4 memory=2048 hdsize=20
#
#       /tmp/esxi-vm-add.sh 00:2c:c8 iso=auto netfind=trunk name=vRouter-BGP vmid=21 affinity=18,19,20,21 cpus=4 memory=4096 hdsize=30
#
#       /tmp/esxi-vm-add.sh 00:0c:41 iso=auto netfind=trunk name=vUbuntu-SRVAPP-01 vmid=31 affinity=22,23 cpus=4 memory=2048
#
# Exemplo 2, servidor com 16 nucleos e 24 gb de RAM:
#       /tmp/esxi-vm-add.sh 00:05:85 iso=auto netfind=trunk name=BRAS-05 vmid=11 affinity=0,1,2,3 cpus=4 memory=4096 hdsize=20
#       /tmp/esxi-vm-add.sh 00:05:85 iso=auto netfind=trunk name=BRAS-06 vmid=12 affinity=4,5,6,7 cpus=4 memory=4096 hdsize=20
#       /tmp/esxi-vm-add.sh 00:05:85 iso=auto netfind=trunk name=BRAS-07 vmid=13 affinity=8,9,10,11 cpus=4 memory=4096 hdsize=20
#       /tmp/esxi-vm-add.sh 00:05:85 iso=auto netfind=trunk name=BRAS-08 vmid=14 affinity=12,13,14,15 cpus=4 memory=4096 hdsize=20
#
# Exemplo 3, servidor com 48 nucleos e 140 gb de RAM:
#       /tmp/esxi-vm-add.sh 00:2c:c8 iso=auto netfind=trunk name=vBGP-01 vmid=1 affinity=0,1,2,3,5,6,7 cpus=8 memory=4096 hdsize=20
#
#       /tmp/esxi-vm-add.sh 00:2c:c8 iso=auto netfind=trunk name=vRouter-BRAS-01 vmid=11 affinity=8,9,10,11,12,13,14,15 cpus=8 memory=8192 hdsize=20
#       /tmp/esxi-vm-add.sh 00:2c:c8 iso=auto netfind=trunk name=vRouter-BRAS-02 vmid=12 affinity=16,17,18,19,20,21,22,23 cpus=8 memory=8192 hdsize=20
#
#       /tmp/esxi-vm-add.sh 00:0c:41 iso=auto netfind=trunk name=vRouter-DNS vmid=21 affinity=24,25,26,27 cpus=4 memory=4096 hdsize=10
#
#=======================================================================================================================================
#
#
#
#
# Constantes
    BIOS_PREFIX="56 4d 7f 55 2a a7 28 7e"
    VMID_PREFIX="52 2f 59 2d ff a9 c0 f8"

    # CPUs: entre 4 e 128 nucleos
    MINCPUS=1
    MAXCPUS=128
    # RAM: em megas, entre 128 megas e 128 gigas
    MINMEMORY=128
    MAXMEMORY=131072
    # HD: em gigas, entre 1 gigas e 8 teras
    MINHDSIZE=1
    MAXHDSIZE=8000

    # Datastore padrao do vmware
    DEFDATASTORE="/vmfs/volumes/datastore1"

# Pre-definicoes:
    VMID=""
    HVMID=""
    PREFIX="vRouter"
    VNAME=""
    MEMORY=4096
    CPUS=4
    AFFINITY="0,1,2,3"
    ISOIMAGE=""
    HDSIZE=20
    MACOWNER="00:0b:a9"
    DATASTORE="$DEFDATASTORE"
    VMPATH=""
    REGISTER=yes
    CREATEHD=yes
    NETCONN=""
    LOCATION=""
    VHV=FALSE

# Locais
    TS=$(date '+%s')

# Funcoes

    # Gerar fake-uuid
    _random_hex(){ grep -m1 -ao '[0-9a-f][0-9a-f]' /dev/urandom | head -1; }
    _fake_uuid(){
				# 8 bytes em hexadecimal separados por espaco
				uuid_prefix="$@"
				# Parte randomica
				r1=$(_random_hex)
				r2=$(_random_hex)
				r3=$(_random_hex)
				r4=$(_random_hex)
				# Parte baseada no timestamp
				utc_ts=$(date '+%s')
				hex_ts=$(printf "%x\n" $utc_ts)
				p1=${hex_ts:0:2}
				p2=${hex_ts:2:2}
				p3=${hex_ts:4:2}
				p4=${hex_ts:6:2}
				_uuid="$uuid_prefix-$p1 $p2 $p3 $p4 $r1 $r2 $r3 $r4"
				echo "$_uuid"
    }

    # Gerar MAC
    macrand=$(_random_hex)
    _gen_mac(){
			seqnum="$1"
			hseqnum=$(printf "%x\n" $seqnum)
			c=$(echo -n $hseqnum | wc -c)
			[ "$c" = "1" ] && hseqnum="0$hseqnum"
			echo "$MACOWNER:$macrand:$HVMID:$hseqnum"
    }

    # Imprimir variaveis
    _print_info(){
			echo "#===================================="
			echo "  VM-ID.................: $VMID [$HVMID]"
			echo "  VM PREFIX.............: $PREFIX"
			echo "  VM NAME...............: $VNAME"
			echo "  VM PATH...............: $VMPATH"
			echo "  CPUs..................: $CPUS"
			echo "  CPU Affinity..........: $AFFINITY"
			echo "  MEMORY (RAM, Mb)......: $MEMORY"
			echo "  ISO-IMAGE.............: $ISOIMAGE"
			echo "  HD-SIZE...............: $HDSIZE"
			echo "  MAC-OWNER.............: $MACOWNER"
			echo "  DATASTORE.............: $DATASTORE"
			echo "  REGISTER..............: $REGISTER"
			echo "  CREATEHD..............: $CREATEHD"
			echo "  NETCONN...............: $NETCONN"
			echo "  NETFIND...............: $NETFIND"
			echo "#===================================="
    }
    # Abortar execucao
    _abort(){ echo; _print_info; echo; echo "Abortado: $1"; echo; exit $2; }
    _help(){
			_print_info
			echo "Use: $0 (parametros) [opcoes]"
			echo
			echo "Parametros:"
			echo " vmid=N                Numero da VM, de 1 a 99"
			echo " isoimage=PATH         Caminho da ISO, padrao 'auto' para detectar"
			echo
			echo "Opcoes:"
			echo " prefix=STR            Prefixo do nome da maquina (nome final: @prefix-@vmid"
			echo " name=STR              Nome da maquina virtual (opcional, usar prefix e vmid por padrao)"
			echo " location=STRUUID      UUID de identificacao do hypervisor (evitar dialog de copy/move ao dar play)"
			echo " cpus=N                Especificar o numero de CPUs (minimo: $MINCPUS)"
			echo " affinity=x,y,z,w      Especificar afinidade de nucleos"
			echo " memory=N              Especificar quantidade de RAM em MB (minimo: $MINMEMORY MB)"
			echo " unreg                 Nao registrar VM (apenas criar no datastore)"
			echo " macowner=XX:XX:XX     Especificar prefixo de MAC-Address"
			echo " hdsize=N              Especificar o tamanho do HD em GB (minimo: $MINHDSIZE Gb, maximo: $MAXHDSIZE)"
			echo " nohd                  Nao criar disco"
			echo " datastore=/vmfs/...   Caminho do DATASTORE (padrao: $DEFDATASTORE)"
			echo " netconn=PG,PG         Conexoes de rede, nome das Port-Group separadas por virgula"
			echo " netfind=REGEX         Conectar em port-groups que satisfacao a expressao regular"
			echo
    }

# Processar argumentos
    for arg in $@; do
		# Ajuda
		[ "$arg" = "-h" ] && _help
		[ "$arg" = "help" ] && _help
		[ "$arg" = "-help" ] && _help
		[ "$arg" = "--help" ] && _help
		
		# palavra "auto" para detectar iso
		[ "x$arg" = "xauto" ] && ISOIMAGE=auto && continue
		
		# desativar criacao do HD
		[ "x$arg" = "xnohd" ] && CREATEHD=no && continue

		# nao registrar
		[ "x$arg" = "xnoreg" ] && REGISTER=no && continue

		# diretorio de datastore informado
		#tmp=$(echo $arg | egrep '^/vmfs/volumes/.*')
		#[ "x$tmp" = "x" ] || [ -d "$tmp" ] && DATASTORE="$tmp" && continue
		[ "x$tmp" = "x" ] || echo "DS: $tmp"

		# argumento numerico:
		num=$(echo $arg | egrep '^[0-9]+$')
		if [ "x$num" != "x" ]; then

			#echo "A [$num]"
			# entre 1 e 99 -> VMID
			[ "x$VMID" = "x" ] && [ "$num" -ge 1 -o "$num" -lt 99 ] && VMID="$num" && continue

			#echo "B"
			# entre mincpus e maxcpus
			[ "x$CPUS" = "x" ] && [ "$num" -ge "$MINCPUS" ] && [ "$num" -le "$MAXCPUS" ] && CPUS="$num" && continue

			#echo "C"
			# entre minmemory e maxmemory
			echo " MEMORY[$MEMORY] Num[$num] MINMEMORY[$MINMEMORY] MAXMEMORY[$MAXMEMORY]"
			[ "x$MEMORY" = "x" ] && [ "$num" -ge "$MINMEMORY" ] && [ "$num" -le "$MAXMEMORY" ] && MEMORY="$num" && continue

			#echo "D"
			# entre minhdsize e maxhdsize
			[ "x$HDSIZE" = "x" ] && [ "$num" -ge "$MINHDSIZE" ] && [ "$num" -le "$MAXHDSIZE" ] && HDSIZE="$num" && continue

		fi
		#echo "E"

		# argumento mac owner prefix
		macprefix=$(echo $arg | egrep '^[0-9a-fA-F:]{2}:[0-9a-fA-F:]{2}:[0-9a-fA-F:]{2}$')
		[ "x$macprefix" = "x" ] || MACOWNER="$macprefix"

		# Analisar argumento
		vname=$(echo $arg | cut -f1 -s -d= | sed 's#^-##;s#^-##;')
		vle=$(echo $arg | cut -f2 -s -d=)
		[ "x$vname" = "x" ] && continue
		[ "x$vle" = "x" ] && continue
		#echo "VAR=$vname VALUE=$vle"
		[ "$vname" = "vmid" ] && VMID="$vle" && continue
		[ "$vname" = "location" -o "$vname" = "loc" ] && LOCATION="$vle" && continue
		[ "$vname" = "cpus" ] && CPUS="$vle" && continue
		[ "$vname" = "affinity" ] && AFFINITY="$vle" && continue
		[ "$vname" = "memory" ] && MEMORY="$vle" && continue
		[ "$vname" = "isoimage" -o "$vname" = "iso" ] && ISOIMAGE="$vle" && continue
		[ "$vname" = "hdsize" ] && HDSIZE="$vle" && continue
		[ "$vname" = "macowner" ] && MACOWNER="$vle" && continue
		[ "$vname" = "vname" -o "$vname" = "name" ] && VNAME="$vle" && continue
		[ "$vname" = "prefix" -o "$vname" = "vprefix" ] && PREFIX="$vle" && continue
		[ "$vname" = "datastore" -o "$vname" = "path" ] && DATASTORE="$vle" && continue
		[ "$vname" = "netconn" ] && NETCONN="$NETCONN,$vle" && continue
		[ "$vname" = "netfind" ] && NETFIND="$vle" && continue
		if [ "$vname" = "vhv" ]; then
			VHV=TRUE
			[ "$vle" = "0" -o "$vle" = "FALSE" -o "$vle" = "false" ] && VHV=FALSE
		fi
    done

# Critica obvia
    [ "x$VMID" = "x" ] && _abort "VMID nao foi especificado"
    [ "x$DATASTORE" = "x" ] && _abort "Datastore nao foi especificado"

# Filtrar caracters validos
    xVMID=$(echo $VMID | egrep '^[0-9]+$')
    xCPUS=$(echo $CPUS | egrep '^[0-9]+$')
    xAFFINITY=$(echo $AFFINITY | egrep '^[0-9,]+$')
    xMEMORY=$(echo $MEMORY | egrep '^[0-9]+$')
    xHDSIZE=$(echo $HDSIZE | egrep '^[0-9]+$')
    xMACOWNER=$(echo $MACOWNER | egrep '^[0-9a-fA-F:]{2}:[0-9a-fA-F:]{2}:[0-9a-fA-F:]{2}$')
    xDATASTORE=$(echo $DATASTORE | egrep '^/vmfs/volumes/.*')
    xVNAME=$(echo $VNAME | egrep '^[0-9a-zA-Z._-]+$')
    xPREFIX=$(echo $PREFIX | egrep '^[0-9a-zA-Z._-]+$')
    xNETCONN=$(echo $NETCONN | egrep '^[0-9a-zA-Z._,-]+$')

# Criticar entradas invalidas sintaticamente
    [ "$VMID" = "$xVMID" ] || _abort "VMID invalido ( .$VMID. )"
    [ "$CPUS" = "$xCPUS" ] || _abort "Numero de CPUs ( .$CPUS. )"
    [ "$CPUS" -lt "$MINCPUS" ] && _abort "Numero de CPUs insuficientes, minimo $MINCPUS ( .$CPUS. < $MINCPUS. Mb )"
    [ "$AFFINITY" = "$xAFFINITY" ] || _abort "Affinity invalido ( .$AFFINITY. )"
    [ "$MEMORY" = "$xMEMORY" ] || _abort "Tamanho de memoria invalida ( .$MEMORY. )"
    [ "$MEMORY" -lt "$MINMEMORY" ] && _abort "Tamanho de memoria insuficiente ( .$MEMORY. < .$MINMEMORY. Mb )"
    [ "$MEMORY" -gt "$MAXMEMORY" ] && _abort "Tamanho de memoria excedente ( .$MEMORY. < .$MAXMEMORY. Mb )"
    [ "$CREATEHD" = "yes" ] && [ "$HDSIZE" = "$xHDSIZE" ] || _abort "Tamanho de HD invalido ( .$HDSIZE. )"
    [ "$CREATEHD" = "yes" ] && [ "$HDSIZE" -lt "$MINHDSIZE" ] && _abort "Tamanho de disco insuficiente ( $HDSIZE < $MINHDSIZE Gb )"
    [ "$CREATEHD" = "yes" ] && [ "$HDSIZE" -gt "$MAXHDSIZE" ] && _abort "Tamanho de disco excedente ( $HDSIZE > $MAXHDSIZE Gb )"
    [ "$MACOWNER" = "$xMACOWNER" ] || _abort "Prefixo de MAC invalido ( .$MACOWNER. )"
    [ "$DATASTORE" = "$xDATASTORE" ] || _abort "Diretorio de datastore invalido ( .$DATASTORE. )"
    [ "$VNAME" = "$xVNAME" ] || _abort "Nome da maquina virtual invalido ( a-z 0-9 . - _ )"
    [ "$PREFIX" = "$xPREFIX" ] || _abort "Nome da maquina virtual invalido ( a-z 0-9 . - _ )"
    [ -d "$DATASTORE" ] || _abort "Diretorio de datastore nao e' diretorio ( .$DATASTORE. )"
    [ "x$VNAME" = "x" -a "x$PREFIX" = "x" ] && _abort "O nome ou o prefixo precisam ser informados"
    [ "$NETCONN" = "$xNETCONN" ] || _abort "Nome de port-group invalido ( a-z 0-9 . - _ )"

    # Nenhuma chave de busca por port-group presente
    [ "x$NETCONN_LIST" = "x" -a "x$NETFIND" = "x" ] && _abort "Nenhuma conexao de rede possivel, use netconn=PG ou netfind=REGEX"


# Gerar ID de 2 digitos, zeros a esquerda
    HVMID="$VMID"
    LEN=$(echo -n $VMID | wc -c)
    [ "$LEN" = "1" ] && HVMID="0$VMID"

# Gerar nome padrao
    [ "x$VNAME" = "x" ] && VNAME="$PREFIX-$HVMID"

# Localizar ISO:
    if [ "$ISOIMAGE" = "auto" ]; then
		isodirlist="
			/vmfs/volumes/datastore@
			/vmfs/volumes/datastore@/ISO
			/vmfs/volumes/datastore@/ISOs
			/vmfs/volumes/datastore@/ISOS
		"
		isolist=""
		# Procure nos datastores
		for storeid in 0 1 2 3; do
			for isodir in $isodirlist; do
				isopath=$(echo $isodir | sed "s#@#$storeid#")
				echo "ISO-PATH: $isopath"
				[ -d "$isopath" ] || continue
				# Diretorio existe, procurar tmsoft-vrouter-???
				isofile=$(ls $isopath/tmsoft-vrouter-* -r1 2>/dev/null | head -1)
				if [ -f "$isofile" ]; then
					isolist="$isolist $isofile"
					ISOIMAGE="$isofile"
					echo " -> ISO-IMAGE: $isopath :: $isofile"
				fi
			done
		done
		[ "$ISOIMAGE" = "auto" ] && _abort "ISO nao encontrada automaticamente"
	else
		# especificada ou ausente
		[ "x$ISOIMAGE" = "x" ] || [ -f "$ISOIMAGE" ] || _abort "ISO nao encontrada em ( .$ISOIMAGE. )"
    fi

# Montar diretorio final
    VMPATH="$DATASTORE/$VNAME"
    [ -d "$VMPATH" ] && _abort "O diretorio de destino para nova maquina ja existe: $VMPATH"

# Carregar nome das port-groups
    #echo "> Carregando lista de vSwitchs"
    #vswitchlist=$(esxcli network vswitch standard list | egrep -i '^[a-z0-9]')
    #vswitchlist=$(echo $vswitchlist)
    #echo " > vSwitchs: $vswitchlist"
    #for vs in $vswitchlist; do echo "  vSwitch ....: $vs"; done
    #echo "> Carregando nome das Port-Groups"
    
    echo "> Carregando lista de Port-Groups"
    portgroups=$(esxcli network vswitch standard list | grep Portgroups: | sed 's#Portgroups: ##g;s#,##g')
    echo "> Obtendo lista de Port-Groups a utilizar"
    # separar port-groups citados
    NETCONN_LIST=$(echo $NETCONN | sed 's#,# #g')
    NETCONN_COUNT=$(for x in $NETCONN_LIST; do echo $x; done | wc -l)
    # lista de busca
    echo "> Conexoes desejadas: $NETCONN_LIST"
    echo "> Conexoes magicas..: $NETFIND"
    #
    USEDPG=""
    for realpg in $portgroups; do
		echo -n "  - $realpg "
		# Procurar na NETCONN_LIST
		found=0
		if [ "x$NETCONN_LIST" != "x" ]; then
			for conn in $NETCONN_LIST; do
				if [ "$conn" = "$realpg" ]; then
					USEDPG="$USEDPG $realpg"
					found=1
				fi
			done
		fi
		# Procurar com NETFIND
		if [ "x$NETFIND" != "x" ]; then
			tst=$(echo $realpg | egrep -i "$NETFIND")
			if [ "x$tst" != "x" ]; then
				USEDPG="$USEDPG $realpg"
				found=1
			fi
		fi
		[ "$found" = "0" ] && echo " [ -- ]"
		[ "$found" = "1" ] && echo " [ OK ]"
    done
    # Remover nomes duplicados
    USEDPG=$(for x in $USEDPG; do echo $x; done | sort -u)
    USEDCOUNT=$(for x in $USEDPG; do echo $x; done | wc -l)

    # Problema, nenhuma PG selecionada
    [ "$USEDCOUNT" = "0" ] && _abort "Nenhuma port-group foi selecionada"
    echo "> Port-Groups selecionadas: "
    PGLIST=""; n=0
    for pg in $USEDPG; do
		mac=$(_gen_mac "$n")
		PGLIST="$PGLIST $n|$pg|$mac"
		echo "   *** [$mac] $pg"
		n=$(($n+1))
    done

# Criar diretorio da VM
    # ignorar diretorio vazio
    rmdir "$VMPATH" 2>/dev/null
    # criar:
    echo "+ Criando diretorio da VM: $VMPATH"
    mkdir -p "$VMPATH" || _abort "FATAL: erro $? ao criar diretorio $VMPATH"

# Criar disco virtual
    VHDNAME="${VNAME}_0.vmdk"
    VHDPATH="$VMPATH/$VHDNAME"
    if [ "$CREATEHD" = "yes" ]; then
		echo "+ Criando HD virtual: $VHDPATH"
		vmkfstools -c "${HDSIZE}g" "$VHDPATH"; sn="$?"
		if [ "$sn" != "0" ]; then
	    	_abort "FATAL: erro $sn ao criar $VHDPATH [ vmkfstools -C vmfs6 -c \"${HDSIZE}g\" \"$VHDPATH\" ]"
		fi
		# vmkfstools -C vmfs3 -b BlockSize -S DatastoreVolumeName /vmfs/devices/disks/ DeviceName:Partition
		# vmkfstools --createfs vmfs6 --blocksize 1m disk_ID:P
		# vmkfstools -C vmfs6 -b 1m disk_ID:P
		# vmkfstools -c 4g newvm.vmdk -a lsilogic
		# vmkfstools -i /vmfs/volumes/ULTRA/11101-PRNT01/11101-PRNT01.vmdk /vmfs/volumes/CRUCIAL/11101-RDBRK02/11101-RDBRK02.vmdk -d thin
		# vmkfstools -i /vmfs/volumes/<your-datastore>/<your-vm-folder>/<your -vm-folder>.vmdk /vmfs/volumes/<your-datastore>/<your--new-vm-folder>/<your-new-vm-folder>.vmdk -d thin
		# vmkfstools -c 2048m test1.vmdk
    fi

# Informar variaveis
    _print_info


# Criar a maquina
    vmsd="$VMPATH/$VNAME.vmsd"
    touch $vmsd

    vmx_file="$VMPATH/$VNAME.vmx"
    vmxtmp="/tmp/new-$VNAME"
    #vmx_file="/tmp/test.vmx"

    echo "> Criando a VM"
    echo    " -> Registro da maquina.: $vmx_file"

    # UUID para BIOS
    echo -n " -> Gerando ID de BIOS .: "
    bios_uuid=$(_fake_uuid $BIOS_PREFIX)
    echo "$bios_uuid"

    # UUID para VM ID
    echo -n " -> Gerando ID de VM ...: "
    vm_uuid=$(_fake_uuid $VMID_PREFIX)
    echo "$vm_uuid"

    # UUID do hypervisor
    echo -n " -> Gerando UUID do hypervisor ...: "
    [ "x$LOCATION" = "x" ] && LOCATION=$(_fake_uuid $VMID_PREFIX)
    echo "$LOCATION"

    # Gerar configuracao de rede 1:1
    tmpeth=/tmp/netconf-nic-$VNAME
    tmpmac=/tmp/netconf-mac-$VNAME
    echo -n > $tmpeth
    echo -n > $tmpmac
    lastid=0
    for pgreg in $PGLIST; do
		id=$(echo $pgreg | cut -f1 -d'|')
		pg=$(echo $pgreg | cut -f2 -d'|')
		mac=$(echo $pgreg | cut -f3 -d'|')
		(
			echo "ethernet$id.virtualDev = \"vmxnet3\""
			echo "ethernet$id.networkName = \"$pg\""
			echo "ethernet$id.addressType = \"static\""
			echo "ethernet$id.wakeOnPcktRcv = \"FALSE\""
			echo "ethernet$id.uptCompatibility = \"TRUE\""
			echo "ethernet$id.present = \"TRUE\""
		) >> $tmpeth
		echo "ethernet$id.address = \"$mac\"" > $tmpmac-$id
		lastid=$id
    done
    if [ "$lastid" != "0" ]; then
		# gerar atribuicao de macs ao contrario
		for id in $(seq $lastid -1 0); do
			cat $tmpmac-$id
			rm $tmpmac-$id 2>/dev/null
		done > $tmpmac
    fi


# Parte 1 - definicoes gerais
cat > $vmxtmp-1 << EOF
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "13"
vmci0.present = "TRUE"
floppy0.present = "FALSE"
numvcpus = "$CPUS"
memSize = "$MEMORY"
bios.bootRetry.delay = "10"
sched.cpu.units = "mhz"
sched.cpu.affinity = "$AFFINITY"
powerType.suspend = "soft"
tools.upgrade.policy = "manual"
scsi0.virtualDev = "pvscsi"
scsi0.present = "TRUE"
sata0.present = "TRUE"
usb.present = "TRUE"
ehci.present = "TRUE"
vhv.enable = "$VHV"
EOF


# Parte 2 - Disco Virtual
    if [ "$CREATEHD" = "yes" ]; then
cat > $vmxtmp-2 << EOF
scsi0:0.deviceType = "scsi-hardDisk"
scsi0:0.fileName = "$VHDNAME"
sched.scsi0:0.shares = "normal"
sched.scsi0:0.throughputCap = "off"
scsi0:0.present = "TRUE"
EOF
    fi


# Parte 3 - definicao de rede
    cat $tmpeth > $vmxtmp-3


# Parte 4 - CD: host ou ISO
    if [ "x$ISOIMAGE" = "x" ]; then
    # usar HOST
cat > $vmxtmp-4 << EOF
sata0:0.deviceType = "atapi-cdrom"
sata0:0.fileName = "/vmfs/devices/cdrom/mpx.vmhba0:C0:T4:L0"
sata0:0.present = "TRUE"
EOF
    else
	# usar ISO
	isopath=$(readlink -f $ISOIMAGE)
cat > $vmxtmp-4 << EOF
sata0:0.deviceType = "cdrom-image"
sata0:0.fileName = "$isopath"
sata0:0.present = "TRUE"
EOF
    fi

# Parte 5 - options
cat > $vmxtmp-5 << EOF
displayName = "$VNAME"
guestOS = "ubuntu-64"
toolScripts.afterPowerOn = "TRUE"
toolScripts.afterResume = "TRUE"
toolScripts.beforeSuspend = "TRUE"
toolScripts.beforePowerOff = "TRUE"
tools.syncTime = "FALSE"
uuid.bios = "$bios_uuid"
uuid.location = "$LOCATION"
vc.uuid = "$vm_uuid"
sched.cpu.min = "0"
sched.cpu.shares = "normal"
sched.mem.min = "0"
sched.mem.minSize = "0"
sched.mem.shares = "normal"
EOF


# Parte 6 - personalizacao de rede
    cat $tmpmac > $vmxtmp-6


# Parte 7 - Placa-mae
cat > $vmxtmp-7 << EOF
tools.guest.desktop.autolock = "FALSE"
nvram = "$VNAME.nvram"
pciBridge0.present = "TRUE"
svga.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
hpet0.present = "TRUE"
RemoteDisplay.maxConnections = "-1"
sched.cpu.latencySensitivity = "normal"
EOF

# Juntar tudo
for i in 1 2 3 4 5 6 7; do
    cat $vmxtmp-$i 2>/dev/null
    rm $vmxtmp-$i 2>/dev/null
done > $vmx_file

# - REGISTRAR VM
if [ "$REGISTER" = "yes" ]; then
    echo "+ Registrando maquina virtual"
    vim-cmd solo/registervm "$vmx_file"
    #esxcli software vib install -d "$VMPATH"; sn="$?"
    if [ "$sn" != "0" ]; then
	_abort "Erro $sn ao registrar VM [ esxcli software vib install -d \"$VMPATH\"  ]"
    fi
fi

echo "++++ CONCLUIDO"
echo
