#!/usr/bin/env bash

# Script that sets up the tutorial environment.
# In particular, it sets a handful of environment variables and installs a minimal software setup
# based on micromamba and some python packages.
#
# This is designed mostly for lxplus!
# A typical project could define a similar script with more sophisticated variable definitions, but
# since this a tutorial, we keep it simple.
#
# Note that variables that are used by the tutoral code are prefixed with "LT_" (Law Tutorial).

action() {
    # shell and location detection
    local shell_is_zsh="$( [ -z "${ZSH_VERSION}" ] && echo "false" || echo "true" )"
    local this_file="$( ${shell_is_zsh} && echo "${(%):-%x}" || echo "${BASH_SOURCE[0]}" )"
    local this_dir="$( cd "$( dirname "${this_file}" )" && pwd )"

    #
    # prepare local variables
    #

    local micromamba_url="https://micro.mamba.pm/api/micromamba/linux-64/latest"
    local pyv="3.9"
    local software_on_afs="true"
    local remote_env="$( [ -z "${LT_REMOTE_ENV}" ] && echo "false" || echo "true" )"

    # zsh options for the scope of this script
    if ${shell_is_zsh}; then
        emulate -L bash
        setopt globdots
    fi

    # complain when an environment other than lxplus is detected
    if [[ "$( hostname )" != *.cern.ch ]]; then
        >&2 echo "this tutorial is designed for lxplus, but your host is $( hostname ), so be aware of potential issues"
    fi

    #
    # global variables
    #

    export LT_USER="${LT_USER:-$( whoami )}"
    export LT_USER_FIRSTCHAR="${LT_USER:0:1}"

    # check the afs type
    # (change this to "user" if you have a "work" account but want to choose "user" instead)
    local afs_type="work"
    [ ! -d "/afs/cern.ch/${afs_type}/${LT_USER_FIRSTCHAR}/${LT_USER}" ] && afs_type="user"

    # data directories
    local lt_data_dir_afs="/afs/cern.ch/${afs_type}/${LT_USER_FIRSTCHAR}/${LT_USER}/law_tutorial_data"
    local lt_data_dir_eos="/eos/user/${LT_USER_FIRSTCHAR}/${LT_USER}/law_tutorial_data"

    # start exporting variables, potentially giving priority to already exported ones
    export LT_DIR="${this_dir}"
    export LT_DATA_DIR="${LT_DATA_DIR:-${lt_data_dir_afs}}"
    export LT_STORE_DIR="${LT_STORE_DIR:-${LT_DATA_DIR}/store}"
    if "${software_on_afs}"; then
        export LT_SOFTWARE_DIR="${LT_SOFTWARE_DIR:-${lt_data_dir_afs}/software}"
    else
        export LT_SOFTWARE_DIR="${LT_SOFTWARE_DIR:-${lt_data_dir_eos}/software}"
    fi
    export LT_CONDA_DIR="${LT_CONDA_DIR:-${LT_SOFTWARE_DIR}/conda}"
    export LT_JOB_DIR="${LT_JOB_DIR:-${lt_data_dir_afs}/jobs}"
    export LT_WLCG_CACHE_DIR="${LT_WLCG_CACHE_DIR:-${lt_data_dir_eos}/wlcg_cache}"
    export LT_LOCAL_SCHEDULER="${LT_LOCAL_SCHEDULER:-true}"
    export LT_SCHEDULER_HOST="${LT_SCHEDULER_HOST:-$( hostname )}"
    export LT_SCHEDULER_PORT="8088"
    export LT_WORKER_KEEP_ALIVE="${LT_WORKER_KEEP_ALIVE:-"${remote_env}"}"
    export LT_HTCONDOR_FLAVOR="${LT_HTCONDOR_FLAVOR:-cern}"

    # external variable defaults
    export LANGUAGE="${LANGUAGE:-en_US.UTF-8}"
    export LANG="${LANG:-en_US.UTF-8}"
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    export PYTHONWARNINGS="${PYTHONWARNINGS:-ignore}"
    export VIRTUAL_ENV_DISABLE_PROMPT="${VIRTUAL_ENV_DISABLE_PROMPT:-1}"
    export MAMBA_ROOT_PREFIX="${LT_CONDA_DIR}"
    export MAMBA_EXE="${MAMBA_ROOT_PREFIX}/bin/micromamba"
    export GLOBUS_THREAD_MODEL="none"
    export X509_CERT_DIR="${X509_CERT_DIR:-/cvmfs/grid.cern.ch/etc/grid-security/certificates}"
    export X509_VOMS_DIR="${X509_VOMS_DIR:-/cvmfs/grid.cern.ch/etc/grid-security/vomsdir}"
    export X509_VOMSES="${X509_VOMSES:-/cvmfs/grid.cern.ch/etc/grid-security/vomses}"
    export VOMS_USERCONF="${VOMS_USERCONF:-${X509_VOMSES}}"

    #
    # minimal local software setup
    #

    export PYTHONPATH="${LT_DIR}:${PYTHONPATH}"

    # increase stack size
    ulimit -s unlimited

    # conda base environment
    local conda_missing="$( [ -d "${LT_CONDA_DIR}" ] && echo "false" || echo "true" )"
    if ${conda_missing}; then
        echo "installing conda/micromamba at ${LT_CONDA_DIR}"
        (
            mkdir -p "${LT_CONDA_DIR}"
            cd "${LT_CONDA_DIR}"
            curl -Ls "${micromamba_url}" | tar -xvj -C . "bin/micromamba"
            ./bin/micromamba shell hook -y --prefix="${LT_CONDA_DIR}" &> "micromamba.sh"
            mkdir -p "etc/profile.d"
            mv "micromamba.sh" "etc/profile.d"
            cat << EOF > ".mambarc"
changeps1: false
always_yes: true
channels:
  - conda-forge
EOF
        )
    fi

    # initialize conda
    source "${LT_CONDA_DIR}/etc/profile.d/micromamba.sh" "" || return "$?"
    micromamba activate || return "$?"
    echo "initialized conda/micromamba"

    # install packages
    if ${conda_missing}; then
        echo
        echo "setting up conda/micromamba environment"

        # conda packages
        micromamba install \
            libgcc \
            bash \
            "python=${pyv}" \
            git \
            git-lfs \
            gfal2 \
            gfal2-util \
            python-gfal2 \
            myproxy \
            conda-pack \
            || return "$?"
        micromamba clean --yes --all

        # add a file to conda/activate.d that handles the gfal setup transparently with conda-pack
cat << EOF > "${LT_CONDA_DIR}/etc/conda/activate.d/gfal_activate.sh"
export GFAL_CONFIG_DIR="\${CONDA_PREFIX}/etc/gfal2.d"
export GFAL_PLUGIN_DIR="\${CONDA_PREFIX}/lib/gfal2-plugins"
export X509_CERT_DIR="${X509_CERT_DIR}"
export X509_VOMS_DIR="${X509_VOMS_DIR}"
export X509_VOMSES="${X509_VOMSES}"
export VOMS_USERCONF="${VOMS_USERCONF}"
EOF

        # pip packages
        pip install --no-cache-dir -U pip setuptools wheel || return "$?"
        pip install --no-cache-dir -r "${LT_DIR}/requirements.txt" || return "$?"
    fi

    #
    # law setup
    #

    export LAW_HOME="${LAW_HOME:-${LT_DIR}/.law}"
    export LAW_CONFIG_FILE="${LAW_CONFIG_FILE:-${LT_DIR}/law.cfg}"

    if which law &> /dev/null; then
        # source law's bash completion scipt
        source "$( law completion )" ""

        # silently index
        law index -q
    fi
}

# entry point
action "$@"
