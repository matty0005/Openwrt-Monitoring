#!/bin/sh
# === Please set the Home server IP ============
HOMESERVER="10.0.5.5"

# === Installing CollectD, Prometheus, and IPTMON. Also Speedtest.sh =============
 echo 'Updating software packages'
 opkg update
 
 echo 'Installing Nano, netperf and sftp-server'
 opkg install nano netperf openssh-sftp-server
 
 echo 'Installing Nano and CollectD Software on Router'
 opkg install collectd collectd-mod-iptables collectd-mod-ping luci-app-statistics collectd-mod-dhcpleases 
 
 echo 'Installing Prometheus on Router'
 opkg install  prometheus prometheus-node-exporter-lua prometheus-node-exporter-lua-nat_traffic prometheus-node-exporter-lua-openwrt prometheus-node-exporter-lua-uci_dhcp_host prometheus-node-exporter-lua-wifi prometheus-node-exporter-lua-wifi_stations
 
 echo 'Installing IPTMON 1.6.1'
 wget https://github.com/oofnikj/iptmon/releases/download/v0.1.6/iptmon_0.1.6-1_all.ipk -O /root/iptmon_0.1.6-1_all.ipk
 opkg install /root/iptmon_0.1.6-1_all.ipk
 
 ipt=$(uci show dhcp.@dnsmasq[0].dhcpscript | grep "iptmon")
if [[ -z "$ipt" ]]; then
  echo "Adding iptmon to DHCPScript option"
        uci set dhcp.@dnsmasq[0].dhcpscript=/usr/sbin/iptmon
        uci commit
        elif [[ -n "$ipt" ]]; then
  echo "IPTMon was found, no changes made to DHCP"
fi
 
 echo 'Copy shell scripts Speedtest.sh and wanip Script from Github/benisai/Openwrt-Monitoring/Router/'
 wget https://raw.githubusercontent.com/benisai/Openwrt-Monitoring/main/Router/speedtest.sh -O /usr/bin/speedtest.sh
 wget https://raw.githubusercontent.com/benisai/Openwrt-Monitoring/main/Router/wanip.sh -O /usr/bin/wanip.sh
 
 echo 'Add speedtest.sh to crontab'
 C=$(crontab -l | grep "speedtest.sh")
if [[ -z "$C" ]]; then
   echo "Adding Speedtest.sh to crontab"
   crontab -l | { cat; echo "0 0 * * * /usr/bin/speedtest.sh > /tmp/speedtest.out"; } | crontab -
   crontab -l | { cat; echo "10 0 * * * rm -rf /tmp/speedtest.out"; } | crontab -
   elif [[ -n "$C" ]]; then
   echo "speedtest.sh was found in crontab"
fi

 
# === Copying nat_traffic.lua and app-statistics Files from GIT =============
 echo 'Copying nat_traffic.lua from /benisai/Openwrt-Monitoring/nat_traffic.lua'
 wget https://raw.githubusercontent.com/benisai/Openwrt-Monitoring/main/Router/nat_traffic.lua -O /usr/lib/lua/prometheus-collectors/nat_traffic.lua
 echo 'Copying luci_statistics from /benisai/Openwrt-Monitoring/luci_statistics'
 wget https://raw.githubusercontent.com/benisai/Openwrt-Monitoring/main/Router/luci_statistics -O /etc/config/luci_statistics
 echo 'Copying speedtest.lua from /benisai/Openwrt-Monitoring/Router/speedtest.lua'
 wget https://raw.githubusercontent.com/benisai/Openwrt-Monitoring/main/Router/speedtest.lua -O /usr/lib/lua/prometheus-collectors/speedtest.lua
 echo 'Copying wanip.lua from /benisai/Openwrt-Monitoring/Router/wanip.lua'
 wget https://raw.githubusercontent.com/benisai/Openwrt-Monitoring/main/Router/wanip.lua -O /usr/lib/lua/prometheus-collectors/wanip.lua

 
# === Setting up app-statistics and prometheus configs =============
 echo 'updating prometheus config from loopback to lan'
 sed -i 's/loopback/lan/g'  /etc/config/prometheus-node-exporter-lua

# === Updating CollectD export ip ==============
 echo 'updating luci_statistics server export config to "${HOMESERVER}"'
 sed -i "s/10.0.5.5/${HOMESERVER}/g"  /etc/config/luci_statistics

# === Setting up DNS ===========
L=$(uci show dhcp.lan.dhcp_option | grep "$HOMESERVER")
if [[ -z "$L" ]]; then
  echo "Adding $HOMESERVER DNS entry to LAN Interface"
  uci add_list dhcp.lan.dhcp_option="6,${HOMESERVER}"
  uci commit dhcp
elif [[ -n "$L" ]]; then
  echo "${HOMESERVER} DNS was found, no changes to DNS"
fi

# === Setting Services to enable and restarting Services =============
 echo 'restarting services'
 /etc/init.d/luci_statistics enable
 /etc/init.d/collectd enable
 /etc/init.d/collectd restart
 /etc/init.d/prometheus-node-exporter-lua restart
 /etc/init.d/dnsmasq restart

# === 
echo 'You should restart the router now for these changes to take effect...'
