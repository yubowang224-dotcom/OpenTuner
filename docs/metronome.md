# 原生节拍器：时间基准与接口

实现：`native/src/metronome.cpp`、`native/android/reference_engine.h`、
`MainActivity.kt`、`lib/audio/metronome_player.dart`。音高Analyzer与Tracker未修改。

## 节奏定义

BPM始终为每分钟四分音符数。每个记谱拍再划分1/2/3/4份，采样间隔为

`P = sampleRate × 60 / BPM × (4 / denominator) / divisions`。

2/4、3/4、4/4的每拍为四分音符。6/8为六个八分音符拍，按3+3分组，
第一拍强、第四拍次强，其他主拍普通；所以BPM120时6/8主拍间隔250ms、
一小节1500ms。Tap也敲四分音符，不把6/8的每个八分音符拍当BPM。

拍点来自从起点累计的分数样本期限`anchor + tickIndex × P`，取到达期限的
第一个样本，不逐拍四舍五入加整数周期，因此恒定配置不累积舍入漂移。
主拍/细分是实际不同幅度和频率的12ms合成点击，起音1ms、余弦收音，
峰值上限0.22FS；停止5ms包络。PCM第一个非零样本比零相位拍点晚1样本，
测试分别核对这个确定关系和拍点误差，不把包络起音计作时钟漂移。

修改在下一个旧配置的细分边界应用，重置小节、锚点和点击；多个待应用修改
以最后一个为准。慢速无细分时可能需等待一拍（20BPM最多3秒），界面明确
提示待应用。停止不等待下一拍，控制线程请求收音；输出设备实际时延未知。

## 线程与所有权

- Kotlin单一控制Executor串行执行采集、参考音、节拍器控制/JNI；三者互斥。
- 输出会话含单调native owner和Dart request。节拍器每次新启动用独立request，
  状态/更新/停止必须匹配；延迟的旧页面操作不能关闭新会话。参考音接口还有
  模式检查，不能停止节拍器。焦点丢失、输出路由变化、离页/后台均停止，手动恢复。
- 回调仅执行固定内存的合成、计数、读取32bit配置原子及发布原子快照，
  不分配、加锁等待、日志、I/O、JNI/Dart调用或运行音高分析。
- 快照用32bit无锁原子字段和序列校验，64bit样本计数拆分存储，避免32bit ABI
  隐式锁和普通内存数据竞争。控制端最多重试4次，失败保留最后一致快照。
- 关闭请求包络并有界等待最多120ms，再停止/关闭流。异常清理由原owner控制。

## 通道契约

同一`org.opentune/audio`：metroStart(config,request)、metroUpdate(config,request)、
metroStop(request)、metroStatus(request)。参数bpm20–300、beats1–12、
denominator4/8、divisions1–4、accent布尔；当前UI提供上述四种拍号。
配置在Kotlin校验后以32bit字传入原生，原生再校验。更新回accepted表示已提交，
不代表已在拍点生效。

16个double字段（都是精确整数，超长会话2^53之外不声明）：

| 索引 | 含义 |
|---|---|
|0–3|ABI=1、native owner、playing、实际输出Hz|
|4–7|已提交样本帧、从0开始的拍号、细分号、累计拍点数；未开始位置为-1|
|8–12|实际生效BPM、每小节拍数、分母、细分、重音0/1|
|13–15|原生错误码、配置待应用0/1、最近拍点的样本位置|

Flutter33ms轮询只是显示，不发声、不按轮询次数增加拍号；一个会话最多一个
在途轮询/更新，参数更新合并。500ms无样本前进判stalled并停止。快照需完整、
有限整数、owner/位置/配置合法，不合格不伪造节拍。显示位置是提交样本进度，
不是已测量的扬声器声学出声时刻，仍有轮询、缓冲与硬件延迟。

## 验证

`cmake -S native -B build/tools1-dsp`、Release构建、CTest全部运行。
`sample_clock_metronome`对320条件真正渲染两小节PCM，并由非零音频定位点击、
检查每个主/次/细分重音幅度和时序；另逐条件推进同一生产调度器十分钟，
这是时钟模拟，不声称渲染十分钟音频。还测参数边界、连续更新、正在发声时
停止、重复停止、无效配置、并发快照。完整CSV为本地build目录的
`metronome-results/timing.csv`，简表见validation.md。

主机与模拟桥接不证明手机无丢音、硬件无时钟漂移或蓝牙同步。手机听测、
焦点/路由实测和端到端延迟未执行。


## 参考输出与ABI2音量扩展

吉他toneStart增加voice(0正弦/1原创拨弦)与gain(0..1)，JNI形参严格对应；钢琴默认voice0/gain1保持原参考，输入/参考/节拍互斥不变。MetroConfig在Dart/Kotlin参数中增加整数gain(0..100)，与原拍速packed word分离，control将gain送入锁自由32位请求，callback内5ms slew，音量改变不触发节拍重置。节拍快照现在ABI2共17double，0..15原意义、16为回调收到的目标gain百分数；pending同时比较实际配置与gain。兼容ABI1/16字段默认100；MetroMailbox将gain与样本位置/配置按同一序列发布，不裸读共享浮点。见[reference-synthesis.md](reference-synthesis.md)及[验证结果](validation.md)。


## 当前ABI3暂停/恢复协议

开始/暂停/恢复/停止独立。暂停约5ms淡出后冻结音乐样本/振荡器/拍位/剩余间隔，保留静音输出；恢复续相位、5ms淡入，停止释放并在新开始第1拍复位。静音请求在完全暂停/渐停/精确渐停完成样本均结算，恢复首样本0。ABI3=19字段，17transport0播放1渐停2暂停3渐入，18输出回调样本心跳，旧0..16意义保持；mailbox完整原子发布。paused依输出心跳而非音乐计数检测500ms停滞；切换未得到原生状态1秒失败，不由UI伪造暂停。nativeMetroPause(JZ) owner隔离，Kotlin生产MetronomeStatus严格解析ABI1/2/3，修复原17字段被16长度门控误判中断。暂停/恢复仍属于同一输出owner，离页/后台/中断停止，不自动恢复。

16实际PCM条件（含静音首样本/非零声对照）和生产C++快照→Java/Dart、controller/真实控件/迟到回复/导航互斥回归见[验证结果](validation.md)。手机实际输出仍未验证。
