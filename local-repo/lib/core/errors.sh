# Sourced do bootstrap.sh - Não executar diretamente

#--------------------------------------------------------------------
# PROTEÇÃO CONTRA DUPLO CARREGAMENTO
#--------------------------------------------------------------------
[[ -n "${_ERRORS_SH_INCLUDED_}" ]] && return
_ERRORS_SH_INCLUDED_=1

#--------------------------------------------------------------------
# COMPONENTE DE TRATAMENTO DE EXCEÇÕES E SINAIS (ERROR HANDLER)
#
# Este módulo centraliza os hooks de interceptação de sinais POSIX.
# Ele impede que o script morra deixando arquivos temporários, travas
# de concorrência órfãs ou estados inconsistentes em disco.
#--------------------------------------------------------------------

errors_register_traps() {
    #----------------------------------------------------------------
    # REGISTRO DE ARMADILHAS DE SINAL (TRAPS)
    #
    # Escuta sinais de interrupção comuns (SIGINT = Ctrl+C, SIGTERM =
    # kill padrão) e o evento de saída (EXIT). Ao interceptá-los,
    # desvia o fluxo para garantir que a casa seja limpa antes do adeus.
    #----------------------------------------------------------------
    trap 'errors_handle_exit' EXIT
    trap 'errors_handle_signal SIGINT' SIGINT
    trap 'errors_handle_signal SIGTERM' SIGTERM
}

errors_handle_signal() {
    #----------------------------------------------------------------
    # CAPTURA DE SINAIS EXTERNOS
    #
    # Registra formalmente no log qual sinal forçou o encerramento do
    # programa, permitindo auditoria posterior do sysadmin, e força
    # a saída controlada invocando o exit.
    #
    # O código de saída segue a convenção Unix de 128+N (N = número do
    # sinal POSIX), em vez de sempre retornar EXIT_FAILURE genérico.
    # Isso preserva no valor de $? qual sinal matou o processo —
    # informação que ferramentas de orquestração (systemd, cron,
    # supervisores de processo) e o próprio administrador usam para
    # diferenciar "abortei por Ctrl+C" (130) de "fui morto por kill"
    # (143) de uma falha lógica qualquer (1).
    #----------------------------------------------------------------
    local signal_name="$1"
    local signal_number

    case "${signal_name}" in
        SIGINT)  signal_number=2  ;;
        SIGTERM) signal_number=15 ;;
        *)       signal_number=0  ;;
    esac

    # Usamos stderr via log_fatal pois o ecossistema foi interrompido de fora
    log_fatal "Application interrupted by operating system signal: ${signal_name}"

    #------------------------------------------------------------
    # Usamos 'exit' (e não 'kill -s "${signal_name}" "$$"') para
    # reemitir o sinal para si mesmo terminaria o processo
    # via disposição padrão do kernel SEM disparar o trap de EXIT
    # registrado em errors_register_traps(). Isso pularia a liberação
    # do lock em lock_release(), deixando o repositório travado até
    # a próxima limpeza manual. O builtin 'exit' sempre aciona o
    # trap EXIT antes de encerrar o processo, garantindo que o
    # errors_handle_exit() (e, por consequência, o lock_release())
    # ainda rode mesmo após um Ctrl+C do administrador.
    #------------------------------------------------------------
    exit "$(( 128 + signal_number ))"
}

errors_handle_exit() {
    #----------------------------------------------------------------
    # GANCHO DE LIMPEZA GERAL (EXIT HOOK)
    #
    # Invocado automaticamente sempre que o script se encerra (seja por
    # sucesso ou falha). É aqui que desalocamos trancas e limpamos
    # lixo residual do diretório temporário.
    #----------------------------------------------------------------
    local exit_code=$?

    # Se o lock.sh tiver sido carregado e possuir uma trava ativa, desfaz
    if function_exists "lock_release"; then
        lock_release
    fi

    if [[ ${exit_code} -eq 0 ]]; then
        log_debug "Exiting program with success state (0)."
    else
        log_debug "Exiting program with failure state (${exit_code}). Cleaning environments."
    fi
}

function_exists() {
    # Helper privado para checar se uma função existe no escopo sem estourar erros
    declare -f "$1" &> /dev/null
}
