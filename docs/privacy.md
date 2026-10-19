# 隐私说明 / Privacy

## 简体中文

只有用户主动开始吉他、钢琴或试测音并授予Android麦克风权限后，才打开输入流。PCM只在本机有界内存和C++工作线程处理；不默认永久保存原始录音，不上传音频，没有云分析、广告或跟踪SDK。离开页面或进入后台停止采集，恢复须主动开始；不提供后台录音服务。其他平台明确显示采集尚未实现。

本地私有偏好保存主题、极简模式和A4参考频率；权限永久拒绝标记仅用于提供系统设置入口。测量会话和声音不持久化。钢琴档案由用户明确保存，包含名称、随机ID、琴型、A4、目标MIDI、UTC时间和格式版本；可选校准还保存分音、B/质量、实际采样率/后端、算法版本和模型曲线/重采搜索提示。文件临时副本、上一有效备份和显式恢复时保留的损坏副本也留在应用私有目录。详见[档案格式](piano-profiles.md)。

没有账号、云同步或用户档案导出/导入入口。Android backup关闭。卸载/清数据会删除本地偏好和档案，当前不承诺跨签名自动迁移。[迁移说明](debug-to-release-migration.zh-CN.md)。

参考音与节拍器在本地合成，不下载乐器音色；播放与采集互斥，不自动重新开启麦克风。配置日志只记录采样率/后端/缓冲等参数，不记录PCM。厂商AGC/降噪/回声处理不可确认时标未知。

0.7.0-beta.2实际Release清单已检查：RECORD_AUDIO存在、无INTERNET、allowBackup=false、无debuggable。Debug INTERNET来自Flutter调试工具，不代表业务上传。手机离线、权限、路由与私有存储行为仍需设备验证。主机实验WAV/CSV和受控截图不是用户录音。

## English

Input starts only after explicit user action and Android microphone permission. PCM stays in bounded device memory for C++ analysis, without default persistent raw recording, uploads, cloud analysis, ads or tracking. Leaving the page or backgrounding stops capture; restart is manual. Non-Android capture is explicitly unsupported.

Private preferences retain theme, focus mode and A4. User-saved piano profiles contain metadata and optional calibration partials, B/quality, stream provenance, algorithm versions, modeled targets and resampling hints. Temporary/previous-valid/corrupt-file recovery copies remain private. No account, cloud sync or user-facing profile export/import is provided. Android backup is disabled; uninstalling or clearing data removes local information.

Reference and metronome sounds are synthesized locally and mutually exclusive with capture. Logs contain stream configuration rather than PCM. The actual0.7.0-beta.2 Release manifest has RECORD_AUDIO, no INTERNET, backup disabled and no debuggable flag. Debug INTERNET is used by Flutter tooling. Phone privacy/lifecycle/offline/storage checks remain unexecuted. Host synthetic data and controlled screenshots are not microphone recordings.
