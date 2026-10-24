# 代数学

《代数学》是 R. EverStarine 编写的五卷本中文教材。从群、环、域出发，逐步进入模、交换代数、同调代数和表示论。各卷目录与先修关系见相应 PDF 及编导读。

## 五卷导览

| 卷次 | 主要内容 | 阅读 |
|---|---|---|
| 第一卷：群、环、域与 Galois 理论 | 群与对称、整除和多项式、域扩张与方程 | [正文 PDF](Book1.pdf) |
| 第二卷：模、多线性代数与非交换环 | 模与张量积、标准形、半单结构与非交换环 | [正文 PDF](Book2.pdf) |
| 第三卷：交换代数与代数几何方法 | 素谱与局部化、计算与维数、局部同调和几何初步 | [正文 PDF](Book3.pdf) |
| 第四卷：范畴与同调代数 | 范畴、复形与消解、同调方法和导出范畴 | [正文 PDF](Book4.pdf) |
| 第五卷：表示论：有限群、箭图与 Lie 代数 | 有限群表示、箭图、Lie 代数及相关专题 | [正文 PDF](Book5.pdf) |

五卷及已接受的扩充内容均已形成初稿，仍在修订和审核。

## 怎样阅读

具备本科线性代数、集合与映射以及基本证明训练的读者，可以从第一卷开始。读过群、环的基础后，也可以转入第二卷的模论，再按兴趣学习交换代数、同调代数或表示论。不必依卷次通读；各编导读说明了所需基础和可以暂缓的内容。

## 源码与编译

仓库发布五卷 TeX 源码、配套书目库与索引样式、构建脚本、五册 PDF 及本 README。各卷主文件为 `BookN/BookN.tex`，共用 `Shared/` 中的源文件；图与表均由 TeX 源码生成。

编译使用 XeLaTeX、Biber 和 MakeIndex，需要包含 ctex、unicode-math 等宏包的 TeX Live。当前字体设置另使用系统字体 Times New Roman 和 SimSun；字体设置见 `Shared/Preamble.tex`。

在项目根目录运行构建脚本，例如只编译第一卷：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./build.ps1 -Book 1
```

省略 `-Book 1` 则编译五卷。脚本在 `tmp/build/BookN/` 生成辅助文件，依次处理书目和三类索引，并在引用与索引页码稳定后更新根目录及卷目录 PDF。各卷的 `.ps1/.bat` 入口供单卷构建及 TeXstudio 快捷编译使用。

也可手工编译；以第一卷为例，在项目根目录依次执行：

```text
cd Book1
xelatex -interaction=nonstopmode -halt-on-error Book1.tex
biber Book1
makeindex -q -s ../Shared/algebra.ist chinese.idx
makeindex -q -s ../Shared/algebra.ist foreign.idx
makeindex -q -s ../Shared/algebra.ist symbols.idx
xelatex -interaction=nonstopmode -halt-on-error Book1.tex
xelatex -interaction=nonstopmode -halt-on-error Book1.tex
```

输出为 `Book1/Book1.pdf`。其他卷将 `Book1` 换成相应卷名。若日志仍提示重跑，继续运行 XeLaTeX；正文页码变化后重新生成三类索引，再编译至引用和页码稳定。源码头部的 TeXstudio 快捷命令调用各卷附带的构建入口。

## 版权声明

© 2026 R. EverStarine。保留所有权利。本项目未授予开放许可证；公开访问、下载或克隆仓库不构成改编、再许可或商业使用授权。第三方材料的权利归各自权利人所有。
