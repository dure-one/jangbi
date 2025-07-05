#!/usr/bin/env bash
export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
SCRIPT_FILENAME=$(basename "$self")
cd $(dirname $0)
source functions.sh

if [[ -z ${JB_VARS} ]]; then
    _load_config
    _root_only
    _distname_check
else
    log_fatal "JB_DEPLOY_PATH configure is not set. please make .config file."
    return 1
fi

# environment
arch2=$(arch) 
arch1=$(dpkg --print-architecture) 
os=$(uname -s)

bash init.sh --sync

pkg_str="$(cat pkgs.list|grep -v "^#"|grep -v -e '^[[:space:]]*$')"
IFS=$'\n' read -rd '' -a lines <<<"$pkg_str"
for((j=0;j<${#lines[@]};j++)){
    IFS=$'|' read -rd '' -a pkg <<<"${lines[j]}"
    pluginname=${pkg[0]}
    pkgpath=${pkg[1]};
    IFS=$'\/' read -rd '' -a pkgdir <<<"$(_trim_string ${pkgpath})"
    pkgdir=${pkgdir[0]}
    pkgfile=${pkgdir[1]}
    IFS=$'\*' read -rd '' -a pkgfilefix <<<"$(_trim_string ${pkgfile})"
    pkgfileprefix=$(_trim_string ${pkgfilefix[0],,})
    pkgfilepostfix=$(_trim_string ${pkgfilefix[1],,})
    pkgurl=$(_trim_string ${pkg[2]})
    pkgurl=${pkgurl//amd64/${arch1,,}}

    # check if plugin enabled
    about_txt=$(typeset -f -- "${pluginname}"|metafor about)
    group_txt=$(typeset -f -- "${pluginname}"|metafor group)
    runtype_txt=$(typeset -f -- "${pluginname}"|metafor runtype)

    printf "${pluginname} ${pkgfile} : "
    # check if plugin is enabled
    [[ ! $group_txt && ! $runtype_txt ]] && echo "${pluginname} is not enabled. edit config and ./init.sh --sync" && continue
    # check if downloaded single file exists
    [[ $(find ${pkgpath} 2>/dev/null| wc -l) == 1 ]] && echo "file ${pkgpath} exists." && continue
    echo "file ${pkgpath} does not exist."
    # download file
    if [[ ${pkgurl} == "https://api.github.com/repos/"* ]]; then
        # download from github api
        # echo "Downloading ${pkgurl} to ${pkgpath}..."
        # with linux and musl or linux and gnu or deb
        # with deb
        possible_list=$(curl -sSL "${pkgurl}" | jq -r '.assets[] | select(.name | contains("'${arch1}'") or contains("'${arch2}'")) | .browser_download_url')
        IFS=$'\n' read -rd '' -a durls <<<"$possible_list"
        for((k=0;k<${#durls[@]};k++)){
            durl=$(_trim_string ${durls[k],,});
            if [[ ${#durls[@]} -gt 1 ]]; then
                if [[ ${durl} == *"linux"* && ${durl} == *"${pkgfilepostfix}" ]]; then 
                    echo "Downloading ${durl} to ${pkgfileprefix} ${pkgfilepostfix}..."
                    wget --directory-prefix=./"${pkgdir}" "${durl}" || echo "error downloading ${pkgfile}"; exit 1
                    break
                fi
            else
                if [[ ${durl} == *"${pkgfileprefix}"* && ${durl} == *"${pkgfilepostfix}" ]]; then 
                    echo "Downloading ${durl} to ${pkgfileprefix} ${pkgfilepostfix}..."
                    wget --directory-prefix=./"${pkgdir}" "${durl}" || echo "error downloading ${pkgfile}"; exit 1
                    break
                fi
            fi
        }
        break
    else
        if [[ ${pkgurl} == *"debian.org"* ]]; then
            echo "Downloading ${pkgurl} to ./"${pkgdir}"..."
            wget --directory-prefix=./"${pkgdir}" "${pkgurl}"
        else
            echo "debian.org and github.com is only supported for now."
        fi
    fi
    # echo "${pluginname} ${pkgpath} ${pkgfile} ${pkgurl} ${group_txt} ${runtype_txt}"
}
