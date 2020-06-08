#!/bin/sh
#
# Copyright (C) 2018-current IsCool Entertainment
# Copyright (C) 2010 Mystic Tree Games
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Moritz "Moss" Wundke (b.thax.dcg@gmail.com)
#
# <License>
#
# Adapted common build methods from NDK-Common.sh and prebuilt-common.sh
# from the Android NDK
#

[ -z "$ISCOOL_OPTIONS_INCLUDED" ] || return 0
ISCOOL_OPTIONS_INCLUDED=1

# Current script name into PROGNAME
PROGNAME=`basename $0`

# return the value of a given named variable
# $1: variable name
#
# example:
#    FOO=BAR
#    BAR=ZOO
#    echo `var_value $FOO`
#    will print 'ZOO'
#
var_value ()
{
    # find a better way to do that ?
    eval echo "$`echo $1`"
}

# Return the maximum length of a series of strings
#
# Usage:  len=`max_length <string1> <string2> ...`
#
max_length ()
{
    echo "$@" \
        | tr ' ' '\n' \
        | awk 'BEGIN {max=0} {len=length($1); if (len > max) max=len} END {print max}'
}

# Translate dashes to underscores
# Usage:  str=`dashes_to_underscores <values>`
dashes_to_underscores ()
{
    echo "$@" | tr '-' '_'
}

#-----------------------------------------------------------------------
#  OPTION PROCESSING
#-----------------------------------------------------------------------

# We recognize the following option formats:
#
#  -f
#  --flag
#
#  -s<value>
#  --setting=<value>
#

# NOTE: We translate '-' into '_' when storing the options in global
#       variables
#

OPTIONS=""

# Set a given option attribute
# $1: option name
# $2: option attribute
# $3: attribute value
#
option_set_attr ()
{
    eval OPTIONS_$1_$2=\"$3\"
}

# Get a given option attribute
# $1: option name
# $2: option attribute
#
option_get_attr ()
{
    echo `var_value OPTIONS_$1_$2`
}

# Register a new option
# $1: option
# $2: name of function that will be called when the option is parsed
# $3: small abstract for the option
# $4: optional. default value
#
register_option ()
{
    local optname optvalue opttype optlabel
    optlabel=
    optname=
    optvalue=
    opttype=
    optarray=
    while true ; do
        # Check for something like --setting=<value>
        if echo "$1" | grep -q -E -e '^--[^=]+=<.+>$' ; then
            optlabel=`expr -- "$1" : '\(--[^=]*\)=.*'`
            optvalue=`expr -- "$1" : '--[^=]*=\(<.*>\)'`

            if expr -- "$1" : '--[^=]*=<.*\(…\)>' >/dev/null; then
                optarray=1
            else
                optarray=
            fi
            
            opttype="long_setting"
            break
        fi

        # Check for something like --flag
        if echo "$1" | grep -q -E -e '^--[^=]+$' ; then
            optlabel="$1"
            optarray=
            opttype="long_flag"
            break
        fi

        # Check for something like -f<value>
        if echo "$1" | grep -q -E -e '^-[A-Za-z0-9]<.+>$' ; then
            optlabel=`expr -- "$1" : '\(-.\).*'`
            optvalue=`expr -- "$1" : '-.\(<.+>\)'`
            optarray=
            opttype="short_setting"
            break
        fi

        # Check for something like -f
        if echo "$1" | grep -q -E -e '^-.$' ; then
            optlabel="$1"
            optarray=
            opttype="short_flag"
            break
        fi

        echo "ERROR: Invalid option format: $1"
        echo "       Check register_option call"
        exit 1
    done

    optname=`dashes_to_underscores $optlabel`
    OPTIONS="$OPTIONS $optname"
    OPTIONS_TEXT="$OPTIONS_TEXT $1"
    option_set_attr $optname label "$optlabel"
    option_set_attr $optname otype "$opttype"
    option_set_attr $optname oarray "$optarray"
    option_set_attr $optname value "$optvalue"
    option_set_attr $optname text "$1"
    option_set_attr $optname funcname "$2"
    option_set_attr $optname abstract "$3"
    option_set_attr $optname default "$4"
}

# Print the help, including a list of registered options for this program
# Note: Assumes PROGRAM_PARAMETERS exist and corresponds to the parameters list
#       and the program description
#
print_help ()
{
    local opt text abstract default

    echo "Usage: $PROGNAME [options] $PROGRAM_PARAMETERS"
    echo ""
    if [ -n "$PROGRAM_INTRODUCTION" ] ; then
        echo "$PROGRAM_INTRODUCTION"
        echo ""
    fi
    echo "Valid options (defaults are in brackets):"
    echo ""

    maxw=`max_length "$OPTIONS_TEXT"`
    AWK_SCRIPT=`echo "{ printf \"%-${maxw}s\", \\$1 }"`
    for opt in $OPTIONS; do
        text=`option_get_attr $opt text | awk "$AWK_SCRIPT"`
        abstract=`option_get_attr $opt abstract`
        default=`option_get_attr $opt default`
        if [ -n "$default" ] ; then
            echo "  $text     $abstract [$default]"
        else
            echo "  $text     $abstract"
        fi
    done
    echo ""
    
    if [ -n "$PROGRAM_POST_OPTIONS" ] ; then
        echo "$PROGRAM_POST_OPTIONS"
        echo ""
    fi
}

option_panic_no_args ()
{
    printf "%s: ERROR: Option '%s' does not take arguments." \
           "$PROGNAME" "$1" >&2
    printf " See --help for usage.\n" >&2
           
    exit 1
}

option_panic_missing_arg ()
{
    printf "%s: ERROR: Option '%s' requires an argument." \
           "$PROGNAME" "$1" >&2
    printf " See --help for usage.\n" >&2

    exit 1
}

extract_parameters ()
{
    local opt optname otype value name funcname in_array
    PARAMETERS=""

    while [ -n "$1" ] ; do
        # If the parameter does not begin with a dash
        # it is not an option.
        param=$(expr -- "$1" : '^\([^\-].*\)$' || true)
        if [ -n "$param" ] ; then
            if [ -n "$in_array" ]; then
                # Launch option-specific function, value, if any as argument
                eval `option_get_attr $name funcname` \"$param\"
            elif [ -z "$PARAMETERS" ] ; then
                PARAMETERS="$1"
            else
                PARAMETERS="$PARAMETERS $1"
            fi
            shift
            continue
        fi

        while true ; do
            # Try to match a long setting, i.e. --option=value
            opt=$(expr -- "$1" : '^\(--[^=]*\)=.*$' || true)
            if [ -n "$opt" ] ; then
                otype="long_setting"
                value=$(expr -- "$1" : '^--[^=]*=\(.*\)$' || true)
                break
            fi

            # Try to match a long flag, i.e. --option
            opt=$(expr -- "$1" : '^\(--.*\)$' || true)
            if [ -n "$opt" ] ; then
                otype="long_flag"
                value=
                break
            fi

            # Try to match a short setting, i.e. -o<value>
            opt=$(expr -- "$1" : '^\(-[A-Za-z0-9]\)..*$' || true)
            if [ -n "$opt" ] ; then
                otype="short_setting"
                value=$(expr -- "$1" : '^-.\(.*\)$' || true)
                break
            fi

            # Try to match a short flag, i.e. -o
            opt=$(expr -- "$1" : '^\(-.\)$' || true)
            if [ -n "$opt" ] ; then
                otype="short_flag"
                value=
                break
            fi

            printf "%s: ERROR: Unknown option '%s'." "$PROGNAME" "$1" >&2
            printf " Use --help for list of valid values.\n" >&2
            
            exit 1
        done

        name=`dashes_to_underscores $opt`
        found=0
        for xopt in $OPTIONS; do
            if [ "$name" != "$xopt" ] ; then
                continue
            fi
            # Check that the type is correct here
            #
            # This also allows us to handle -o <value> as -o<value>
            #
            xotype=`option_get_attr $name otype`
            if [ "$otype" != "$xotype" ] ; then
                case "$xotype" in
                "short_flag"|"long_flag")
                    option_panic_no_args $opt
                    ;;
                "short_setting"|"long_setting")
                    if [ -z "$2" ] ; then
                        option_panic_missing_arg $opt
                    fi
                    value="$2"
                    shift
                    ;;
                esac
            fi
            found=1

            in_array=`option_get_attr $name oarray`
            break
        done
        if [ "$found" = "0" ] ; then
            printf "%s: ERROR: Unknown option '%s'. See --help for usage.\n" \
                   "$PROGNAME" "$opt" >&2
            exit 1
        fi
        # Launch option-specific function, value, if any as argument
        eval `option_get_attr $name funcname` \"$value\"
        shift
    done
}

check_option_is_set()
{
    if [ -z "$2" ]
    then
        printf "%s: %s is not set. See --help for details.\n" "$0" "$1" >&2
        exit 1
    fi
}

do_option_help ()
{
    print_help
    exit 0
}

register_option "--help"          do_option_help     "Print this help."
