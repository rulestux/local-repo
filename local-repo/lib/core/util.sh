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
# COMPONENTE DE UTILITÁRIOS GLOBAIS (HELPER MODULE)
#--------------------------------------------------------------------
[[ -n "${_UTIL_SH_INCLUDED_}" ]] && return
_UTIL_SH_INCLUDED_=1

util_timestamp() {
    #----------------------------------------------------------------
    # CENTRALIZADOR DE CARIMBO DE DATA E HORA
    #
    # Isola o formato de timestamp usado para auditorias e logs.
    # Caso os requisitos do projeto mudem no futuro para exigir UTC,
    # ISO8601 ou microsegundos, a alteração é feita unicamente aqui.
    #----------------------------------------------------------------
    date +"%Y-%m-%d %H:%M:%S"
}

util_make_temp() {
    #----------------------------------------------------------------
    # CRIADOR CENTRALIZADO DE ARQUIVOS/DIRETÓRIOS TEMPORÁRIOS SEGUROS
    #
    # ARGUMENTOS: $1 - Rótulo descritivo (aparece no nome, só para
    #                  facilitar auditoria manual em /tmp).
    #             $2 - Tipo: "file" (padrão, compatível com todo
    #                  código já existente que chama esta função com
    #                  um único argumento) ou "dir".
    #----------------------------------------------------------------
    local label="${1:-tmp}"
    local kind="${2:-file}"

    if [[ "${kind}" == "dir" ]]; then
        mktemp -d "/tmp/${PROGRAM_NAME}.${label}.XXXXXX"
    else
        mktemp "/tmp/${PROGRAM_NAME}.${label}.XXXXXX"
    fi
}

util_host_architecture() {
    #----------------------------------------------------------------
    # RESOLUÇÃO CENTRALIZADA DA ARQUITETURA NATIVA DO HOST
    #
    # Extraída para cá porque tanto init.sh (ao gerar o template do
    # manifesto) quanto validation.sh (ao herdar arquitetura para
    # entradas sem '|arch' explícito) precisam do mesmo valor. Manter
    # essa lógica duplicada em dois lugares arriscaria os dois
    # discordarem entre si no futuro, por exemplo quando um novo
    # backend (pacman.sh, apk.sh) for adicionado.
    #----------------------------------------------------------------
    if [[ "${CURRENT_BACKEND}" == "${BACKEND_APT}" ]]; then
        dpkg --print-architecture 2>/dev/null || uname -m
    else
        uname -m
    fi
}
