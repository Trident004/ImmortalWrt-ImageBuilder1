#!/bin/bash
# Log file for debugging
source shell/apk-custom-packages.sh
echo "第三方APK软件包: $CUSTOM_PACKAGES"
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
# yml 传入的路由器型号 PROFILE
echo "Building for profile: $PROFILE"
# yml 传入的固件大小 ROOTFS_PARTSIZE
echo "Building for ROOTFS_PARTSIZE: $ROOTFS_PARTSIZE"

echo "Create pppoe-settings"
mkdir -p  /home/build/immortalwrt/files/etc/config

# 创建pppoe配置文件 yml传入环境变量ENABLE_PPPOE等 写入配置文件 供99-custom.sh读取
cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

echo "cat pppoe-settings"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings

if [ -z "$CUSTOM_PACKAGES" ]; then
  echo "⚪️ 未选择 任何第三方软件包"
else
  # ============= 同步第三方插件库==============
  # 同步第三方软件仓库run/apk
  echo "🔄 正在同步第三方软件仓库 Cloning run file repo..."
  git clone --depth=1 https://github.com/wukongdaily/apk.git /tmp/store-apk-repo

  # 拷贝 run/arm64 下所有 run 文件和apk文件 到 extra-packages 目录
  mkdir -p /home/build/immortalwrt/extra-packages
  cp -r /tmp/store-apk-repo/run/arm64/* /home/build/immortalwrt/extra-packages/

  echo "✅ Run files copied to extra-packages:"
  # 解压并拷贝apk到packages目录
  sh shell/apk-prepare-packages.sh
  ls -lah /home/build/immortalwrt/packages/
fi



# ================== 🌟 新增：注入自定义编译的 APK 资产 🌟 ==================
echo "$(date '+%Y-%m-%d %H:%M:%S') - 📥 正在下载自定义编译的 APK 组件..."
mkdir -p /home/build/immortalwrt/packages/

# 定义专属 APK 下载直链 (已剔除重复项)
CUSTOM_APKS=(
    "https://github.com/ShimizuKawasaki/nas-packages-luci-actions/releases/download/auto-build-28369299848-1/luci-app-quickstart-0.12.7-r1.apk"
    "https://github.com/ShimizuKawasaki/nas-packages-luci-actions/releases/download/auto-build-28369299848-1/luci-app-store-0.2.0-r3.apk"
    "https://github.com/ShimizuKawasaki/nas-packages-luci-actions/releases/download/auto-build-28369299848-1/luci-i18n-quickstart-zh-cn-26.176.34044.f2b69d3.apk"
    "https://github.com/ShimizuKawasaki/nas-packages-luci-actions/releases/download/auto-build-28369299848-1/luci-lib-taskd-1.0.25.apk"
    "https://github.com/ShimizuKawasaki/nas-packages-luci-actions/releases/download/auto-build-28369299848-1/luci-lib-xterm-4.18.0.apk"
    "https://github.com/ShimizuKawasaki/nas-packages-luci-actions/releases/download/auto-build-28369299848-1/quickstart-0.13.0-r1.apk"
    "https://github.com/ShimizuKawasaki/nas-packages-luci-actions/releases/download/auto-build-28369299848-1/taskd-1.0.3-r2.apk"
)

# 循环静默下载到 ImageBuilder 的本地安装包池
for url in "${CUSTOM_APKS[@]}"; do
    echo "下载: $(basename "$url")"
    wget -q -P /home/build/immortalwrt/packages/ "$url"
done

# 🌟 核心修复补丁：将 GitHub 错误转义的 . 号手动改回原生支持的 ~ 号
mv /home/build/immortalwrt/packages/luci-i18n-quickstart-zh-cn-26.176.34044.f2b69d3.apk /home/build/immortalwrt/packages/luci-i18n-quickstart-zh-cn-26.176.34044~f2b69d3.apk


# 让 ImageBuilder 重新生成本地软件源索引 (确保 APK 被系统识别)
make package_index
echo "✅ 自定义 APK 下载并索引完成！"
# ====================================================================

# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建固件..."
# ============= imm仓库内的插件==============
# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES=""
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES openssh-sftp-server"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-theme-argon"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"



# 判断是否需要编译 Docker 插件
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "Adding package: luci-i18n-dockerman-zh-cn"
fi
# 文件管理器
PACKAGES="$PACKAGES luci-i18n-filemanager-zh-cn"

#GEO 基础工具包
PACKAGES="$PACKAGES v2ray-geoip"
PACKAGES="$PACKAGES v2ray-geosite"

# ======== shell/custom-packages.sh =======
# ================= 🌟 声明打包刚刚下载的自定义组件 🌟 =================
PACKAGES="$PACKAGES luci-app-quickstart"
PACKAGES="$PACKAGES luci-i18n-quickstart-zh-cn"
PACKAGES="$PACKAGES quickstart"

PACKAGES="$PACKAGES luci-app-store"
PACKAGES="$PACKAGES luci-lib-taskd"
PACKAGES="$PACKAGES luci-lib-xterm"
PACKAGES="$PACKAGES taskd"

# 强烈建议补充 luci-compat，确保 iStore 旧版界面能正常挂载到 LuCI 菜单
# ====================================================================
# 合并imm仓库以外的第三方插件
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"

# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"





make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
