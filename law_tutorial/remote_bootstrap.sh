#!/usr/bin/env bash

# Bootstrap file for batch jobs that is sent with all jobs and
# automatically called by the law remote job wrapper script to find the
# setup.sh file of this tutorial which sets up software and some environment
# variables. All render variables are defined in the workflow base task in tutorial/framework.py.
# Depending on the type of workflow used (crab or htcondor), one of the two bootstrap methods is
# called, which is - again - controlled through a render variable (bootstrap_name).

bootstrap_crab() {
    # for crab jobs, predefine some variables, fetch the software and repository bundles, then setup

    # set env variables
    export LT_REMOTE_ENV="crab"
    export LT_USER="{{lt_user}}"
    export LT_DIR="${LAW_JOB_HOME}/repo"
    export LT_DATA_DIR="${LAW_JOB_HOME}/data"
    export LT_STORE_DIR="${LT_DATA_DIR}/store"
    export LT_SOFTWARE_DIR="${LT_DATA_DIR}/software"

    # source the law wlcg tools (mainly for law_wlcg_get_file)
    echo -e "\nsourcing wlcg tools ..."
    source "{{wlcg_tools}}" "" || return "$?"
    echo "done sourcing wlcg tools"

    # load and unpack the software bundle
    (
        echo -e "\nfetching software bundle ..."
        mkdir -p "${LT_SOFTWARE_DIR}" &&
        cd "${LT_SOFTWARE_DIR}" &&
        law_wlcg_get_file '{{lt_software_uris}}' '{{lt_software_pattern}}' "software.tgz" &&
        tar -xzf "software.tgz" &&
        rm "software.tgz" &&
        echo "done fetching software bundle"
    ) || return "$?"

    # load and unpack the repo bundle
    (
        echo -e "\nfetching repository bundle ..."
        mkdir -p "${LT_DIR}" &&
        cd "${LT_DIR}" &&
        law_wlcg_get_file '{{lt_repo_uris}}' '{{lt_repo_pattern}}' "repo.tgz" &&
        tar -xzf "repo.tgz" &&
        rm "repo.tgz" &&
        echo "done fetching repository bundle"
    ) || return "$?"

    # source it
    source "${LT_DIR}/setup.sh" "" || return "$?"
}

bootstrap_htcondor() {
    export LT_REMOTE_ENV="htcondor"
    export LT_USER="{{lt_user}}"
    export LT_DIR="${LAW_JOB_HOME}/repo"
    export LT_DATA_DIR="{{lt_data_dir}}"
    export LT_STORE_DIR="{{lt_store_dir}}"
    export LT_SOFTWARE_DIR="{{lt_software_dir}}"
    [ ! -z "{{vomsproxy_file}}" ] && export X509_USER_PROXY="${PWD}/{{vomsproxy_file}}"

    # source the law wlcg tools (mainly for law_wlcg_get_file)
    echo -e "\nsourcing wlcg tools ..."
    source "{{wlcg_tools}}" "" || return "$?"
    echo "done sourcing wlcg tools"

    # load and unpack the repo bundle
    (
        echo -e "\nfetching repository bundle ..."
        mkdir -p "${LT_DIR}" &&
        cd "${LT_DIR}" &&
        law_wlcg_get_file '{{lt_repo_uris}}' '{{lt_repo_pattern}}' "repo.tgz" &&
        tar -xzf "repo.tgz" &&
        rm "repo.tgz" &&
        echo "done fetching repository bundle"
    ) || return "$?"

    # source it
    source "${LT_DIR}/setup.sh" "" || return "$?"
}

# invoke the bootstrap method
bootstrap_{{bootstrap_name}} "$@"
