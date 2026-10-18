# OpenTuner working agreement

- Follow the staged brief. Current local signed candidate is0.7.0-beta.2/code5001. Read docs/release-signing-report.md and migration/signing guidance. A dedicated key already exists outside the project: never regenerate/replace it or expose private material. All ABI/universal APKs share the dedicated certificate and unified versionCode. Phone/real-piano validation remains pending; mechanical calibration stays Experimental. Preserve all original history/old APKs.
- Android first; Flutter/Dart UI, portable C++ DSP, Android audio adapter. Revisit exact toolchain pins only with recorded compatibility evidence.
- Read `docs/requirements.md`, `docs/architecture.md`, and `docs/stage-0-report.md` before continuing implementation.
- Never use mock measurements or decorative waveforms to represent microphone input. Unsupported features must be visibly unavailable or experimental.
- Separate raw estimates, accepted/tracked pitch, and rendered needle state. Record invalid data and latency honestly.
- No allocation, locks, logging, I/O, JNI/Dart calls, FFT or pitch analysis in real-time audio callbacks. Use preallocated bounded queues and a worker.
- Mechanical piano analysis remains Experimental until real-piano validation. Electronic piano defaults to equal temperament. Distinguish ideal string parameter from measured first partial.
- All main UI strings belong in centralized English and Simplified Chinese localization resources. No permission request before user intent.
- Local processing; no audio upload, tracking SDKs or persistent raw recording by default. Inspect actual release manifest before privacy claims.
- Preserve existing tools and projects. Prefer project-local/session environment configuration over changing global Java/PATH settings.
- Run and record checks. Never mark skipped/unavailable checks passed. Each stage needs commands, evidence, limitations, device-test status and a Git commit.
- No remote repository creation, push, public release, history deletion or force push without the user's explicit authorization. Git author identity is not proof of GitHub authentication.
- Never commit tokens, signing material, local tool paths or build binaries. Local evidence belongs under ignored `artifacts/`; concise reviewed reports belong under `docs/`.

- Latest user changes: display/GitHub project name OpenTuner; retain applicationId/signing identity and existing directory/repository. User-provided cropped icon only, no redraw. Seven/twelve-string guitar requirements are canceled (keep six-string/shared DSP).
- User waived per-round phone acceptance: do not block work/publication waiting for phone feedback; label unperformed device/audio/latency checks honestly. Required automated/build/security/license checks remain. After all agreed Android scope is complete, user authorizes Codex to publish to GitHub directly, checking actual account/repository/scope first; ask only when a new ambiguous account/scope, private data or terms issue requires a user decision. Current Tools1 is not final Android completion and does not trigger remote actions. No forced pushes/history deletion.

- Navigation hotfix: read docs/navigationfix-report.md. Keep RouteTooltipsTransitions when merging paused appearance changes; do not restore old theme.dart over it. Code10 fixes controlled covered-tooltip/resize failures, not a verified cure for every phone assertion; framework6430 remains un-reproduced. Appearance/preferences/PCM waveform work has resumed and is delivered separately in docs/appearance-report.md. Preserve the navigation guard in both light/dark themes; the PCM display filter never changes the accepted pitch core.


## 2026-10-19 M1时点历史授权与交付（后续状态以前文及末条为准）

用户反馈此前手机红屏已解决；精确framework6430未在本机独立复现的历史边界保留，不把该反馈扩展为钢琴专业流程验收。M1实现七种六弦预设、原创拨弦参考音/App增益、较清晰的节拍器点击/App播放中音量与独立致谢页；详情见[M1验收报告](docs/m1-guitar-report.md)。M2全88键/专用音域评估/全局A4持久化/档案骨架与M3 Experimental分音/非谐性/个体曲线仍需实施，不以页面占位宣称完成；七/十二弦取消。

用户委托自主领导至Android完整约定范围/构建/测试/安全/许可审查后发布GitHub。使用实际连接账号，自行选择名称（优先OpenTuner）；发布前核归属/重名/远端，不能覆盖无关仓库、强推、删历史或公开凭证/私钥/隐私数据。当前M1不触发公开，不检查Gitee。GitHub完成后才考虑可选Gitee；只有可信额度明确剩余≥75%才尝试，未知/歧义则跳过，既有浏览器登录不授权新增OAuth/令牌/扩展持久访问。iOS在Android发布后同仓库推进。

发布前确保App及两README致谢忠实保留哈尔滨工业大学《数据分析与特征提取》课程、张淼老师、“顶级原则”、免费完整开源承诺与作者为大家服务的共产主义思想表达；不得虚构教师头衔/经历/背书，不篡改为别的理论或删除价值表达。当前源码尚未公开，不放假链接；正式公开后填入核实仓库地址。原始私人授权只在ignored artifacts保留，不随源码公开。

- GitHub only; Gitee was explicitly canceled. Remote publishing is coordinated by the main chat. Do not retry blocked GCM/file uploads or change account/extension settings without the specific new authorization. Chinese README.md first, English README.en.md, Chinese-compatible README.zh-CN.md.
