# OpenTuner 0.7.0-beta.2

## 简体中文

Android Beta，versionCode5001，最低Android7/API24。请在Release的Assets区域下载APK：普通64位手机推荐arm64-v8a，不确定架构选universal；armeabi-v7a和x86_64供对应架构。

### 功能

- 本地实时麦克风音高分析、可靠性、真实PCM波形与频谱。
- 七种六弦吉他预设、自动/手动目标、可停止参考音和App音量。
-88键钢琴ET、全局A4、本地档案与正弦参考音。
- Experimental机械钢琴分音/非谐性拟合、引导校准、有界个体曲线和保存/应用。默认六点只支持A1–A6，不外推。
- 原生样本时钟节拍器，独立开始/暂停/恢复/停止，拍号、重音、细分和Tap Tempo。
- 简体中文/英语、浅/深/系统主题、极简模式、离线许可证与课程致谢。

### 安装与验证

四个架构/通用APK使用同一专用证书与统一版本码。正式证书SHA256：`ae27b3e61d3d21419b6a45236bc9c56cbddcf05044a2311f56f4627d2eaf6892`。文件哈希见SHA256SUMS.txt。

**已装旧Debug的用户先不要卸载**：证书不同，不能直接覆盖，当前无用户档案导出/导入入口，不承诺无损迁移。见[安装指南](install-release.zh-CN.md)和[迁移说明](debug-to-release-migration.zh-CN.md)。

已有208 Flutter/12组原生及受影响回归证据；签名/元数据变更运行静态分析和13项针对测试。干净源码独立通过7项smoke和150.1s arm64无密钥AOT构建。三ABI与通用包完成实际签名、Manifest/JNI/许可证/16KB静态检查。

没有本版本真机安装、手机端到端延迟或实琴认证。合成结果不代表复杂声源/厂商设备精度，机械功能保持Experimental。私钥和私有配置不分发。完整源码树位于仓库Code页，源码ZIP为补充。

## English

Android Beta, unified versionCode5001, Android7/API24+. Download an APK from the release Assets: arm64-v8a for typical64-bit phones, universal if unsure; armeabi-v7a/x86_64 for matching architectures.

Includes local microphone pitch analysis and actual waveform/spectrum, seven six-string presets/references,88-key ET piano/shared A4/profiles, Experimental partial fitting and bounded individual targets, native sample-clock metronome, themes/focus, localization and course acknowledgements. Mechanical support normally spansA1–A6 without extrapolation.

Keep any old Debug app and data: the dedicated release certificate differs, direct replacement is blocked and no profile export/import exists. No lossless migration is promised. File hashes are inSHA256SUMS.txt; the official certificate is `ae27b3e61d3d21419b6a45236bc9c56cbddcf05044a2311f56f4627d2eaf6892`.

Recorded checks include208 Flutter/12 native groups, affected regressions, analysis and13 metadata tests; an independently extracted source passed7 smoke tests and a150.1s unsigned arm64 AOT build without the official key. Signed packages passed manifest/JNI/license/16KB static checks. No new phone installation, end-to-end latency or real-piano certification is claimed. Private signing material is excluded. The complete repository source tree is supplemented by a source ZIP.
