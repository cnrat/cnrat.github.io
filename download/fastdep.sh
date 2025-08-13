#!/usr/bin/env bash

[ -t 0 ] && tput civis && stty -echo

PRCE_SRC_URL='https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.zip'
SHADOWSOCKS_SRC_URL='https://status.nezumi.moe/download/shadowsocks-libev-ne-master.zip'

COLOR_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_BLUE='\033[0;34m'

log()   { printf "%b[%s] %s%b\n" "$C_BLUE" "$(date '+%F %T')" "$*" "$COLOR_RESET"; }
info()  { printf "%b[%s] [INFO] %s%b\n" "$C_GREEN"  "$(date '+%F %T')" "$*" "$COLOR_RESET"; }
warn()  { printf "%b[%s] [WARN] %s%b\n" "$C_YELLOW" "$(date '+%F %T')" "$*" "$COLOR_RESET"; }
error() { printf "%b[%s] [ERRO] %s%b\n" "$C_RED"    "$(date '+%F %T')" "$*" "$COLOR_RESET"; }

pkg_install() {
    local pkgs=("$@")
    local tries=0
    until dnf -y --setopt=tsflags=nodocs install "${pkgs[@]}"; do
        tries=$((tries+1))
        if (( tries >= 3 )); then
        error "install failed: ${pkgs[*]}"
        return 1
        fi
        warn "install failed: retry (${tries}/3)..."
        sleep 2
    done
}

pkg_gp_install() {
    local pkgs=("$@")
    local tries=0
    until dnf -y --setopt=tsflags=nodocs group install "${pkgs[@]}"; do
        tries=$((tries+1))
        if (( tries >= 3 )); then
        error "install failed: ${pkgs[*]}"
        return 1
        fi
        warn "install failed: retry (${tries}/3)..."
        sleep 2
    done
}

pkg_remove() {
    local pkgs=("$@")
    local tries=0
    until dnf -y --setopt=tsflags=nodocs remove "${pkgs[@]}"; do
        tries=$((tries+1))
        if (( tries >= 3 )); then
        error "remove failed: ${pkgs[*]}"
        return 1
        fi
        warn "remove failed: retry (${tries}/3)..."
        sleep 2
    done
}

pkg_updateall() {
    local tries=0
    until dnf -y --setopt=tsflags=nodocs update; do
        tries=$((tries+1))
        if (( tries >= 3 )); then
        error "update failed: all"
        return 1
        fi
        warn "update failed: retry (${tries}/3)..."
        sleep 2
    done
}

log "Permanently redirecting shell history and selected system logs to /dev/null to prevent further logging."
{
  rm -rf /root/.bash_history && ln -s /dev/null /root/.bash_history
  rm -rf /var/log/lastlog && ln -s /dev/null /var/log/lastlog
  rm -rf /var/log/dmesg && ln -s /dev/null /var/log/dmesg
  rm -rf /var/log/cron && ln -s /dev/null /var/log/cron
  rm -rf /var/log/boot.log && ln -s /dev/null /var/log/boot.log
  rm -rf /var/log/maillog && ln -s /dev/null /var/log/maillog
  rm -rf /var/log/wtmp && ln -s /dev/null /var/log/wtmp
  rm -rf /var/log/yum.log && ln -s /dev/null /var/log/yum.log
}>>/var/log/FastDep.log 2>&1

log "Removing all cockpit-related packages from the system."
{
    pkg_remove cockpit*
}>>/var/log/FastDep.log 2>&1

log "Adding the ELRepo repository by importing its GPG key and installing the release package."
{
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-v2-elrepo.org && \
    pkg_install https://www.elrepo.org/elrepo-release-10.el10.elrepo.noarch.rpm
}>>/var/log/FastDep.log 2>&1

log "Enabling ELRepo kernel repository, installing the latest mainline kernel, and setting it as the default boot option."
{
    yum-config-manager --enable elrepo-kernel
    pkg_install kernel-ml kernel-ml-devel && \
    grub2-mkconfig && grub2-set-default 0
}>>/var/log/FastDep.log 2>&1

log "Switching to iptables/ipset firewall by installing required services, applying predefined rules, and disabling firewalld."
{
    pkg_install iptables-services ipset-service net-tools && \
    wget -qO /etc/sysconfig/iptables https://gist.githubusercontent.com/cnrat/11ec6a57cf0eb8f6f7a120dbac2df1f2/raw/iptables && \
    systemctl stop firewalld && systemctl disable firewalld && systemctl enable iptables && \
    systemctl start iptables && systemctl enable ipset && systemctl start ipset
}>>/var/log/FastDep.log 2>&1

log "Installing runonce."
{
  wget --no-check-certificate -O /usr/bin/runonce https://gist.githubusercontent.com/cnrat/5c1787c4be9b21d1a56a2643956839c5/raw/runonce && chmod a+x /usr/bin/runonce
}>>/var/log/FastDep.log 2>&1

log "Installing additional repositories, development tools, and security/monitoring utilities, then enabling haveged and applying custom Fail2ban configuration."
{
    pkg_install epel-release
    pkg_gp_install "Development Tools"
    pkg_install btop jq iptraf iftop bind-utils haveged fail2ban
    systemctl enable haveged && systemctl start haveged
    wget -qO /root/.vimrc https://gist.githubusercontent.com/cnrat/11ec6a57cf0eb8f6f7a120dbac2df1f2/raw/vimrc
    wget https://gist.githubusercontent.com/cnrat/11ec6a57cf0eb8f6f7a120dbac2df1f2/raw/f2bconf.zip && \
    unzip f2bconf.zip -d / && \
    rm -rf f2bconf.zip
}>>/var/log/FastDep.log 2>&1

log "Building and installing PCRE from source after installing Development Tools."
{
    wget -q ${PRCE_SRC_URL} && \
    unzip "$(basename "${PRCE_SRC_URL}")" && \
    cd "$(basename "${PRCE_SRC_URL}" .zip)" && \
    chmod a+x configure && \
    ./configure && \
    make && \
    make install && \
    cd ~ && rm -rf "$(basename "${PRCE_SRC_URL}" .zip)"*
}>>/var/log/FastDep.log 2>&1

log "Building and installing Shadowsocks from source with adjusted compiler flags, then cleaning up."
{
    wget -q ${SHADOWSOCKS_SRC_URL} && \
    unzip "$(basename "${SHADOWSOCKS_SRC_URL}")" && \
    cd "$(basename "${SHADOWSOCKS_SRC_URL}" -master.zip)" && \
    chmod a+x configure && \
    ./configure && \
    make CFLAGS+='-Wno-error=stringop-truncation -Wno-stringop-truncation -Wno-error=format-overflow -Wno-format-overflow -Wno-error=format-truncation -Wno-format-truncation -fcommon' && \
    make install && \
    cd ~ && rm -rf "$(basename "${SHADOWSOCKS_SRC_URL}" -master.zip)"*
}>>/var/log/FastDep.log 2>&1

log 'Making script run after reboot.'
{
  wget --no-check-certificate -O /root/runlater_for_centos7.sh https://gist.githubusercontent.com/cnrat/5c1787c4be9b21d1a56a2643956839c5/raw/runlater_for_centos7.sh && chmod a+x /root/runlater_for_centos7.sh
  runonce /root/runlater_for_centos7.sh
}>>/var/log/FastDep.log 2>&1

log 'Rebooting system in 3 seconds... '
{
  sleep 3
  reboot
}>>/var/log/FastDep.log 2>&1

[ -t 0 ] && stty echo && tput cnorm