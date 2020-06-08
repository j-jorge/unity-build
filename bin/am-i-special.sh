#!/bin/bash

set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)"
. "$script_dir/../lib/benchmark-utils.sh"

build_for_release=0
build_with_debug_info=0
git_commit=
git_repository=
project_build_dir=
project_cmake_args=()
project_cmake_lists=.
project_name=
project_source_dir=
modification_ratio=10
modification_count=

files_to_delete="$(mktemp)"
trap 'rm -f ${files_to_delete} $(cat "${files_to_delete}")' EXIT

shared_temp_file="$(mktemp)"
echo "$shared_temp_file" >> "$files_to_delete"

collect_candidate_files()
{
    pushd "$1" >/dev/null
    
    find "$PWD" -iname "*.[ch]" \
         -o -iname "*.[tchi]pp" \
         -o -iname "*.[tchi]xx" \
         -o -iname "*.[tchi]++" \
         -o -iname "*.hh" \
         -o -iname "*.cc" \

    popd >/dev/null
}

collect_files_to_modify()
{
    local file_list="$1"
    local file_count="$2"

    local count

    if [ -n "$modification_count" ]
    then
        count="$modification_count"
    else
        count=$((file_count * modification_ratio / 100 + 1))
    fi
    
    sort --random-sort "$file_list" \
        | head -n "$count"
}

modify_source_files()
{
    local file_list="$1"
    
    local tmp_source
    tmp_source="$(mktemp)"

    local tag
    tag="$(date +%s)"

    local i
    i=0

    while read -r file
    do
        cat > "$tmp_source" <<EOF
$(cat "$file")
extern int force_build_${tag}_${i};
EOF

        mv "$tmp_source" "$file"
        i=$((i + 1))
    done \
        < "$file_list" 
}

reset_source()
{
    pushd "$1" >/dev/null
    git reset --hard HEAD
    popd >/dev/null
}

double_build()
{
    local unity_build_arg

    if [ "$1" == "with_unity_build" ]
    then
        unity_build_arg="ON"
    else
        unity_build_arg="OFF"
    fi

    printf '== Initial build, unity build is %s ==\n' "${unity_build_arg}"
    reset_source "$project_source_dir"

    local build_type=Debug

    if [ "$build_for_release" -ne 0 ]
    then
        if [ "$build_with_debug_info" -ne 0 ]
        then
            build_type=RelWithDebInfo
        else
            build_type=Release
        fi
    fi

    cmake -S "$project_source_dir/$project_cmake_lists/" \
          -B . \
          -DCMAKE_BUILD_TYPE="$build_type" \
          -DCMAKE_UNITY_BUILD="$unity_build_arg" \
          -DCMAKE_UNITY_BUILD_BATCH_SIZE=65536 \
          "${cmake_args[@]}" \
          "${project_cmake_args[@]}" \
        || exit 1

    "${build_command[@]}"

    printf '== Classic with some modifications ==\n'
    modify_source_files "$files_to_modify"
    /usr/bin/time -f %e "${build_command[@]}"
}

enable_debug()
{
    build_with_debug_info=1
}

enable_release()
{
    build_for_release=1
}

add_project_cmake_arg()
{
    project_cmake_args+=("$@")
}

set_project_cmake_lists()
{
    project_cmake_lists="$1"
}

set_git_commit()
{
    git_commit="$1"
}

set_git_repository()
{
    git_repository="$1"
}

set_modification_ratio()
{
    modification_ratio="$1"
}

set_modification_count()
{
    modification_count="$1"
}

set_project_name()
{
    project_name="$1"
}

sanity_check

register_option '--enable-debug' enable_debug \
                "Build for debug. If --enable-release is set then the build \
is in release mode with debug info."

register_option '--enable-release' enable_release \
                "Build for release. If --enable-debug is set then the build \
is in release mode with debug info."

register_option '--cmake-arg=<arg…>' add_project_cmake_arg \
                "Argument to pass verbatim to CMake."

register_option '--cmakelists=<path>' set_project_cmake_lists \
                "The directory where to find the main CMakeLists.txt file, \
relatively to the project's root."

register_option '--commit=<hash|tag|branch>' set_git_commit \
                "The commit to checkout in the project's source."

register_option '--name=<string>' set_project_name \
                "The name of the project, used to create the directories and \
in the report."

register_option '--modification-count=<integer>' set_modification_count \
                "The number files to be modified for the builds. It takes \
precedence over --modification-ratio."

register_option '--modification-ratio=<integer>' set_modification_ratio \
                "The ratio of files to be modified for the builds." \
                "$modification_ratio"
register_option '--no-ccache' disable_ccache \
                "Do not use ccache even if available."
register_option '--repository=<url>' set_git_repository \
                "The git repository from which to fetch the project."

extract_parameters "$@"

check_option_is_set '--commit' "$git_commit"
check_option_is_set '--name' "$project_name"
check_option_is_set '--repository' "$git_repository"

printf '==== %s ====\n' "$project_name"

create_project_directories "$project_name"
project_source_dir="$(project_source_root "$project_name")"
project_build_dir="$(project_build_root "$project_name")"

cd "$project_source_dir"
clone_project . "$git_repository" "$git_commit"

! command -v cloc > /dev/null || cloc "$project_source_dir"

candidate_files="$(mktemp)"
echo "$candidate_files" >> "$files_to_delete"
collect_candidate_files "$project_source_dir" > "$candidate_files"

total_file_count="$(wc -l "$candidate_files" | awk '{print $1}')"

files_to_modify="$(mktemp)"
echo "$files_to_modify" >> "$files_to_delete"
collect_files_to_modify "$candidate_files" "$total_file_count" \
                        > "$files_to_modify"

printf '== Files to modify ==\n'
cat "$files_to_modify"

modified_file_count="$(wc -l < "$files_to_modify")"

cd "$project_build_dir"

configure_build_commands

double_build without_unity_build |& tee "$shared_temp_file"
[ "${PIPESTATUS[0]}" -eq 0 ] || exit "${PIPESTATUS[0]}"
time_without_unity_build="$(tail -n 1 "$shared_temp_file")"

double_build with_unity_build |& tee "$shared_temp_file"
[ "${PIPESTATUS[0]}" -eq 0 ] || exit "${PIPESTATUS[0]}"
time_with_unity_build="$(tail -n 1 "$shared_temp_file")"

printf 'Total files: %s\n' "$total_file_count"
printf 'Modified files: %s\n' "$modified_file_count"
printf 'Seconds with unity build: %s\n' "$time_with_unity_build"
printf 'Seconds without unity build: %s\n' "$time_without_unity_build"
