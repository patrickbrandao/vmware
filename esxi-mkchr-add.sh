#!/bin/sh
#
#
#=======================================================================================================================================
#
#
# Adicionar VM padrao para Mikrotik CHR no VMWare ESXI 6.5
# Autor: Patrick Brandao <patrickbrandao@gmail.com>
# Copyright: Todos os direitos reservados 2006-2018
#
#=======================================================================================================================================
#
#	1 - Crie uma pasta no storage com as imagens VMDK baixadas do site da Mikrotik
#
#	cd /vmfs/volumes/datastore1/
#	mkdir VHD-Templates
#	cd VHD-Templates/
#	wget http://download2.mikrotik.com/routeros/6.39.3/chr-6.39.3.vmdk
#	wget http://download2.mikrotik.com/routeros/6.41/chr-6.41.vmdk
#
#
#	2 - Baixe o script
#
#	mkdir /vmfs/volumes/datastore1/Scripts
#	cd /vmfs/volumes/datastore1/Scripts
#	wget http://www.tmsoft.com.br/temp/esxi-mkchr-add.sh -O esxi-mkchr-add.sh
#	chmod +x mkchr-add.sh
#
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
#    Mikrotik RouterBoard - Routerboard.com
#		e4:8d:8c
#		4c:5e:0c
#		6c:3b:6b
#		d4:Ca:6d
#		00:0c:42
#		64:d1:54
#
# Use a ajuda:
#
#    ./esxi-mkchr-add.sh --help
#
# Exemplo:
#    ./esxi-mkchr-add.sh 00:0c:42 vmid=1 name=vMikrotik-01 hd=/vmfs/volumes/datastore1/VHD-Templates/chr-6.41.vmdk netfind=trunk
#
#=======================================================================================================================================
#
# Constantes
    BIOS_PREFIX="56 4d 7f 55 2a a6 66 66"
    VMID_PREFIX="52 2f 59 2d ff a7 66 61"

    # CPUs: entre 4 e 128 nucleos
    MINCPUS=1
    MAXCPUS=128
    # RAM: entre 2 gigas e 128 gigas
    MINMEMORY=128
    MAXMEMORY=131072
    # HD: entre 100 megas e 100.000 megas (100 gigas)
    MINHDSIZE=100
    MAXHDSIZE=100000

    # Datastore padrao do vmware
    DEFDATASTORE="/vmfs/volumes/datastore1"

# Pre-definicoes:
    VMID=""
    HVMID=""
    PREFIX="vMikrotik-CHR"
    VNAME=""
    MEMORY=4096
    CPUS=4
    AFFINITY="all"
    HDSIZE=512
    HDTEMPLATEPATH=""
    MACOWNER="00:0b:a9"
    DATASTORE="$DEFDATASTORE"
    VMPATH=""
    REGISTER=yes
    NETCONN=""

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
		#uuid.bios .......: "56 4d 7f 55 2a a7 28 7e-22 be 3a 01 a7 0f 04 14"
		#uuid.location ...: "56 4d 7f 55 2a a7 28 7e-22 be 3a 01 a7 0f 04 14"
		#vc.uuid .........: "52 2f 59 2d ff a9 c0 f8-b1 eb 4a e6 19 bb ba d1"
		#test ............: "56 4d 7f 55 2a a7 28 7e-59 ee 2a 8f 8a c4 eb 91"
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
		echo "  HD-SIZE...............: $HDSIZE"
		echo "  MAC-OWNER.............: $MACOWNER"
		echo "  DATASTORE.............: $DATASTORE"
		echo "  REGISTER..............: $REGISTER"
		echo "  HDTEMPLATEPATH........: $HDTEMPLATEPATH"
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
		echo
		echo "Opcoes:"
		echo " prefix=STR            Prefixo do nome da maquina (nome final: @prefix-@vmid"
		echo " name=STR              Nome da maquina virtual (opcional, usar prefix e vmid por padrao)"
		echo " cpus=N                Especificar o numero de CPUs (minimo: $MINCPUS)"
		echo " affinity=x,y,z,w      Especificar afinidade de nucleos"
		echo " memory=N              Especificar quantidade de RAM em MB (minimo: $MINMEMORY MB)"
		echo " unreg                 Nao registrar VM (apenas criar no datastore)"
		echo " macowner=XX:XX:XX     Especificar prefixo de MAC-Address, ou 'auto' para deixar automatico"
		echo " hdsize=N              Especificar o tamanho do HD (resize) em Mb (minimo: $MINHDSIZE Mb, maximo: $MAXHDSIZE Mb)"
		echo " hd=/vmfs/...          Especificar o caminho para o arquivo VMDK padrao (a ser copiado)"
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

		# nao registrar
		[ "x$arg" = "xnoreg" ] && REGISTER=no && continue

		# diretorio de datastore informado
		[ "x$tmp" = "x" ] || echo "DS: $tmp"

		# argumento numerico:
		num=$(echo $arg | egrep '^[0-9]+$')
		if [ "x$num" != "x" ]; then
			# entre 1 e 99 -> VMID
			[ "x$VMID" = "x" ] && [ "$num" -ge 1 -o "$num" -lt 99 ] && VMID="$num" && continue

			# entre mincpus e maxcpus
			[ "x$CPUS" = "x" ] && [ "$num" -ge "$MINCPUS" ] && [ "$num" -le "$MAXCPUS" ] && CPUS="$num" && continue

			# entre minmemory e maxmemory
			echo " MEMORY[$MEMORY] Num[$num] MINMEMORY[$MINMEMORY] MAXMEMORY[$MAXMEMORY]"
			[ "x$MEMORY" = "x" ] && [ "$num" -ge "$MINMEMORY" ] && [ "$num" -le "$MAXMEMORY" ] && MEMORY="$num" && continue

			# entre minhdsize e maxhdsize
			[ "x$HDSIZE" = "x" ] && [ "$num" -ge "$MINHDSIZE" ] && [ "$num" -le "$MAXHDSIZE" ] && HDSIZE="$num" && continue
		fi

		# argumento mac owner prefix
		macprefix=$(echo $arg | egrep '^[0-9a-fA-F:]{2}:[0-9a-fA-F:]{2}:[0-9a-fA-F:]{2}$')
		[ "x$macprefix" = "x" ] || MACOWNER="$macprefix"

		# argumento e' um arquivo, deve ser o VHD
		if [ -f "$arg" ]; then
			echo "$arg" | egrep '\.vmdk$' 1>/dev/null 2>/dev/null && HDTEMPLATEPATH="$arg" && continue
		fi

		# Analisar argumento
		vname=$(echo $arg | cut -f1 -s -d= | sed 's#^-##;s#^-##;')
		vle=$(echo $arg | cut -f2 -s -d=)
		[ "x$vname" = "x" ] && continue
		[ "x$vle" = "x" ] && continue
		[ "$vname" = "vmid" ] && VMID="$vle" && continue
		[ "$vname" = "cpus" ] && CPUS="$vle" && continue
		[ "$vname" = "affinity" ] && AFFINITY="$vle" && continue
		[ "$vname" = "memory" ] && MEMORY="$vle" && continue
		[ "$vname" = "hdsize" ] && HDSIZE="$vle" && continue
		[ "$vname" = "hd" -o "$vname" = "disk" ] && HDTEMPLATEPATH="$vle" && continue
		[ "$vname" = "macowner" ] && MACOWNER="$vle" && continue
		[ "$vname" = "vname" -o "$vname" = "name" ] && VNAME="$vle" && continue
		[ "$vname" = "prefix" -o "$vname" = "vprefix" ] && PREFIX="$vle" && continue
		[ "$vname" = "datastore" -o "$vname" = "path" ] && DATASTORE="$vle" && continue
		[ "$vname" = "netconn" ] && NETCONN="$NETCONN,$vle" && continue
		[ "$vname" = "netfind" ] && NETFIND="$vle" && continue
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
    [ "$AFFINITY" = "all" -o "$AFFINITY" = "$xAFFINITY" ] || _abort "Affinity invalido ( .$AFFINITY. )"
    [ "$MEMORY" = "$xMEMORY" ] || _abort "Tamanho de memoria invalida ( .$MEMORY. )"
    [ "$MEMORY" -lt "$MINMEMORY" ] && _abort "Tamanho de memoria insuficiente ( .$MEMORY. < .$MINMEMORY. Mb )"
    [ "$MEMORY" -gt "$MAXMEMORY" ] && _abort "Tamanho de memoria excedente ( .$MEMORY. < .$MAXMEMORY. Mb )"
    [ "$HDSIZE" = "$xHDSIZE" ] || _abort "Tamanho de HD invalido ( .$HDSIZE. )"
    [ "$HDSIZE" -lt "$MINHDSIZE" ] && _abort "Tamanho de disco insuficiente ( $HDSIZE < $MINHDSIZE Mb )"
    [ "$HDSIZE" -gt "$MAXHDSIZE" ] && _abort "Tamanho de disco excedente ( $HDSIZE > $MAXHDSIZE Mb )"
    [ "$MACOWNER" = "$xMACOWNER" ] || _abort "Prefixo de MAC invalido ( .$MACOWNER. )"
    [ "$DATASTORE" = "$xDATASTORE" ] || _abort "Diretorio de datastore invalido ( .$DATASTORE. )"
    [ "$VNAME" = "$xVNAME" ] || _abort "Nome da maquina virtual invalido ( a-z 0-9 . - _ )"
    [ "$PREFIX" = "$xPREFIX" ] || _abort "Nome da maquina virtual invalido ( a-z 0-9 . - _ )"
    [ -d "$DATASTORE" ] || _abort "Diretorio de datastore nao e' diretorio ( .$DATASTORE. )"
    [ "x$VNAME" = "x" -a "x$PREFIX" = "x" ] && _abort "O nome ou o prefixo precisam ser informados"
    [ "$NETCONN" = "$xNETCONN" ] || _abort "Nome de port-group invalido ( a-z 0-9 . - _ )"

    # Nenhuma chave de busca por port-group presente
    [ "x$NETCONN_LIST" = "x" -a "x$NETFIND" = "x" ] && _abort "Nenhuma conexao de rede possivel, use netconn=PG ou netfind=REGEX"

    # Template de disco existe?
    [ "x$HDTEMPLATEPATH" = "x" ] && _abort "Caminho para o disco modelo nao informado (informe hd=/vmfs/..)"
    [ -f "$HDTEMPLATEPATH" ] || _abort "Arquivo do disco modelo nao encontrado [$HDTEMPLATEPATH]"

# Gerar ID de 2 digitos, zeros a esquerda
    HVMID="$VMID"
    LEN=$(echo -n $VMID | wc -c)
    [ "$LEN" = "1" ] && HVMID="0$VMID"

# Gerar nome padrao
    [ "x$VNAME" = "x" ] && VNAME="$PREFIX-$HVMID"

# Montar diretorio final
    VMPATH="$DATASTORE/$VNAME"
    [ -d "$VMPATH" ] && _abort "O diretorio de destino para nova maquina ja existe: $VMPATH"

# Carregar nome das port-groups
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
    VMVHDPATH="$VMPATH/$VHDNAME"
	echo "+ Copiando modelo de HD virtual:"
	echo "  src> $HDTEMPLATEPATH"
	echo "  dst> $VMVHDPATH"
	vmkfstools -i "$HDTEMPLATEPATH" "$VMVHDPATH" -d thin; sn="$?"
	if [ "$sn" != "0" ]; then
    	_abort "FATAL: erro $sn ao copiar $VMVHDPATH [ vmkfstools -i '$HDTEMPLATEPATH' '$VMVHDPATH' -d thin]"
	fi
	# Sincronizar com disco
	sync

	echo "+ Redimencionando tamanho do disco"
	FLAT_VHDNAME="${VNAME}_0-flat.vmdk"
	FLAT_VMVHDPATH="$VMPATH/$FLAT_VHDNAME"
	[ -f "$FLAT_VMVHDPATH" ] || _abort "FATAL: arquivo VHD VMDK Flat nao encontrado: $FLAT_VHDNAME [$FLAT_VMVHDPATH]"

	vhdtotalsizeb=$(stat -c "%s" "$FLAT_VMVHDPATH")
	vhdfinalsizeb=$(($HDSIZE*1024*1024))
	echo "  actual size> $vhdtotalsizeb bytes"
	echo "  target size> $vhdfinalsizeb bytes"
	if [ "$vhdtotalsizeb" -le "$vhdfinalsizeb" ]; then
		# Ampliar o disco
		vmkfstools -X "${HDSIZE}M" "$VMVHDPATH"
	elif [ "$vhdtotalsizeb" -gt "$vhdfinalsizeb" ]; then
		echo "  -- Desnecessario, ja esta maior que o tamanho requerido"
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
    echo -n " -> Gerandi ID de VM ...: "
    vm_uuid=$(_fake_uuid $VMID_PREFIX)
    echo "$vm_uuid"

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


# Parte 1 - definicoes gerais [OK]
cat > $vmxtmp-1 << EOF
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "13"
vmci0.present = "TRUE"
floppy0.present = "FALSE"
memSize = "$MEMORY"
bios.bootRetry.delay = "10"
sched.cpu.units = "mhz"
sched.cpu.affinity = "$AFFINITY"
powerType.suspend = "soft"
tools.upgrade.policy = "manual"
displayName = "$VNAME"
guestOS = "ubuntu-64"
numvcpus = "$CPUS"
toolScripts.afterPowerOn = "TRUE"
toolScripts.afterResume = "TRUE"
toolScripts.beforeSuspend = "TRUE"
toolScripts.beforePowerOff = "TRUE"
tools.syncTime = "FALSE"
uuid.bios = "$bios_uuid"
uuid.location = "$bios_uuid"
vc.uuid = "$vm_uuid"
sched.cpu.min = "0"
sched.cpu.shares = "normal"
sched.mem.min = "0"
sched.mem.minSize = "0"
sched.mem.shares = "normal"
EOF


# Parte 2 - definicao de rede
    cat $tmpeth > $vmxtmp-2


# Parte 3 - Disco Virtual [OK]
cat > $vmxtmp-2 << EOF
ide0:0.fileName = "$VHDNAME"
sched.ide0:0.shares = "normal"
sched.ide0:0.throughputCap = "off"
ide0:0.present = "TRUE"
EOF

# Parte 4 - (free)
cat > $vmxtmp-4 << EOF
EOF

# Parte 5 - options
cat > $vmxtmp-5 << EOF
cleanShutdown = "TRUE"
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



