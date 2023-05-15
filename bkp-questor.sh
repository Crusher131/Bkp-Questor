#!/bin/bash
DATA=$(date --date "0 day ago" +%a-%d-%m-%Y)
#Parametros passados por comando
helpFunction()
{
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



echo " "
log() {
  LOG_FILE="/var/log/backup_full.log"
  local message=$1
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local return_value=$2
   if [[ ! -z "$return_value" ]]; then
    echo "[${timestamp}] ${message} (retorno: ${return_value})" >> "$LOG_FILE"
   else
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
   fi

  
}

dados(){

DATAIN=`date +%c`
log "##################################################################"
log "#                                                                "
log "#                 HARDTEC - INFORMATICA                          "
log "#               SISTEMA DE BACKUP - HARDTEC                      "
log "#                                                                "
log "##################################################################"
log " Backup iniciado em $DATAIN               "
log "------------------------------------------------------------------"
CLIENTE=""
EMAIL=""
TIME_BKCP="1"
DSTDIR="/diversos/backup"
#################### CONFIGURACOES PARA FIREBIRD ###########################################################

FBDDIR="/opt/firebird/bin"
FBDQUE="/home/firebird/questor.fdb"
ARQQUE=$DSTDIR/bkp-Questor-$CUSTOM_NAME-$CLIENTE-$DATA.fbk
ARQTGZQUE=$DSTDIR/bkp-Questor-$CUSTOM_NAME-$CLIENTE-$DATA.tgz
ARQDEL=bkp-Questor-$CUSTOM_NAME-$CLIENTE

USER=""
SENHA=''

################### FIM DA CONFIGURACAO DO FIREBIRD ########################################################

}

apagando(){
    find_result_file=$(mktemp)
    DATAIN=`date +%c`
        log "##################################################################"
        log "#                                                                #"
        log "#         ELIMINANDO BACKUPS ANTIGOS                             #"
        log "#                                                                #"
        log "##################################################################"

        log "Arquivos com $TIME_BKCP dias serao eliminados!"
        log "------------------------------------------------------------------"
    find $DSTDIR -name "*$ARQDEL*" -mtime +$TIME_BKCP -exec rm -fv {} ";"  > "$find_result_file"
    find_ok=$?
    while IFS= read -r line; do
        log "$line"
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
        DATAFIN=`date +%c`
        log "------------------------------------------------------------------"
        log "Arquivos de backup mais antigo eliminado com sucesso!"
        log "INICIO: $DATAIN"
        log "FIM: $DATAFIN"
        log "------------------------------------------------------------------"
    else
        DATAFIN=`date +%c`
        log "------------------------------------------------------------------"
        log "Erro removendo backup antigo!"
        log "------------------------------------------------------------------"

  fi
}

firebird(){
    DATAIN=`date +%c`
        log "##################################################################"
        log "#                                                                #"
        log "#         INICIANDO BACKUP FIREBIRD                              #"
        log "#                                                                #"
        log "##################################################################"
        log "Backup firebird $CLIENTE iniciado"

        $FBDDIR/gbak -b $FBDQUE $ARQQUE -user $USER -pas $SENHA #gerando backup do firebird
    if [ $? -eq 0 ] ; then
        DATAFIN=`date +%c`
        tar -czf $ARQTGZQUE $ARQQUE
        rm -f $ARQQUE
        ls -lgoh $ARQTGZQUE
        log "------------------------------------------------------------------"
        log "Backup firebird $CLIENTE realizado $DATAFIN "
        log "------------------------------------------------------------------"
    else
        DATAFIN=`date +%c`
        log "------------------------------------------------------------------"
        log "ERRO! Backup do dia $DATAIN"
        log "BACKUP FIREBIRD NAO REALIZADO" | mail -s "$CLIENTE - BACKUP FIREBIRD COM PROBLEMA" $EMAIL $SUPORTE
        log "------------------------------------------------------------------"
        exit 1
fi
}

dados
apagando
firebird
exit 0
