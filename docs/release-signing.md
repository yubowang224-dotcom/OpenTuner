# 发布签名与维护者备份

## 公钥身份

正式证书为RSA3072/PKCS12，主体CN=OpenTuner Release，不代表学校或教师发布。证书SHA256：

`ae27b3e61d3d21419b6a45236bc9c56cbddcf05044a2311f56f4627d2eaf6892`

旧Debug证书为`a112fb5cd80d09a36b44cc7923fc8ce37884945fdcf05a7a5a53c6443add6064`。两者不同；[迁移说明](debug-to-release-migration.zh-CN.md)。签名只建立更新身份，不构成声学精度或设备兼容认证。

## 外部配置

官方私钥、密码和恢复材料不分发。`tools/build-release.ps1`只使用既有外部配置，不生成或替换密钥，拒绝工程内私钥、过宽文件权限、不完整环境和已有同名交付覆盖。Windows配置的schema为1，字段storeFile/keyAlias/passwordDpapi/certificateSha256；passwordDpapi由当前Windows用户DPAPI保护。配置位于工程外，持有原密钥的维护者可通过SigningConfigPath参数选择。

脚本在构建进程中解密并经四个环境变量传入Gradle：OPENTUNER_STORE_FILE、OPENTUNER_STORE_PASSWORD、OPENTUNER_KEY_ALIAS、OPENTUNER_KEY_PASSWORD。结束后恢复环境；日志写入前过滤私有值。Gradle配置缓存和自动堆转储关闭，签名构建不使用常驻daemon。未配置环境的开发/CI Release明确未签名，没有Debug兜底。

其他开发者应使用自己的外部签名材料；其APK不能作为官方同身份更新。不要把密码写入命令行、源码、Issue、构建日志或聊天。

## 版本与检查

0.7.0-beta.2所有ABI/通用APK的versionCode为5001，后续单调递增。force-version-code-ignoring-abi=true取消ABI*1000偏移，适用于这里的直接APK分发。

检查实际APK的apksigner签名、证书、包名/版本/最低API、原生库、许可证、Manifest及ELF/ZIP16KB对齐；不能只信文件名。静态检查不等于实际安装和设备运行。

## 离线备份

私有材料存于工程外的受限目录；默认维护者目录为`%LOCALAPPDATA%\OpenTuner\signing`。NTFS限定维护者账户与SYSTEM。DPAPI配置单独备份不足以支持换电脑或重装系统。

将原PKCS12、alias和敏感恢复资料一起保存在自己控制的离线加密介质，保留原件。恢复演练只在受控本机核公钥指纹，不打印密码。不要上传私钥、恢复文件或密码；公钥证书可以公开。当前未完成离线恢复演练，不能据文件存在保证可恢复。

丢失原密钥或密码可能失去后续更新能力。需要恢复时使用原PKCS12与恢复资料重建本机配置，不新建替代证书冒充原身份。
