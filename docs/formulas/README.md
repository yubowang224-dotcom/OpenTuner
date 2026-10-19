# 公式资源

本目录SVG使用完整分式、上下标、求和上下限和根式，正文以相对链接引用。公式内置白色背景、深色路径字形及可访问标题，不依赖外部字体、脚本、网络或浏览器数学插件；明暗主题均可显示。

source.json保存可编辑数学源、自然语言替代文字和生产源码位置。tools/render_formulas.py使用Matplotlib mathtext生成SVG，不调用外部TeX。重新生成与一致性检查命令分别为python tools/render_formulas.py和python tools/render_formulas.py --check。

长公式按定义拆行。每个公式的变量及数值保护条件在引用它的章节说明；代码中的离散样本索引不改作连续变量。更新公式时应核对source_refs指向的生产实现，并保留测量、跟踪和渲染状态的区别。

字形为STIX字体的SVG路径轮廓，许可证见FONT-LICENSE.txt；未分发字体二进制。公式与图形排版不改变算法或构成新的声学测量。
