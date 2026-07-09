# Sourced do bootstrap.sh - Não executar diretamente

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
