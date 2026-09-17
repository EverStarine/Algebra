# 代数学

R. EverStarine 编写的五卷本代数学专业书籍项目。目录以 [计划纲要](计划纲要.md) 为准，工程组织与通用排版参照“分析学”项目。

当前为**可编译的项目骨架**：已建立编、章、节、小节与附录，保留标题、选读标记及写作任务注释；正文、证明、习题与文献尚待编写。根目录 PDF 是目录与版式预览，不是完成稿。

## 五卷结构

| 卷 | 书名与源码入口 | 编 | 章 | 正文节 | 附录 | 附录节 | PDF 预览 |
|---|---|---:|---:|---:|---:|---:|---|
| 一 | [群、环、域与 Galois 理论](Book1/Book1.tex) | 3 | 22 | 89 | 5 | 19 | [Book1.pdf](Book1.pdf) |
| 二 | [模、多线性代数与非交换环](Book2/Book2.tex) | 4 | 20 | 84 | 4 | 17 | [Book2.pdf](Book2.pdf) |
| 三 | [交换代数与代数几何方法](Book3/Book3.tex) | 4 | 24 | 106 | 7 | 29 | [Book3.pdf](Book3.pdf) |
| 四 | [范畴与同调代数](Book4/Book4.tex) | 4 | 20 | 84 | 3 | 12 | [Book4.pdf](Book4.pdf) |
| 五 | [表示论：有限群、箭图与李代数](Book5/Book5.tex) | 4 | 22 | 95 | 5 | 18 | [Book5.pdf](Book5.pdf) |
| 合计 | | 19 | 108 | 458 | 24 | 95 | |

正文和原已分节附录共设 1,602 个小节，五卷依次为 288、279、426、266、343 个。附录节包括纲要原列的 35 节，以及根据其余 15 个附录主题补齐的 60 节。

每卷独立编号。12 个选读章、8 个选读节沿用纲要的星号；附录显示为 A、B、C……，不加卷号或选读星号。原纲要仅列主题的附录已据此补齐节标题；正文与原已分节附录的细目已整理成小节，显示为 `1.1.1`、`A.1.1` 等。五卷的学习次序与先修分流见纲要，不将出版顺序当作单一先修链。

## 文件组织

```text
Shared/                         五卷共用样式、字体、书目与索引样式
BookN/
  BookN.tex                     本卷主文件（N = 1, ..., 5）
  build-BookN.ps1 / .bat         本卷完整编译入口
  FrontMatter/                  书前内容与序言
  PartXX/
    PartXX.tex                  编题、编导读与章入口
    ChapterCC/
      ChapterCC.tex             章入口
      SectionCCSS.tex           第 CC 章第 SS 节，内含有编号的小节
  Appendices/
    Appendices.tex              附录总入口
    AppendixA/
      AppendixA.tex             附录 A 入口
      SectionA01.tex            附录 A.1，其他附录节依此命名
  BackMatter/                   后记、参考文献、中外文与符号索引
  Figures/ / Tables/            图表源码预留目录
scripts/Build-Book.ps1           五卷共用的编译逻辑
scripts/Check-Outline.ps1        纲要与目录完整性核验
build.ps1                       全部或指定卷编译
tmp/                            本地临时产物，不提交
Book1.pdf ... Book5.pdf          通过构建校验的五卷预览
```

TeX 文件采用 UTF-8。纲要节下的要点整理为简短的小节标题，完整原文保存在相应源文件的注释中，作为待写清单。小节写在所属节文件内，不再拆分单独文件；原未分节附录根据主题新增节文件。以后调整标题时同步检查入口、标签与相关纲要内容。不要用初始化生成器覆盖已经写好的正文。

## 编译

使用已有的 TeX Live，要求 `xelatex`、`biber` 和 `makeindex` 可用；共享样式使用 TeX Live 自带的 Fandol、TeX Gyre、Latin Modern 与 AMS 字体，不依赖本机商业字体。

从根目录编译全部五卷：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

只编译一卷：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Book 1
```

在 PowerShell 会话内可选择多卷：

```powershell
.\build.ps1 -Book 1,3
```

也可以双击 `BookN/build-BookN.bat`。在 TeXstudio 中打开 `BookN/BookN.tex` 后按“编译”或“构建并查看”，顶部魔法注释会调用同目录完整编译脚本。修改过魔法注释后请重新打开主文件。各节已配置根文档注释。

完整流程为 **XeLaTeX → 有引文时运行 Biber → 分别生成三类索引 → XeLaTeX 两轮 → 日志校验 → 更新 PDF**。空书目、空索引仍保留书后入口。有真实引用和索引条目后，完整构建会自动排入；无需改变主文件。辅助文件写入 `tmp/build/BookN/`。成功后将 PDF 复制到根目录，将 PDF 与 SyncTeX 复制到卷目录供 TeXstudio 预览和双向定位；卷目录的预览副本由 Git 忽略。

编译失败或存在未解决的引用、缺字、重复标签等问题时，脚本停止并保留日志，不覆盖已验收的根目录 PDF。优先修复现有安装与 PATH；脚本也会探测本机已有的 `D:\texstudio\texlive\2025\bin\windows`，且仅在当前进程内补充 PATH。

目录核验：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Check-Outline.ps1
```

## 写作与编辑规范

- [写作规范](写作规范.md)：写作层次、证明职责、章结构与习题。
- [格式规范](格式规范.md)：排版、文件组织与公共命令。
- [术语规范](术语规范.md)：代数主称、原文注解、符号与索引。
- [工作流程说明](工作流程说明.md)：编辑、构建、核验与交付。
- [书目维护注意事项](书目维护注意事项.md)：真实书目与引用核验。
- [审核进度](审核进度.md)：仅记录真实完成的写作与审核。
- [跨卷引用表](跨卷引用表.md)：证明归属、跨卷调用与先修。
- [版权声明](版权声明.md)：署名与使用权限。
- [AGENTS.md](AGENTS.md)：自动化编辑的工作入口。

迁移保留了分析学项目的通用排版、编译与编辑规则，删去其专有术语、正文及文献、既有图表候选、旧审核历史和模型绑定。`Shared/References.bib` 为空书目库；图表目录为空占位。未迁移分析学专用的本地技能。

## 仓库

目标仓库：[EverStarine/Algebra](https://github.com/EverStarine/Algebra)。提交源文件、规范与五份根目录 PDF；临时构建、文献原文件及编辑器预览副本不提交。项目当前未授予开放源代码或开放内容许可证，具体见版权声明。
