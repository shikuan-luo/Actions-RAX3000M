#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# 修改openwrt登陆地址,把下面的 192.168.10.1 修改成你想要的就可以了
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 修改子网掩码
#sed -i 's/255.255.255.0/255.255.0.0/g' package/base-files/files/bin/config_generate

# 修改主机名字，把 RAX3000M 修改你喜欢的就行（不能纯数字或者使用中文）
sed -i 's/ImmortalWrt/RAX3000M/g' package/base-files/files/bin/config_generate

# Enable wifi
# sed -i 's/.disabled=1/.disabled=0/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh

# echo "修改wifi名称"
# sed -i "s/OpenWrt/$wifi_name/g" package/kernel/mac80211/files/lib/wifi/mac80211.sh

# Set Wifi SSID and Password
# sed -i 's/.ssid=OpenWrt/.ssid=Tomato24/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
# sed -i 's/.encryption=none/.encryption=psk-mixed/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
# sed -i '/set\ wireless.default_radio${devidx}.encryption=psk-mixed/a set\ wireless.default_radio${devidx}.key=Psn@2416' package/kernel/mac80211/files/lib/wifi/mac80211.sh

# 设置密码为空（安装固件时无需密码登陆，然后自己修改想要的密码）
# sed -i "/CYXluq4wUazHjmCDBCqXF/d" package/lean/default-settings/files/zzz-default-settings

# Set default root password
# sed -i 's/root::0:0:99999:7:::/root:$1$kWRCl0Y2$7JL\/jLAF1xoVIiIMdTO5f.:16788:0:99999:7:::/g' package/base-files/files/etc/shadow

# 修改默认主题Modify default THEME
# sed -i 's/luci-theme-bootstrap/luci-theme-atmaterial_new/g' ./feeds/luci/collections/luci/Makefile

##-----------------Add OpenClash dev core------------------
curl -sL -m 30 --retry 2 https://raw.githubusercontent.com/vernesong/OpenClash/core/master/dev/clash-linux-arm64.tar.gz -o /tmp/clash.tar.gz
tar zxvf /tmp/clash.tar.gz -C /tmp >/dev/null 2>&1
chmod +x /tmp/clash >/dev/null 2>&1
mkdir -p feeds/luci/applications/luci-app-openclash/root/etc/openclash/core
mv /tmp/clash feeds/luci/applications/luci-app-openclash/root/etc/openclash/core/clash >/dev/null 2>&1
rm -rf /tmp/clash.tar.gz >/dev/null 2>&1

##-----------------Add OpenClash Meta (Mihomo) core------------------
MIHOMO_VERSION=$(curl -sL https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -n "$MIHOMO_VERSION" ]; then
  curl -sL -m 60 --retry 2 "https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-arm64-${MIHOMO_VERSION}.gz" -o /tmp/mihomo.gz
  gzip -d /tmp/mihomo.gz >/dev/null 2>&1
  chmod +x /tmp/mihomo >/dev/null 2>&1
  mv /tmp/mihomo feeds/luci/applications/luci-app-openclash/root/etc/openclash/core/clash_meta >/dev/null 2>&1
  echo "Mihomo Meta core ${MIHOMO_VERSION} (linux-arm64) installed."
else
  echo "WARNING: Failed to get Mihomo version, Meta core not installed!"
fi

##-----------------Manually set CPU frequency for MT7981B-----------------
sed -i '/"mediatek"\/\*|\"mvebu"\/\*/{n; s/.*/\tcpu_freq="1.3GHz" ;;/}' package/emortal/autocore/files/generic/cpuinfo

# ============================================
# 以下为 v2 修正版新增的修复
# ============================================

# 修复1：mtwifi-cfg 前端 wireless.js 替换
# luci-app-mtwifi-cfg 安装后不会自动替换标准 wireless.js
# 导致 WiFi 加密前端只显示"无加密"
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-fix-mtwifi-cfg << 'FIXEOF'
#!/bin/sh
if [ -f /rom/usr/share/luci-app-mtwifi-cfg/wireless-mtk.js ]; then
    cp /rom/usr/share/luci-app-mtwifi-cfg/wireless-mtk.js /www/luci-static/resources/view/network/wireless.js
fi
exit 0
FIXEOF
chmod +x files/etc/uci-defaults/99-fix-mtwifi-cfg

# 修复3：OpenClash 默认启用 Meta 内核 + 自启动
cat > files/etc/uci-defaults/98-openclash-defaults << 'OCEOF'
#!/bin/sh
uci set openclash.config.enable='1'
uci set openclash.config.en_mode='clash_meta'
uci commit openclash
/etc/init.d/openclash enable
exit 0
OCEOF
chmod +x files/etc/uci-defaults/98-openclash-defaults