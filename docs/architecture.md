# 软件架构

OpenTuner 使用 Flutter/Dart 呈现界面、Kotlin 管理 Android 生命周期和权限、Oboe 采集/播放音频、可移植 C++ 实现 DSP。主机测试和 Android 使用同一生产分析实现。iOS 采集尚未实现，可通过平台适配层接入同一核心。

## 输入与线程

Android 用户意图/权限 → 串行控制 executor → Oboe PCM 回调 → 预分配有界 SPSC → C++ worker → 带会话/序号/时间的快照 → Kotlin/JNI/MethodChannel → Dart 状态 → 连续指针。

回调只进行有界搬运和计数，不执行分配、锁等待、日志、I/O、FFT、YIN 或 JNI/Dart 调用。worker 处理断点和过载并重置跟踪；快照锁只由非实时线程访问。停止顺序为关闭输入回调、结束并 join worker、释放分析器及缓冲。

通用分析使用80ms窗/20ms步，ET钢琴180ms/20ms，机械分音750ms/100ms。均使用流的实际采样率。详见[音频处理](audio-signal-processing.md)、[桥接契约](audio-bridge.md)、[机械模型](piano-calibration.md)。

## 输出与所有权

参考音/节拍器使用同一个原生输出适配器。相位累加器与包络生成参考音，样本计数器调度节拍；UI帧率不决定发声时刻。输入、参考音和节拍器互斥，会话owner阻止旧页面关闭新流。离页、后台、路由或焦点变化停止音频，需主动恢复。

## UI与数据

`lib/app.dart`组织响应式导航；`lib/pages.dart`与专用页面呈现吉他、钢琴、试测音、节拍器和设置。`lib/model`保存领域状态，`lib/audio`解码与控制快照，`lib/widgets`绘制仪表和图形。集中ARB提供英语/简体中文；ChangeNotifier/ValueNotifier承担状态通知，不引入额外状态管理框架。

原始估计、跟踪结果、数字显示与指针位置独立管理。旧会话/序号、非有限数、长度错误、过期数据和无效频率均拒绝。演示不作为采集失败的回退。

偏好与钢琴档案使用本地私有存储，原始PCM不持久化。[档案格式](piano-profiles.md) · [隐私](privacy.md)。

## 构建边界

`native`可独立CMake/CTest；`native/android`链接固定Oboe源码和JNI。app-local CMake避免重复链接同一引擎。Android最低API24，声明arm64-v8a/armeabi-v7a/x86_64；编译和静态对齐检查不等于设备兼容验证。[依赖](dependencies.md) · [验证](validation.md)。
