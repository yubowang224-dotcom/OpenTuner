# 依赖、工具链与许可证

版本固定于toolchain.versions.json、pubspec.lock和Android构建配置。构建兼容性来自实际本地构建，手机厂商/路由兼容性另行验证。

| 组件 | 固定版本 | 说明 |
|---|---|---|
| Flutter / Dart | 3.47.5 / 3.13.4 | UI、本地化、测试；Flutter BSD-3-Clause及引擎综合通知 |
| JDK | 21 | Java构建工具，GPLv2 with Classpath Exception，不随APK分发 |
| Android SDK / Build Tools | 36 / 36.0.0 | 最低运行API24，目标36；各SDK组件条款适用 |
| NDK / Android CMake | 28.2.13676358 / 3.22.1 | libc++_shared及LLVM综合NOTICE随包保留 |
| Gradle / AGP / Kotlin | 9.3.1 / 9.1.0 / 2.4.0 | 与工程模板及实际构建组合固定 |
| Oboe | 1.11.0，b115f47593969fd67a21e9f63640ffef749b5067 | Apache-2.0，固定include/src/CMake源码在native/third_party/oboe，静态链接 |
| intl | 0.20.3 | BSD-3-Clause；其他Dart依赖以lockfile和第三方声明为准 |
| Python实验工具 | 3.11、numpy2.4.4、matplotlib3.10.8 | 仅主机图表，不随APK分发；tools/requirements-evaluation.txt固定包版本 |

App不依赖广告、跟踪、云分析、数据库或音色下载SDK。FFT/YIN/跟踪/刚弦模型为本项目按公开理论实现，不复制受限pYIN源代码；基础研究归属原作者。测试WAV为原创合成信号，不捆绑真实乐器录音或外部字体。

Oboe按系统能力使用OpenSL ES/AAudio，流请求不保证每个设备的独占、低延迟或未经处理输入。厂商AGC/降噪状态不可确认时标未知。三ABI实际编译与64位ELF/ZIP16KB静态检查通过，不替代API24/16KB设备运行。

[完整第三方声明](../THIRD_PARTY_NOTICES.md)列出真实许可证路径；Apache-2.0不重新许可第三方组件。Flutter综合引擎通知及NDK综合通知不意味着每个列名组件均进入同一APK。

参考：[Flutter源码](https://github.com/flutter/flutter/tree/3.47.5)、[Oboe源码](https://github.com/google/oboe/tree/1.11.0)、[NDK版本说明](https://developer.android.com/ndk/downloads/revision_history)。
