# Sourced do bootstrap.sh - Não executar diretamente

#################################################################
# local-repo - Manages and converges local packet pools for     #
#              offline environments.                            #
#                                                               #
# Site:         https://github.com/rulestux                     #
# Author:       Jean Felipe                                     #
# Maintenance:  Jean Felipe                                     #
# License:      MIT                                             #
#                                                               #
#################################################################

#--------------------------------------------------------------------
# PROTEÇÃO CONTRA DUPLO CARREGAMENTO
#--------------------------------------------------------------------
[[ -n "${_LOCK_SH_INCLUDED_}" ]] && return
_LOCK_SH_INCLUDED_=1

# Variável de controle interna para rastrear se este processo detém a tranca
_LOCK_FD=""

# Flag separada da FD: o descritor pode estar aberto (exec já rodou) sem que
# o flock tenha sido efetivamente concedido. Precisamos distinguir os dois
# estados para não limpar/apagar um lock que nunca nos pertenceu de fato.
_LOCK_ACQUIRED=0

lock_acquire() {
    #----------------------------------------------------------------
    # AQUISIÇÃO DE EXCLUSÃO MÚTUA DE PROCESSO (MUTEX)
    #
    # Abre ou cria o arquivo de lock definido na variável global e
    # tenta aplicar uma trava não-bloqueante (-n) exclusiva. Se outro
    # administrador ou cron já estiver rodando o local-repo, a tentativa
    # falha imediatamente, abortando a concorrência destrutiva.
    #----------------------------------------------------------------
    log_debug "Attempting to acquire exclusive system lock on: ${LOCK_FILE}"

    # Garante que o diretório pai da trava exista fisicamente
    local lock_dir
    lock_dir="$(dirname "${LOCK_FILE}")"
    if [[ ! -d "${lock_dir}" ]]; then
        mkdir -p "${lock_dir}" || {
            log_fatal "Failed to create runtime lock directory: ${lock_dir}"
            exit "${EXIT_LOCK_FAILED}"
        }
    fi

    # Atribui o descritor de arquivo 98 para gerenciar a trava em nível de kernel
    _LOCK_FD=98

    # Abre o descritor apontando para o arquivo de trava
    eval "exec ${_LOCK_FD}>\"${LOCK_FILE}\""

    # Tenta travar de forma exclusiva e não-bloqueante utilizando flock nativo
    if ! flock -n "${_LOCK_FD}"; then
        #------------------------------------------------------------
        # IMPORTANTE: se a aquisição falhar, fechamos o FD e limpamos
        # a variável imediatamente. Isso evita que lock_release() mais
        # tarde (disparado pelo trap EXIT) interprete este FD aberto
        # como "lock detido por este processo" e apague o arquivo de
        # lock de um OUTRO processo que realmente está com a trava.
        # Sem isso, um processo que falha ao adquirir o lock acaba
        # deletando o inode do lock ativo, permitindo que um terceiro
        # processo "fure a fila" enquanto o dono original ainda roda.
        #------------------------------------------------------------
        eval "exec ${_LOCK_FD}>&-"
        _LOCK_FD=""
        log_fatal "Another instance of ${PROGRAM_NAME} is currently running. Execution blocked."
        exit "${EXIT_LOCK_FAILED}"
    fi

    # Só marcamos como "adquirido" depois que o flock realmente teve sucesso
    _LOCK_ACQUIRED=1

    # Grava o PID do processo atual dentro do arquivo para fins de depuração do sysadmin
    echo "$$" >&"${_LOCK_FD}"
    log_debug "System lock successfully acquired by process PID: $$"
}

lock_release() {
    #----------------------------------------------------------------
    # LIBERAÇÃO DA TRANCA (RELEASE)
    #
    # Desfaz a trava do flock e fecha o descritor de arquivos associado.
    # Chamado de forma segura pelo encerramento controlado em errors.sh.
    #
    # Só age se este processo realmente chegou a adquirir o lock
    # (_LOCK_ACQUIRED=1). Isso é o que impede a remoção acidental do
    # arquivo de lock de outro processo — ver nota em lock_acquire().
    #----------------------------------------------------------------
    if [[ "${_LOCK_ACQUIRED}" -eq 1 ]] && [[ -n "${_LOCK_FD}" ]]; then
        log_debug "Releasing system lock and closing file descriptor ${_LOCK_FD}."
        flock -u "${_LOCK_FD}"
        eval "exec ${_LOCK_FD}>&-"
        _LOCK_FD=""
        _LOCK_ACQUIRED=0

        # Remove fisicamente o arquivo de lock — seguro aqui porque só
        # chegamos neste ponto se este processo era o dono legítimo da trava.
        if [[ -f "${LOCK_FILE}" ]]; then
            rm -f "${LOCK_FILE}"
        fi
    fi
}
