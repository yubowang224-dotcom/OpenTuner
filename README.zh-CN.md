# OpenTuner

[简体中文](README.md) · [English](README.en.md)

## 下载安装包

**安装包尚未发布。** 请查看[GitHub Releases 安装包列表](https://github.com/yubowang224-dotcom/OpenTuner/releases)；正式上传后会在此补充本次版本与APK直达链接。此版本为Beta预发布。

- **普通64位Android手机：推荐 arm64-v8a APK。**
- **不确定架构：选择 universal 通用APK。**
- armeabi-v7a供对应32位设备；x86_64供对应架构设备/模拟器。Android7及以上。
- 已装旧Debug测试版：**先不要卸载**，新正式证书不同，不能直接覆盖；当前没有档案导出入口。[安装教程](docs/install-release.zh-CN.md) · [迁移说明](docs/debug-to-release-migration.zh-CN.md)。

完整实现源码、算法、测试、构建脚本与资源均按Apache-2.0开放；仓库将提供完整可浏览、可克隆的源码树，源码ZIP仅作补充。第三方组件保留其各自许可证，见[第三方声明](THIRD_PARTY_NOTICES.md)。私钥、密码、机器私有配置、个人数据与构建垃圾不属于公开源码。


**当前正式签名候选：0.7.0-beta.2，versionCode 5001，Android 7/API24+。** 真实本地试测音、七种六弦吉他调弦、88键ET钢琴、参考音、原生节拍器、主题/极简与实验性机械钢琴校准均有实际实现。免费无VIP，核心声音在本机处理。

[项目仓库](https://github.com/yubowang224-dotcom/OpenTuner)已核实创建；源码、安装包和远端CI公开状态以仓库实际内容及 Releases 为准，本地构建不冒充上传成功。Release Notes：[中文在前 / English follows](docs/release-notes-0.7.0-beta.2.md)。

正式签名只表示专用长期证书与后续更新身份，**不表示无条件生产稳定或职业声学认证**。机械钢琴保持Experimental，默认六点模型仅支持A1–A6；手机/实琴与厂商兼容未验证。已有208项Flutter/12组原生和最终受影响复验证据；本次签名/元数据变更静态分析及13项针对测试通过，原生源码指纹未变。[签名验收](docs/release-signing-report.md) · [签名与备份](docs/release-signing.md)。

**已安装旧Debug的用户：不要先卸载。** 正式证书不同，不能直接覆盖，当前没有档案导出入口，不承诺无损迁移。[先读迁移说明](docs/debug-to-release-migration.zh-CN.md)。

<img src="docs/screenshots/m3-piano-focus-en-dark.png" width="260" alt="实际Flutter极简组件，受控测试注入，非手机">
<img src="docs/screenshots/m1-acknowledgements-zh-dark.png" width="260" alt="实际Flutter致谢页测试渲染，非手机">

以上均为实际生产组件测试渲染，受控快照不是手机录音、发声或声学精度证据。源码/安装包上传尚未完成；上方链接为已核实的实际仓库。

Android优先的开源吉他/钢琴调音项目，采用Flutter界面、C++音高分析与Oboe原生音频。
希望以无需订阅、可学习和改进的工具降低使用与研究门槛。本项目也是《数据分析与
特征提取》课程实践，特别感谢主讲老师张淼老师。
[课程算法](docs/audio-signal-processing.md) · [可复现实验](docs/pitch-tracking-evaluation.md)。

历史实现快照：[Tools1](docs/tools1-report.md)、[导航修复](docs/navigationfix-report.md)、[外观/PCM](docs/appearance-report.md)。历史报告按当时状态归档，不代表当前完整功能状态。

## 当前功能与边界

- **代码已实现、自动化已验证：** 真实试测音/波形/频谱、YIN与谐波门控、自适应跟踪；
  七种六弦手动/自动目标；3秒可停吉他拨弦/钢琴正弦参考音与App音量；20–300四分音符BPM原生
  节拍器、2/4/3/4/4/4/6/8、重音、每记谱拍1/2/3/4细分、四分音符Tap测速。
- **解释限制：** 不折回八度来强行显示调准。自动匹配可能歧义，泛音可能接近其他弦，
  需手动选弦确认。参考音、采集和节拍互斥，不后台运行、不自动恢复。
- **钢琴基础：** 全88键手动目标、独立180ms窗生产分析、目标/实测/音分分开、全局A4保存和版本化私有档案。电子默认ET；机械相容档案可显式应用支持范围内的实验目标，不回退手动演示。
- **Experimental：** 分音/B、接收/重测/撤销、schema2来源档案和个体模型已接通。改样本使曲线失效，历史搜索提示不能作为目标；手机/实琴及后继清单仍待验证，不声称职业调律认证。七/十二弦已取消。iOS在约定Android项目完成公开后，同仓库推进。

新显示名称和用户审查通过的图标为OpenTuner；保留`org.opentune.tuner`包名；正式版使用与旧Debug不同的专用证书，
不能直接覆盖测试版，必须先处理需保留的本地资料。当前目录和Git历史不重建。实际项目仓库为[OpenTuner](https://github.com/yubowang224-dotcom/OpenTuner)。源码/APK上传仍由协调端另行核验。

去标识化源码快照已独立解压，实际通过锁定依赖解析、双语生成、7项smoke与arm64未签名AOT构建。[源码/导出证据](docs/release-prep-export-verification.md) · [code17安装](docs/install-release-prep.zh-CN.md)。

## 构建与复现

固定Flutter3.47.5/Dart3.13.4、JDK21、SDK36、NDKr28c、Oboe1.11.0；无需重复安装。
在已配置的本机PowerShell中：

```powershell
. ./tools/activate.ps1
flutter pub get --enforce-lockfile
flutter gen-l10n
flutter analyze
flutter test
cmake -S native -B build/m3-dsp
cmake --build build/m3-dsp --config Release
ctest --test-dir build/m3-dsp -C Release --output-on-failure
./tools/build-debug.ps1
```

脚本拒绝覆盖已有同名APK，再次交付需新versionName及递增versionCode。
当前官方签名身份SHA256：`ae27b3e61d3d21419b6a45236bc9c56cbddcf05044a2311f56f4627d2eaf6892`。

按架构选择arm64-v8a、armeabi-v7a、x86_64或通用APK；均为5001。文件SHA256见Release附件SHA256SUMS及[签名报告](docs/release-signing-report.md)。[正式包安装教程](docs/install-release.zh-CN.md)。旧Debug/code17包仍在本地保留，与正式签名不同。开发/CI没有私有签名配置时默认构建未签名Release；不要把自建Debug当官方更新，官方私钥不会分发。

签名材料/恢复密码/本机配置不在仓库。源码导出只包含审查文件，原Git历史留本机；见[公开清单](docs/publication-inventory.md)。Gitee已取消，仅发布GitHub。远端上传/CI由协调任务另行验证。

## 算法原理 / Algorithm

机械模式新增独立刚弦分音拟合、质量拒绝和八度分音协调最小二乘目标。理想弦参数、直接观测第一分音与模型推断清楚区分；测点B与插值B分别标明，所有调律目标均为模型计算，不外推或声称职业听感最优。修改样本使曲线失效，历史搜索提示不充当当前目标。[模型/版本/引用](docs/piano-calibration.md)。


连续麦克风样本进入有界队列，由工作线程去直流、提取能量/YIN周期性及频谱谐波一致性。
候选质量门控与连续对数音高跟踪降低抖动；原始频率、跟踪频率、显示数字、渲染指针分别
管理。不确定声音仍显示真实波形频谱，不编造当前音高。吉他和钢琴音分相对实际选定目标Hz。独立钢琴模式增加观测窗与实际分音细化，不能把所选目标送回当测量答案。[钢琴实现/局限](docs/piano-foundation.md)。

这是借鉴YIN/pYIN的工程组合，不宣称基础算法原创或完整pYIN。比较同时公开拒检、误差、
八度错误、抖动及滑音滞后；本轮没有重调已认可Analyzer和140/50ms参数，57,330行对照
结果除计算耗时外与保存基线一致。

- [声音采集与数学处理](docs/audio-signal-processing.md)
- [数据分析与特征提取](docs/feature-extraction.md)
- [算法对照、图表与复现](docs/pitch-tracking-evaluation.md)
- [架构](docs/architecture.md) · [桥接](docs/audio-bridge.md)
- [隐私](docs/privacy.md) · [依赖](docs/dependencies.md) · [Windows环境](docs/windows-setup.zh-CN.md)
- 历史报告：[阶段0](docs/stage-0-report.md)、[阶段1](docs/stage-1-report.md)、
  [阶段2](docs/stage-2-report.md)、[阶段2.5](docs/stage-2.5-report.md)、[UX1](docs/stage25-ux1-report.md)。
  历史报告按当时状态归档，不代表当前所有功能状态。

## 致谢

特别感谢《数据分析与特征提取》课程主讲老师张淼老师。张老师让我认识到开源共享精神与“顶级原则”的重要性。OpenTuner 希望通过开放源代码、公开算法实现以及可复现实验，实践这些理念。

本应用源自哈尔滨工业大学《数据分析与特征提取》课程的开源大作业。在张淼老师“顶级原则”思想与开源共享理念的启发下，作者制作了 OpenTuner。本软件免费使用，并以公开完整源代码为发布承诺，希望秉持为大家服务的共产主义思想，尽一份绵薄之力。

这是作者个人的课程项目，并非学校或教师的官方发布或背书；上述观点属于作者个人表达。

项目仓库：[OpenTuner](https://github.com/yubowang224-dotcom/OpenTuner)。公开源码与安装包以仓库当前内容及 Releases 为准。

[Apache-2.0](LICENSE) · [第三方声明](THIRD_PARTY_NOTICES.md) ·
[贡献](CONTRIBUTING.md) · [变更记录](CHANGELOG.md)。

[Beta2 independent source build / 干净源码独立构建](docs/release-source-beta2-verification.md)。
