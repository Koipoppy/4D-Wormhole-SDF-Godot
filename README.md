# 四维空间 SDF 引擎 + 虫洞（Godot 4）

按三个参考链接的数学实现的虫洞渲染器：**虫洞不是空间里的管子或传送门，而是弯曲的空间本身**。
Ellis / Morris–Thorne 零潮汐力虫洞的三维空间度规

```
ds² = dl² + (l² + b₀²)·dΩ²
```

在 4D 欧氏空间中有**精确等距嵌入**（代入 l = b₀·sinh u）：

```
P(u, θ, φ) = ( b₀·u ,  b₀·cosh(u)·n̂(θ,φ) )    n̂ ∈ S² ⊂ ℝ³
⇔  超曲面  ρ = b₀·cosh(w/b₀) ,  ρ = √(x²+y²+z²)
```

即把悬链线绕 w 轴旋转得到的**超悬链面**：喉口是 w=0 处半径 b₀ 的球，u→±∞ 两侧是两个
渐近平直的宇宙。观察者是生活在这个弯曲三维空间里的三维生物；**光线沿超曲面的测地线
传播**（约束积分器），喉口附近的星光多重像与爱因斯坦环全部是度规的真实结果。

## 参考来源

| 来源 | 内容 | 对应实现 |
|---|---|---|
| [Wikipedia: Wormhole](https://en.wikipedia.org/wiki/Wormhole) | Morris–Thorne 度规、喉半径 b₀、嵌入图 | 度规的 4D 等距嵌入超曲面 ρ=b₀cosh(w/b₀)；视图 ② 即嵌入图 (w,ρ) |
| [optozorax《虫洞在现实中看起来会是什么样？》(BV1Q8HP69EQh)](https://www.bilibili.com/video/BV1Q8HP69EQh/) | 测地线光线步进、穿喉连续、多重像 | 测地线约束积分器逐像素渲染；飞过喉口连续到达另一宇宙；喉口边缘的多重像 |
| [wxyhly《四维世界（一）》](https://wxyhly-en.github.io/archives/orbit4d/) | 4D 空间的转动与几何直觉 | 整个世界 4D 欧氏嵌入：弯曲空间是 4D 中的超曲面，相机标架是 4D 正交标架 |

## 运行 / 构建

- Godot 4.3+ 导入 `project.godot`，F5（本机 4.7.1 已验证）；`./build.sh "…Godot.exe"` 出单文件 exe。
- 截图验证：`Godot.exe --path . -- --shot=<png> [--shot-pos=x,y,z,w] [--shot-yaw=deg] [--shot-pitch=deg] [--shot-mode=0|1] [--ss=1.5]`

## 操作

| 按键 | 作用 |
|---|---|
| 鼠标 / WASD / Space·C / 滚轮 | 切空间内转身 / 移动 / 升降 / 调速（左键捕获鼠标，Esc 释放） |
| Q / E | 翻滚 |
| **V** | 视图：① 第一人称 ② 嵌入图 (w, ρ)——Wikipedia 的 Flamm 型图 |
| **F** | 超采样 1.0× / 1.5× / 2.0×（SubViewport SSAA） |

## 原理

1. **弯曲空间 = 4D 中的超曲面**。虫洞空间按上面的等距嵌入放进 4D 欧氏空间；
   观察者每帧被投影回超曲面（`surf_project`，牛顿迭代隐式面投影），移动与视线
   始终在切向 3-空间内。
2. **光线 = 测地线**。约束积分器：沿切向速度直线步进 → 投影回超曲面 → 速度重新
   切向化并归一（RATTLE 型约束积分，二阶收敛）。喉口附近星光的多重像、爱因斯坦环、
   穿喉看到另一宇宙，全部是该积分的自然结果——度规即渲染。
3. **场景**：悬链面地板（θ=π/2 截面，Z=0，即嵌入图曲面本身，棋盘材质 +
   `fwidth` 解析抗锯齿）+ 两个宇宙的星空（w<0 冷色 / w>0 暖色，由测地线逃逸侧决定）。
   穿过喉口时星空色温连续切换——这就是"到达另一个宇宙"的物理呈现。
4. **地板碰撞**：悬链面地板是实体，`cat_sdf ≥ 0.35`（无法钻入地板下方）。

## 调参

| 名称 | 默认 | 含义 |
|---|---|---|
| `throat_r` | 3.0 | Morris–Thorne 喉半径 b₀（决定喉口大小与空间弯曲程度） |
| `MAX_STEPS` | 500 | 测地线积分步数 |
| `W_ESCAPE` | 55 | 逃逸判定（转为星空） |

## 文件结构

```
project.godot               工程配置；run/main_scene = exe 入口场景
export_presets.cfg          Windows 导出预设（x86_64、嵌入 PCK）
build.sh / build.bat        一键构建
scenes/main.tscn            SubViewport（超采样）+ 全屏着色器 + HUD
scripts/main.gd             超曲面约束相机、测地线渲染所需状态、嵌入图、截图自检
shaders/wormhole4d.gdshader  超曲面投影、测地线积分器、悬链面地板、星空、嵌入图
icon.svg
```

## 已验证（Godot 4.7.1 实机 + 截图目检）

- `build/v21_start.png`：宇宙 B 侧俯瞰悬链面收向喉口，暗区为透过喉口的宇宙 A 星空；
- `build/v21_waist.png`：贴着喉口（u=+0.54），A 层星空占满视野；
- `build/v21_sheetA.png`：穿过喉口到达宇宙 A（u=−2.02），色温互换、几何对称；
- `build/v19_diagram.png`：嵌入图 (w,ρ)——悬链线、喉口标记、相机位置。
