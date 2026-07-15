# Sourced dinamicamente por backend.sh - Não executar diretamente

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
# DRIVE DE IMPLEMENTAÇÃO CONCRETA: ECOSSISTEMA APT (DEBIAN/UBUNTU)
#
# Este módulo materializa o contrato definido em backend-api.sh,
# manipulando comandos avançados da árvore apt/dpkg.
#--------------------------------------------------------------------
[[ -n "${_APT_SH_INCLUDED_}" ]] && return
_APT_SH_INCLUDED_=1

backend_check_dependencies() {
    #----------------------------------------------------------------
    # VALIDAÇÃO DE DEPENDÊNCIAS DO BACKEND
    #
    # Garante que o ecossistema host possui as ferramentas cruciais
    # para manipulação estrutural de pacotes .deb e indexação de repositórios.
    #----------------------------------------------------------------
    log_debug "APT backend running self-dependency scan..."

    local apt_commands=("apt-get" "apt-cache" "dpkg" "dpkg-deb" "apt-ftparchive" "gzip")
    local missing_apt=()

    for cmd in "${apt_commands[@]}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing_apt+=("${cmd}")
        fi
    done

    if [[ ${#missing_apt[@]} -gt 0 ]]; then
        log_fatal "APT backend engine failure. Missing required tools: ${missing_apt[*]}"
        log_fatal "Please install 'apt-utils' and core build packages on this host."
        exit "${EXIT_ENV_MISSING}"
    fi

    log_debug "APT backend dependencies verified successfully."
    return "${EXIT_SUCCESS}"
}

backend_parse_pool_identity() {
    #----------------------------------------------------------------
    # TRADUÇÃO DE NOME FÍSICO → IDENTIDADE LÓGICA (CONVENÇÃO .DEB)
    #
    # Pacotes Debian seguem estritamente a convenção de nomenclatura
    # '<nome>_<versao>_<arquitetura>.deb'. O nome do pacote nunca
    # contém underscore (proibido pela Debian Policy), então o
    # primeiro campo delimitado por '_' é sempre o nome; o último
    # campo antes da extensão é sempre a arquitetura. A versão no
    # meio pode conter underscores livremente e não atrapalha essa
    # extração pelas pontas.
    #----------------------------------------------------------------
    local filename="$1"
    local base="${filename%.deb}"

    if [[ "${base}" == "${filename}" ]]; then
        log_warn "File does not match expected .deb naming convention, skipping identity parse: ${filename}"
        return "${EXIT_FAILURE}"
    fi

    local name="${base%%_*}"
    local arch="${base##*_}"

    echo "${name}|${arch}"
    return "${EXIT_SUCCESS}"
}

backend_download_package() {
    #----------------------------------------------------------------
    # DOWNLOAD RECURSIVO DE PACOTE + FECHO DE DEPENDÊNCIAS (APT)
    #
    # 'apt-get download' sozinho baixa APENAS o pacote pedido, sem
    # dependências. Resolvemos o fecho transitivo via 'apt-cache
    # depends --recurse', que já é dependência obrigatória do core —
    # evita introduzir 'apt-rdepends' como binário adicional só para
    # essa finalidade.
    #----------------------------------------------------------------
    local package_name="$1"
    local destination_pool="$2"
    local target_arch="$3"

    log_info "Resolving recursive dependency tree for: ${package_name}"

    # Filtra a saída do apt-cache para restar só nomes reais de pacote:
    # a ferramenta também emite rótulos como 'Depends:'/'PreDepends:' e
    # marcadores de pacotes virtuais/alternativas ('<pkg>', '|pkg'),
    # que 'grep -E "^\w"' descarta por não começarem com letra/dígito.
    local dependency_tree
    dependency_tree=$(apt-cache depends --recurse --no-recommends --no-suggests \
        --no-conflicts --no-breaks --no-replaces --no-enhances --no-pre-depends \
        "${package_name}" 2>/dev/null | grep -E '^\w' | sort -u)

    if [[ -z "${dependency_tree}" ]]; then
        log_error "Package not found or has no resolvable dependency tree: ${package_name}"
        return "${EXIT_FAILURE}"
    fi

    # 'apt-get download' sempre escreve no diretório de trabalho atual —
    # não aceita um caminho de destino explícito. Isolamos isso num
    # diretório temporário próprio para não sujar o CWD do processo
    # principal do local-repo.
    local work_dir
    work_dir=$(util_make_temp "aptdl" "dir")
    log_debug "Isolating package downloads in temporary workspace: ${work_dir}"

    while IFS= read -r dep_pkg; do
        [[ -z "${dep_pkg}" ]] && continue

        local dep_target="${dep_pkg}"
        [[ -n "${target_arch}" ]] && dep_target="${dep_pkg}:${target_arch}"

        log_debug "Downloading dependency closure member: ${dep_target}"

        if ! ( cd "${work_dir}" && apt-get download "${dep_target}" &> /dev/null ); then
            # Não é necessariamente um erro fatal: pode ser um pacote já
            # satisfeito no host, ou um alternativo dentro de um OR de
            # dependências que não precisa ser baixado.
            log_warn "Failed to download package (may be virtual/already satisfied): ${dep_target}"
        fi
    done <<< "${dependency_tree}"

    local downloaded_count
    downloaded_count=$(find "${work_dir}" -maxdepth 1 -type f -name "*.deb" | wc -l)

    if [[ ${downloaded_count} -eq 0 ]]; then
        log_error "No .deb files were successfully downloaded for: ${package_name}"
        rm -rf "${work_dir}"
        return "${EXIT_FAILURE}"
    fi

    # Move em vez de copiar: evita duplicar espaço em disco durante a
    # transição do diretório temporário para a pool definitiva.
    mv "${work_dir}"/*.deb "${destination_pool}/" 2>/dev/null
    rm -rf "${work_dir}"

    log_info "Downloaded ${downloaded_count} package file(s) for '${package_name}' (including dependency closure)."
    return "${EXIT_SUCCESS}"
}

backend_generate_metadata() {
    #----------------------------------------------------------------
    # GERAÇÃO DE ÍNDICE APT (FORMATO FLAT REPOSITORY)
    #----------------------------------------------------------------
    local repo_root="$1"
    local pool_dir="${repo_root}/pool"

    log_info "Rebuilding APT package index (flat repository format)..."

    if [[ ! -d "${pool_dir}" ]]; then
        log_error "Pool directory not found, cannot generate metadata: ${pool_dir}"
        return "${EXIT_FAILURE}"
    fi

    # A execução precisa ocorrer com CWD em repo_root para que o campo
    # 'Filename:' do índice saia relativo à raiz do repositório
    # ('pool/pacote.deb'), e não relativo à própria pool — é esse
    # caminho relativo que o sources.list 'file://.../repo ./' espera.
    if ! ( cd "${repo_root}" && apt-ftparchive packages pool > "${repo_root}/Packages" 2>/dev/null ); then
        log_error "apt-ftparchive failed to generate the Packages index."
        return "${EXIT_FAILURE}"
    fi

    if ! gzip -kf "${repo_root}/Packages"; then
        log_error "Failed to compress Packages index into Packages.gz."
        return "${EXIT_FAILURE}"
    fi

    # Release não-assinado: decisão consciente de escopo (ver comentário
    # da função). O host consumidor usa '[trusted=yes]' no sources.list.
    ( cd "${repo_root}" && apt-ftparchive release . > "${repo_root}/Release" 2>/dev/null )

    log_info "Repository metadata index successfully rebuilt at: ${repo_root}/Packages.gz"
    return "${EXIT_SUCCESS}"
}

backend_install_from_local_pool() {
    #----------------------------------------------------------------
    # INSTALAÇÃO NO HOST A PARTIR EXCLUSIVAMENTE DA POOL LOCAL
    #
    # Usa a sintaxe interna do apt-get 'Dir::Etc::sourcelist',
    # com a flag -o (de Option), para apontar para uma fonte temporária
    # única (a pool local), e 'Dir::Etc::sourceparts' para /dev/null
    # para desabilitar qualquer sources.list.d/ configurado no host;
    # garante que nenhum pacote seja buscado remotamente nesta operação,
    # mantendo a promessa de instalação estritamente offline.
    # Em '-o APT::Get::List-Cleanup="0"' a flag definida como "0" (falso)
    # impede que o APT delete o cache dos repositórios normais do sistema
    # do usuário durante essa operação isolada.
    #----------------------------------------------------------------
    local package_name="$1"
    local repo_root="$2"

    if [[ ! -f "${repo_root}/Packages.gz" ]]; then
        log_error "Repository metadata not found. Run '${PROGRAM_NAME} sync' first to build ${repo_root}/Packages.gz."
        return "${EXIT_FAILURE}"
    fi

    local tmp_sourcelist
    tmp_sourcelist=$(util_make_temp "sources")
    echo "deb [trusted=yes] file://${repo_root} ./" > "${tmp_sourcelist}"

    log_info "Refreshing APT cache scoped exclusively to the local offline repository..."

    if ! apt-get -o Dir::Etc::sourcelist="${tmp_sourcelist}" \
                 -o Dir::Etc::sourceparts="/dev/null" \
                 -o APT::Get::List-Cleanup="0" \
                 update &> /dev/null; then
        log_error "Failed to refresh APT cache from local repository source."
        rm -f "${tmp_sourcelist}"
        return "${EXIT_FAILURE}"
    fi

    log_info "Installing '${package_name}' exclusively from the local offline pool..."

    if ! apt-get -o Dir::Etc::sourcelist="${tmp_sourcelist}" \
                 -o Dir::Etc::sourceparts="/dev/null" \
                 install -y "${package_name}"; then
        log_error "APT reported a failure while installing: ${package_name}"
        rm -f "${tmp_sourcelist}"
        return "${EXIT_FAILURE}"
    fi

    rm -f "${tmp_sourcelist}"
    log_info "Package '${package_name}' successfully installed on host from local pool."
    return "${EXIT_SUCCESS}"
}
