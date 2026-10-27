# 主虫洞的微分几何

**Ellis / Morris–Thorne 零潮汐力虫洞：从度规、4D 等距嵌入到测地线渲染**

> **范围**：本文只讲项目里的**主虫洞**（主喉口 B↔C），不讨论同空间虫洞组件（球面口 / 4D 管道）。
> **代码基线**：工作区 v37 的 `scripts/main.gd` 与 `shaders/wormhole4d.gdshader`。
> 主虫洞的 `surf_*`/`cat_*` 函数在 v36→v37 之间没有改变；v37 的 `render_scene` 增加了同空间组件的 `world_*` 包装，主虫洞路径不变。README 的“虫洞组件”章节仍是 v36 的球面口方案，本文不涉及。

**目录**

1. [约定与记号](#1-约定与记号)
2. [从 Morris–Thorne 度规到 Ellis 虫洞](#2-从-morristhorne-度规到-ellis-虫洞)
3. [4D 等距嵌入](#3-4d-等距嵌入悬链线悬链面超悬链面)
4. [内蕴几何：度规、测地线、曲率](#4-内蕴几何度规测地线曲率)
5. [外蕴几何：超曲面如何在 R⁴ 里弯曲](#5-外蕴几何超曲面如何在-r4-里弯曲)
6. [观察者、光线与约束积分](#6-观察者光线与约束积分)
7. [渲染管线](#7-渲染管线从公式到像素)
8. [拓扑、物理与可穿越性](#8-拓扑物理与可穿越性)
9. [常见误解](#9-常见误解)
10. [代码索引](#10-代码索引)
- [附录 A：公式速查](#附录-a公式速查)
- [附录 B：参考文献](#附录-b参考文献)

---

## 0. 一句话概括

项目把**三维弯曲空间本身**实现为四维欧氏空间中的一张超曲面

$$
\Sigma:\quad \rho=b_0\cosh\!\left(\frac{w}{b_0}\right),
\qquad \rho=\sqrt{x^2+y^2+z^2},
$$

其中 $b_0=3\,\text{m}$ 是喉半径。观察者生活在这张三维超曲面上，位置每帧被投影回 $\Sigma$；光线沿 $\Sigma$ 的测地线传播。$w=0$ 处的**喉口**是一个半径 $b_0$ 的极小 2-球，$w\to\pm\infty$ 是同一张流形的两个渐近平直端（宇宙 B 与 C）。

**虫洞不是空间里的管子，也不是传送门；虫洞就是空间本身的曲率与拓扑。** 穿过喉口 = 沿空间连续飞行到另一端，没有任何传送/映射规则。

---

## 1. 约定与记号

### 1.1 嵌入空间

环境空间是**四维欧氏空间** $\mathbb{R}^4$，坐标

$$
X^\mu=(x,y,z,w),\qquad \mu=1,2,3,4,
$$

度规

$$
\delta_{\mu\nu}=\operatorname{diag}(1,1,1,1).
$$

四个坐标**全部是空间坐标**。$w$ 是嵌入坐标，**不是时间**。这一点是理解整个项目的关键。

### 1.2 物理时空

实际的四维时空度规是

$$
ds^2=-dt^2+ds_\Sigma^2,
$$

即时间方向与三维空间 $\Sigma$ 的直积。项目只渲染 $t=\text{const}$ 的空间切片，因为：

- 度规是**静态**的（$g_{tt}=-1$ 与 $t$ 无关）；
- 观察者是**静态**的（不按测地线自由下落，而是悬停在 $\Sigma$ 上）；
- 光线的空间路径只由 $ds_\Sigma^2$ 决定（见 §4.6）。

因此渲染器只需要 $\Sigma$ 的三维几何，不需要积分时间。

### 1.3 坐标与参数

| 符号 | 定义 | 含义 |
|---|---|---|
| $b_0$ | `THROAT_R`，默认 $3$ | Morris–Thorne 喉半径 |
| $w$ | 第 4 个嵌入坐标 | 嵌入空间中的轴向坐标，**不是**固有距离 |
| $u$ | $u=w/b_0$ | 无量纲坐标；HUD 显示的就是它 |
| $l$ | $l=b_0\sinh u$ | 从喉口量起的**有符号固有距离** |
| $\rho$ | $\rho=\sqrt{x^2+y^2+z^2}$ | 面积半径（areal radius） |
| $\theta,\varphi$ | 球坐标 | $\hat n=(\sin\theta\cos\varphi,\sin\theta\sin\varphi,\cos\theta)$ |
| $B$ | $w<0$（$u<0,l<0$） | 宇宙 B（“家”，冷色） |
| $C$ | $w>0$（$u>0,l>0$） | 宇宙 C（“远”，暖色） |

三套坐标的关系：

$$
\rho=b_0\cosh u=\sqrt{l^2+b_0^2},
\qquad
w=b_0u=b_0\operatorname{asinh}\!\left(\frac{l}{b_0}\right).
$$

喉口：$u=w=l=0,\ \rho=b_0$。

---

## 2. 从 Morris–Thorne 度规到 Ellis 虫洞

### 2.1 Morris–Thorne 的一般形式

静态、球对称、可穿越虫洞的 Morris–Thorne 度规：

$$
ds^2=-e^{2\Phi(r)}dt^2
+\frac{dr^2}{1-b(r)/r}
+r^2\,d\Omega^2,
\qquad
d\Omega^2=d\theta^2+\sin^2\theta\,d\varphi^2.
$$

- $\Phi(r)$：红移函数（redshift function）；
- $b(r)$：形状函数（shape function）；
- 喉口 $r_0$ 满足 $b(r_0)=r_0$；
- 可穿越条件：$b'(r_0)<1$（flare-out）、$\Phi$ 有限、无事件视界；
- 一般需要违反零能量条件（NEC）的“奇异物质”。

### 2.2 Ellis 特例：零潮汐力

项目取

$$
\Phi(r)\equiv 0,
\qquad
b(r)=\frac{b_0^2}{r}.
$$

这是 Ellis（1973）/ Bronnikov（1973）的**零潮汐力虫洞**，也是 Morris–Thorne 类中最简单、且能全局嵌入 $\mathbb{R}^4$ 的成员之一。

喉口在 $r=b_0$：$b(b_0)=b_0$，且

$$
b'(b_0)=-\frac{b_0^2}{b_0^2}=-1<1,
$$

满足 flare-out。

### 2.3 固有距离与约化度规

定义径向固有距离

$$
l(r)=\int_{b_0}^{r}\frac{dr'}{\sqrt{1-b_0^2/r'^2}}
=\sqrt{r^2-b_0^2}.
$$

于是

$$
r^2=l^2+b_0^2,
\qquad
dr^2\left(1-\frac{b_0^2}{r^2}\right)^{-1}=dl^2.
$$

三维空间度规化为

$$
\boxed{
ds_\Sigma^2=dl^2+(l^2+b_0^2)\,d\Omega^2
}
$$

这就是 README 开头写的度规。$l$ 可以为负：$l<0$ 是宇宙 B，$l>0$ 是宇宙 C，$l=0$ 是喉口。度规只依赖 $l^2$，所以 $l\to-l$ 是等距对称。

### 2.4 两个端、无 horizon、零潮汐力

- **两个渐近平直端**：$l\to\pm\infty$ 时 $r\approx|l|$，度规趋于 $dl^2+l^2d\Omega^2$，即平直 $\mathbb{R}^3$ 的球坐标形式。两端是同一张连通流形的两个“尽头”。
- **无事件视界**：$g_{tt}=-1$ 处处非零，没有 $g_{tt}=0$ 的面；喉口不是 horizon。
- **零潮汐力**：$\Phi=0\Rightarrow g_{tt}$ 为常数。对静态观察者 $u^\mu=(1,0,0,0)$，潮汐张量
  $$
  E_{ij}=R_{i t j t}=0
  $$
  （因为度规是 $t$ 与 $\Sigma$ 的直积）。这就是“零潮汐力”的严格含义：静态观察者不会被潮汐力撕开。
- **但时空并不平**：Kretschmann 标量非零（见 §4.7）。“零潮汐力”不等于“零曲率”。

### 2.5 为什么需要奇异物质

对 Ellis 度规，取 $G=c=1$，爱因斯坦张量的 $tt$ 分量为

$$
G_{tt}=\frac{1}{2}R^{(3)}
=-\frac{b_0^2}{(l^2+b_0^2)^2}
=-\frac{b_0^2}{\rho^4}.
$$

因此静态观察者测得的能量密度（用 $\varepsilon$ 表示，避免和面积半径 $\rho$ 混淆）

$$
\varepsilon=T_{tt}=\frac{G_{tt}}{8\pi}
=-\frac{b_0^2}{8\pi\rho^4}<0.
$$

径向压强同为负：

$$
p_r=T_{ll}=-\frac{b_0^2}{8\pi\rho^4},
\qquad
p_\theta=T_{\hat\theta\hat\theta}=+\frac{b_0^2}{8\pi\rho^4}.
$$

径向零矢量 $k^\mu=(1,1,0,0)$ 给出

$$
T_{\mu\nu}k^\mu k^\nu
=\varepsilon+p_r
=-\frac{b_0^2}{4\pi\rho^4}<0,
$$

**违反零能量条件（NEC）**。这就是虫洞需要“奇异物质”的数学来源；项目把它当作几何模型，不模拟物质来源。

---

## 3. 4D 等距嵌入：悬链线、悬链面、超悬链面

### 3.1 嵌入 ansatz

把三维空间 $\Sigma$ 嵌入 $\mathbb{R}^4$，用柱坐标 $(\rho,\theta,\varphi,w)$：

$$
ds^2=d\rho^2+\rho^2d\Omega^2+dw^2.
$$

希望它诱导出

$$
ds_\Sigma^2=dl^2+(l^2+b_0^2)d\Omega^2.
$$

匹配 $d\Omega^2$ 的系数：

$$
\rho^2=l^2+b_0^2.
$$

匹配径向部分：

$$
d\rho^2+dw^2=dl^2.
$$

由 $\rho^2=l^2+b_0^2$ 得 $\rho\,d\rho=l\,dl$，所以

$$
d\rho=\frac{l}{\sqrt{l^2+b_0^2}}\,dl,
$$

$$
dw^2=dl^2-d\rho^2
=dl^2\left(1-\frac{l^2}{l^2+b_0^2}\right)
=\frac{b_0^2}{l^2+b_0^2}dl^2.
$$

取 $w(0)=0$：

$$
w=\int_0^l\frac{b_0\,dl'}{\sqrt{l'^2+b_0^2}}
=b_0\operatorname{asinh}\!\left(\frac{l}{b_0}\right).
$$

反解：

$$
l=b_0\sinh\!\left(\frac{w}{b_0}\right),
\qquad
\rho=\sqrt{l^2+b_0^2}
=b_0\cosh\!\left(\frac{w}{b_0}\right).
$$

于是

$$
\boxed{
\Sigma:\quad \rho=b_0\cosh\!\left(\frac{w}{b_0}\right)
}
$$

参数形式（与 README 完全一致）：

$$
P(u,\theta,\varphi)=
\bigl(
b_0\cosh u\;\hat n(\theta,\varphi),
\;b_0u
\bigr),
\qquad u=\frac{w}{b_0}.
$$

### 3.2 几何图像

- 在 $(w,\rho)$ 半平面里，曲线 $\rho=b_0\cosh(w/b_0)$ 是一条**悬链线**（catenary），最小值在 $(0,b_0)$。
- 把这条曲线绕 $w$ 轴旋转，得到二维**悬链面**（catenoid）：这是 $\theta=\pi/2$ 的赤道截面，也就是项目里的“悬链面地板”。
- 再把 $S^2$ 纤维加上去（$\theta,\varphi$ 都变化），得到三维**超悬链面**（hyper-catenoid）：这才是观察者生活的三维空间 $\Sigma$。
- 喉口是 $w=0$ 处的 $S^2$，半径 $b_0$，是整张超曲面的“腰”。

**关键区别**：

| 对象 | 维数 | 嵌入空间 | 说明 |
|---|---|---|---|
| 悬链线 $\rho=b_0\cosh(w/b_0)$ | 1D | $\mathbb{R}^2$ | 生成曲线 |
| 悬链面（赤道/地板） | 2D | $\mathbb{R}^3\subset\mathbb{R}^4$ | 视图 ② 的嵌入图曲面；极小曲面 |
| 超悬链面 $\Sigma$ | 3D | $\mathbb{R}^4$ | 观察者生活的物理空间 |

### 3.3 嵌入是等距的，不是“示意图”

上面的推导不是可视化技巧：诱导度规逐项等于 Ellis 度规。因此

- $\Sigma$ 的**内蕴曲率**完全由它在 $\mathbb{R}^4$ 中的**外蕴弯曲**（第二基本形式）产生；
- 环境 $\mathbb{R}^4$ 是平的，所有曲率都是 $\Sigma$ 的 extrinsic curvature；
- 这就是为什么可以用“4D 中的一张曲面”来精确表示弯曲空间。

一般地，$n$ 维黎曼流形等距嵌入 $\mathbb{R}^{n(n+1)/2}$：解析情形是 Janet–Cartan 定理，光滑情形是 Nash 嵌入定理；$n=3$ 一般需要 $\mathbb{R}^6$。Ellis 度规的特殊性在于它只需要 $\mathbb{R}^4$——这正是项目能实时渲染的原因。

### 3.4 渐近平直与固有距离

由 $\rho=b_0\cosh u$：

- $u\to\pm\infty$：$\rho\approx\frac{b_0}{2}e^{|u|}$，$l\approx\frac{b_0}{2}e^{|u|}$，所以 $\rho\approx|l|$，度规趋于 $dl^2+l^2d\Omega^2$，即平直空间；
- $u=0$：$\rho=b_0$ 最小；
- 固有距离 $|l|=b_0|\sinh u|$ 随 $|u|$ 指数增长。代码的逃逸阈值 $|w|=55$ 对应
  $$
  |l|\approx\frac{b_0}{2}e^{55/3}\approx1.4\times10^8\ \text{m},
  $$
  已经远到可以视为无穷远。所以 $w=55$ 只是坐标截断，不是物理边界。

### 3.5 嵌入图（视图 ②）

`embed_diagram()` 画的是 $(w,\rho)$ 半平面里的悬链线：

$$
\rho=b_0\cosh(w/b_0),
$$

横轴 $w\in[-32,32]$，纵轴 $\rho\in[0,44]$，并标出观察者 $(w,\rho)$ 和喉口 $(0,b_0)$。这是**子午面截面**，不是整个三维空间；整个三维空间是这条曲线绕 $w$ 轴旋转再加 $S^2$ 纤维。

---

## 4. 内蕴几何：度规、测地线、曲率

### 4.1 诱导度规的三种写法

**(a) $l$ 坐标（固有距离）**

$$
ds_\Sigma^2=dl^2+(l^2+b_0^2)\bigl(d\theta^2+\sin^2\theta\,d\varphi^2\bigr).
$$

**(b) $u$ 坐标（无量纲）**

由 $dl=b_0\cosh u\,du$，$l^2+b_0^2=b_0^2\cosh^2u$：

$$
ds_\Sigma^2
=b_0^2\cosh^2u
\bigl(du^2+d\theta^2+\sin^2\theta\,d\varphi^2\bigr).
$$

这是共形于 $du^2+d\Omega^2$ 的形式。实际上 Ellis 三维空间还是**共形平直**的：令 $s=e^u$，则

$$
du^2+d\Omega^2
=\frac{1}{s^2}\bigl(ds^2+s^2d\Omega^2\bigr),
$$

而 $ds^2+s^2d\Omega^2$ 正是平直 $\mathbb{R}^3$ 的球坐标度规。因此

$$
ds_\Sigma^2
=\Omega^2(s)\bigl(ds^2+s^2d\Omega^2\bigr),
\qquad
\Omega^2(s)=\frac{b_0^2\cosh^2(\ln s)}{s^2}.
$$

这说明 Ellis 空间的内蕴曲率虽然非零（$R^{(3)}=-2b_0^2/\rho^4$），但它的共形结构是平凡的；曲率全部来自共形因子 $\Omega$。

**(c) $w$ 坐标（嵌入坐标）**

由 $dw=b_0du$：

$$
ds_\Sigma^2
=\cosh^2u\,dw^2
+b_0^2\cosh^2u\,d\Omega^2.
$$

### 4.2 Christoffel 符号

对 $ds^2=dl^2+f(l)^2d\Omega^2$，$f^2=l^2+b_0^2$，$f'=l/f$，非零分量为

$$
\begin{aligned}
\Gamma^l{}_{\theta\theta}&=-f f'=-l, &
\Gamma^l{}_{\varphi\varphi}&=-f f'\sin^2\theta=-l\sin^2\theta,\\
\Gamma^\theta{}_{l\theta}&=\frac{f'}{f}=\frac{l}{f^2}, &
\Gamma^\theta{}_{\varphi\varphi}&=-\sin\theta\cos\theta,\\
\Gamma^\varphi{}_{l\varphi}&=\frac{f'}{f}=\frac{l}{f^2}, &
\Gamma^\varphi{}_{\theta\varphi}&=\cot\theta.
\end{aligned}
$$

### 4.3 测地线方程

$$
\begin{aligned}
l''-l\bigl(\theta'^2+\sin^2\theta\,\varphi'^2\bigr)&=0,\\
\theta''+2\frac{l}{f^2}l'\theta'-\sin\theta\cos\theta\,\varphi'^2&=0,\\
\varphi''+2\frac{l}{f^2}l'\varphi'+2\cot\theta\,\theta'\varphi'&=0.
\end{aligned}
$$

（撇号是对仿射参数求导。）

在赤道面 $\theta=\pi/2$、$\theta'=0$ 上：

$$
l''=l\varphi'^2,
\qquad
\varphi''+2\frac{l}{f^2}l'\varphi'=0.
$$

第二式给出守恒的角动量

$$
L=f^2\varphi'=(l^2+b_0^2)\varphi'=\text{const}.
$$

对单位速度的空间测地线：

$$
l'^2+f^2\varphi'^2=1
\quad\Longrightarrow\quad
l'^2=1-\frac{L^2}{l^2+b_0^2}.
$$

### 4.4 临界碰撞参数与光线分类

令 $L$ 为碰撞参数（impact parameter）。转折点 $l_t$ 满足 $l'^2=0$：

$$
L^2=l_t^2+b_0^2.
$$

- $L<b_0$：$l_t$ 不存在；光线**穿过喉口** $l=0$，进入另一个宇宙。
- $L>b_0$：光线在 $l_t=\sqrt{L^2-b_0^2}$ 处折返，回到同一侧。
- $L=b_0$：临界光线，$l_t=0$；它**渐近地绕喉口螺旋**，永不穿过也永不折返。

因此**临界碰撞参数就是喉半径 $b_0$**。这是 Ellis 虫洞最干净的解析结果之一。

### 4.5 偏折积分、多重像、爱因斯坦环

由 $d\varphi/dl=L/(f^2\sqrt{1-L^2/f^2})$，令 $l=b_0\sinh u$：

$$
d\varphi=\frac{L\,du}{\sqrt{b_0^2\cosh^2u-L^2}}.
$$

对 $L>b_0$，光线从 $u=-\infty$ 到转折点 $u_t=\operatorname{arcosh}(L/b_0)$ 再回到 $u=-\infty$，总偏折角

$$
\Delta\varphi
=2\int_{u_t}^{\infty}
\frac{L\,du}{\sqrt{b_0^2\cosh^2u-L^2}}
-\pi.
$$

- $L\to\infty$：$\Delta\varphi\to0$（远离喉口，近似直线）；
- $L\to b_0^+$：积分在 $u_t\to0$ 处对数发散，$\Delta\varphi\to\infty$；
- 因此存在**多重像**：不同绕行圈数的光线给出同一光源的不同像；当光源、观察者、喉口严格对齐时，像合并成**爱因斯坦环**。环的角半径由 $L=b_0$ 决定。

对 $L<b_0$，光线穿过喉口，总方位角变化为

$$
\Delta\varphi_{\text{pass}}
=\int_{-\infty}^{\infty}
\frac{L\,du}{\sqrt{b_0^2\cosh^2u-L^2}}
-\pi,
$$

它在另一个宇宙中形成“透过去”的像。

> 代码里的光线步进不是解析积分；它用约束积分器逐像素追踪测地线（§6），所以这些像会自然出现，但数值上会有步长/终止条件带来的误差。

### 4.6 时空零测地线为什么退化为空间测地线

四维时空度规 $ds^2=-dt^2+ds_\Sigma^2$ 是 $t$ 与 $\Sigma$ 的直积。对零测地线：

$$
-dt^2+dl^2+f^2d\Omega^2=0.
$$

守恒量：

$$
E=\dot t,\qquad L=f^2\dot\varphi.
$$

径向方程：

$$
\dot l^2=E^2-\frac{L^2}{f^2}.
$$

空间路径的方程与 §4.3 的单位速度空间测地线完全同形（把 $E$ 吸收进仿射参数）。因此**光线在空间中的路径就是 $\Sigma$ 的测地线**；时间只决定到达时刻，不影响形状。渲染器不需要时间维。

### 4.7 曲率

对三维度规 $ds^2=dl^2+f^2d\Omega^2$，$f^2=l^2+b_0^2$：

**赤道二维截面的高斯曲率**

$$
K=-\frac{f''}{f}
=-\frac{b_0^2}{(l^2+b_0^2)^2}
=-\frac{b_0^2}{\rho^4}.
$$

**三维 Ricci 张量（正交标架）**

$$
R_{ll}=-\frac{2f''}{f}
=-\frac{2b_0^2}{\rho^4},
\qquad
R_{\theta\theta}=R_{\varphi\varphi}=0.
$$

**三维 Ricci 标量**

$$
R^{(3)}=-\frac{2b_0^2}{\rho^4}.
$$

**Kretschmann 标量**

三维中 $R_{ijkl}R^{ijkl}=4R_{ij}R^{ij}-R^2$，代入得

$$
K_{\text{Kretschmann}}
=\frac{12b_0^4}{\rho^8}.
$$

在喉口 $\rho=b_0$：

$$
R^{(3)}=-\frac{2}{b_0^2},
\qquad
K_{\text{Kretschmann}}=\frac{12}{b_0^4}.
$$

曲率尺度是 $b_0$。$b_0=3\,\text{m}$ 时，喉口曲率半径也是米量级——这是一个“人类尺度”的虫洞，不是天体物理尺度。

**符号的含义**：$K<0$ 表示赤道截面像马鞍面（负曲率）。Schwarzschild 的 Flamm 抛物面在二维赤道截面上也呈负高斯曲率（它也是向外张开的“喇叭口”），但两者的三维曲率结构不同：Schwarzschild 是真空（三维空间 Ricci 为零），其潮汐力由 Weyl 张量描述；Ellis 的三维空间 Ricci 非零（由奇异物质支撑），但静态潮汐张量 $R_{itjt}$ 为零。Ellis 虫洞是“无质量”的，喉口附近是负曲率。

### 4.8 喉口是极小曲面

横截面积（$w=\text{const}$ 的 $S^2$）：

$$
A(w)=4\pi\rho^2=4\pi b_0^2\cosh^2\!\left(\frac{w}{b_0}\right).
$$

$$
A'(0)=0,
\qquad
A''(0)=8\pi>0.
$$

所以 $w=0$ 是面积的极小值——这就是 flare-out 的几何表现。

更强地，喉口 $S^2$ 在 $\Sigma$ 中是**全测地**（totally geodesic）的。半径为 $r=\rho$ 的球面在 $\Sigma$ 中的外蕴曲率（相对于 $\partial_l$ 方向，记为 $k_{ab}$，以区别于高斯曲率 $K$）为

$$
k_{ab}=\frac{f'}{f}h_{ab}
=\frac{l}{l^2+b_0^2}h_{ab},
$$

在 $l=0$ 处 $k_{ab}=0$。因此：

- 切于喉口的测地线会一直留在喉口上（走 $S^2$ 的大圆）；
- 横穿喉口的测地线会平滑地穿到另一侧；
- 喉口是 $l\to-l$ 等距对称的**不动点集**。

### 4.9 测地线偏离与“零潮汐力”的精确含义

测地线偏离方程：

$$
\frac{D^2\xi^\mu}{d\tau^2}
=-R^\mu{}_{\nu\rho\sigma}u^\nu\xi^\rho u^\sigma.
$$

对静态观察者 $u^\mu=(1,0,0,0)$：

$$
\frac{D^2\xi^i}{d\tau^2}
=-R^i{}_{t j t}\xi^j=0,
$$

因为 $R_{itjt}=0$。所以静态观察者之间的测地线偏离为零——没有潮汐力。

但 $R_{ijkl}\neq0$，Kretschmann 标量非零。**零潮汐力只说明 $R_{itjt}=0$，不说明时空平坦。** 这是 Ellis 虫洞最容易被误解的地方之一。

---

## 5. 外蕴几何：超曲面如何在 R⁴ 里弯曲

### 5.1 法向量与第二基本形式

隐式曲面

$$
F(p)=\rho-b_0\cosh\!\left(\frac{w}{b_0}\right)=0.
$$

梯度：

$$
\nabla F=
\left(
\frac{x}{\rho},\frac{y}{\rho},\frac{z}{\rho},
-\sinh\!\left(\frac{w}{b_0}\right)
\right)
=
\left(
\hat n,\;-\sinh u
\right).
$$

单位法向：

$$
N=\frac{\nabla F}{|\nabla F|}
=
\left(
\frac{\hat n}{\cosh u},\;-\tanh u
\right),
\qquad
|N|=1.
$$

参数化 $X(u,\theta,\varphi)=(b_0\cosh u\,\hat n,\;b_0u)$。切向量：

$$
\begin{aligned}
X_u&=(b_0\sinh u\,\hat n,\;b_0),\\
X_\theta&=b_0\cosh u\;e_\theta,\\
X_\varphi&=b_0\cosh u\sin\theta\;e_\varphi.
\end{aligned}
$$

二阶导数与第二基本形式（坐标基）：

$$
\Pi_{uu}=b_0,
\qquad
\Pi_{\theta\theta}=-b_0,
\qquad
\Pi_{\varphi\varphi}=-b_0\sin^2\theta.
$$

即

$$
\Pi=b_0\bigl(du^2-d\theta^2-\sin^2\theta\,d\varphi^2\bigr).
$$

### 5.2 主曲率、平均曲率

在正交标架

$$
\hat e_u=\frac{X_u}{|X_u|},\qquad
\hat e_\theta=\frac{X_\theta}{|X_\theta|},\qquad
\hat e_\varphi=\frac{X_\varphi}{|X_\varphi|}
$$

中，形状算子（shape operator）的本征值——主曲率——为

$$
\kappa_u=+\frac{1}{b_0\cosh^2u},
\qquad
\kappa_\theta=\kappa_\varphi=-\frac{1}{b_0\cosh^2u}.
$$

平均曲率：

$$
H=\frac{1}{3}(\kappa_u+\kappa_\theta+\kappa_\varphi)
=-\frac{1}{3b_0\cosh^2u}.
$$

在喉口 $u=0$：

$$
(\kappa_u,\kappa_\theta,\kappa_\varphi)
=\left(+\frac{1}{b_0},-\frac{1}{b_0},-\frac{1}{b_0}\right),
\qquad
H=-\frac{1}{3b_0}\neq0.
$$

**注意**：三维超曲面 $\Sigma$ 不是极小曲面（$H\neq0$）。真正极小的是它的二维赤道截面——悬链面。

### 5.3 二维悬链面 vs 三维超悬链面

赤道截面 $\theta=\pi/2$（$z=0$）的参数化：

$$
(x,y,w)=(\rho\cos\varphi,\rho\sin\varphi,w),
\qquad
\rho=b_0\cosh(w/b_0).
$$

这是 $\mathbb{R}^3$ 中的**悬链面**（catenoid）：

- 两个主曲率 $\pm1/(b_0\cosh^2u)$，和为零；
- 平均曲率 $H_{2D}=0$：**极小曲面**；
- 高斯曲率 $K=-b_0^2/\rho^4$；
- 这就是视图 ② 的嵌入图曲面，也是项目里的“悬链面地板”。

而完整的三维空间是这条悬链面加 $S^2$ 纤维的**超悬链面**；它的平均曲率不为零。两者的关系：

$$
\text{悬链线}\;\xrightarrow{\text{绕 }w\text{ 轴旋转}}\;
\text{二维悬链面（地板）}
\;\xrightarrow{\text{加 }S^2\text{ 纤维}}\;
\text{三维超悬链面（物理空间）}.
$$

### 5.4 Gauss 方程：内蕴曲率来自外蕴弯曲

环境 $\mathbb{R}^4$ 平坦，所以 Gauss 方程给出

$$
R^\Sigma_{abcd}
=\Pi_{ac}\Pi_{bd}-\Pi_{ad}\Pi_{bc}.
$$

用主曲率表示截面曲率：

$$
K_{u\theta}=\kappa_u\kappa_\theta
=-\frac{1}{b_0^2\cosh^4u},
\qquad
K_{u\varphi}=-\frac{1}{b_0^2\cosh^4u},
\qquad
K_{\theta\varphi}=\kappa_\theta\kappa_\varphi
=+\frac{1}{b_0^2\cosh^4u}.
$$

Ricci：

$$
R_{uu}=K_{u\theta}+K_{u\varphi}
=-\frac{2}{b_0^2\cosh^4u}
=-\frac{2b_0^2}{\rho^4},
\qquad
R_{\theta\theta}=R_{\varphi\varphi}=0.
$$

与 §4.7 完全一致。**内蕴曲率不是另加的东西，而是外蕴弯曲的平方。** 这就是 Gauss 的 Theorema Egregium 在平坦环境中的形式，也是“弯曲空间 = 4D 中的超曲面”的数学内容。

外蕴几何的另一半是 Codazzi–Mainardi 方程：

$$
\nabla_a\Pi_{bc}-\nabla_b\Pi_{ac}=0.
$$

环境 $\mathbb{R}^4$ 平坦时它自动成立：嵌入的混合偏导可交换，$\partial_a\partial_b X=\partial_b\partial_a X$，取法向分量即得 Codazzi–Mainardi。Gauss + Codazzi–Mainardi 一起保证：这张超曲面的内蕴几何与它在 $\mathbb{R}^4$ 中的外蕴弯曲完全自洽。

### 5.5 喉口的全测地性与 flare-out

喉口 $S^2$ 作为 $\Sigma$ 的子流形，其外蕴曲率 $k_{ab}=(l/f^2)h_{ab}$ 在 $l=0$ 为零：

- 它是 $\Sigma$ 中的**极小曲面**（平均曲率零）；
- 它是 $l\to-l$ 等距的**不动点集**；
- 面积 $A(w)$ 在 $w=0$ 取极小。

这就是 Morris–Thorne 的 flare-out 条件在几何上的完整图像。

---

## 6. 观察者、光线与约束积分

### 6.1 观察者的 4D 正交标架

观察者位置 $p\in\Sigma$，携带一个四维正交标架

$$
(n,\;e_1,e_2,e_3),
\qquad
n=N(p),\quad e_i\in T_p\Sigma,
$$

其中 $n$ 是 $\Sigma$ 的单位法向，$e_1,e_2,e_3$ 是切空间的三个正交基。对应代码：

- `n_axis` = $n$；
- `fwd` = 视线方向 $e_1$；
- `right` = 右方向 $e_2$；
- `up` = 上方向 $e_3$。

鼠标/键盘的转身是在切空间内做 $SO(3)$ 旋转：

$$
e_1'=\cos\alpha\,e_1+\sin\alpha\,e_2,
\qquad
e_2'=-\sin\alpha\,e_1+\cos\alpha\,e_2,
$$

法向 $n$ 不变。`_rot_pair(i,j,ang)` 就是实现这个二维旋转。

移动后，标架用 Gram–Schmidt 重新正交化（`_make_ortho`）：

$$
e_1\leftarrow \frac{e_1-(e_1\cdot n)n}{|e_1-(e_1\cdot n)n|},
$$

$$
e_2\leftarrow \frac{e_2-(e_2\cdot n)n-(e_2\cdot e_1)e_1}{|\cdots|},
\qquad
e_3\leftarrow \frac{e_3-(e_3\cdot n)n-(e_3\cdot e_1)e_1-(e_3\cdot e_2)e_2}{|\cdots|}.
$$

这保证标架始终是 $T_p\Sigma$ 的正交基。

### 6.2 位置投影：牛顿迭代

观察者每帧先做自由移动 $p\leftarrow p+v\Delta t$，然后投影回 $\Sigma$：

$$
p\leftarrow p-\frac{F(p)}{|\nabla F(p)|^2}\nabla F(p),
$$

迭代 3 次（`surf_project`）。这是隐式曲面 $F=0$ 的牛顿投影；对靠近曲面的点二次收敛。投影后位置在数值精度内回到 $\Sigma$ 上，法向由 `surf_normal` 重新计算。

代码：

```gdscript
func surf_f(p: Vector4) -> float:
    return Vector3(p.x, p.y, p.z).length() - THROAT_R * cosh(p.w / THROAT_R)

func surf_grad(p: Vector4) -> Vector4:
    var rho := Vector3(p.x, p.y, p.z).length()
    var g3 := Vector3.ZERO
    if rho > 0.0001:
        g3 = Vector3(p.x, p.y, p.z) / rho
    return Vector4(g3.x, g3.y, g3.z, -sinh(p.w / THROAT_R))

func surf_project(p: Vector4) -> Vector4:
    for i in 3:
        var g := surf_grad(p)
        var f := surf_f(p)
        p -= g * f / maxf(g.dot(g), 0.000001)
    return p
```

对应数学：

$$
\nabla F=
\left(\hat n,-\sinh u\right),
\qquad
|\nabla F|^2=1+\sinh^2u=\cosh^2u,
$$

$$
N=\frac{\nabla F}{|\nabla F|}
=\left(\frac{\hat n}{\cosh u},-\tanh u\right).
$$

### 6.3 光线 = 约束测地线

在 $\Sigma$ 上的测地线满足“加速度沿法向”：

$$
p''=\lambda\nabla F,
\qquad
F(p)=0.
$$

对 $F(p(t))=0$ 求二阶导：

$$
\nabla F\cdot p''+p'^T\operatorname{Hess}F\,p'=0.
$$

代入 $p''=\lambda\nabla F$：

$$
\lambda=-\frac{p'^T\operatorname{Hess}F\,p'}{|\nabla F|^2}.
$$

所以

$$
p''=
-\frac{p'^T\operatorname{Hess}F\,p'}{|\nabla F|^2}\nabla F.
$$

用第二基本形式写：

$$
p''=\Pi(p',p')\,N.
$$

**约束力 $\lambda\nabla F$ 正是让曲线贴着 $\Sigma$ 所需的法向加速度。** 环境 $\mathbb{R}^4$ 是平的，所以没有别的力。

### 6.4 投影积分器

代码的离散方案：

$$
p_{n+1}=\pi_\Sigma\bigl(p_n+h\,v_n\bigr),
\qquad
v_{n+1}=\frac{P_{T_{p_{n+1}}\Sigma}(v_n)}
{\bigl|P_{T_{p_{n+1}}\Sigma}(v_n)\bigr|},
$$

其中 $\pi_\Sigma$ 是牛顿投影，$P_{T\Sigma}$ 是切向投影：

$$
P_{T\Sigma}(v)=v-(v\cdot N)N.
$$

几何解释：

1. 沿当前切向速度走直线（平直空间中的“惯性”）；
2. 把点投影回 $\Sigma$（位置约束）；
3. 把速度重新切向化并归一（速度约束）。

这不是精确的 Christoffel 积分，而是一个**一阶约束投影积分器**（projection/SHAKE 型；严格说比完整的 RATTLE 少一步速度修正）。连续极限 $h\to0$ 下收敛到测地线；每一步位置误差 $O(h^3)$，速度误差 $O(h^2)$，全局一阶。

代码（shader）：

```glsl
p += v * h;
p = surf_project(p);
vec4 n = surf_normal(p);
v -= n * dot(v, n);
v = normalize(v);
```

> 注意：观察者的**移动**不是测地线（玩家可以随意飞），但**光线**是测地线。这是第一人称渲染与自由飞行的区别。

### 6.5 测地线积分的几何直觉

- 光线想走直线；$\Sigma$ 弯了，直线会离开曲面；
- 投影把它拉回曲面，拉回的方向就是法向；
- 法向加速度 $\Pi(v,v)N$ 正是曲面“强迫”光线弯曲的地方；
- 在喉口附近，$\Pi$ 很大（$1/b_0$ 量级），所以光线强烈偏折，产生多重像/爱因斯坦环。

---

## 7. 渲染管线：从公式到像素

### 7.1 每像素光线

对像素坐标 `uv`：

$$
\text{ndc}
=\left(2u_x-1,\;1-2u_y\right),
\qquad
\text{ndc}_x\leftarrow \text{ndc}_x\cdot\text{aspect},
$$

$$
v=\operatorname{normalize}
\left(
\text{cam\_fwd}
+\text{cam\_right}\cdot\text{ndc}_x
+\text{cam\_up}\cdot\text{ndc}_y
\right).
$$

因为 `cam_fwd/right/up` 都在 $T_p\Sigma$ 内，$v$ 也是切向量。

### 7.2 主循环（`render_scene`）

```glsl
vec4 p = surf_project(cam_pos);
float travel = 0.0;
bool hit = false;

for (int i = 0; i < MAX_STEPS; i++){
    float df = cat_sdf(p);
    if (abs(df) < 0.02){ hit = true; break; }

    float h = clamp(0.5 * abs(df) + 0.04, 0.05, 0.7);
    float near_throat = clamp(1.0 - length(p.xyz) / (throat_r * 6.0), 0.0, 1.0);
    h *= 1.0 - 0.55 * near_throat;

    p += v * h;
    p = surf_project(p);
    vec4 n = surf_normal(p);
    v -= n * dot(v, n);
    v = normalize(v);
    travel += h;

    if (travel > 260.0) break;
    if (abs(p.w) > W_ESCAPE) break;
}
```

> 这是主虫洞单独工作时的等价伪代码。v37 的 `render_scene` 实际调用 `world_floor_sdf` / `world_project`，把主虫洞与同空间组件做并集；同空间组件不活跃时二者相同。本文不展开组件。

逐步解释：

1. **`cat_sdf(p)`**：地板（赤道悬链面）的符号距离代理（在固定 $w$ 的子午面里量距离）。`|df|<0.02` 视为命中地板。
2. **步长**：$h=\operatorname{clamp}(0.5|df|+0.04,0.05,0.7)$。这是 SDF 球体追踪的启发式步长；靠近地板时自动变小。
3. **喉口附近减速**：`near_throat` 在 $\rho<6b_0$ 时从 0 增到 1，步长最多缩小 55%，避免在强曲率区跨过曲面。
4. **约束积分**：直线步进 → 投影回 $\Sigma$ → 速度切向化归一（§6.4）。
5. **终止**：走够 260 m 或 $|w|>55$ 就转星空；否则继续。

### 7.3 地板 SDF 与碰撞

地板是 $\theta=\pi/2$ 的悬链面（$z=0$）：

$$
\rho_{xy}=b_0\cosh(w/b_0).
$$

代码的 `cat_sdf`：

```glsl
float cat_sdf(vec4 p){
    float zz = p.z;
    float rho_xy = length(p.xy);
    float dr = rho_xy - throat_r * cosh(p.w / throat_r);
    return sign(zz) * sqrt(zz * zz + dr * dr);
}
```

它在固定 $w$ 的 $(z,\rho_{xy})$ 截面里，量到该截面上悬链线交点 $(z=0,\rho_{xy}=b_0\cosh(w/b_0))$ 的距离，并在 $z=0$ 两侧变号。零集正好是地板；但它是**子午面距离代理**，不是 $\Sigma$ 上的精确内蕴距离（也不是到整条悬链线的最短距离）。光线步进用它作启发式 SDF，够用但不是严格的距离场。

观察者碰撞（`main.gd`）：

```gdscript
var dcat := cat_sdf(pos)
if dcat < 0.35:
    var cn := cat_normal(pos)
    pos += cn * (0.35 - dcat)
    var vdown := vel.dot(-cn)
    if vdown > 0.0:
        vel += cn * vdown
```

即：保持 0.35 m 离地间隙；若速度朝地板里，去掉法向分量。`cat_normal` 是 `cat_sdf` 的有限差分梯度，作为地板法向。

> 当前 v37 的对应代码用 `world_floor_sdf` / `world_floor_normal`（不含同空间组件时分别退化为 `cat_sdf` / `cat_normal`）；上面保留 `cat_*` 是为了突出主虫洞。

### 7.4 星空与两个宇宙

光线逃逸后，用 4D 方向 $v$ 采样程序化星空：

```glsl
vec3 sky_col(vec4 v){
    float uni = smoothstep(-3.0, 3.0, v.w * 6.0);
    vec3 col = mix(vec3(0.008,0.010,0.026), vec3(0.026,0.012,0.008), uni);
    col += star_layer(v, 15.0, 0.980, 1.0, uni);
    ...
}
```

- `uni` 由 $v_w$ 决定：逃向 $w<0$（宇宙 B）偏冷蓝，$w>0$（宇宙 C）偏暖棕；
- 星星是 4D 网格哈希 `hash14(vec4)`，所以星图本身是四维方向场的采样；
- 颜色过渡是连续的，不是纹理切换——穿过喉口时色温平滑变化，这就是“到达另一个宇宙”的视觉呈现。

### 7.5 嵌入图与 HUD

- 视图 ②（`embed_diagram`）：画 $(w,\rho)$ 里的 $\rho=b_0\cosh(w/b_0)$，标出观察者和喉口。
- HUD：显示 $X,Y,Z,W$、$u=w/b_0$、$w$、$\rho$、宇宙标签、速度、超采样倍率。
- $l=b_0\sinh u$ 没有直接显示，但它是从喉口量起的固有距离；$u$ 是它的无量纲版本。

### 7.6 数值参数与近似

| 参数 | 值 | 作用 |
|---|---|---|
| `THROAT_R` / `throat_r` | 3.0 | $b_0$ |
| `MAX_STEPS` | 1200 | 每条光线最多步数 |
| 命中阈值 | 0.02 | $\lvert\text{cat\_sdf}\rvert<0.02$ 视为命中 |
| 步长 | $[0.05,0.7]$ | SDF 启发式 |
| `W_ESCAPE` | 55 | $\lvert w\rvert$ 逃逸阈值 |
| `travel` 上限 | 260 m（v36 为 200） | 路径长度逃逸 |
| 地板间隙 | 0.35 m | 观察者碰撞 |
| 超采样 | 1.0/1.5/2.0 | SubViewport SSAA |

近似与限制：

- 一阶投影积分，不是精确 Christoffel/测地线解；
- `cat_sdf` 是子午面距离代理，不是 $\Sigma$ 上的精确 SDF；
- 没有时间延迟、没有引力红移（$g_{tt}=-1$，静态）；
- 观察者不是自由下落测地线观察者；光线才是测地线；
- 星空是程序化背景，不是真实天体；
- 同空间虫洞组件不在本文范围；`world_*` 包装函数把主虫洞与组件做并集，主虫洞路径等价于 `surf_*`/`cat_*`。

---

## 8. 拓扑、物理与可穿越性

### 8.1 空间拓扑

Ellis 空间 $\Sigma$ 的拓扑：

$$
\Sigma\cong S^2\times\mathbb{R}\cong\mathbb{R}^3\setminus\{0\}.
$$

- 两个渐近平直端（$w\to\pm\infty$）；
- 一个喉口 $S^2$（$w=0$）；
- $\pi_1(\Sigma)=0$，$H_2(\Sigma)=\mathbb{Z}$（喉口这个 2-闭链不可收缩）。

“两个宇宙”不是两个分离的时空，而是**同一张连通流形的两个端**。这是 Einstein–Rosen 桥的静态、可穿越版本。

### 8.2 可穿越性

- 无事件视界：$g_{tt}=-1$；
- 喉口是极小 $S^2$，潮汐力为零（静态观察者）；
- 从任何有限点出发，都能在有限固有距离内到达喉口；沿途曲率有限；没有 horizon 阻挡；
- 但两端 $|l|\to\infty$，彼此相距无限远；
- 代价：NEC 违反，需要负能量密度的奇异物质（§2.5）。

所以这是一个**数学上可穿越、物理上需要奇异物质**的虫洞。

### 8.3 为什么“零潮汐力”不等于“没有曲率”

- $R_{itjt}=0$：静态观察者的潮汐加速度为零；
- $R_{ijkl}\neq0$：空间曲率仍在，光线仍偏折；
- Kretschmann $=12b_0^4/\rho^8\neq0$：曲率不变量非零。

这是 Ellis 虫洞与 Schwarzschild 虫洞的一个重要区别：Schwarzschild 的潮汐力会撕人，Ellis 的不会；但两者都不是平坦空间。

---

## 9. 常见误解

1. **“4D 就是 4D 时空，W 是时间。”**
   不是。环境是四维**欧氏空间** $(x,y,z,w)$，四个都是空间坐标；$w$ 是嵌入坐标。物理时空是 $-dt^2+ds_\Sigma^2$，渲染器不积分 $t$。

2. **“虫洞是平直空间里的一条管子。”**
   不是。主虫洞是三维空间本身的曲率与拓扑；没有“管子壁”，观察者就生活在弯曲空间里。

3. **“两个宇宙是两个独立时空。”**
   不是。它们是同一张流形的两个渐近平直端；穿过喉口是沿同一张流形连续走。

4. **“零潮汐力 = 平坦。”**
   不是。$R_{itjt}=0$ 但 $R_{ijkl}\neq0$，光线会偏折，Kretschmann 非零。

5. **“观察者在走测地线。”**
   不是。玩家是自由飞行的观察者；只有光线沿测地线传播。

6. **“渲染是精确的 GR 光线追踪。”**
   不是。它是一阶约束投影积分 + 启发式 SDF 步进；透镜/多重像在定性上正确，定量上有数值误差。

7. **“W_ESCAPE=55 是宇宙的边界。”**
   不是。它只是坐标截断；对应的固有距离约 $1.4\times10^8$ m，早已渐近平直。

8. **“喉口是黑洞的 horizon。”**
   不是。没有 horizon，$g_{tt}$ 不为零；喉口是极小 $S^2$，可以穿过。

9. **“嵌入图就是整个三维空间。”**
   不是。视图 ② 是 $(w,\rho)$ 子午面截面；完整三维空间是这条曲线加 $S^2$ 纤维（超悬链面）。

10. **“这个虫洞在现实中存在。”**
    不知道。它是 Einstein 方程的一个数学解，需要违反 NEC 的奇异物质；项目只实现几何与渲染。

---

## 10. 代码索引

### 10.1 主虫洞数学 ↔ 代码

| 数学对象 | 代码 | 位置 |
|---|---|---|
| $b_0$ | `THROAT_R` / `throat_r` | `scripts/main.gd:24`；shader `:28` |
| $\Sigma:\rho=b_0\cosh(w/b_0)$ | `surf_f` | `main.gd:201-203`；shader `:47-49` |
| $\nabla F$ | `surf_grad` | `main.gd:205-210`；shader `:51-55` |
| 牛顿投影 $\pi_\Sigma$ | `surf_project` | `main.gd:213-218`；shader `:57-64` |
| 单位法向 $N$ | `surf_normal` | `main.gd:221-222`；shader `:66-68` |
| 地板悬链面 SDF | `cat_sdf` | `main.gd:227-231`；shader `:74-79` |
| 地板法向 | `cat_normal` | `main.gd:234-241`；shader `:81-88` |
| 地板棋盘材质 | `cat_albedo` | shader `:90-99` |
| 4D 正交标架 / Gram–Schmidt | `_make_ortho`, `_init_frame` | `main.gd:370-392` |
| 切空间旋转 | `_rot_pair` | `main.gd:395-403` |
| 观察者移动 + 投影 | `_process` | `main.gd:422-461` |
| 地板碰撞 | `cat_sdf`/`cat_normal` 使用处 | `main.gd:448-454` |
| 光线测地线积分 | `render_scene` 主循环 | shader `:266-340` |
| 星空 / 两个宇宙 | `sky_col`, `star_layer` | shader `:205-235` |
| 嵌入图 | `embed_diagram` | shader `:245-260` |
| HUD | `_update_hud` | `main.gd:481-488` |

> `world_*`（`world_f`, `world_project`, `world_floor_sdf` 等）是加上同空间虫洞组件后的并集包装；主虫洞单独工作时等价于 `surf_*`/`cat_*`。本文不展开组件。

### 10.2 运行/验证

- 主喉口截图：`build/v37_spawn.png`（出生点正对主喉口）、`build/m24_spawn.png`、`build/m24_uniC.png`、`build/m24_embed.png`。
- 嵌入图：游戏内按 `V`。
- 截图命令行：`Godot.exe --path . -- --shot=<png> [--shot-pos=...] [--shot-look=...] [--shot-mode=0|1]`。
- 同空间虫洞的自检（`tests/portal_test.gd`）不在本文范围。

---

## 附录 A：公式速查

**度规**

$$
ds_\Sigma^2=dl^2+(l^2+b_0^2)d\Omega^2
=b_0^2\cosh^2u\,(du^2+d\Omega^2),
\qquad u=w/b_0.
$$

**坐标关系**

$$
\rho=b_0\cosh u,\qquad
l=b_0\sinh u,\qquad
w=b_0u=b_0\operatorname{asinh}(l/b_0).
$$

**嵌入**

$$
X(u,\theta,\varphi)=(b_0\cosh u\,\hat n,\;b_0u),
\qquad
\hat n=(\sin\theta\cos\varphi,\sin\theta\sin\varphi,\cos\theta).
$$

**法向**

$$
N=\left(\frac{\hat n}{\cosh u},-\tanh u\right).
$$

**第二基本形式（坐标基）**

$$
\Pi=b_0(du^2-d\theta^2-\sin^2\theta\,d\varphi^2).
$$

**主曲率**

$$
\kappa_u=+\frac{1}{b_0\cosh^2u},\qquad
\kappa_\theta=\kappa_\varphi=-\frac{1}{b_0\cosh^2u}.
$$

**平均曲率**

$$
H=-\frac{1}{3b_0\cosh^2u}.
$$

**曲率**

$$
K_{\text{equator}}=-\frac{b_0^2}{\rho^4},\qquad
R^{(3)}=-\frac{2b_0^2}{\rho^4},\qquad
K_{\text{Kretschmann}}=\frac{12b_0^4}{\rho^8}.
$$

**能量密度 / NEC**

$$
\varepsilon=p_r=-\frac{b_0^2}{8\pi\rho^4},\qquad
p_\theta=+\frac{b_0^2}{8\pi\rho^4},\qquad
\varepsilon+p_r<0.
$$

**临界碰撞参数**

$$
L_c=b_0.
$$

**测地线方程（赤道）**

$$
l''=l\varphi'^2,\qquad
L=(l^2+b_0^2)\varphi'=\text{const},\qquad
l'^2=1-\frac{L^2}{l^2+b_0^2}.
$$

**投影积分器**

$$
p_{n+1}=\pi_\Sigma(p_n+h v_n),\qquad
v_{n+1}=\frac{v_n-(v_n\cdot N)N}{|v_n-(v_n\cdot N)N|}.
$$

---

## 附录 B：参考文献

1. M. S. Morris, K. S. Thorne, *Wormholes in spacetime and their use for interstellar travel: A tool for teaching general relativity*, Am. J. Phys. **56**, 395 (1988).
2. H. G. Ellis, *Ether flow through a drainhole: A particle model in general relativity*, J. Math. Phys. **14**, 104 (1973).
3. K. A. Bronnikov, *Scalar-tensor theory and scalar charge*, Acta Phys. Pol. B **4**, 251 (1973).
4. M. Visser, *Traversable wormholes: Some simple examples*, Phys. Rev. D **39**, 3182 (1989); M. Visser, *Lorentzian Wormholes: From Einstein to Hawking*, AIP Press (1995).
5. L. Flamm, *Beiträge zur Einsteinschen Gravitationstheorie*, Phys. Z. **17**, 448 (1916).
6. M. P. do Carmo, *Differential Geometry of Curves and Surfaces*; *Riemannian Geometry*, Birkhäuser.
7. R. M. Wald, *General Relativity*, University of Chicago Press (1984).
8. M. Janet (1926), É. Cartan (1927)：等距嵌入定理；一般 $n$ 维黎曼流形可嵌入 $\mathbb{R}^{n(n+1)/2}$。
9. Wikipedia, *Wormhole*：Morris–Thorne 度规、喉半径、嵌入图。
10. optozorax,《虫洞在现实中看起来会是什么样？》(BV1Q8HP69EQh)：测地线光线步进与穿喉连续性的视觉参考。
11. wxyhly,《四维世界（一）》：4D 空间旋转与几何直觉。

---

*文档基线：2026-10-27，工作区 v37。若后续修改 `THROAT_R`、`MAX_STEPS`、`W_ESCAPE` 或测地线积分器，请同步更新本文第 6–7 节与附录 A。*
