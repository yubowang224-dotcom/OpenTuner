// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'OpenTuner';

  @override
  String get guitar => '吉他';

  @override
  String get piano => '钢琴';

  @override
  String get explore => '试测音';

  @override
  String get metronome => '节拍器';

  @override
  String get settings => '设置';

  @override
  String get guitarTitle => '让每根弦，恰到好处。';

  @override
  String get guitarSubtitle => '留一点安静，听见更好的音准。';

  @override
  String get pianoTitle => '认真对待，每一个音。';

  @override
  String get pianoSubtitle => '从清晰的音高开始，走近你的钢琴。';

  @override
  String get exploreTitle => '看见你的声音。';

  @override
  String get exploreSubtitle => '哼唱、歌唱，或探索一个持续的音。';

  @override
  String get metronomeTitle => '找到自己的节奏。';

  @override
  String get metronomeSubtitle => '一步一步，为练习设置合适的节拍。';

  @override
  String get settingsTitle => '简单一点，刚刚好。';

  @override
  String get settingsSubtitle => '让 OpenTuner 更贴近你的使用习惯。';

  @override
  String get uiPreview => '界面预览';

  @override
  String get audioNotConnected => '专用检测待开发';

  @override
  String get audioStageNotice => '当前乐器页面尚未实现检测，请前往试测音使用真实麦克风分析。';

  @override
  String get waitingAudio => '等待音频接入';

  @override
  String get uncertain => '未检测到稳定音高';

  @override
  String get flat => '偏低';

  @override
  String get inTune => '准确';

  @override
  String get sharp => '偏高';

  @override
  String get centsUnit => '音分';

  @override
  String get target => '目标音';

  @override
  String get detectedNote => '检测音名';

  @override
  String get demoNote => '演示音名';

  @override
  String get standardTuning => '标准调弦';

  @override
  String get sixStrings => '六弦 · E A D G B E';

  @override
  String get targetOnly => '吉他页支持七种六弦预设与拨弦参考音。';

  @override
  String stringLabel(int number) {
    return '第 $number 弦';
  }

  @override
  String get minimalMode => '极简模式';

  @override
  String get minimalDescription => '只保留音名、指针与必要的偏差反馈。';

  @override
  String get normalMode => '显示详情';

  @override
  String get details => '测量详情';

  @override
  String get measuredFrequency => '检测频率';

  @override
  String get targetFrequency => '目标频率';

  @override
  String get confidence => '音高可信度';

  @override
  String get notMeasured => '尚未测量';

  @override
  String get demoTitle => '试试指针动画';

  @override
  String get demoDescription => '仅供视觉演示，不使用麦克风，也没有真实音高测量。';

  @override
  String get demoOn => '演示中 · 无音频';

  @override
  String get demoOff => '退出演示';

  @override
  String get demoSlider => '演示音分偏差';

  @override
  String demoOffset(String value) {
    return '演示偏差：$value 音分';
  }

  @override
  String gaugeSemantics(String note, String value, String state) {
    return '调音仪表：$note，$value，$state';
  }

  @override
  String get pianoType => '钢琴类型';

  @override
  String get digitalPiano => '电子钢琴';

  @override
  String get uprightPiano => '立式钢琴';

  @override
  String get grandPiano => '三角钢琴';

  @override
  String get pianoTarget => '目标音选择预览';

  @override
  String get pianoRangeNotice => '可选择 A0 至 C8 的全部 88 键。';

  @override
  String get electronicNotice => '电子钢琴采用十二平均律目标，不应用机械钢琴的拉伸曲线。';

  @override
  String get professionalTitle => '个体钢琴校准';

  @override
  String get professionalNotice => '尚未实现。后续将加入分音分析与基于测量的拉伸曲线，并需要真实机械钢琴验证。';

  @override
  String get planned => '计划开发';

  @override
  String get microphoneTitle => '麦克风尚未接入';

  @override
  String get microphoneNotice => '接入真实采集后，这里将显示音高、波形和频谱。当前页面不申请权限、不录音。';

  @override
  String get captureUnavailable => '采集功能尚未开放';

  @override
  String get waveform => '实时波形';

  @override
  String get spectrum => '实时频谱';

  @override
  String get realDataOnly => '等待真实采样数据';

  @override
  String get bpm => 'BPM';

  @override
  String get tempo => '速度';

  @override
  String tempoValue(int value) {
    return '每分钟 $value 拍';
  }

  @override
  String get slower => '降低速度';

  @override
  String get faster => '提高速度';

  @override
  String get timeSignature => '拍号';

  @override
  String get subdivision => '节拍细分';

  @override
  String get quarter => '四分音符';

  @override
  String get eighth => '八分音符';

  @override
  String get triplet => '三连音';

  @override
  String get sixteenth => '十六分音符';

  @override
  String get beatPreview => '节拍布局预览';

  @override
  String get metronomeNotice => 'Android 已接入音频时钟播放。需主动开始，离开页面停止。';

  @override
  String get playbackUnavailable => '节拍音频尚未接入';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get english => 'English';

  @override
  String get chinese => '简体中文';

  @override
  String get appearance => '外观';

  @override
  String get lightTheme => '浅色主题';

  @override
  String get sessionSettings => '语言及播放设置仅本次有效；Android 会保存主题、极简模式与 A4 参考频率。';

  @override
  String get privacyTitle => '声音，属于你自己。';

  @override
  String get privacyDescription =>
      '仅在主动开始测量后使用麦克风。声音在本机处理，不保存录音、不上传。私有钢琴档案可保存分音频率、质量、设备信息及模型调律目标；没有广告或跟踪 SDK。';

  @override
  String get about => '关于 OpenTuner';

  @override
  String get versionLabel => '版本 0.7.0 Beta 2 · 机械钢琴校准仍属实验性';

  @override
  String get licenseLabel => '开源 · Apache License 2.0';

  @override
  String get availability => '功能开发状态';

  @override
  String get availabilityDescription =>
      '试测音与吉他保留原有通用 C++ 跟踪。钢琴支持 88 键十二平均律测量，以及可选 Experimental 机械钢琴校准：分音拟合、质量拒绝与测点范围内的个体模型目标。尚未经过实琴或职业验证；范围外使用十二平均律。';

  @override
  String get referencePitch => '参考音高';

  @override
  String get referencePitchNotice => '全局 A4 同步应用于所有目标与参考音。';

  @override
  String get noPermission => '尚未申请麦克风权限';

  @override
  String targetSemantics(String label, String note) {
    return '$label，$note';
  }

  @override
  String get localAnalysis => '本地音频分析';

  @override
  String get micIdle => '麦克风已停止 · 准备好后点击开始';

  @override
  String get micStarting => '正在申请麦克风权限 / 打开音频流…';

  @override
  String get micRunning => '麦克风采集中 · 实时分析';

  @override
  String get micUnsupported => '当前平台尚未实现音频采集';

  @override
  String get micDenied => '麦克风权限被拒绝，可以重新尝试。';

  @override
  String get micSettings => '请在 Android 应用设置中允许使用麦克风。';

  @override
  String get micRevoked => '麦克风权限已被撤销，采集已停止。';

  @override
  String get micBackground => '切入后台后已停止采集，点击开始可重新采集。';

  @override
  String get micDeviceChanged => '输入设备已变化，采集已停止，请点击开始重新打开。';

  @override
  String get micSilenced => '麦克风被系统静音或限制，请检查隐私开关及其他录音应用。';

  @override
  String get micInterrupted => '音频流被中断，请点击开始重新打开。';

  @override
  String get micStalled => '没有收到新音频，采集已停止，请检查输入设备。';

  @override
  String get micError => '无法打开或读取音频，请检查权限、其他录音应用后重试。';

  @override
  String get startCapture => '开始试测音';

  @override
  String get stopCapture => '停止采集';

  @override
  String get openAppSettings => '打开应用设置';

  @override
  String get capturePrivacy =>
      '声音仅在本机分析，不上传、不保存原始录音。当前估计单一音高，先尝试约 50–2000 Hz 的稳定哼唱；复杂声音可能没有明确音高。';

  @override
  String get signalLevel => '数字信号电平';

  @override
  String get algorithmScore => '周期性评分';

  @override
  String get scoreNotice =>
      '0–1 周期性评分，不是正确概率。音分相对所选参照音；自动参照采用 ±55 音分迟滞及短时边界确认，原始与跟踪 Hz 不受影响。';

  @override
  String get clippingWarning => '检测到削波 · 请远离麦克风一些';

  @override
  String get liveDetails => '实时波形、频谱与诊断';

  @override
  String get audioConfiguration => '实际音频流';

  @override
  String get rawFrequency => '原始候选频率';

  @override
  String get bufferInfo => '突发 / 容量';

  @override
  String get framesUnit => '帧';

  @override
  String get droppedSamples => '丢弃样本数';

  @override
  String get inputPreset => '输入预设';

  @override
  String get processingUnknown =>
      '设备 AGC / 降噪 / 回声处理状态：未知。请求某种输入预设不能证明关闭了所有处理。';

  @override
  String get normalizedPcm => 'PCM 幅值 −1…+1';

  @override
  String get spectrumNotice =>
      'Hann 窗 · 单边各 FFT 栅格的峰值幅度 dBFS，不是经校准的声压级。非栅格频率会向相邻栅格泄漏。';

  @override
  String get openSourceLicenses => '开源许可证';

  @override
  String get noClearPitch => '未检测到明确音高';

  @override
  String get playReference => '播放参考音 · 3 秒';

  @override
  String get stopReference => '停止参考音';

  @override
  String get referenceUnsupported => '当前平台尚未实现参考音播放。';

  @override
  String get referenceError => '无法播放，请检查音频输出或其他应用。';

  @override
  String get referenceSafety => '播放参考音会停止麦克风测量。播放后请手动开始调音或试测音；先调低媒体音量。';

  @override
  String get trackedFrequency => '跟踪频率';

  @override
  String get noiseFloor => '噪声底 / 电平余量';

  @override
  String get spectralFeatures => '谱重心 / 谐波一致性';

  @override
  String get trackingFeatures => '候选数 / 跟踪状态';

  @override
  String get referenceAudio => '参考音';

  @override
  String get automaticReference => '自动参照音';

  @override
  String get lockedReference => '已锁定参照音';

  @override
  String lockReference(String note) {
    return '锁定 $note';
  }

  @override
  String unlockReference(String note) {
    return '解锁 $note';
  }

  @override
  String get lockReferenceNotice => '仅锁定参照，测量仍实时变化；静音仍失效。停止、后台或离开试测音后恢复自动。';

  @override
  String get switchingReference => '切换参照音…';

  @override
  String get flatOutsideRange => '← 偏低 · 超出仪表范围';

  @override
  String get sharpOutsideRange => '偏高 · 超出仪表范围 →';

  @override
  String referenceGaugeSemantics(
    String reference,
    String detected,
    String cents,
    String state,
  ) {
    return '参照音 $reference，检测音 $detected，$cents，$state';
  }

  @override
  String get guitarLiveSubtitle => '七种六弦预设 · 实时麦克风调音。';

  @override
  String get manualTarget => '手动选弦';

  @override
  String get autoTarget => '自动匹配';

  @override
  String get guitarAmbiguous => '目标有歧义，请手动选弦。';

  @override
  String get guitarOutside => '超出自动范围，请手动选弦。';

  @override
  String get guitarReferenceSafety => '参考音播放时停止测量。结束后稍候，再手动开启麦克风。请用外部声源检查调音。';

  @override
  String get guitarAutoNotice =>
      '自动按当前预设的绝对音高在 ±150 音分内匹配，距离差不超过 25 音分时判为歧义；换弦需两帧新结果确认。泛音可能接近另一根弦，请酌情手动选择。';

  @override
  String get metronomeLiveSubtitle => '由音频样本时钟驱动，强弱分明。';

  @override
  String get metronomeUnsupported => '当前平台尚未实现音频播放。';

  @override
  String get metronomePlaying => '播放中 · 原生音频时钟';

  @override
  String get metronomeStarting => '正在开启音频输出…';

  @override
  String get metronomeStopped => '已停止';

  @override
  String get metronomeInterrupted => '播放中断或失败。请检查音频输出后重新开始。';

  @override
  String get quarterBpm => '每分钟四分音符数';

  @override
  String get metroAccent => '重音（6/8：3+3）';

  @override
  String get metronomePending => '更改将在下一细分拍点生效，并重新起小节。';

  @override
  String get startMetronome => '开始节拍器';

  @override
  String get stopMetronome => '停止节拍器';

  @override
  String get tapQuarter => '轻敲四分音符测速';

  @override
  String get subdivisionsPerPulse => '每个记谱拍的细分数';

  @override
  String get metronomeClockNotice =>
      'BPM 与轻敲始终按四分音符计。6/8 为六个八分音符拍，按 3+3 分组（每四分音符两个拍）；细分作用于每个记谱拍。修改在下一细分拍点生效并重新起小节。视觉显示已提交的音频样本位置，另有轮询及未知扬声器延迟。离页、后台或音频中断后停止，需手动重启。';

  @override
  String metroBeat(int beat) {
    return '第 $beat 拍';
  }

  @override
  String get completionNoDevice => '未执行真机检查；不阻塞后续开发。';

  @override
  String get nativeAudio => '原生音频';

  @override
  String get guitarConfirming => '正在确认吉他目标…';

  @override
  String get startGuitar => '开始调音';

  @override
  String get stopGuitar => '停止调音';

  @override
  String get switchTool => '切换工具';

  @override
  String get exitMinimal => '退出极简';

  @override
  String get darkTheme => '深色';

  @override
  String get preferencesFailed => '外观偏好读取或保存失败。本次设置仍生效，可重新选择以重试。';

  @override
  String get preferencesSessionOnly =>
      '此预览仅保存本次偏好；Android 在本机保存主题、极简模式与 A4 参考频率。';

  @override
  String get preferencesSaving => '正在本机保存外观…';

  @override
  String get preferencesSaved => '主题、极简模式与 A4 参考频率已保存在本机。语言及播放设置仅本次有效。';

  @override
  String get sampledPcm => '显示低通 PCM · 幅值 FS · 时间 ms（纵轴自动缩放）';

  @override
  String get envelopePcm => '旧版最小/最大包络 · FS';

  @override
  String get waveTriggered => '按真实上升交叉对齐，并非合成波形。';

  @override
  String get waveFree => '连续更新的 PCM 短窗；未触发对齐。';

  @override
  String get waveTiming => '音频样本时钟 · 起止与间隔';

  @override
  String get guitarPreset => '调弦预设';

  @override
  String get presetDropD => 'Drop D · DADGBE';

  @override
  String get presetDStandard => '全降一音 · DGCFAD';

  @override
  String get presetHalfDown => '全降半音 · Eb Ab Db Gb Bb Eb';

  @override
  String get presetDadgad => 'DADGAD';

  @override
  String get presetOpenD => '开放 D · DADF#AD';

  @override
  String get presetOpenG => '开放 G · DGDGBD';

  @override
  String get presetRestart => '预设已切换，测量已停止；请重新开始以获取新读数。';

  @override
  String get guitarVoice => '拨弦吉他 · 原创合成音色';

  @override
  String synthVolume(int percent) {
    return '合成音量 $percent%';
  }

  @override
  String get synthVolumeNotice => '仅调节 App 合成音量；调整会停止当前参考音，请再次播放。系统媒体音量需另行调节。';

  @override
  String get metroVolumeNotice => '播放中可调 App 音量，不重置节拍；系统媒体音量独立。';

  @override
  String get acknowledgements => '致谢';

  @override
  String get acknowledgementsBody =>
      '本应用源自哈尔滨工业大学《数据分析与特征提取》课程的开源大作业。在张淼老师“顶级原则”思想与开源共享理念的启发下，作者制作了 OpenTuner。本软件免费使用，并以公开完整源代码为发布承诺，希望秉持为大家服务的共产主义思想，尽一份绵薄之力。';

  @override
  String get acknowledgementsAttribution =>
      '这是作者个人的课程项目，并非学校或教师的官方发布或背书；上述观点属于作者个人表达。';

  @override
  String get sourcePublicationPending =>
      '源码项目仓库：\nhttps://github.com/yubowang224-dotcom/OpenTuner';

  @override
  String get referenceSetting => '全局标准音高';

  @override
  String get referenceInvalid => '请输入 400–480 Hz 的 A4 频率。';

  @override
  String get applyReference => '应用 A4';

  @override
  String get referenceCalibrationNotice =>
      '修改 A4 会停止旧测量和参考音。这是音乐音高基准，不是麦克风采样时钟校准。';

  @override
  String get pianoProfiles => '本地钢琴档案';

  @override
  String get profileReady => '本地档案可用。';

  @override
  String get profileUnsupported => '当前平台尚未实现档案存储。';

  @override
  String get profileUnavailable => '档案存储失败，请重新读取；不会覆盖现有文件。';

  @override
  String get profileCorrupt => '档案数据损坏，未读到可用备份，已阻止写入。';

  @override
  String get profileSchema => '当前不支持此档案版本，不会降级或覆盖。';

  @override
  String get profileConflict => '档案已被其他写入改变，或未确认更新；请重新读取。';

  @override
  String get profileInvalid => '请检查名称和数据，名称不能为空或重复。';

  @override
  String get profileRecovered => '已读取较早的有效备份；编辑前请恢复，最近修改可能缺失。';

  @override
  String get profileDataNotice =>
      '仅在本机保存名称、钢琴类型、A4、当前琴键和 UTC 时间，不含原始录音或专业拉伸数据。';

  @override
  String get profileMatches => '当前设置与所选档案一致。';

  @override
  String get profileModified => '当前设置与档案不同，修改尚未保存。';

  @override
  String get profileBusy => '正在读取或保存本地档案…';

  @override
  String get profileName => '钢琴名称';

  @override
  String get profileCreate => '保存为新档案';

  @override
  String get profileReload => '重新读取';

  @override
  String get profileRecover => '恢复备份';

  @override
  String get profileConfirmUpdate => '允许用当前设置更新所选档案';

  @override
  String get profileUpdate => '更新所选档案';

  @override
  String get pianoLiveSubtitle => '88 键 · 十二平均律音高测量。';

  @override
  String get pianoMechanicalNotice =>
      '当前为十二平均律基础测量，并非个体化调律。下方提供实验性实测校准，尚未经实琴验证。';

  @override
  String get pianoManualNotice => '请手动选择实际琴键，当前不自动切换琴键。';

  @override
  String get pianoLowest => '最低音 · A0';

  @override
  String get pianoHighest => '最高音 · C8';

  @override
  String get pianoReferenceSafety => '正弦参考音 · 播放时停止测量，结束后请手动重新开始。';

  @override
  String get pianoAnalysisNotice =>
      '钢琴模式观察约 180 毫秒声音，输入采样率需至少 16 kHz。微弱、混合或非谐性声音可能不确定；原始与跟踪频率分离，评分不是正确概率。';

  @override
  String pianoKeyNumber(int number) {
    return '第 $number / 88 键';
  }

  @override
  String pianoOctave(int number) {
    return '$number 组';
  }

  @override
  String get profileCapacity => '档案容量上限为 64 个且总数据不超过 1 MiB。已有数据未变，请减少保存的测量信息。';

  @override
  String get calTitle => '机械钢琴 · 实验性';

  @override
  String get calSubtitle => '测量稳定分音，审阅质量，再计算有限范围的拉伸目标。';

  @override
  String get calExperimental => '实验性，仅经合成验证，未经实琴或职业调律师认证。机械调律应由有经验者处理。';

  @override
  String get calNeedProfile => '请先保存并选中与当前琴型、A4 一致的机械钢琴档案。';

  @override
  String get calOpen => '测量分音 / 管理校准';

  @override
  String get calTake => '接收当前稳定样本';

  @override
  String get calRemove => '删除当前键样本';

  @override
  String get calUndo => '撤销采样修改';

  @override
  String get calSave => '保存草稿（替换本档案校准）';

  @override
  String get calSaved => '已保存到本机。';

  @override
  String get calUnsaved => '草稿修改尚未保存。';

  @override
  String get calGenerate => '生成拉伸目标';

  @override
  String get calApply => '应用已保存拉伸目标';

  @override
  String get calDisable => '恢复十二平均律目标';

  @override
  String get calInsufficient =>
      '至少需要 5 个有效键（含 A4），覆盖 A4 两侧、跨度 36 半音，相邻测点间隔不超过八度。不作外推。';

  @override
  String get calAssociationChanged => '档案、A4、琴型或页面已改变，采集停止；请关闭后重新进入。';

  @override
  String get calDataNotice =>
      '在本地保存观测分音、拟合/质量、来源信息及模型目标，不保存原始录音。离开前请明确保存；改动样本会使曲线失效。';

  @override
  String get calSamplingNotice =>
      '弹奏单个指定键并等待稳定。750 毫秒窗 / 100 毫秒步，需要连续 4 帧一致。弱音、阶次歧义或未分辨多弦可能不可靠。';

  @override
  String get calFirstObserved => '已观测一阶分音；实时偏差采用实际谱峰频率。';

  @override
  String get calFirstInferred => '未观测一阶分音。第一分音 Hz 由弦模型推算，并非直接测量。';

  @override
  String get calIdeal => '理想弦参数';

  @override
  String get calModelFirst => '拟合第一分音';

  @override
  String get calObservedFirst => '观测一阶分音';

  @override
  String get calBFit => '非谐性 B';

  @override
  String get calResidual => '拟合 RMS 残差（音分）';

  @override
  String get calSensitivity => 'B 敏感度代理';

  @override
  String get calExplained => '已解释谱峰功率比例';

  @override
  String get calStable => '连续一致帧数';

  @override
  String get calPartialOrders => '观测分音阶数';

  @override
  String calCurveRange(String low, String high) {
    return '模型支持范围：$low–$high；范围外使用十二平均律。';
  }

  @override
  String get calBMeasured => 'B 来自测量';

  @override
  String get calBInterpolated => 'B 来自插值';

  @override
  String get calTargetModel => '目标由模型计算，不是直接测量值。';

  @override
  String get calOutside => '超出校准范围 · 使用平均律目标与分析';

  @override
  String get calActive => '实验性拉伸目标已应用';

  @override
  String get calTargets => '查看目标频率';

  @override
  String get calModelNotice =>
      '按 2:1 / 4:2 八度与 4:1 双八度分音协调，加弱平均律/邻键正则；A4 锚定第一分音。权重为工程假设，不是经验证的听觉最优解。';

  @override
  String get calError => '无法生成或应用这些目标，请检查样本、支持范围及已保存档案。';

  @override
  String get calStoredIncompatible => '旧校准仍保留，但与当前 A4 / 琴型不一致，已停用；保存新草稿会替换它。';

  @override
  String get calSourceMic => 'Android 麦克风入口（不是经认证的声学证据）';

  @override
  String get calSourceSynthetic => '主机合成测试夹具 · 非手机';

  @override
  String get calReason0 => '分音稳定，可以接收。';

  @override
  String get calReason1 => '正在确认连续一致帧…';

  @override
  String get calReason2 => '未检测到可测声音。';

  @override
  String get calReason3 => '发生削波，请降低音量或拉远距离。';

  @override
  String get calReason4 => '可靠分音不足（至少需要四个）。';

  @override
  String get calReason5 => '谱峰不支持所选琴键或弦模型。';

  @override
  String get calReason6 => '分音阶次或模型存在歧义，请重测。';

  @override
  String get calReason7 => '分音附近存在多个强峰，可能有多弦干扰。';

  @override
  String get calReason8 => '声音尚未稳定。';

  @override
  String get calReason9 => '输入带宽不足以支持足够分音。';

  @override
  String get calReason10 => '当前数据不足以可靠辨识 B。';

  @override
  String get calCurveCaption => '相对平均律偏移（音分）· 点：实测 B；线：模型目标';

  @override
  String get calFitScore => '分音拟合启发式评分';

  @override
  String get calFitScoreNotice => '已解释峰功率比例 × exp(−RMS 残差 / 2)，不是经校准的正确概率。';

  @override
  String get calLiveNotice =>
      '实验性第一分音测量：750 毫秒窗 / 100 毫秒步，需连续 4 帧一致，响应慢于平均律模式。';

  @override
  String get calSelectedKey => '选定目标琴键';

  @override
  String get calNearestEt => '最近平均律音名（检测）';

  @override
  String get calIdentityNotice => '目标琴键由用户指定；拉伸目标的最近平均律音名可能不同，仅凭频率不能证明物理琴键身份。';

  @override
  String get calPianoSubtitle => '个体化模型拉伸 · 实验性';

  @override
  String get calUseHints => '使用先前模型的搜索中心';

  @override
  String get calHintsNotice =>
      '仅作搜索提示，不是有效调律目标。重采已拉伸琴键时请明确选择；新样本使旧曲线失效，需重新生成才能应用。';

  @override
  String get calHintUnavailable => '此键没有先前搜索提示，采样仍使用平均律关联范围。';

  @override
  String get calAssociationCenter => '当前采样关联中心';

  @override
  String get pauseMetronome => '暂停节拍器';

  @override
  String get resumeMetronome => '恢复节拍器';

  @override
  String get metronomePaused => '已暂停 · 保留拍位';

  @override
  String get metronomeTransition => '正在切换播放状态…';

  @override
  String get metronomeTransportNotice =>
      '暂停经短暂淡出后保留拍位与剩余间隔，恢复从该位置继续。停止清除位置，再开始从第 1 拍起。暂停仍独占播放；离页或进入后台后完全停止。';
}
