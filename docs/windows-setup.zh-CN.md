# Windows 构建指南

## 工具

安装或选择工具链：Flutter3.47.5（随附Dart3.13.4）、JDK21、Android SDK Platform36/Build Tools36.0.0/Platform Tools、NDK28.2.13676358、Android CMake3.22.1。主机C++测试需要CMake和C++17编译器（例如Visual Studio的桌面C++组件）。具体版本也见toolchain.versions.json。

SDK是开发工具集，JDK用于Java构建，Gradle由工程wrapper管理，NDK/CMake编译原生C++。PATH是终端查找命令的目录列表。无需为了本项目覆盖其他工程的全局Java/PATH。

## 本机会话配置

可以直接把已安装的Flutter/JDK/Android工具配置到当前终端。也可建立ignored `.local/toolchain.json`供`tools/activate.ps1`使用，JSON包含四个真实绝对目录字符串：flutter、androidSdk、jdk、cmakeBin。不要将本机配置提交到仓库。

```powershell
. ./tools/activate.ps1
flutter --version
dart --version
java -version
flutter doctor -v
```

脚本仅修改当前PowerShell进程。缺少配置或目录不存在时，核对实际安装位置；不要照抄其他电脑路径。通过Android Studio SDK Manager或官方命令行工具管理SDK组件；新的SDK许可需阅读后自行同意。

## 构建与回归

```powershell
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter analyze
flutter test
cmake -S native -B build/dsp
cmake --build build/dsp --config Release
ctest --test-dir build/dsp -C Release --output-on-failure
flutter build apk --debug
```

Debug APK位于`build/app/outputs/flutter-apk/app-debug.apk`。`flutter build apk --release --split-per-abi`可构建三ABI优化包；无外部签名环境时明确未签名，不能直接安装。签名详见[维护指南](release-signing.md)。正式包安装见[安装指南](install-release.zh-CN.md)。

网络失败时检查自己的网络/代理；不关闭TLS校验或使用未知镜像。代理参数仅用于当前进程/脚本，不提交含代理口令的配置。版本不匹配先核固定工具链和lockfile，不用盲目升级依赖掩盖错误。

## 连接手机

Android开发者选项中开启USB调试，用支持数据的线缆连接，解锁手机并确认该电脑的调试指纹。执行`adb devices -l`，只有序列号后为device才表示连接；unauthorized需在手机确认，offline需重连。只有标题表示无设备，不能算手机验收通过。

安装/权限/哼唱/外部测试音/后台操作及结果记录见[安装指南](install-release.zh-CN.md)和[设备记录模板](device-test-m3-template.md)。不要公开设备序列号、私人档案或签名材料。
