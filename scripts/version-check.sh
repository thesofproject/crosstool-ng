# This script checks the version of the configuration file and either
# alerts the user about the need to run the upgrade, or attempts to
# perform such an upgrade.

CFGFILE="${1}"

. "${CT_LIB_DIR}/scripts/functions"
. "${CFGFILE}"

# If an old config does not define a version, assume it is 0. This is used
# if we run this script on an old full .config file, not restored from a
# defconfig.
CT_CONFIG_VERSION="${CT_CONFIG_VERSION:-0}"
if [ "${CT_CONFIG_VERSION_CURRENT}" == "${CT_CONFIG_VERSION}" ]; then
    # Nothing to do
    exit 0
fi

if [ -z "${CT_UPGRADECONFIG}" ]; then
    if [ "${CT_CONFIG_VERSION}" != "0" ]; then
        oldversion="is version ${CT_CONFIG_VERSION}"
    else
        oldversion="has no version"
    fi
    cat 2>&1 <<EOF

Configuration file was generated by an older version of crosstool-NG;
configuration file ${oldversion}; crosstool-NG currently expects
version ${CT_CONFIG_VERSION_CURRENT}. If this configuration file was generated by a crosstool-NG
version 1.23.0 or later, you can run 'ct-ng upgradeconfig'.
Compatibility with previous releases is not guaranteed. In any case,
verify the resulting configuration.

EOF
    if [ "${CT_VCHECK}" = "strict" ]; then
        exit 1
    else
        exit 0
    fi
fi

is_set()
{
    if [ "x${val+set}" = "xset" ]; then
        return 0
    else
        return 1
    fi
}

info()
{
    # $opt comes from the caller
    echo "INFO ${opt:+:: ${opt} }:: $1" >&2
}

warning()
{
    # $opt comes from the caller
    echo "WARN ${opt:+:: ${opt} }:: $1" >&2
}

warning_if_set()
{
    if is_set; then
        warning "$@"
    fi
}

# When a symbol is replaced with a newer version. If it is a choice and
# the replacement existed in the old version as well, add a replacement_for
# handler for the other symbol to avoid kconfig warnings.
replace()
{
    local newopt="${1}"

    if is_set; then
        info "No longer supported; replacing with '${newopt}'".
        opt="${newopt}"
    else
        # Wasn't set; just drop it silently
        unset opt
    fi
}

# Avoid multiple definitions for a symbol when multiple old symbols are folded into one
# in a new version. If any of the variable names passed as arguments are set, skip
# emitting this variable (which, presumably, is "not set").
replacement_for()
{
    while [ -n "${1}" ]; do
        if [ -n "${!1}" ]; then
            unset opt
            return
        fi
        shift
    done
}

# Upgrade from v0: select Linaro as the vendor if a Linaro version was selected
# (in v0, both GNU and Linaro versions were combined in a single list). GNU is
# the default, leave it to olddefconfig to select it if we don't see a Linaro version.
# We don't depend on CT_xxx_SHOW_LINARO symbols: they just enabled showing Linaro
# versions in that list, but it may have been GNU version that was actually selected.
select_linaro()
{
    if is_set; then
        echo "# CT_${1}_USE_GNU is not set"
        echo "CT_${1}_USE_LINARO=y"
    fi
}


### Per-version upgrade drivers. Called with ${opt} and ${val} set,
### may modify these variables

# Upgrade from version 0 (which is 1.23, as released) to version 1
# (current state of master as of 2019/01/20). Upgrades in the interim
# versions may be broken.
upgrade_v0()
{
    case "${opt}" in
    CT_ARCH_alpha|CT_ARCH_arm|CT_ARCH_avr|CT_ARCH_m68k|CT_ARCH_microblaze|\
    CT_ARCH_mips|CT_ARCH_nios2|CT_ARCH_powerpc|CT_ARCH_s390|CT_ARCH_sh|\
    CT_ARCH_sparc|CT_ARCH_x86|CT_ARCH_xtensa|\
    CT_BINUTILS_binutils|\
    CT_CC_gcc|\
    CT_COMP_TOOLS_autoconf|CT_COMP_TOOLS_automake|CT_COMP_TOOLS_libtool|\
    CT_COMP_TOOLS_m4|CT_COMP_TOOLS_make|\
    CT_DEBUG_duma|CT_DEBUG_gdb|CT_DEBUG_ltrace|CT_DEBUG_strace|\
    CT_KERNEL_bare_metal|CT_KERNEL_linux|CT_KERNEL_windows|\
    CT_LIBC_avr_libc|CT_LIBC_glibc|CT_LIBC_musl|CT_LIBC_newlib|CT_LIBC_none|\
    CT_LIBC_uClibc)
        # Renamed to upper-case
        opt=${opt^^}
        ;;
    CT_ARCH_XTENSA_CUSTOM_NAME)
        replace CT_OVERLAY_NAME
        ;;
    CT_ARCH_XTENSA_CUSTOM_OVERLAY_LOCATION)
        replace CT_OVERLAY_LOCATION
        ;;
    CT_LIBC_mingw)
        # Renamed to MINGW_W64
        opt=CT_LIBC_MINGW_W64
        ;;
    CT_ARCH_*_AVAILABLE|CT_KERNEL_*_AVAILABLE|CT_LIBC_*_AVAILABLE)
        # Previously used "backend selectors". Autogenerated, no warning
        unset opt
        ;;
    CT_CONFIGURE_has_*)
        # Configure-detected build machine options. Drop, will use current.
        unset opt
        ;;
    CT_*_or_later)
        # Automatically selected version constraints. Drop, will auto-select current ones.
        unset opt
        ;;
    CT_BACKEND_ARCH|CT_BACKEND_KERNEL|CT_BACKEND_LIBC|CT_IS_A_BACKEND)
        warning "Option ${opt} is no longer supported, dropping"
        unset opt
        ;;
    CT_*_SHOW_LINARO)
        # Used to just include Linaro versions into the list. We'll infer whether Linaro is
        # actually used from the actual version selected, below.
        unset opt
        ;;
    CT_CC_GCC_4_8|CT_CC_GCC_4_9|CT_CC_GCC_5|CT_CC_GCC_6|\
    CT_LIBC_NEWLIB_2_0|CT_LIBC_NEWLIB_2_1|CT_LIBC_NEWLIB_2_2|CT_LIBC_NEWLIB_2_3|CT_LIBC_NEWLIB_2_4|CT_LIBC_NEWLIB_2_5)
        # In 1.23.0, each package had its own ad-hoc version constraints. Drop, new ones
        # will be autoselected.
        unset opt
        ;;
    # Custom location: translate to the new framework. No generic way to interpret the version
    # string user may have configured; just warn him to select it manually.
    CT_BINUTILS_CUSTOM)
        warning_if_set "Assuming custom location contains GNU sources; edit the configuration if it was Linaro version"
        replace CT_BINUTILS_SRC_CUSTOM
        ;;
    CT_CC_GCC_CUSTOM)
        warning_if_set "Assuming custom location contains GNU sources; edit the configuration if it was Linaro version"
        replace CT_GCC_SRC_CUSTOM
        ;;
    CT_CC_GCC_CUSTOM_LOCATION)
        replace CT_GCC_CUSTOM_LOCATION
        ;;
    CT_ELF2FLT_CUSTOM)
        replace CT_ELF2FLT_SRC_CUSTOM
        ;;
    CT_ELF2FLT_GIT)
        if is_set; then
            echo "CT_ELF2FLT_SRC_DEVEL=y"
        fi
        replace CT_ELF2FLT_DEVEL_VCS_git
        ;;
    CT_ELF2FLT_GIT_CSET)
        replace CT_ELF2FLT_DEVEL_REVISION
        ;;
    CT_GDB_CUSTOM)
        warning_if_set "Assuming custom location contains GNU sources; edit the configuration if it was Linaro version"
        replace CT_GDB_SRC_CUSTOM
        ;;
    CT_KERNEL_LINUX_CUSTOM)
        replace CT_LINUX_SRC_CUSTOM
        ;;
    CT_KERNEL_LINUX_CUSTOM_LOCATION)
        replace CT_LINUX_CUSTOM_LOCATION
        ;;
    CT_LIBC_AVR_LIBC_CUSTOM)
        replace CT_AVR_LIBC_SRC_CUSTOM
        ;;
    CT_LIBC_AVR_LIBC_CUSTOM_LOCATION)
        replace CT_AVR_LIBC_CUSTOM_LOCATION
        ;;
    CT_LIBC_GLIBC_CUSTOM)
        warning_if_set "Assuming custom location contains GNU sources; edit the configuration if it was Linaro version"
        replace CT_GLIBC_SRC_CUSTOM
        ;;
    CT_LIBC_GLIBC_CUSTOM_LOCATION)
        replace CT_GLIBC_CUSTOM_LOCATION
        ;;
    CT_LIBC_MUSL_CUSTOM)
        replace CT_MUSL_SRC_CUSTOM
        ;;
    CT_LIBC_MUSL_CUSTOM_LOCATION)
        replace CT_MUSL_CUSTOM_LOCATION
        ;;
    CT_LIBC_NEWLIB_CUSTOM)
        warning_if_set "Assuming custom location contains GNU sources; edit the configuration if it was Linaro version"
        replace CT_NEWLIB_SRC_CUSTOM
        ;;
    CT_LIBC_NEWLIB_CUSTOM_LOCATION)
        replace CT_NEWLIB_CUSTOM_LOCATION
        ;;
    CT_LIBC_UCLIBC_CUSTOM)
        if [ "${CT_LIBC_UCLIBC_CUSTOM_UCLIBC}" = "y" ]; then
            replace CT_UCLIBC_SRC_CUSTOM
        else
            replace CT_UCLIBC_NG_SRC_CUSTOM
        fi
        ;;
    CT_LIBC_UCLIBC_CUSTOM_UCLIBC)
        replace CT_UCLIBC_SRC_CUSTOM
        ;;
    CT_LIBC_UCLIBC_CUSTOM_UCLIBC_NG)
        replace CT_UCLIBC_NG_SRC_CUSTOM
        ;;
    CT_LIBC_UCLIBC_CUSTOM_UCLIBC_NG_OLD)
        warning_if_set "uClibc-NG versions before 1.0.15 no longer supported"
        replace CT_UCLIBC_NG_SRC_CUSTOM
        ;;
    CT_LIBC_UCLIBC_CUSTOM_LOCATION)
        if [ "${CT_LIBC_UCLIBC_CUSTOM_UCLIBC}" = "y" ]; then
            replace CT_UCLIBC_CUSTOM_LOCATION
        else
            replace CT_UCLIBC_NG_CUSTOM_LOCATION
        fi
        ;;
    CT_WINAPI_V_DEVEL)
        replace CT_MINGW_W64_SRC_DEVEL
        ;;
    CT_WINAPI_V_select)
        # Internal selector
        unset opt
        ;;
    CT_BINUTILS_CUSTOM_VERSION|CT_CC_GCC_CUSTOM_VERSION|CT_ELF2FLT_CUSTOM_VERSION|CT_KERNEL_LINUX_CUSTOM_VERSION|\
    CT_LIBC_AVR_LIBC_CUSTOM_VERSION|CT_LIBC_GLIBC_CUSTOM_VERSION|CT_LIBC_MUSL_CUSTOM_VERSION|\
    CT_LIBC_NEWLIB_CUSTOM_VERSION|CT_LIBC_UCLIBC_CUSTOM_VERSION|CT_GDB_CUSTOM_VERSION)
        warning_if_set "Cannot automatically convert custom version; edit configuration to select it"
        unset opt
        ;;
    CT_CC_GCC_VERSION|CT_CC_VERSION|CT_KERNEL_VERSION|CT_WINAPI_VERSION|CT_LIBC_VERSION)
        # Auto-selected; the symbol was just renamed
        unset opt
        ;;
    CT_LIBC_glibc_family)
        # Internal selector, not user-visible
        unset opt
        ;;
    CT_LIBC_ADDONS_LIST)
        warning_if_set "Support for custom add-ons has been removed. If using libidn add-on, edit the configuration."
        ;;
    CT_LIBC_DISABLE_VERSIONING)
        replace CT_GLIBC_DISABLE_VERSIONING
        ;;
    CT_LIBC_ENABLE_FORTIFIED_BUILD)
        replace CT_GLIBC_ENABLE_FORTIFIED_BUILD
        ;;
    CT_LIBC_GLIBC_CONFIGPARMS|CT_LIBC_GLIBC_EXTRA_CFLAGS|CT_LIBC_GLIBC_EXTRA_CONFIG_ARRAY|\
    CT_LIBC_GLIBC_FORCE_UNWIND|CT_LIBC_GLIBC_KERNEL_VERSION_AS_HEADERS|CT_LIBC_GLIBC_KERNEL_VERSION_CHOSEN|\
    CT_LIBC_GLIBC_KERNEL_VERSION_NONE|CT_LIBC_GLIBC_MIN_KERNEL|CT_LIBC_GLIBC_MIN_KERNEL_VERSION)
        replace CT_GLIBC_${opt#CT_LIBC_GLIBC_}
        ;;
    CT_LIBC_LOCALES)
        replace CT_GLIBC_LOCALES
        ;;
    CT_LIBC_OLDEST_ABI)
        replace CT_GLIBC_OLDEST_ABI
        ;;
    CT_LIBC_GLIBC_NEEDS_PORTS|CT_LIBC_GLIBC_PORTS_EXTERNAL|CT_LIBC_GLIBC_USE_PORTS)
        # Auto-selected
        unset opt
        ;;
    CT_LIBC_UCLIBC_LOCALES_PREGEN_DATA)
        warning_if_set "Support for pregenerated locales in uClibc has been removed"
        unset opt
        ;;
    # Trivial version replacements
    CT_AUTOMAKE_V_1_11_1)           replace CT_AUTOMAKE_V_1_11_6;;
    CT_AUTOMAKE_V_1_11_6)           replacement_for CT_AUTOMAKE_V_1_11_1;;
    CT_AUTOMAKE_V_1_14)             replace CT_AUTOMAKE_V_1_14_1;;
    CT_AUTOMAKE_V_1_15)             replace CT_AUTOMAKE_V_1_15_1;;
    CT_BINUTILS_V_2_26)             replace CT_BINUTILS_V_2_26_1;;
    CT_BINUTILS_V_2_28)             replace CT_BINUTILS_V_2_28_1;;
    CT_BINUTILS_LINARO_V_2_23_2)    select_linaro BINUTILS; replace CT_BINUTILS_LINARO_V_2_23_2_2013_10_4;;
    CT_BINUTILS_LINARO_V_2_24)      select_linaro BINUTILS; replace CT_BINUTILS_LINARO_V_2_24_0_2014_11_2;;
    CT_BINUTILS_LINARO_V_2_25)      select_linaro BINUTILS; replace CT_BINUTILS_LINARO_V_2_25_0_2015_01_2;;
    CT_CC_GCC_V_4_8_5)              replace CT_GCC_V_4_8_5;;
    CT_CC_GCC_V_4_9_4)              replace CT_GCC_V_4_9_4;;
    CT_CC_GCC_V_5_4_0)              replace CT_GCC_V_5_5_0;;
    CT_CC_GCC_V_6_3_0)              replace CT_GCC_V_6_5_0;;
    CT_CC_GCC_V_linaro_4_8)         select_linaro GCC; replace CT_GCC_LINARO_V_4_8_2015_06;;
    CT_CC_GCC_V_linaro_4_9)         select_linaro GCC; replace CT_GCC_LINARO_V_4_9_2017_01;;
    CT_CC_GCC_V_linaro_5_4)         select_linaro GCC; replace CT_GCC_LINARO_V_5_5_2017_10;;
    CT_CC_GCC_V_linaro_6_3)         select_linaro GCC; replace CT_GCC_LINARO_V_6_4_2018_05;;
    CT_CLOOG_V_0_18_0)              replace CT_CLOOG_V_0_18_1;;
    CT_CLOOG_V_0_18_1)              replacement_for CT_CLOOG_V_0_18_0;;
    CT_EXPAT_V_2_2_0)               replace CT_EXPAT_V_2_2_6;; # 2.2.6 was not available in ct-ng 1.23.0 - no replacement_for
    CT_GDB_V_6_8a)                  replace CT_GDB_V_6_8A;;
    CT_GDB_V_7_0a)                  replace CT_GDB_V_7_0_1A;;
    CT_GDB_V_7_0_1a)                replace CT_GDB_V_7_0_1A;;
    CT_GDB_V_7_1a)                  replace CT_GDB_V_7_1A;;
    CT_GDB_V_7_2a)                  replace CT_GDB_V_7_2A;;
    CT_GDB_V_7_3a)                  replace CT_GDB_V_7_3A;;
    CT_GDB_V_7_4)                   replace CT_GDB_V_7_4_1;;
    CT_GDB_V_7_7)                   replace CT_GDB_V_7_7_1;;
    CT_GDB_V_7_8|CT_GDB_V_7_8_1)    replace CT_GDB_V_7_8_2;;
    CT_GDB_V_7_8_2)                 replacement_for CT_GDB_V_7_8 CT_GDB_V_7_8_1;;
    CT_GDB_V_7_9)                   replace CT_GDB_V_7_9_1;;
    CT_GDB_V_7_10)                  replace CT_CT_GDB_V_7_10_1;;
    CT_GDB_V_linaro_7_3)            select_linaro GDB; replace CT_GDB_LINARO_V_7_3_2011_12;;
    CT_GDB_V_linaro_7_4)            select_linaro GDB; replace CT_GDB_LINARO_V_7_4_2012_06;;
    CT_GDB_V_linaro_7_5)            select_linaro GDB; replace CT_GDB_LINARO_V_7_5_2012_12;;
    CT_GDB_V_linaro_7_6)            select_linaro GDB; replace CT_GDB_LINARO_V_7_6_1_2013_10;;
    CT_GDB_V_linaro_7_7)            select_linaro GDB; replace CT_GDB_LINARO_V_7_7_1_2014_06_1;;
    CT_GDB_V_linaro_7_7_1)          select_linaro GDB; replace CT_GDB_LINARO_V_7_7_1_2014_06_1;;
    CT_GDB_V_linaro_7_8)            select_linaro GDB; replace CT_GDB_LINARO_V_7_8_2014_09;;
    CT_GMP_V_4_3_0|CT_GMP_V_4_3_1)  replace CT_GMP_V_4_3_2;;
    CT_GMP_V_4_3_2)                 replacement_for CT_GMP_V_4_3_0 CT_GMP_V_4_3_1;;
    CT_GMP_V_5_0_1|CT_GMP_V_5_0_2)  replace CT_GMP_V_5_0_5;; # 5.0.5 not in ct-ng 1.23.0
    CT_GMP_V_5_1_1)                 replace CT_GMP_V_5_1_3;;
    CT_GMP_V_5_1_3)                 replacement_for CT_GMP_V_5_1_1;;
    CT_GMP_V_6_0_0)                 replace CT_GMP_V_6_0_0A;; # 6.0.0a not in ct-ng 1.23.0
    CT_GMP_V_6_1_0)                 replace CT_GMP_V_6_1_2;;
    CT_GMP_V_6_1_2)                 replacement_for CT_GMP_V_6_1_0;;
    CT_ISL_V_0_11_1)                replace CT_ISL_V_0_11_2;;
    CT_ISL_V_0_14)                  replace CT_ISL_V_0_14_1;;
    CT_KERNEL_V_2_6_32|CT_KERNEL_V_2_6_33|CT_KERNEL_V_2_6_34|CT_KERNEL_V_2_6_35|\
    CT_KERNEL_V_2_6_36|CT_KERNEL_V_2_6_37|CT_KERNEL_V_2_6_38|CT_KERNEL_V_2_6_39|\
    CT_KERNEL_V_3_0|CT_KERNEL_V_3_1|CT_KERNEL_V_3_2|CT_KERNEL_V_3_3|CT_KERNEL_V_3_4|CT_KERNEL_V_3_5|\
    CT_KERNEL_V_3_6|CT_KERNEL_V_3_7|CT_KERNEL_V_3_8|CT_KERNEL_V_3_9|CT_KERNEL_V_3_10|CT_KERNEL_V_3_11|\
    CT_KERNEL_V_3_12|CT_KERNEL_V_3_13|CT_KERNEL_V_3_14|CT_KERNEL_V_3_15|CT_KERNEL_V_3_16|\
    CT_KERNEL_V_3_17|CT_KERNEL_V_3_18|CT_KERNEL_V_3_19|\
    CT_KERNEL_V_4_0|CT_KERNEL_V_4_1|CT_KERNEL_V_4_2|CT_KERNEL_V_4_3|CT_KERNEL_V_4_4|\
    CT_KERNEL_V_4_5|CT_KERNEL_V_4_6|CT_KERNEL_V_4_7|CT_KERNEL_V_4_8|CT_KERNEL_V_4_9|CT_KERNEL_V_4_10)
                                    replace CT_LINUX_${opt#CT_KERNEL_};;
    CT_LIBC_AVR_LIBC_V_1_8_0)       replace CT_AVR_LIBC_V_1_8_1;;
    CT_LIBC_AVR_LIBC_V_1_8_1)       replace CT_AVR_LIBC_V_1_8_1;;
    CT_LIBC_AVR_LIBC_V_2_0_0)       replace CT_AVR_LIBC_V_2_0_0;;
    CT_LIBC_GLIBC_V_2_12_1|CT_LIBC_GLIBC_V_2_12_2|CT_LIBC_GLIBC_V_2_13|CT_LIBC_GLIBC_V_2_14|\
    CT_LIBC_GLIBC_V_2_14_1|CT_LIBC_GLIBC_V_2_15|CT_LIBC_GLIBC_V_2_16_0|CT_LIBC_GLIBC_V_2_17|\
    CT_LIBC_GLIBC_V_2_18|CT_LIBC_GLIBC_V_2_19|CT_LIBC_GLIBC_V_2_20|CT_LIBC_GLIBC_V_2_21|\
    CT_LIBC_GLIBC_V_2_22|CT_LIBC_GLIBC_V_2_23|CT_LIBC_GLIBC_V_2_24|CT_LIBC_GLIBC_V_2_25)
                                    replace CT_GLIBC_${opt#CT_LIBC_GLIBC_};;
    CT_LIBC_GLIBC_LINARO_V_2_20)    replace CT_GLIBC_LINARO_V_2_20_2014_11;;
    CT_LIBC_MUSL_V_1_1_15|CT_LIBC_MUSL_V_1_1_16)
                                    replace CT_MUSL_${opt#CT_LIBC_MUSL_};;
    CT_LIBC_NEWLIB_V_1_17_0|CT_LIBC_NEWLIB_V_1_18_0|CT_LIBC_NEWLIB_V_1_19_0|CT_LIBC_NEWLIB_V_1_20_0|\
    CT_LIBC_NEWLIB_V_2_0_0|CT_LIBC_NEWLIB_V_2_1_0|CT_LIBC_NEWLIB_V_2_2_0|CT_LIBC_NEWLIB_V_2_3_0|\
    CT_LIBC_NEWLIB_V_2_4_0|CT_LIBC_NEWLIB_V_2_5_0)
                                    replace CT_NEWLIB_${opt#CT_LIBC_NEWLIB_};;
    CT_LIBC_NEWLIB_LINARO_V_2_1_0)  select_linaro NEWLIB; replace CT_NEWLIB_LINARO_V_2_1_0_2014;;
    CT_LIBC_NEWLIB_LINARO_V_2_2_0)  select_linaro NEWLIB; replace CT_NEWLIB_LINARO_V_2_2_0_2015;;
    CT_LIBELF_V_0_8_12)             replace CT_LIBELF_V_0_8_13;;
    CT_LIBELF_V_0_8_13)             replacement_for CT_LIBELF_V_0_8_12;;
    CT_M4_V_1_4_13|CT_M4_V_1_4_17)  replace CT_CT_M4_V_1_4_18;;
    CT_M4_V_1_4_18)                 replacement_for CT_M4_V_1_4_13 CT_M4_V_1_4_17;;
    CT_MPC_V_0_8_1)                 replace CT_MPC_V_0_8_2;;
    CT_MPC_V_0_8_2)                 replacement_for CT_MPC_V_0_8_1;;
    CT_MPC_V_1_0|CT_MPC_V_1_0_1|CT_MPC_V_1_0_2)
                                    replace CT_MPC_V_1_0_3;;
    CT_MPC_V_1_0_3)                 replacement_for CT_MPC_V_1_0 CT_MPC_V_1_0_1 CT_MPC_V_1_0_2;;
    CT_MPFR_V_2_4_0|CT_MPFR_V_2_4_1)
                                    replace CT_MPFR_V_2_4_2;;
    CT_MPFR_V_2_4_2)                replacement_for CT_MPFR_V_2_4_0 CT_MPFR_V_2_4_1;;
    CT_MPFR_V_3_0_0)                replace CT_MPFR_V_3_0_1;;
    CT_MPFR_V_3_0_1)                replacement_for CT_MPFR_V_3_0_0;;
    CT_MPFR_V_3_1_0|CT_MPFR_V_3_1_2|CT_MPFR_V_3_1_3|CT_MPFR_V_3_1_5)
                                    replace CT_MPFR_V_3_1_6;;
    CT_MPFR_V_3_1_6)                replacement_for CT_MPFR_V_3_1_0 CT_MPFR_V_3_1_2 CT_MPFR_V_3_1_3 CT_MPFR_V_3_1_5;;
    CT_STRACE_V_4_5_18|CT_STRACE_V_4_5_19)
                                    replace CT_STRACE_V_4_5_20;;
    CT_STRACE_V_4_5_20)             replacement_for CT_STRACE_V_4_5_18 CT_STRACE_V_4_5_19;;
    CT_LIBC_UCLIBC_NG_V_1_0_20|CT_LIBC_UCLIBC_NG_V_1_0_21|CT_LIBC_UCLIBC_NG_V_1_0_22)
                                    is_set && echo "CT_UCLIBC_USE_UCLIBC_NG_ORG=y"
                                    replace CT_UCLIBC_NG_V_1_0_25
                                    ;;
    CT_LIBC_UCLIBC_V_0_9_33_2)
                                    is_set && echo "CT_UCLIBC_USE_UCLIBC_ORG=y"
                                    replace CT_UCLIBC_V_0_9_33_2
                                    ;;
    CT_WINAPI_V_2_0_7|CT_WINAPI_V_2_0_7|CT_WINAPI_V_2_0_9)
                                    replace CT_MINGW_W64_V_V2_0_10;;
    CT_WINAPI_V_3_0_0)              replace CT_MINGW_W64_V_V3_0_0;;
    CT_WINAPI_V_3_1_0)              replace CT_MINGW_W64_V_V3_1_0;;
    CT_WINAPI_V_3_2_0)              replace CT_MINGW_W64_V_V3_2_0;;
    CT_WINAPI_V_3_3_0)              replace CT_MINGW_W64_V_V3_3_0;;
    CT_WINAPI_V_4_0_0|CT_WINAPI_V_4_0_1|CT_WINAPI_V_4_0_2|CT_WINAPI_V_4_0_3|\
    CT_WINAPI_V_4_0_4|CT_WINAPI_V_4_0_5|CT_WINAPI_V_4_0_6)
                                    replace CT_MINGW_W64_V_V4_0_6;;
    CT_WINAPI_V_5_0_0|CT_WINAPI_V_5_0_1)
                                    replace CT_MINGW_W64_V_V5_0_3;;

    # Misc
    CT_CLOOG_NEEDS_AUTORECONF)
        # Was unused in 1.23, just drop
        unset opt
        ;;
    CT_PATCH_SINGLE)
        # Internal selector in 1.23
        unset opt
        ;;
    CT_PATCH_BUNDLED_FALLBACK_LOCAL|CT_PATCH_LOCAL_FALLBACK_BUNDLED)
        warning_if_set "Fallback patch order has been removed"
        ;;
    CT_CC_GCC_TARGET_FINAL)
        warning_if_set "Option removed"
        ;;
    CT_COMPLIBS|CT_COMPLIBS_NEEDED|CT_CC_GCC_latest)
        # Internal selectors
        unset opt
        ;;
    esac

}

# Upgrade v1 -> v2: several packages had their config options renamed
# to leave only the relevant part - so that further upgrades of, say,
# GCC 6.5.0 to 6.6.0 do not result in config changes.
upgrade_v1()
{
    case "${opt}" in
    CT_ANDROID_NDK_V_R10E|CT_ANDROID_NDK_V_R11C|CT_ANDROID_NDK_V_R12B|\
    CT_ANDROID_NDK_V_R13B|CT_ANDROID_NDK_V_R14B|CT_ANDROID_NDK_V_R15C|\
    CT_ANDROID_NDK_V_R16B|CT_ANDROID_NDK_V_R17C)
        replace "${opt%[A-Z]}"
        ;;
    CT_AUTOMAKE_V_1_11_6|CT_AUTOMAKE_V_1_14_1|\
    CT_AUTOMAKE_V_1_15_1|CT_AUTOMAKE_V_1_16_1)
        replace "${opt%_[0-9]}"
        ;;
    CT_BINUTILS_LINARO_V_2_23_2_2013_10_4|CT_BINUTILS_LINARO_V_2_24_0_2014_11_2|\
    CT_BINUTILS_LINARO_V_2_25_0_2015_01_2)
        replace "${opt%_[0-9]_201[345]*}"
        ;;
    CT_BINUTILS_V_2_23_2|CT_BINUTILS_V_2_25_1|CT_BINUTILS_V_2_26_1|\
    CT_BINUTILS_V_2_28_1|CT_BINUTILS_V_2_29_1|CT_BINUTILS_V_2_31_1)
        replace "${opt%_[0-9]}"
        ;;
    CT_DTC_V_1_4_7)
        replace CT_DTC_V_1_4
        ;;
    CT_EXPAT_V_2_1_1|CT_EXPAT_V_2_2_6)
        replace "${opt%_[0-9]}"
        ;;
    CT_GCC_LINARO_V_4_8_2015_06|CT_GCC_LINARO_V_4_9_2017_01)
        replace "${opt%_201[57]*}"
        ;;
    CT_GCC_LINARO_V_5_5_2017_10|CT_GCC_LINARO_V_6_4_2018_05|\
    CT_GCC_LINARO_V_7_3_2018_05)
        replace "${opt%_[0-9]_201[78]*}"
        ;;
    CT_GCC_V_4_8_5|CT_GCC_V_4_9_4)
        replace "${opt%_[0-9]}"
        ;;
    CT_GCC_V_5_5_0|CT_GCC_V_6_5_0|CT_GCC_V_7_4_0|CT_GCC_V_8_2_0)
        replace "${opt%_[0-9]_[0-9]}"
        ;;
    CT_GDB_LINARO_V_7_3_2011_12|CT_GDB_LINARO_V_7_4_2012_06|CT_GDB_LINARO_V_7_5_2012_12|\
    CT_GDB_LINARO_V_7_7_2014_05|CT_GDB_LINARO_V_7_8_2014_09)
        replace "${opt%_201[57]*}"
        ;;
    CT_GDB_LINARO_V_7_6_1_2013_10|CT_GDB_LINARO_V_7_7_1_2014_06_1)
        replace "${opt%_[0-9]_201[345]*}"
        ;;

    CT_GDB_V_6_8A|CT_GDB_V_7_1A|CT_GDB_V_7_2A)
        replace "${opt%A}"
        ;;
    CT_GDB_V_7_0_1A)
        replace CT_GDB_V_7_0
        ;;
    CT_GDB_V_7_3_1|CT_GDB_V_7_4_1|CT_GDB_V_7_5_1|CT_GDB_V_7_6_1|CT_GDB_V_7_7_1|\
    CT_GDB_V_7_8_2|CT_GDB_V_7_9_1|CT_GDB_V_7_10_1|CT_GDB_V_7_11_1|CT_GDB_V_7_12_1|\
    CT_GDB_V_8_0_1|CT_GDB_V_8_1_1)
        replace "${opt%_[0-9]}"
        ;;
    CT_GLIBC_LINARO_V_2_20_2014_11)
        replace CT_GLIBC_LINARO_V_2_20
        ;;
    CT_GMP_V_4_3_2|CT_GMP_V_5_0_5|CT_GMP_V_5_1_3|CT_GMP_V_6_0_0A|CT_GMP_V_6_1_2)
        replace "${opt%_[0-9]*}"
        ;;
    CT_ISL_V_0_11_2|CT_ISL_V_0_12_2|CT_ISL_V_0_14_1|CT_ISL_V_0_16_1|CT_ISL_V_0_17_1)
        replace "${opt%_[0-9]}"
        ;;
    CT_LIBELF_V_0_8_13)
        replace CT_LIBELF_V_0_8
        ;;
    CT_LIBTOOL_V_2_4_6)
        replace CT_LIBTOOL_V_2_4
        ;;
    CT_M4_V_1_4_18)
        replace CT_M4_V_1_4
        ;;
    CT_MAKE_V_4_2_1)
        replace CT_MAKE_V_4_2
        ;;
    CT_MINGW_W64_V_V2_0_10|CT_MINGW_W64_V_V3_0_0|CT_MINGW_W64_V_V3_1_0|CT_MINGW_W64_V_V3_2_0|\
    CT_MINGW_W64_V_V3_3_0|CT_MINGW_W64_V_V4_0_6|CT_MINGW_W64_V_V5_0_3|CT_MINGW_W64_V_V6_0_0)
        replace "${opt%_[0-9]}"
        ;;
    CT_MPC_V_0_8_2|CT_MPC_V_1_0_3|CT_MPC_V_1_1_0)
        replace "${opt%_[0-9]}"
        ;;
    CT_MPFR_V_2_4_2|CT_MPFR_V_3_0_1|CT_MPFR_V_3_1_6|CT_MPFR_V_4_0_1)
        replace "${opt%_[0-9]}"
        ;;
    CT_NEWLIB_LINARO_V_2_1_0_2014|CT_NEWLIB_LINARO_V_2_2_0_2015)
        replace "${opt%_[0-9]_201[345]*}"
        ;;
    CT_NEWLIB_V_1_17_0|CT_NEWLIB_V_1_18_0|CT_NEWLIB_V_1_19_0|CT_NEWLIB_V_1_20_0|CT_NEWLIB_V_2_0_0|\
    CT_NEWLIB_V_2_1_0|CT_NEWLIB_V_2_2_0|CT_NEWLIB_V_2_3_0|CT_NEWLIB_V_2_4_0|CT_NEWLIB_V_2_5_0|\
    CT_NEWLIB_V_3_0_0)
        replace "${opt%_[0-9]}"
        ;;

    CT_CLOOG_HAS_WITH_GMP_ISL_OSL|CT_CLOOG_0_18_or_later|CT_CLOOG_0_18_or_older|\
    CT_CLOOG_REQUIRE_0_18_or_later|CT_CLOOG_REQUIRE_0_18_or_older|\
    CT_CLOOG_REQUIRE_later_than_0_18|CT_CLOOG_REQUIRE_older_than_0_18|\
    CT_CLOOG_later_than_0_18|CT_CLOOG_older_than_0_18|CT_GCC_REQUIRE_4_9_2_or_later|\
    CT_GCC_REQUIRE_4_9_2_or_older|CT_GCC_REQUIRE_later_than_4_9_2|\
    CT_GCC_REQUIRE_older_than_4_9_2|CT_GCC_4_9_2_or_later|CT_GCC_4_9_2_or_older|\
    CT_GCC_BUG_61144|CT_GCC_later_than_4_9_2|CT_GCC_older_than_4_9_2)
        unset opt # No longer used auto-selectors
        ;;
    esac
}

# Main upgrade driver. One version at a time, read line by line, interpret
# the options and replace anything that needs replacing.
cp "${CFGFILE}" "${CFGFILE}.before-upgrade"
v=${CT_CONFIG_VERSION}
input="${CFGFILE}"
while [ "${v}" -lt "${CT_CONFIG_VERSION_CURRENT}" ]; do
    vn=$[ v + 1 ]
    info "Upgrading v${v} to v${vn}"
    {
        while read ln; do
            unset val
            q=
            case "${ln}" in
                CT_CONFIG_VERSION_CURRENT=*|CT_CONFIG_VERSION=*)
                    continue
                    ;;
                CT_*=*)
                    opt=${ln%%=*}
                    val=${ln#*=}
                    case "${val}" in
                    \"*\")
                        val="${val%\"}"
                        val="${val#\"}"
                        q=\"
                        ;;
                    esac
                    ;;
                "# CT_"*" is not set")
                    opt=${ln#* }
                    opt=${opt%% *}
                    ;;
                *)
                    echo "${ln}"
                    continue
                    ;;
            esac
            upgrade_v${v}
            # Emit the option(s)
            if [ x${opt+set} = x ]; then
                continue
            elif [ x${val+set} = x ]; then
                echo "# ${opt} is not set"
            else
                echo "${opt}=${q}${val}${q}"
            fi
        done
        echo "CT_CONFIG_VERSION=\"${vn}\""
        echo "CT_CONFIG_VERSION_CURRENT=\"${CT_CONFIG_VERSION_CURRENT}\""
    } < "${input}" > "${CFGFILE}.${vn}"
    unset opt
    v=${vn}
    rm -f "${input}"
    input="${CFGFILE}.${vn}"
    # Reload the next input so that the upgrade function can rely on other CT_xxx variables,
    # not just the currently processed variable.
    # TBD clean the environment first to avoid any stale values
    . "${input}"
    # Ideally, we'd do 'ct-ng olddefconfig' after each step with the appropriate
    # Kconfig so that the next step would be able to use auto-set values from the
    # previous step. However, that would require us to keep archived config/ trees
    # from every config file version, which is not practical. So, I decided to defer
    # this until it is actually needed. Even then, it is probably sufficient to only
    # keep the versions where there is such a dependency.
done
mv "${CFGFILE}.${CT_CONFIG_VERSION_CURRENT}" "${CFGFILE}"
cp "${CFGFILE}" "${CFGFILE}.before-olddefconfig"
cat >&2 <<EOF

Done. The original '${CFGFILE}' has been saved as '${CFGFILE}.before-upgrade'.
Will now run through 'ct-ng olddefconfig'.  The intermediate configuration (after the upgrade script,
but before running 'ct-ng olddefconfig') has been saved as '${CFGFILE}.before-olddefconfig'.
EOF
