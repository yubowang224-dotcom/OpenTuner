# OpenTuner

[简体中文](README.md) · [English](README.en.md)

免费的开源 Android 吉他与钢琴调音工具，支持本地实时音高分析、参考音和节拍器。采用 Flutter、C++ DSP 与 Oboe，音频在设备上处理。

## 下载安装包

**安装包尚未发布。** 请查看 [GitHub Releases](https://github.com/yubowang224-dotcom/OpenTuner/releases)。当前版本为 **0.7.0-beta.2 / versionCode 5001**，支持 **Android 7 / API 24 及以上**。

- **普通 64 位 Android 手机：推荐 arm64-v8a APK。**
- **不确定架构：选择 universal 通用 APK。**
- armeabi-v7a 适用于相应 32 位设备，x86_64 适用于相应架构设备或模拟器。
- 已安装旧 Debug 测试版：**先不要卸载**。正式证书不同，不能直接覆盖；当前没有档案导出/导入入口。[安装指南](docs/install-release.zh-CN.md) · [迁移说明](docs/debug-to-release-migration.zh-CN.md)。

## 功能

- 实时麦克风试测音：音名、Hz、音分、可靠性、真实 PCM 波形与频谱。
- 七种六弦吉他调弦预设，自动/手动目标选择和可停止的拨弦参考音。
- 88 键钢琴目标、全局 A4 参考频率、本地档案和正弦参考音。电子钢琴默认十二平均律。
- 实验性机械钢琴校准：分音检测、非谐性拟合、引导采样、个体调律曲线和档案保存。
- 原生样本时钟节拍器：20–300 BPM，拍号、重音、细分、Tap Tempo，独立开始/暂停/恢复/停止。
- 简体中文与英语，浅色/深色/系统主题、极简模式、App 音量和离线许可证。

<img src="docs/screenshots/m3-piano-focus-en-dark.png" width="260" alt="钢琴极简界面组件测试渲染">
<img src="docs/screenshots/m1-acknowledgements-zh-dark.png" width="260" alt="致谢界面组件测试渲染">

截图来自实际 Flutter 组件的受控测试渲染，不是手机音频实测证据。

## 使用与验证边界

机械钢琴功能保持 **Experimental**。默认六点模型仅支持 A1–A6，不外推到全部 88 键，不代表职业调律师认证。合成测试误差不能推广到手机、实琴、混合声源或所有厂商设备。

无法可靠确定单一音高时，界面显示无效/不确定状态，仍可观察真实波形和频谱。自动匹配可能受泛音影响，可改用手动目标确认。参考音、麦克风和节拍器互斥；切页或后台停止，不自动恢复。

自动化验证包含 Flutter 单元/组件测试、C++ DSP 回归、合成信号实验及三 ABI/通用 Release 静态检查；实际手机安装、端到端延迟和机械钢琴验证仍待完成。见[验证方法与结果](docs/validation.md)。

## 算法原理

麦克风连续 PCM 进入预分配有界队列，后台线程去直流并提取能量、YIN 周期性与频谱谐波一致性。候选质量门控和连续对数音高跟踪降低瞬时抖动；原始频率、跟踪频率、数字显示和指针渲染分别管理。音分按实际目标频率计算，不通过八度折回强行显示调准。

机械钢琴分析独立拟合刚弦分音模型，并以加权分音协调计算有界目标曲线；直接测量、插值参数和模型推断分别标明。这是基于 YIN、pYIN 等研究的工程实现，不宣称基础算法原创或完整实现 pYIN。

- [音频处理](docs/audio-signal-processing.md) · [特征提取](docs/feature-extraction.md)
- [跟踪算法对比与复现](docs/pitch-tracking-evaluation.md)
- [钢琴基础](docs/piano-foundation.md) · [机械钢琴模型](docs/piano-calibration.md)
- [架构](docs/architecture.md) · [音频桥接](docs/audio-bridge.md)

## 构建与测试

工具链：Flutter 3.47.5 / Dart 3.13.4、JDK 21、Android SDK 36、NDK 28.2.13676358、Oboe 1.11.0。具体配置见 [Windows 构建指南](docs/windows-setup.zh-CN.md)。配置好工具路径后执行：

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

`applicationId` 为 `org.opentune.tuner`。没有外部签名配置时，Release 构建明确未签名；官方私钥不分发。[签名与维护者备份指南](docs/release-signing.md)。正式证书 SHA256：

`ae27b3e61d3d21419b6a45236bc9c56cbddcf05044a2311f56f4627d2eaf6892`

## 隐私与开源

音频本地处理，不默认保存原始录音，不上传音频，无广告或跟踪 SDK。需要用户主动开始并授予麦克风权限；Release 无 INTERNET 权限。钢琴档案保存于本地私有存储。见[隐私说明](docs/privacy.md)。

完整实现源码、算法、资源、测试与构建脚本按 Apache-2.0 开放；第三方组件保留各自许可证。源码 ZIP 是仓库源码树的补充。私钥、密码、本机配置、个人数据与构建缓存不属于源码分发内容。

## 致谢

特别感谢《数据分析与特征提取》课程主讲老师张淼老师。张老师让我认识到开源共享精神与“顶级原则”的重要性。OpenTuner 希望通过开放源代码、公开算法实现以及可复现实验，实践这些理念。

本应用源自哈尔滨工业大学《数据分析与特征提取》课程的开源大作业。在张淼老师“顶级原则”思想与开源共享理念的启发下，作者制作了 OpenTuner。本软件免费使用，并以公开完整源代码为发布承诺，希望秉持为大家服务的共产主义思想，尽一份绵薄之力。

这是作者个人的课程项目，并非学校或教师的官方发布或背书；上述观点属于作者个人表达。

[Apache-2.0](LICENSE) · [第三方声明](THIRD_PARTY_NOTICES.md) · [贡献](CONTRIBUTING.md) · [变更记录](CHANGELOG.md)
