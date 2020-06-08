#!/bin/bash -x

utils_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
. "$utils_script_dir/options.sh"

source_root="$PWD/unity-build-test/source"
build_root="$PWD/unity-build-test/build"
install_root="$PWD/unity-build-test/install"

ccache_disabled=0

cmake_args=()
build_command=()

disable_ccache()
{
    ccache_disabled=1
}

configure_build_commands()
{
    cmake_args+=("-G" "Unix Makefiles")
    build_command=(make -j"$(nproc)")

    if [ "$ccache_disabled" = 0 ] && command -v ccache >/dev/null
    then
        cmake_args+=("-DCMAKE_C_COMPILER_LAUNCHER=ccache"
                     "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache")
    fi

}

project_source_root()
{
    echo "$source_root/$1"
}

project_build_root()
{
    echo "$build_root/$1"
}

create_project_directories()
{
    local project_build_dir
    project_build_dir="$(project_build_root "$1")"
    rm -fr "$project_build_dir"
    
    mkdir -p "$(project_source_root "$1")" \
          "$project_build_dir" \
          "$install_root"
}

clone_project()
{
    local target_directory="$1"
    local repository="$2"
    local commit="$3"

    [ -n "$(ls -A "$target_directory")" ] \
        || git clone "$repository" "$target_directory" --depth 1 -b "$commit"
}

# From https://stackoverflow.com/a/4025065/1171783
compare_versions() {

    if [ "$1" == "$2" ]
    then
        echo 0
        return
    fi
    
    local IFS=.
    local i
    local lhs=($1)
    local rhs=($2)
    
    # fill empty fields in lhs with zeros
    for ((i=${#lhs[@]}; i<${#rhs[@]}; i++))
    do
        lhs[i]=0
    done
    
    for ((i=0; i!=${#lhs[@]}; i++))
    do
        if [[ -z ${rhs[i]} ]]
        then
            # fill empty fields in rhs with zeros
            rhs[i]=0
        fi

        local left_field=10#${lhs[i]}
        local right_field=10#${rhs[i]}
        
        if ((left_field < right_field))
        then
            echo -1
            return
        elif ((left_field > right_field))
        then
            echo 1
            return
        fi
    done

    echo 0
    return
}

sanity_check()
{
    local result=0
    
    if ! command -v make > /dev/null
    then
        printf "The 'make' command does not exist. Aborting.\n" >&2
        result=1
    fi
    
    if command -v cmake > /dev/null
    then
        local cmake_minimum_version="3.16"
        local cmake_current_version

        cmake_current_version="$(cmake --version \
                                       | head -n1 \
                                       | grep -o '[0-9.]\+')"

        local version_order
        version_order="$(compare_versions "$cmake_current_version" \
                                          "$cmake_minimum_version")"
        

        if [ "$version_order" -eq -1 ]
        then
            (
                printf 'CMake is too old.'
                printf ' I need at version %s or greater, I found version %s.' \
                       "$cmake_minimum_version" \
                       "$cmake_current_version"
                printf ' Aborting.\n'
            )>&2

            result=1
        fi
    else
        printf "The 'make' command does not exist. Aborting.\n" >&2
        result=1
    fi

    return $result
}
