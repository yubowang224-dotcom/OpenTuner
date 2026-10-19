# 真实PCM时域显示：数学、线程与可复现实验

本模块只改绘图数据，不修改YIN、候选评分、音高Tracker或140/50ms时间常数。生产入口仍是Oboe的真实PCM；测试信号没有进入生产App的接口。频谱仍独立使用原Analyzer的80ms帧、Hann窗和单边峰幅dBFS/bin，不能从显示曲线反推频谱。

## 从样本到坐标

worker保有既有80ms帧，实际采样率R在8–192kHz范围内。显示长度约20ms，抽取倍数D=ceil(round(0.020R)/512)，点数min(512,floor(round(0.020R)/D)+1)，时间间隔Δt=D/R。没有音频重采样进入音高分析。

D>1时先做对称、单位DC增益的Blackman窗sinc FIR，长度32D+1（最大257），截止频率0.4/D cycles/source sample。未归一化系数为 h[j]=sin(2πfc j)/(πj) × (0.42+0.5cos(πj/M)+0.08cos(2πj/M))，j∈[-M,M]、M=16D；j=0取2fc，再除系数总和。D=1时不降采样、不滤波。该显示低通在抽取前限制带外混叠，也意味着它不是完整宽带原始波形。

FIR以既有帧内的中心样本为时间，需左右M点边界。显示结束与开始都由真实样本位置决定；x_i=1000iD/R ms，样本时钟起始 t0=frameEnd+(startIndex-frameCount)/R。对称滤波使用已收到帧内的双侧样本，没有宣称零延迟实时因果滤波；边界留白和触发会使显示片段较帧尾更早。UI显示t0、t0+(N-1)Δt以及Δt，不将这个软件时钟当作手机端到端声学延迟。

只有Analyzer判定frameQualified时才搜索真实滤波样本减去帧DC均值后的最后一个上升交叉，最多向前20ms；不以估计频率重新合成正弦。噪声/多声源即使误判可触发，其形状仍是实际样本，没有保证可靠声源分离。无交叉就自由更新，静音为真实零线。DC保留在显示数据中，未伪造去DC后的零点。

绘图纵轴以max(0.01,max|x|)×1.15自动设置，单位FS；这是显示缩放，不是麦克风AGC，也不是标定声压级。无可靠音高时仍可绘图，但音名/Hz保持无效。旧ABI1/2的min/max对只画包络，绝不将其当新PCM序列连接。

## 有界线程与传输

WaveformDisplay在打开输入流的控制线程预计算系数，在现有DSP worker内运行，固定512样本结果与257系数，无逐帧堆分配。RT回调只搬运有界队列，不加滤波、FFT、锁、日志、JNI或Dart调用。worker使用同一帧先Analyzer后显示提取，原结果和显示结果在已有mutex内一起发布。数据断点清除显示。异常仍由既有worker catch发布ErrorInternal，控制轮询进入错误停止；没有吞掉错误改为演示数据。该异常/Oboe真实系统路径尚无手机注入验证。

ABI3详细契约见[audio-bridge.md](audio-bridge.md)。关闭详情和进入极简时不计算新显示样本、不传图形payload；返回普通模式不自动展开详情。已有Analyzer在详情开启时仍计算其旧包络作为内部结果，但不再跨桥发送它；未为了优化显示而改写已认可分析实现。

## 预先固定的测试与结果

native/tests/waveform_tests.cpp使用同一生产模块。180条件=5种采样率（8/44.1/48/96/192kHz）×6频率（50/82.406889/220/440/880/2000Hz）×2幅度（0.005/0.4FS）×3相位（0/0.7/2.9rad），均加0.13FS DC，80ms真实输入帧。逐样本比对真值，误差门槛1%幅度+1e-6，周期计数容差1.1周期，窗口19.8–20.0ms，点数/时间边界严格检查。不是只选成功帧。另8个超显示Nyquist条件须抑制超过50dB，并检查双音、固定种子48121噪声、静音、恒DC、NaN拒绝。

| Hz | 条件数 | 原10ms搜索触发 | 新20ms搜索触发 |
|---|---:|---:|---:|
| 50 | 30 | 20 | 30 |
| 82.406889 | 30 | 12 | 30 |
| 220/440/880/2000（各） | 30 | 30 | 30 |
| 总计 | 180 | 152 | 180 |

原10ms逐条件CSV在[evidence/wave-trigger10ms.csv](evidence/wave-trigger10ms.csv)，原日志不回改。20ms版本最大样本误差/幅度为0.0000336564（约0.00337%）；8个带外条件衰减-104.211至-76.3873dB。19.75ms是相较原搜索逐条件起始样本最早的额外变化，均值2.20833ms：原搜索未触发时，新搜索可能向前近完整20ms，不能说只额外10ms。它不改变音高/指针时间轴。该权衡只在合成矩阵内评估，真实人声稳定显示待手机检查。

Windows/MSVC Release主机的具体耗时见[外观报告](validation.md)，不替代手机CPU、内存或延迟。Analyzer/features/Tracker/C ABI源码与4ae838a相同，57,330行音高实验输出除compute_ms外完全一致。

## 从源码复现

```powershell
. ./tools/activate.ps1
cmake -S native -B build/appearance-dsp
cmake --build build/appearance-dsp --config Release
ctest --test-dir build/appearance-dsp -C Release -V
python tools/sync_waveform_fixtures.py --source build/appearance-dsp/waveform-results --check
python tools/check_appearance_evidence.py
flutter test test/waveform_test.dart
flutter test tools/capture_appearance_preview.dart
```

最后的截图脚本需本地工具配置和Windows字体，仅用于预览，不属于CI运行条件。Flutter测试只读提交的四个小型原创合成JSON，不依赖已有build目录。重新生成仅使用sync脚本的显式--update；CI使用--check验证生产C++结果（PCM容差1e-6，FFT1e-4dB，元数据1e-9）。测试图中的Hz/后端/其他诊断是受控快照注入，只有波形/频谱来自C++合成帧处理，不能作为完整算法或真机录音证据。测试默认Ahem字体在CustomPainter中显示矩形，显式使用与仪表相同的Roboto后预览刻度可读；没有据此断言手机也有字体缺陷。
