#!/bin/bash
#
#
#########################################################################################################################################

DATA=$(date --date "0 day ago" +%a-%d-%m-%Y)
init=true
config=(
    "CLIENTE="
    "TIME_BKCP="
    "DSTDIR="
    "FBDDIR="
    "FBDQUE="
    "ARQQUE="
    "ARQTGZQUE="
    "ARQDEL="
    "USER="
    "SENHA="
    "CIFSCOPY="
    "CIFSMOUNT="
    "CIFSUMOUNT="
    "CIFSREMOTE="
    "CIFSLOCAL="
    "CIFS_USER="
    "CIFS_PASSWORD="
    "CIFS_DOMAIN="
    "WPP_NOTIFI="
    "WPP_TOKEN="
    "WPP_DEST="
    "WPP_SERVER="
    )
configprint=(
    "CLIENTE="
    "TIME_BKCP=         #O numero de dias sempre inicia em 0 sendo 1 igual a dois dias"
    "DSTDIR="
    "FBDDIR=\"/opt/firebird/bin\""
    "FBDQUE=\"/home/firebird/questor.fdb\""
    "ARQQUE=\$DSTDIR/bkp-Questor-\$CUSTOM_NAME-\$CLIENTE-\$DATA.fbk"
    "ARQTGZQUE=\$DSTDIR/bkp-Questor-\$CUSTOM_NAME-\$CLIENTE-\$DATA.tgz"
    "ARQDEL=bkp-Questor-\$CUSTOM_NAME-\$CLIENTE"
    "USER=SYSDBA"
    "SENHA="
    "CIFSCOPY=false       #Se true Irá fazer a copia para o compartilhamento windows configurado"
    "CIFSMOUNT=false      #Se true irá montar o compartilhamento windows criado"
    "CIFSUMOUNT=false     #Se true irá desmontar o compartilhamento windows após o termino"
    "CIFSREMOTE=          #Endereço remoto usado no CIFS/comando de montagem"
    "CIFSLOCAL=           #Pasta local aonde será montado o compartilhamento"
    "CIFS_USER=           #Usuário utilizado para montar o compartilhamento"
    "CIFS_PASSWORD=''     #Senha utilizada para montar o compartilhamento(Deve ser mantida entre aspas simples)"
    "CIFS_DOMAIN=         #Dominio utilizado para montar o compartilhamento"
    "WPP_NOTIFI=          #Se será enviado notificação de erro por whatsapp"
    "WPP_TOKEN=''         #Token HTCHAT para envio"
    "WPP_DEST=            #Numero de destino do envio"
    "WPP_SERVER=          #Servidor HTCHAT"
    )



helpFunction(){
    echo ""
    echo "Uso: $0 -n Nome"
    echo " -n Adicionar Customização ao nome do arquivo de backup
    ex: $0 -n 10horas
    Vai Gerar um arquivo 
    $DSTDIR/bkp-Questor-10horas-$CLIENTE-$DATA.tgz"
}


while getopts "n:" opt
    do
        case "$opt" in
          n ) CUSTOM_NAME="$OPTARG" ;;
          ? ) helpFunction ;; 
    esac
done

if [ -z "$CUSTOM_NAME" ] 
    then
        echo "Erro: Você deve inserir um nome para o backup $CUSTOM_NAME";
        helpFunction
        exit 2
fi

if test -f "/scripts/bkp-questor.cfg"; then
    a=0
        for i in "${config[@]}"; do
            if ! grep -q "$i" "/scripts/bkp-questor.cfg"; then 
                echo "${configprint[$a]}" >> bkp-questor.cfg
                echo "${configprint[$a]}"
                init=false
            fi
            ((a=a+1))
        done
    source /scripts/bkp-questor.cfg
else
    init=false
    touch /scripts/bkp-questor.cfg
    for i in "${config[@]}"; do
        echo "${configprint[$a]}" >> /scripts/bkp-questor.cfg
        echo "${configprint[$a]}"
        ((a=a+1))
    done
fi

if [ "$init" = "false" ]; then
    echo "O arquivo bkp-questor.cfg Não existia ou estava com linhas faltantes, Ele foi corrigido, favor efetue as alterações necessarias e execute novamente"
    exit 2
fi
OPERATION_ID=$(od -vAn -N2 -tu2 < /dev/urandom)

log() {
    LOG_FILE="/var/log/backup_full.log"
    local message=$1
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local return_value=$2
    if [[ ! -z "$return_value" ]]; then
        echo "[${timestamp}] ${OPERATION_ID} ${message} (retorno: ${return_value})" >> "$LOG_FILE"
   else
        echo "[${timestamp}] ${OPERATION_ID} ${message}" >> "$LOG_FILE"
   fi
}
ARQTGZQUE2=$ARQTGZQUE


mountcifs() {
    df | awk '{print $1, $6}' |grep "$CIFSREMOTE $CIFSLOCAL" > /dev/null
    if [ $? != '0' ]; then
        mount.cifs $CIFSREMOTE $CIFSLOCAL -o user=$CIFS_USER,password="$CIFS_PASSWORD",domain=$CIFS_DOMAIN > /dev/null
        df | awk '{print $1, $6}' |grep "$CIFSREMOTE $CIFSLOCAL" > /dev/null
        retval=$?
    else
    retval='0'
    fi
    if [ $retval != '0' ]; then
        send_whats 2 > /dev/null
    fi
    echo $retval
}

umountcifs() {
    if [ $CIFSUMOUNT = true ]; then
        df | awk '{print $1, $6}' |grep "$CIFSREMOTE $CIFSLOCAL" >/dev/null
        if [ $? != '1' ]; then
            umount $CIFSLOCAL
        fi
    fi
}


send_whats() {
    case $1 in 
        1) 
        WPP_MSG="Destino CIFS está indisponivel e sua montagem está desativada! Cliente: $CLIENTE
        $(cat $LOG_FILE|grep $OPERATION_ID)"
            ex=1
        ;;
        2) 
        WPP_MSG="Falha ao montar o  destino CIFS. Verifique as credenciais e a conexão. Cliente: $CLIENTE "
            ex=2
        ;;
        3) 
        if [ $CIFSUMOUNT = true ]; then
            WPP_MSG="Erro ao efetuar o rsync do backup local para o destino CFIS, backup local será mantido e desmontará o destino CIFS. Cliente: $CLIENTE"
            umountcifs
        else
            WPP_MSG="Erro ao efetuar o rsync do backup local para o destino CFIS, backup local será mantido. Cliente: $CLIENTE"
        fi
            ex=3
        ;;
        4) 
        WPP_MSG="Falha ao gerar backup do banco de dados FIREBIRD! Cliente: $CLIENTE"
            ex=4
        ;;
        5)
        WPP_MSG="Falha ao comprimir o arquivo do banco, backup cancelado!"
        ;;
    esac
    if [ $WPP_NOTIFI = true ]; then
        COUNT=1
        while [ $COUNT -le 20 ]; do

            log "Iniciando Tentativa de entrega de mensagem (Tentativa nº $COUNT) ..."
            LOGCAT=$(cat $LOG_FILE |grep $OPERATION_ID)
            curl --insecure -X POST \
            -H "Content-Type:application/json" \
            -H "token:$WPP_TOKEN"   \
            -d "{\"query\":\"mutation partner_api_send_message{partner_api_send_message(recipient:\\\"$WPP_DEST\\\" message:\\\"$WPP_MSG \\\n LOG: \\\n $LOGCAT\\\" tipo:\\\"text\\\"){message}}\",\"variables\":{},\"operationName\":\"partner_api_send_message\"}"\
             https://$WPP_SERVER/graphql_api
            
            RET=$?

            if [ $RET -eq 0 ]; then
                log "Tentativa de envio de mensagem numero $COUNT relizada com sucesso!"
                exit $ex
            else
                log "Tentativa de entrega numero $COUNT falhou!"
                log "Aguardando 30 segundos e tentando novamente!"
                sleep 30
                (( COUNT++ ))
            fi

        done
    fi
    exit 5
}

copy_to_cifs() {
    if [ $CIFSCOPY = false ]; then
        exit 0
    fi
        echo "cifs mount = "$CIFSMOUNT
    if [ $CIFSMOUNT = true ]; then
        mount_ok=$(mountcifs)
    else
        df | awk '{print $1, $6}' |grep "$CIFSREMOTE $CIFSLOCAL" > /dev/null
        mount_ok=$?
    fi
    if [ $mount_ok = '0' ]; then
        rsync -zuva $ARQTGZQUE2 $CIFSLOCAL
        if [ $? != 0 ]; then
            send_whats 3
        fi
    else
        send_whats 1
        exit 1
    fi
    umountcifs
    exit 0
}



apagando(){
    find_result_file=$(mktemp)
    log "Eliminando Backups antigos"
    log "Arquivos com $TIME_BKCP dias serao eliminados!"
    find $DSTDIR -name "*$ARQDEL*" -mtime +$TIME_BKCP -exec rm -fv {} ";"  > "$find_result_file"
    find_ok=$?
    while IFS= read -r line; do
        log "Arquivo : $line"
    done < "$find_result_file"
    line_count=$(wc -l < "$find_result_file")
    if [[ $line_count -eq 0 ]]; then
        log "Não haviam arquivos para serem removidos"
    else if [[ $line_count -eq 1 ]]; then
            log "Somente um arquivo foi removido"
        else 
            log "Um total de $line_count arquivos foram removidos"
        fi
    fi
    rm "$find_result_file"
    if [ $find_ok -eq 0 ] ; then
        log "Arquivos antigos removidos com sucesso!"
    else
        log "Erro ao tentar remover arquivos antigos!"
  fi
}

firebird(){
        log "Iniciando export do banco de dados firebird"

        $FBDDIR/gbak -b $FBDQUE $ARQQUE -user $USER -pas $SENHA 
    if [ $? -eq 0 ] ; then
        log "Export do banco efetuado com sucesso!"
        log "Iniciando compactação do arquivo"
        tar -czf $ARQTGZQUE2 $ARQQUE
        if [ $? -eq 0 ]; then
            log "Compactacao realizada com sucesso!"
            log "Removendo arquivo de export"
            rm -f $ARQQUE
            ls -lgoh $ARQTGZQUE2
        else
            log "Erro ao comprimir arquivo Cancelando backup"
            send_whats 5
            
        fi
    else
        log "Backup do firebird Falhou"
        
        send_whats 4
        exit 1
fi
}


apagando
firebird
copy_to_cifs
exit 0
