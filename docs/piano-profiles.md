# 本地钢琴档案格式与恢复

当前schema2追加calibration；旧schema1为基础元数据格式，读取保持不写，仅在显式保存时迁移。下文分别说明基础字段和校准扩展。

基础元数据包含：随机32位hex ID、1..80字符名称、digital/upright/grand、A4 400..480、当前MIDI21..108、创建/修改UTC与固定 `mode: equalTemperament`。旧schema1不保存音频、B、分音或拉伸曲线。这些是旧schema1字段，当前schema2校准扩展见下文。名称不成为路径。大小写不敏感的重复名称拒绝，最多64条；第65条显示容量提示，原64条仍能加载/更新。

Android通过独立偏好通道提供 `filesDir/pianos` 私有目录，Dart生产 `FileProfileStore` 写固定 `pianos.json`。根对象严格为schema=1、revision、selectedId、profiles四字段；版本未知时只读并显示不支持，不回退旧schema覆盖。档案字段类型/范围/唯一ID/重复名/选中ID/UTC时序及canonical ISO8601均校验。UTC日期须与Dart `toIso8601String()`完全一致，非法日历归一化也会拒绝。超过1 MiB、非法UTF-8或截断JSON视为损坏，不自动改成空档案。

写入先验证，按绝对目录串行并持有文件锁；保存须匹配expectedRevision且nextRevision=old+1，过期写拒绝。flush临时文件→保留上一份有效main为 `.bak` →同目录rename替换main。文件锁句柄在异常路径也关闭。没有声称跨进程断电恢复在所有文件系统上绝对可靠；手机进程终止/磁盘满/厂商文件系统仍待验证。

main损坏且backup有效时提供只读恢复预览；必须点击恢复才将损坏main改名保留 `pianos.corrupt-时间`，再从备份重建main。备份是**上一有效revision**，可能丢失最近一次修改。无可用备份时保持损坏文件并显示失败，不悄悄清空。未知schema不允许借恢复降级覆盖。

页面支持创建、重载、选取并应用到A4/类型/目标、明确勾选后更新；更新确认绑定ID/revision/本次操作代次，换档案或重载即失效。加载过程中后续A4/目标/类型/离页意图优先，晚到加载不能覆盖新选择。选中档案和当前设置不一致时明确提示已修改。启动档案加载有2秒界面超时；重试共享同一未完成读取，晚到结果不自动应用；不阻塞应用永久启动。文件写入依赖OS异步IO完成，不声称每个文件系统都有固定写时限。

主题/极简/A4由独立SharedPreferences schema2保存，schema1迁移默认A4=440；存储失败可见，不把失败说成已跨重启保存。语言仍跟随系统/会话选择，音频会话和测量不持久化。Android backup关闭，不提供云同步或导出。参考A4只是音律基准，**不是麦克风采样时钟/声压校准**。

生产文件存储测试在临时独立目录实际读写，包含重启式重载、重复名、双实例并发/过期revision、64容量、损坏/非法UTF-8/超限/未知schema/备份恢复。Flutter模拟测试覆盖档案UI与迟到请求，JVM覆盖生产请求参数不可变。手机跨重启/存储异常与系统授权仍未执行。


## schema2校准扩展

根仍为schema/revision/selectedId/profiles；schema=2，Profile增加calibration字段（可null）。校准对象精确9字段：algorithm/a4/kind/created/updated/samples/curve/hintAlgorithm/searchHints。测量含16阶以内观测、f_ideal/模型f1/观测第一分音/残差/B/敏感度/质量、原始会话与实际采样率后端、UTC/source；associationHz与associationAlgorithm成对记录已拉伸重采的已知关联中心。它们是搜索约束，不是频率真值。

曲线目标全部模型计算、B测量或区间内插值；读取时使用生产模型重算核对全部点。改样本清曲线，可保留最多88个有界searchHints；map非空必须有已知hintAlgorithm，空map必须显式null，字段缺失/未知或配对错误拒绝，任何未知非null版本均为schema只读错误，不借备份降级。兼容A4/琴型才可用提示，载入不自动激活目标。旧历史校准在元数据改变后保留但不可应用。

保存前按UTF8字节验证总档案≤1MiB，容量/过期写/未知schema/损坏恢复保护延用。实文件测试覆盖带>60c目标重采样本的来源/提示存取与重新生成，以及未知提示版本在空/非空map均不覆盖原文件。无PCM保存、无新增上传。完整语义与模型版本见[piano-calibration.md](piano-calibration.md)。
