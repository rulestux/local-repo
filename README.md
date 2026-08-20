<div align="center">

# local-repo

### Gerenciador declarativo de repositórios locais de pacotes para Linux

Crie, sincronize e transporte repositórios de pacotes portáteis para instalações **100% offline**, usando um modelo declarativo inspirado em ferramentas modernas de Infraestrutura como Código (IaC).

**Offline-first • Declarativo • Portátil • Incremental**

[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Linux](https://img.shields.io/badge/Platform-Linux-black?logo=linux)
![Bash](https://img.shields.io/badge/Bash-5.0+-4EAA25?logo=gnubash)
![Backend APT](https://img.shields.io/badge/Backend-APT-red)
![Backend DNF](https://img.shields.io/badge/DNF-Planejado-lightgrey)
![Status](https://img.shields.io/badge/Status-Pré--Alpha-orange)

</div>

---

## Índice

1. [O que é o local-repo](#o-que-é-o-local-repo)
2. [Estado atual do projeto](#estado-atual-do-projeto)
3. [Para quem é este projeto](#para-quem-é-este-projeto)
4. [Por que não usar apenas `apt-mirror` ou `reprepro`?](#por-que-não-usar-apenas-apt-mirror-ou-reprepro)
5. [Requisitos](#requisitos)
6. [Instalação](#instalação)
7. [Primeiros passos](#primeiros-passos)
8. [Referência de comandos](#referência-de-comandos)
9. [Estrutura do repositório em disco](#estrutura-do-repositório-em-disco)
10. [Arquivo de configuração](#arquivo-de-configuração)
11. [Como o local-repo funciona por dentro](#como-o-local-repo-funciona-por-dentro)
12. [Organização do código-fonte](#organização-do-código-fonte)
13. [Princípios de design](#princípios-de-design)
14. [Roadmap](#roadmap)
15. [Licença](#licença)

---

## O que é o local-repo?

Imagine que você precisa instalar ferramentas como `htop`, `tmux` ou `smartmontools` em uma máquina Linux **sem acesso à internet** — um servidor isolado, um laboratório trancado ou um notebook de campo.

Copiar apenas o `.deb` do pacote para um pen drive normalmente não resolve: na hora de instalar, o sistema reclama de dependências que também precisam estar presentes.

O **local-repo** resolve isso funcionando como um "montador de repositório portátil":

1. **Você declara o que quer** — lista os pacotes desejados em um arquivo de texto simples (`packages.list`).
2. **Ele resolve o trabalho pesado** — em uma máquina com internet, baixa cada pacote junto com **todas as dependências recursivas**, organizando tudo em uma pasta (`pool/`).
3. **Você transporta e instala offline** — copia essa pasta para um pen drive/SSD, leva até a máquina isolada, e instala a partir do repositório local, sem precisar de rede.

Não é um espelho (*mirror*) completo de uma distribuição — é um repositório sob medida, contendo só o que você pediu.

---

## Estado atual do projeto

> [!WARNING]
> O **local-repo** está em desenvolvimento ativo (versão `0.1`, pré-alpha). A arquitetura está definida e uma parte relevante do núcleo já funciona; o restante está planejado para versões futuras.

O que **já está implementado e funcional** hoje, com backend APT (Debian/Ubuntu):

| Comando | O que faz |
|---|---|
| `init` | Cria a estrutura do repositório e o manifesto inicial |
| `download` | Registra pacotes no estado desejado e sincroniza |
| `install` | Faz `download` + instala o pacote no host a partir do repositório local |
| `sync` | Converge o repositório com o que está declarado em `packages.list` |
| `diff` | Mostra divergências entre o que foi declarado, o que é conhecido e o que existe fisicamente |
| `update` | Atualiza o cache de metadados upstream e lista pacotes desatualizados |
| `upgrade` | Baixa novamente pacotes desatualizados e limpa versões antigas |
| `import` | Importa um repositório existente (`--from-iso`, `--from-directory`, `--from-tar`) |
| `export` | Exporta o repositório para um `.tar.gz` de backup/transporte |

O que ainda está **planejado**, com desenho arquitetural definido mas sem implementação (interface pode mudar):

`remove`, `purge`, `verify`, `scan`, `prune`, `search`, `info`, `stats`, `clean`, backend DNF e a interface em modo texto (`local-repo-tui`).

Este README documenta o comportamento real dos comandos já implementados e sinaliza claramente o que ainda é planejamento.

---

## Para quem é este projeto?

- **Estudantes e curiosos** que querem entender na prática como o Linux resolve árvores de dependências, ou que precisam abastecer ambientes de estudo isolados.
- **Técnicos e suporte de campo** que fazem manutenção em servidores isolados, redes industriais ou máquinas corporativas restritas.
- **Administradores de sistemas e SREs/DevOps** que querem automatizar provisionamento offline de forma previsível, com uma abordagem declarativa parecida com IaC.
- **Donos de home lab** (Proxmox, KVM, Docker, clusters de Raspberry Pi) que reinstalam VMs com frequência e não querem baixar os mesmos pacotes toda vez.

---

## Por que não usar apenas `apt-mirror` ou `reprepro`?

O ecossistema Linux já tem ferramentas maduras para espelhamento e distribuição de repositórios — `reprepro`, `aptly`, `apt-mirror`, `apt-cacher-ng`. Elas continuam sendo a escolha certa para espelhar distribuições inteiras ou operar infraestrutura corporativa de pacotes.

O **local-repo** não compete com elas: ele resolve um problema mais específico — manter um **subconjunto pequeno e declarativo** de pacotes, com dependências resolvidas, pronto para ser transportado em uma mídia física e usado sem rede nem servidores.

| Característica | local-repo | reprepro | aptly | apt-mirror | apt-cacher-ng |
|---|:---:|:---:|:---:|:---:|:---:|
| Operação offline | ✅ | ✅ | ✅ | ⚠️ | ⚠️ |
| Modelo declarativo (lista de pacotes desejados) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Pensado para portabilidade (pen drive / SSD) | ✅ | ⚠️ | ⚠️ | ❌ | ❌ |
| Sem banco de dados | ✅ | ✅ | ❌ | ✅ | ❌ |
| Sem serviço residente (daemon) | ✅ | ✅ | ✅ | ✅ | ❌ |

> A tabela compara escopo e abordagem, não qualidade — cada ferramenta resolve um problema diferente.

---

## Requisitos

**Sistema operacional:** Linux, com Bash 5.0+, `coreutils`, `util-linux`, `grep`, `sed`, `awk`.

**Backend APT** (Debian/Ubuntu — funcional hoje):

```bash
sudo apt install dpkg-dev apt-utils dpkg fdupes util-linux
```

**Backend DNF** (Fedora/RHEL — planejado, ainda não implementado):

```bash
sudo dnf install createrepo_c rpm dnf-plugins-core
```

---

## Instalação

```bash
git clone https://github.com/rulestux/local-repo.git
cd local-repo
sudo ./install.sh
```

O script `install.sh` copia os arquivos para o sistema e deixa o comando `local-repo` disponível no `PATH`.

---

## Primeiros passos

### 1. Inicialize um repositório

```bash
sudo local-repo init
```

Cria a estrutura de pastas em `${REPO_BASE_DIR}` (por padrão `/var/local-repo`, ajustável via configuração — veja [Arquivo de configuração](#arquivo-de-configuração)) e um `packages.list` de exemplo comentado.

### 2. Declare os pacotes que você quer

Edite `state/packages.list` manualmente, ou use `download` para adicionar pacotes pela linha de comando:

```bash
sudo local-repo download htop tmux
```

Isso registra os pacotes no manifesto e já dispara a sincronização (baixa o pacote e todas as suas dependências para `pool/`).

### 3. Sincronize a qualquer momento

```bash
sudo local-repo sync
```

Compara `packages.list` (o que você quer) com `packages.state` (o que já foi baixado) e baixa apenas o que estiver faltando — sem repetir downloads desnecessários.

### 4. Instale usando o repositório local

```bash
sudo local-repo install curl
```

Garante que `curl` esteja convergido na pool local e então o instala no host **usando apenas os arquivos locais**, sem tocar na rede.

### 5. Veja o que está fora de sincronia

```bash
local-repo diff
```

Saída típica:

```text
=== Missing Packages (Desired but not synced) ===
+ docker.io|amd64

=== Orphaned Local Files (Present in pool but untracked) ===
! libfoo|amd64
```

`+` marca o que está declarado mas ainda não foi baixado; `!` marca arquivos presentes na `pool/` que não constam no inventário.

---

## Referência de comandos

Comandos com ✅ estão implementados e funcionam com o backend APT hoje. Comandos com 🚧 fazem parte do desenho arquitetural, mas ainda não foram implementados.

| Comando | Status | Descrição |
|---|:---:|---|
| `init` | ✅ | Inicializa um novo repositório (pastas + manifesto inicial) |
| `download <pkg>[|arch] ...` | ✅ | Adiciona pacotes ao estado desejado e sincroniza |
| `install <pkg>` | ✅ | `download` + instalação no host a partir do repositório local |
| `sync` | ✅ | Converge `pool/` com o que está em `packages.list` |
| `diff` | ✅ | Mostra divergências entre desejado, conhecido e real |
| `update` | ✅ | Atualiza cache upstream e lista pacotes desatualizados na pool |
| `upgrade` | ✅ | Baixa versões atualizadas e remove as obsoletas da pool |
| `import --from-iso <arquivo.iso>` | ✅ | Importa pacotes a partir de uma imagem ISO |
| `import --from-directory <dir>` | ✅ | Importa pacotes a partir de um diretório existente |
| `import --from-tar <arquivo.tar.gz>` | ✅ | Restaura um repositório exportado anteriormente |
| `export --to-tar <arquivo.tar.gz>` | ✅ | Exporta o repositório inteiro para backup/transporte |
| `remove <pkg>` | 🚧 | Remover pacote do host mantendo-o no repositório |
| `purge <pkg>` | 🚧 | Remover pacote definitivamente do repositório |
| `verify` | 🚧 | Auditoria de integridade e checksums (tipo `fsck`) |
| `scan` | 🚧 | Reconstruir `packages.state` a partir dos arquivos físicos em `pool/` |
| `prune` | 🚧 | Remover interativamente pacotes órfãos da pool |
| `search <termo>` | 🚧 | Pesquisar pacotes no repositório local |
| `info <pkg>` | 🚧 | Exibir metadados de um pacote |
| `stats` | 🚧 | Painel com estatísticas do repositório |
| `clean` | 🚧 | Limpar arquivos temporários e locks |
| `local-repo-tui` | 🚧 | Interface em modo texto (baseada em `dialog`) sobre os mesmos comandos |

---

## Estrutura do repositório em disco

Cada repositório criado com `local-repo init` segue este layout:

```text
REPO_BASE_DIR/
├── pool/                     # Pacotes físicos (.deb) já baixados — a fonte real da verdade
├── state/
│   ├── packages.list         # Estado desejado — único arquivo editável manualmente
│   └── packages.state        # Estado conhecido — inventário gerado automaticamente
├── run/
│   └── local-repo.lock       # Trava de concorrência (flock), evita execuções simultâneas
└── log/
    └── local-repo.log        # Log estruturado das operações
```

### Formato de `packages.list`

```text
# Uma entrada por linha, várias por linha, ou pipe explícito de arquitetura
tmux htop vim
curl|amd64
nginx|armhf
```

Se a arquitetura for omitida, o local-repo usa automaticamente a arquitetura nativa do host.

### Formato de `packages.state`

É gerado e mantido pelo próprio sistema — não deve ser editado à mão. No estado atual da implementação, cada linha contém `nome|arquitetura`, ordenada e sem duplicatas, refletindo o que já foi convergido para a `pool/`. (Rastreamento adicional por versão/data faz parte do desenho arquitetural, mas ainda não está implementado no formato do arquivo.)

---

## Arquivo de configuração

```text
/etc/local-repo/local-repo.conf
```

Exemplo:

```bash
REPO_BASE_DIR="/srv/local-repo"
BACKEND="apt"
LOG_LEVEL="INFO"
```

O arquivo é lido linha a linha por um parser próprio (não é feito `source` direto nele), e apenas estas chaves são reconhecidas:

| Chave | Valores aceitos | Efeito |
|---|---|---|
| `REPO_BASE_DIR` | caminho absoluto | Onde o repositório vive (`pool/`, `state/`, `run/`, `log/`) |
| `BACKEND` | `apt` (`dnf` planejado) | Backend usado para resolver e baixar pacotes |
| `LOG_LEVEL` | `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL` | Verbosidade dos logs |

Se o arquivo não existir, o local-repo usa `/var/local-repo` como diretório padrão do repositório.

---

## Como o local-repo funciona por dentro

### O modelo dos três estados

A ideia central do projeto é separar **intenção**, **conhecimento** e **realidade** em três camadas independentes:

```text
packages.list  →  o que você DECLAROU querer      (Estado Desejado)
packages.state →  o que o sistema SABE que baixou  (Estado Conhecido)
pool/          →  o que EXISTE fisicamente em disco (Estado Real)
```

Comandos como `sync` e `download` fazem esses estados **convergirem**: comparam o desejado com o conhecido e baixam apenas a diferença. O comando `diff` faz essa comparação de forma passiva, sem alterar nada — só relata os desvios.

Essa separação é o que permite, por exemplo, que um inventário perdido seja reconstruído a partir dos arquivos físicos (comando `scan`, planejado), ou que divergências sejam auditadas sem depender de um banco de dados.

### Abstração de backend

Toda interação com o gerenciador de pacotes da distribuição (`apt`, `dpkg`, futuramente `dnf`) passa por uma camada de abstração (`lib/backend/`). O núcleo do sistema (`lib/core/`) não sabe nada sobre APT ou DNF — ele só conhece a interface comum definida em `lib/api/backend-api.sh`. Isso é o que permite adicionar um novo backend sem reescrever o restante da aplicação.

### Ordem de inicialização

Toda execução do `local-repo` segue sempre a mesma sequência determinística, carregada pelo `bootstrap.sh`:

```text
local-repo → bootstrap.sh → constants.sh → util.sh → log.sh → errors.sh
           → lock.sh → validation.sh → config.sh → environment.sh
           → backend.sh → dispatcher → comando solicitado
```

Cada módulo depende apenas das camadas carregadas antes dele — isso reduz acoplamento e torna o comportamento previsível e mais fácil de testar.

### Concorrência

Operações que modificam o repositório adquirem uma trava via `flock` (`run/local-repo.lock`), evitando que duas execuções simultâneas corrompam o estado.

### Portabilidade

Como nenhum estado depende de caminhos absolutos fixos, o repositório inteiro pode ser copiado para outro pen drive, outro diretório ou outra máquina — basta apontar `REPO_BASE_DIR` para o novo local.

---

## Organização do código-fonte

```text
local-repo/
├── local-repo              # Dispatcher — ponto de entrada da CLI, sem lógica de negócio
├── local-repo-tui           # Wrapper de interface em modo texto (planejado)
├── lib/
│   ├── core/                # Infraestrutura compartilhada
│   │   ├── bootstrap.sh      # Orquestrador de carregamento
│   │   ├── constants.sh      # Constantes e valores padrão
│   │   ├── config.sh         # Parser do arquivo .conf
│   │   ├── validation.sh     # Sanitização do manifesto
│   │   ├── environment.sh    # Checagem de dependências do host
│   │   ├── log.sh             # Sistema de logging
│   │   ├── errors.sh          # Tratamento de erros e traps
│   │   ├── lock.sh            # Controle de concorrência (flock)
│   │   └── util.sh            # Funções utilitárias
│   ├── api/
│   │   └── backend-api.sh    # Contrato que todo backend deve implementar
│   ├── backend/
│   │   ├── backend.sh         # Detecção e carregamento dinâmico do backend
│   │   ├── apt.sh              # Driver para Debian/Ubuntu (implementado)
│   │   └── dnf.sh              # Driver para Fedora/RHEL (planejado)
│   └── commands/              # Um módulo por comando (init.sh, sync.sh, diff.sh...)
├── tui/                     # Telas da interface em modo texto (planejado)
├── install.sh
├── uninstall.sh
└── README.md
```

Cada comando tem seu próprio arquivo em `lib/commands/`, evitando um script único e gigantesco — isso facilita revisar, testar e adicionar comandos novos isoladamente.

---

## Princípios de design

Decisões que guiam o projeto e que qualquer contribuição deve respeitar:

- **Offline-first** — toda operação que não depende estritamente de rede deve funcionar sem internet.
- **Declaratividade** — o administrador diz *o que* quer; o sistema decide *como* chegar lá.
- **Recuperabilidade** — nenhum arquivo derivado (índices, inventário) deve ser a única fonte da verdade; tudo deve poder ser reconstruído a partir dos dados físicos.
- **Transparência** — estados armazenados em texto plano, legíveis e manipuláveis com `grep`, `awk`, `sed`.
- **Idempotência** — rodar `sync` duas vezes seguidas não deve baixar nada duas vezes.
- **Portabilidade** — nenhuma dependência de caminho absoluto fixo do host.
- **Sem daemon, sem banco de dados, sem servidor web** — menor superfície, menor consumo de recursos, mais fácil de auditar.
- **Simplicidade antes de funcionalidades** — preferir a solução mais simples sempre que houver equivalência funcional.

---

## Roadmap

Ordem aproximada do que falta para a versão estável:

1. Comandos de manutenção do host: `remove`, `purge`, `prune`, `clean`.
2. Auditoria e recuperação: `verify`, `scan`.
3. Consulta: `search`, `info`, `stats`.
4. Backend DNF (`dnf.sh`), para Fedora/RHEL.
5. Interface em modo texto `local-repo-tui`, como camada visual sobre a CLI existente.

O objetivo de longo prazo é manter a mesma filosofia — simplicidade, transparência e portabilidade — à medida que essas funcionalidades forem chegando, em vez de acumular funcionalidades às custas da previsibilidade do sistema.

---

## Licença

Distribuído sob a licença MIT. Veja [LICENSE](LICENSE) para mais detalhes.