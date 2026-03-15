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
# v3 最终版修复（共5项）
# ============================================

# 修复1：wireless-mtk.js 直接文件覆盖（不用 uci-defaults，不可靠）
# luci-app-mtwifi-cfg 安装后不会自动替换 wireless.js
# 必须在编译阶段直接把 wireless-mtk.js 放到正确位置
# 先找到源码中 wireless-mtk.js 的位置
MTWIFI_JS=$(find . -name "wireless-mtk.js" -path "*/luci-app-mtwifi-cfg/*" 2>/dev/null | head -1)
if [ -n "$MTWIFI_JS" ]; then
    mkdir -p files/www/luci-static/resources/view/network/
    cp "$MTWIFI_JS" files/www/luci-static/resources/view/network/wireless.js
    echo ">>> wireless-mtk.js 已复制到 files/ 目录，将直接覆盖标准 wireless.js"
else
    echo ">>> 警告：未找到 wireless-mtk.js，尝试备用方案"
    # 备用方案：用 uci-defaults 脚本在首次启动时替换
    mkdir -p files/etc/uci-defaults
    cat > files/etc/uci-defaults/99-fix-mtwifi-cfg << 'FIXEOF'
#!/bin/sh
if [ -f /rom/usr/share/luci-app-mtwifi-cfg/wireless-mtk.js ]; then
    cp /rom/usr/share/luci-app-mtwifi-cfg/wireless-mtk.js /www/luci-static/resources/view/network/wireless.js
fi
exit 0
FIXEOF
    chmod +x files/etc/uci-defaults/99-fix-mtwifi-cfg
fi

# 修复2：预下载 Mihomo Meta 内核（aarch64 linux-arm64 v1.19.0）
mkdir -p files/etc/openclash/core
curl -L --retry 3 --connect-timeout 60 https://github.com/MetaCubeX/mihomo/releases/download/v1.19.0/mihomo-linux-arm64-v1.19.0.gz -o /tmp/mihomo.gz
if [ -f /tmp/mihomo.gz ]; then
    gunzip /tmp/mihomo.gz
    mv /tmp/mihomo files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    echo ">>> Mihomo Meta v1.19.0 内核已预装"
else
    echo ">>> 错误：Mihomo 下载失败！"
    exit 1
fi

# 修复3：OpenClash 默认启用 Meta 内核 + 自启动
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/98-openclash-defaults << 'OCEOF'
#!/bin/sh
uci set openclash.config.enable='1'
uci set openclash.config.en_mode='clash_meta'
uci commit openclash
/etc/init.d/openclash enable
exit 0
OCEOF
chmod +x files/etc/uci-defaults/98-openclash-defaults

# 修复4：默认 WiFi 加密
cat > files/etc/uci-defaults/97-wifi-defaults << 'WIFIEOF'
#!/bin/sh
uci set wireless.default_MT7981_1_1.encryption='sae-mixed'
uci set wireless.default_MT7981_1_1.key='5df375fb'
uci set wireless.default_MT7981_1_1.ssid='CMCC-tdqy'
uci set wireless.default_MT7981_1_2.encryption='sae-mixed'
uci set wireless.default_MT7981_1_2.key='5df375fb'
uci set wireless.default_MT7981_1_2.ssid='CMCC-tdqy-5G'
uci commit wireless
exit 0
WIFIEOF
chmod +x files/etc/uci-defaults/97-wifi-defaults

# 修复5：默认 LAN IP 192.168.10.1
if ! grep -q "192.168.10.1" package/base-files/files/bin/config_generate 2>/dev/null; then
    sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate
fi