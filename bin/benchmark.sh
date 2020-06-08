#!/bin/bash

set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
. "$script_dir/../lib/benchmark-utils.sh"

am_i_special_args=()
weak_function_enabled=1
tweenerspp_enabled=1
iscool_core_enabled=1

boost_install=yes
gtest_install=yes
jsoncpp_install=yes
mofilereader_install=yes

store_project_result()
{
    local exit_code="$1"
    local project_name="$2"

    if [ "$exit_code" -eq 0 ]
    then
        results+=("$project_name"
                  $(tail -n 4 "${build_output_file}" | cut -d: -f2))
    else
        results+=("$project_name" x x x x)
    fi
}

check_compile()
{
    local cxx="$CXX"
    
    [ -n "$cxx" ] || cxx=c++

    echo "#include <$1>" | "$cxx" -x c++ -E -c - -o /dev/null 2> /dev/null
}

install_boost()
{
    [ "$boost_install" != "no" ] || return 0

    [ "$boost_install" == "force" ] \
        || ! check_compile "boost/version.hpp" \
        || return 0
    
    [ ! -e "$install_root/lib/libboost_system.a" ] || return 0

    printf 'Installing Boost.\n'
    
    create_project_directories boost

    local boost_source
    boost_source="$(project_source_root boost)"

    local boost_build
    boost_build="$(project_build_root boost)"

    pushd "$boost_source" >/dev/null
    local boost_dir="boost_1_73_0"
    local boost_archive="$boost_dir.tar.bz2"

    curl -L -C - -O \
         https://dl.bintray.com/boostorg/release/1.73.0/source/"$boost_archive"

    cd "$(project_build_root boost)"

    printf 'Extracting Boost archive.\n'
    tar xf "$boost_source/$boost_archive"

    cd "$boost_dir"

    ./bootstrap.sh \
        --with-libraries=filesystem,program_options,system,thread \
        --prefix="$install_root"

    ./b2 \
        --prefix="$install_root" \
        --build-type=minimal \
        link=static \
        variant=release \
        threading=multi \
        install
         
    popd > /dev/null
}

install_gettext()
{
    [ "$gettext_install" != "no" ] || return 0

    [ "$gettext_install" == "force" ] \
        || ! command -v xgettext > /dev/null \
        || return 0
    
    [ ! -e "$install_root/bin/xgettext" ] || return 0

    printf 'Installing Gettext.\n'
    
    create_project_directories gettext

    local gettext_source
    gettext_source="$(project_source_root gettext)"

    local gettext_build
    gettext_build="$(project_build_root gettext)"

    pushd "$gettext_source" >/dev/null
    local gettext_dir="gettext-0.20.2"
    local gettext_archive="$gettext_dir.tar.gz"

    curl -L -C - -O \
         https://ftp.gnu.org/pub/gnu/gettext/"$gettext_archive"

    cd "$(project_build_root gettext)"

    printf 'Extracting Gettext archive.\n'
    tar xf "$gettext_source/$gettext_archive"

    cd "$gettext_dir"

    ./configure --enable-release \
                --prefix="$install_root"

    make install -j$(ncpu)
         
    popd > /dev/null
}

install_gtest()
{
    [ "$gtest_install" != "no" ] || return 0

    [ "$gtest_install" == "force" ] \
        || ! check_compile "gtest/gtest.h" \
        || return 0
    
    [ ! -e "$install_root/lib/libgtest.a" ] || return 0

    printf 'Installing Googletest.\n'
    
    create_project_directories gtest
    
    local gtest_source
    gtest_source="$(project_source_root gtest)"
    
    clone_project "$gtest_source" \
                  "https://github.com/google/googletest.git" \
                  "release-1.10.0"

    pushd "$(project_build_root gtest)" >/dev/null
    cmake -S "$gtest_source/" \
          -B . \
          "${cmake_args[@]}" \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="$install_root"
    
    "${build_command[@]}" install
    popd >/dev/null
}

install_jsoncpp()
{
    [ "$jsoncpp_install" != "no" ] || return 0

    [ "$jsoncpp_install" == "force" ] \
        || ! check_compile "json/value.h" \
        || return 0
    
    [ ! -e "$install_root/lib/libjsoncpp.a" ] || return 0

    printf 'Installing JsonCpp.\n'
    
    create_project_directories jsoncpp
    
    local jsoncpp_source
    jsoncpp_source="$(project_source_root jsoncpp)"
    
    clone_project "$jsoncpp_source" \
                  "https://github.com/open-source-parsers/jsoncpp.git" \
                  "1.9.3"

    pushd "$(project_build_root jsoncpp)" >/dev/null
    cmake -S "$jsoncpp_source/" \
          -B . \
          "${cmake_args[@]}" \
          -DJSONCPP_WITH_TESTS=OFF \
          -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF \
          -DJSONCPP_WITH_CMAKE_PACKAGE=ON \
          -DJSONCPP_WITH_PKGCONFIG_SUPPORT=OFF \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="$install_root"
    
    "${build_command[@]}" install
    popd >/dev/null
}

install_mofilereader()
{
    [ "$mofilereader_install" != "no" ] || return 0

    [ "$mofilereader_install" == "force" ] \
        || ! check_compile "moFileReader/moFileReader.h" \
        || return 0
    
    [ ! -e "$install_root/lib/libmoFileReader.a" ] || return 0

    printf 'Installing MoFileReader.\n'
    
    create_project_directories mofilereader

    local mofilereader_source
    mofilereader_source="$(project_source_root mofilereader)"
    
    clone_project "$mofilereader_source" \
                  "https://github.com/j-jorge/mofilereader.git" \
                  "v1"

    pushd "$(project_build_root mofilereader)" >/dev/null
    cmake -S "$mofilereader_source/build/" \
          -B . \
          "${cmake_args[@]}" \
          -DCOMPILE_DLL=OFF \
          -DCOMPILE_APP=OFF \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="$install_root"
    
    "${build_command[@]}" install
    popd >/dev/null
}
build_weak_function()
{
    install_gtest
    
    "$script_dir"/am-i-special.sh \
                 "${am_i_special_args[@]}" \
                 --repository https://github.com/j-jorge/weak-function/ \
                 --commit v3 \
                 --name weak-function \
                 --cmakelists cmake \
                 --cmake-arg -DENABLE_COMPILATION_UNITS=OFF \
                 --cmake-arg -DWFL_EXAMPLES_ENABLED=ON \
                 --cmake-arg -DWFL_TESTING_ENABLED=ON \
                 --cmake-arg -DCMAKE_PREFIX_PATH="$install_root" \
        | tee "${build_output_file}"

    store_project_result "${PIPESTATUS[0]}" weak-function
}

build_tweenerspp()
{
    install_boost
    install_gtest
    
    "$script_dir"/am-i-special.sh \
                 "${am_i_special_args[@]}" \
                 --repository https://github.com/j-jorge/tweenerspp/ \
                 --commit v1.1 \
                 --name tweenerspp \
                 --cmakelists cmake \
                 --cmake-arg -DENABLE_COMPILATION_UNITS=OFF \
                 --cmake-arg -DTWEENERS_BENCHMARKING_ENABLED=ON \
                 --cmake-arg -DTWEENERS_DEMO_ENABLED=OFF \
                 --cmake-arg -DTWEENERS_TESTING_ENABLED=ON \
                 --cmake-arg -DCMAKE_PREFIX_PATH="$install_root" \
        | tee "${build_output_file}"

    store_project_result "${PIPESTATUS[0]}" tweenerspp
}

build_iscool_core()
{
    install_boost
    install_gettext
    install_gtest
    install_jsoncpp
    install_mofilereader
    
    "$script_dir"/am-i-special.sh \
                 "${am_i_special_args[@]}" \
                 --repository "https://github.com/j-jorge/iscool-core" \
                 --commit 1.7.5-1 \
                 --name iscool-core \
                 --cmakelists build-scripts/cmake \
                 --cmake-arg -DENABLE_COMPILATION_UNITS=OFF \
                 --cmake-arg -DISCOOL_AUTO_RUN_TESTS=OFF \
                 --cmake-arg -DUSE_DEFAULT_GOOGLE_TEST=YES \
                 --cmake-arg -DUSE_DEFAULT_JSONCPP=YES \
                 --cmake-arg -DUSE_DEFAULT_MO_FILE_READER=YES \
                 --cmake-arg -DCMAKE_PREFIX_PATH="$install_root" \
        | tee "${build_output_file}"

    store_project_result "${PIPESTATUS[0]}" iscool-core
}

benchmark_disable_ccache()
{
    am_i_special_args+=(--no-ccache)
    disable_ccache
}

enable_debug()
{
    am_i_special_args+=(--enable-debug)
}

enable_release()
{
    am_i_special_args+=(--enable-release)
}

disable_weak_function()
{
    weak_function_enabled=0
}

disable_tweenerspp()
{
    tweenerspp_enabled=0
}

disable_iscool_core()
{
    iscool_core_enabled=0
}

set_modification_ratio()
{
    am_i_special_args+=("--modification-ratio=$1")
}

set_modification_count()
{
    am_i_special_args+=("--modification-count=$1")
}

set_boost_installation()
{
    boost_install="$1"
}

set_gettext_installation()
{
    gettext_install="$1"
}

set_gtest_installation()
{
    gtest_install="$1"
}

set_jsoncpp_installation()
{
    jsoncpp_install="$1"
}

set_mofilereader_installation()
{
    mofilereader_install="$1"
}

sanity_check

register_option '--enable-debug' enable_debug \
                "Build for debug. If --enable-release is set then the build \
is in release mode with debug info."

register_option '--enable-release' enable_release \
                "Build for release. If --enable-debug is set then the build \
is in release mode with debug info."

register_option '--exclude-wfl' disable_weak_function \
                "Do not benchmark the building of the weak function library."

register_option '--exclude-tweenerspp' disable_tweenerspp \
                "Do not benchmark the building of the tweenerspp library."

register_option '--exclude-iscool-core' disable_iscool_core \
                "Do not benchmark the building of the iscool::core library."

register_option '--modification-count=<integer>' set_modification_count \
                "The number files to be modified for the builds. It takes \
precedence over --modification-ratio."

register_option '--modification-ratio=<integer>' set_modification_ratio \
                "The ratio of files to be modified for the builds." "10"

register_option '--no-ccache' benchmark_disable_ccache \
                "Do not use ccache even if available."

register_option '--install-boost=<yes|no|force>' set_boost_installation \
                'Drive the installation of Boost.' \
                "$boost_install"

register_option '--install-gettext=<yes|no|force>' set_gettext_installation \
                'Drive the installation of Gettext.' \
                "$gettext_install"

register_option '--install-gtest=<yes|no|force>' set_gtest_installation \
                'Drive the installation of Googletest.' \
                "$gtest_install"

register_option '--install-jsoncpp=<yes|no|force>' set_jsoncpp_installation \
                'Drive the installation of JsonCpp.' \
                "$jsoncpp_install"

register_option '--install-mofilereader=<yes|no|force>' \
                set_mofilereader_installation \
                'Drive the installation of MoFileReader.' \
                "$mofilereader_install"

PROGRAM_POST_OPTIONS="\
Regarding the --install-<lib> options, \"no\" skips the installation, \"yes\"
installs the library in the build directory if it is not available in the
system, \"force\" installs the library regardless of its availability."

extract_parameters "$@"

configure_build_commands

build_output_file="$(mktemp)"
trap "rm -f ${build_output_file}" EXIT

[ "$weak_function_enabled" = 0 ] || build_weak_function
[ "$tweenerspp_enabled" = 0 ] || build_tweenerspp
[ "$iscool_core_enabled" = 0 ] || build_iscool_core

i=0
c="${#results[@]}"

printf '+---------------+\n'
printf '|  The Results  |\n'
printf '+---------------+\n'

while [ "$i" -lt "$c" ]
do
    project="${results[$i]}"
    total_file_count="${results[$((i+1))]}"
    file_count="${results[$((i+2))]}"
    with="${results[$((i+3))]}"
    without="${results[$((i+4))]}"
    i=$((i+5))

    if [[ "$total_file_count$file_count$with$without" == *x* ]]
    then
        printf "The build of '%s' failed.\n" "$project"
    else
        printf "Building with %s modified files out of %s in '%s' took %s seconds with a unity build, %s seconds without.\n" \
               "$file_count" "$total_file_count" "$project" "$with" "$without"
    fi
done
