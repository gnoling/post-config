#!/usr/bin/env bash
#
# Post-installation Configuration Scripts
#
# First stage script for OVH dedicated servers
# - Get distro name
# - Check server is an OVH dedicated server
# - Download and execute appropriate scripts


# OVH dedicated servers are expected to run this script as "script"
EXPECT_SCRIPT_PATH="/tmp/script"

# Remote scripts URI root
URI_ROOT="https://raw.githubusercontent.com/"\
"gnoling/post-config/master/"

# OS Release file
OSR_FILE="/etc/os-release"

# Secondary script file
NEXT_FILE=/tmp/next

# Error codes
ERR_OK=0
ERR_NOT_DEDICATED=1
ERR_OSR_FILE=2
ERR_DISTRO=3
ERR_TRAVIS=255


check_ovh_dedicated () {
  if ! [[ "${0}" == $EXPECT_SCRIPT_PATH ]]; then
    err "unexpected script path ${0}: Not a dedicated server."
    exit $ERR_NOT_DEDICATED
  fi
}


get_distro () {
  if ! [[ -r $OSR_FILE ]]; then
    err "cannot access $OSR_FILE: No such file."
    exit $ERR_OSR_FILE
  fi
  DISTRO=$(sed -n '/^ID=/s///p' /etc/os-release)
}


exec_remote () {
  # 'raw.githubusercontent.com' domain may not clear HTTPS CA checks
  bash <(wget --no-check-certificate -O - $URI_ROOT$1)
  return $?
}


cfg_debian () {
  exec_remote "scripts/ovh/ovh_debian"
  exec_remote "scripts/debian/deb_host"
  exec_remote "scripts/debian/deb_lxc"
}


run_tests () {
  err "test error message"
  exec_remote "tests/returns_zero"
  local retval=$?
  if ! [[ $retval -eq 0 ]]; then
    exit $ERR_TRAVIS
  fi
  exec_remote "tests/returns_one"
  local retval=$?
  if ! [[ $retval -eq 1 ]]; then
    err "Returned $? instead of 1."
    exit $ERR_TRAVIS
  fi
  exit 0
}


main () {
  get_distro

  if [[ $TRAVIS ]]; then
    run_tests
    exit $ERR_OK
  fi

  check_ovh_dedicated

  case "$DISTRO" in
    debian)
      cfg_debian
      ;;

    *)
      err "unsupported distribution: $DISTRO"
      exit $ERR_DISTRO
      ;;
  esac
  touch postconfig_completed
  exit 1
}


err() { cat <<< "${0##*/}: $@" 1>&2; }


main
