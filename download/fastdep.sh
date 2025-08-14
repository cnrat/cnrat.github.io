#!/usr/bin/env bash

[ -t 0 ] && tput civis && stty -echo

PRCE_SRC_URL='https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.zip'
SHADOWSOCKS_SRC_URL='https://status.nezumi.moe/download/shadowsocks-libev-ne-master.zip'

C_DEFAULT='\033[0m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_BLUE='\033[0;34m'

log()   { printf "%b[%s] [LOG] %s%b\n" "$C_DEFAULT"     "$(date '+%F %T')" "$*" "$C_DEFAULT"; }
info()  { printf "%b[%s] [INF] %s%b\n" "$C_BLUE"        "$(date '+%F %T')" "$*" "$C_DEFAULT"; }
warn()  { printf "%b[%s] [WRN] %s%b\n" "$C_YELLOW"      "$(date '+%F %T')" "$*" "$C_DEFAULT"; }
error() { printf "%b[%s] [ERR] %s%b\n" "$C_RED"         "$(date '+%F %T')" "$*" "$C_DEFAULT"; }

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

log "Installing additional repositories."
{
    pkg_install epel-release
}>>/var/log/FastDep.log 2>&1

log "Installing development tools."
{
    pkg_gp_install "Development Tools"
}>>/var/log/FastDep.log 2>&1

log "Installing security/monitoring utilities."
{
    pkg_install btop jq iptraf iftop bind-utils haveged sqlite3 ipcalc
    systemctl enable haveged && systemctl start haveged
    wget -qO /root/.vimrc https://gist.githubusercontent.com/cnrat/11ec6a57cf0eb8f6f7a120dbac2df1f2/raw/vimrc
    wget -qO /etc/profile.d/neconsole.sh "https://gist.githubusercontent.com/cnrat/5714f54daa7620e081c120d5072ccff3/raw/neconsole.sh?rnd=$(date +%s)"
}>>/var/log/FastDep.log 2>&1

log "Installing fail2ban, then enabling haveged and applying custom Fail2ban configuration." 
{
    pkg_install fail2ban
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

[ -t 0 ] && stty echo && tput cnorm