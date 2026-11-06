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

- Godot 4.3+ 导入 `project.godot`，F5（本机 4.7.1 已验证）；`./build.sh "…Godot.exe"` 出单文件 exe 到**项目根目录**。
- 启动后进入**场景选择页**，再进入具体场景。
- 截图验证：`Godot.exe --path . -- --shot=<png> [--shot-pos=x,y,z,w] [--shot-yaw=deg] [--shot-pitch=deg] [--shot-mode=0|1] [--ss=1.5]`
  指定其他场景：`Godot.exe --path . res://scenes/floor_2dchecker.tscn -- --shot=…`

## 场景选择

| 场景 | 文件 | 说明 |
|---|---|---|
| 01 双房间虫洞 | `scenes/main.tscn` | Ellis 超曲面 · 红/蓝立方体房间 · 中心喉口 |
| 02 悬链面棋盘地板 | `scenes/floor_2dchecker.tscn` | 从 `4D-002-2dchecker` worktree 导入（tag 0.0.2 + 2D checker 改动）· 2D 棋盘地板 + 双宇宙星空 |
| 03 薄壳动态虫洞 | `scenes/thinshell.tscn` | 可移动球口对 · 准静态动态度规（端口实验） |
| 04 动态 Ellis 虫洞 | `scenes/dynamic_ellis.tscn` | 入口移动 + 周期性隐去；隐去时入口完全消失、空间平直，房间颜色保留 |

菜单里点击卡片或按 `1/2/3/4` 进入；游戏中按 `M` 或点右上角"场景选择"返回。

## 操作

| 按键 | 作用 |
|---|---|
| 鼠标 / WASD / Space·C / 滚轮 | 切空间内转身 / 移动 / 升降 / 调速（左键捕获鼠标，Esc 释放） |
| Q / E | 翻滚 |
| **V** | 视图：① 第一人称 ② 嵌入图 (w, ρ)——虫洞曲线悬浮在方格平面上方，虚线/竖线为平面投影 |
| **F** | 超采样 1.0× / 1.5× / 2.0×（SubViewport SSAA） |
| **M** | 返回场景选择菜单（右上角按钮同效） |

## 薄壳动态虫洞（路线 A）

`scenes/thinshell.tscn` 是独立实验场景：在 Ellis 空间的一个房间里放一对**可移动球口**，
两个口的球面边界被认同成同一条通道。

| 按键 | 作用 |
|---|---|
| **1 / 2** | 把口 A / B 放到准星命中的墙面；先放一个为**待定**，两个都放置后虫洞才激活 |
| 方向键 | 移动口 A（关闭自动漂移） |
| **T** | 自动漂移开关 |
| **X** | 删除当前虫洞实体（清空 A/B；1/2 重新放置） |
| **Backspace** | 重置为默认的已激活口对 |
| 飞进口 | 从另一个口出来，位置/速度/相机标架按口的切标架映射 |

模型说明：

- 环境仍是 Ellis 超曲面；每个口周围叠加一个**紧支撑的 C∞ bump**（支撑半径 3.2 m，
  转移截面半径 1.4 m）。bump 在支撑边界处及其所有导数为 0，所以与 Ellis 光滑拼接，
  曲率变化只在口附近。
- 两个口都确定后，bump 从 0 平滑升到 4.0：流形在线形变，然后才激活转移；之前只有
  一个待定的暗环，流形保持 Ellis 不变。
- 这不是实体管：bump 改的是 `F(p)=0` 这张三维流形本身，没有管壁/管体积。
- 口 A 默认沿曲面漂移，演示时间相关几何；渲染是**准静态**的：每帧冻结几何，
  光线按瞬时空间度规积分，忽略光行时和度规时间导数项。
- “创建/删除”目前是放置/清空，属于经典 GR 之外的近似；严格 GR 不允许
  光滑的拓扑变化（Geroch 定理）。bump 是几何形变，不是精确 Einstein 解；
  壳的应力张量、Israel 条件和 4D 光线还没实现。

## 动态 Ellis 虫洞（04）

`scenes/dynamic_ellis.tscn` 让 Ellis 虫洞**移动并周期性消失/出现**：

- 每一帧的剖面仍是 `ρ = b₀·cosh(w/b₀)`；入口中心 `C(t)` 沿
  `(5·sin(0.55t), 3·sin(0.37t+1), 0)` 在房间里移动。
- 显隐周期 12 s：4 s 可见 → 2 s 淡出 → 2 s 隐去 → 2 s 淡入。
- 隐去时 `b₀` 严格降到 0：曲面直接切换为平直平面 `w=0`，喉口**完全消失**，
  `K₂=0`，房间保持你所在侧的红/蓝颜色（不做去饱和）。
- 玩家保持房间里的绝对位置不变，只根据当前入口中心和 `b₀` 重算 `w`；
  所以入口移动/消失不会把玩家拖向喉口或产生黑屏。
- `T` 开关入口移动；`Y` 开关显隐周期；`V` 嵌入图（平直时显示 w=0 轴）；`F` 超采样。
- HUD 显示 `C`、可见度、`b₀`、`K₂`、房间侧别和“可见/隐去中/空间完全平直”状态。

限制：`b₀=0` 在 GR 里是一个 pinch-off 极限，严格的光滑拓扑变化仍不成立；
这里用平直平面 `w=0` 表示“完全消失”，房间侧别保留，另一侧随喉口一起消失。

## 原理

1. **弯曲空间 = 4D 中的超曲面**。虫洞空间按上面的等距嵌入放进 4D 欧氏空间；
   观察者每帧被投影回超曲面（`surf_project`，牛顿迭代隐式面投影），移动与视线
   始终在切向 3-空间内。
2. **光线 = 测地线**。约束积分器：沿切向速度直线步进 → 投影回超曲面 → 速度重新
   切向化并归一（RATTLE 型约束积分，二阶收敛）。喉口附近星光的多重像、爱因斯坦环、
   穿喉看到另一宇宙，全部是该积分的自然结果——度规即渲染。
3. **场景**：两个立方体房间——`w>0` 红房间、`w<0` 蓝房间，墙面为方格/棋盘纹理。
   每个房间中心就是 Ellis 喉口入口；相机/光线仍受完整 Ellis 度规约束，走进中心
   喉口（穿过 `w=0`）就进入另一个房间，房间墙面在喉口附近自然产生度规透镜弯曲。
4. **房间边界**：`|x|,|y|,|z| ≤ ROOM_L`；中心喉口保持可穿越，不是实体墙。

## 调参

| 名称 | 默认 | 含义 |
|---|---|---|
| `throat_r` | 3.0 | Morris–Thorne 喉半径 b₀（决定喉口大小与空间弯曲程度） |
| `ROOM_L` | 18.0 | 立方体房间半边长 |
| `ROOM_W` | 6.0 | 房间中心 / 喉口所在 `|w|` |
| `diagram_lift` | 8.0 | 嵌入图中虫洞相对方格平面的悬浮高度（ρ 单位） |
| `MAX_STEPS` | 1200 | 测地线积分步数 |

## 文件结构

```
project.godot               工程配置；run/main_scene = exe 入口场景
export_presets.cfg          Windows 导出预设（x86_64、嵌入 PCK）
build.sh / build.bat        一键构建（输出到根目录）
4DWormholeEngine.exe        构建产物（根目录）
scenes/main.tscn            SubViewport（超采样）+ 全屏着色器 + HUD
scenes/menu.tscn            场景选择页入口
scenes/floor_2dchecker.tscn 4D-002-2dchecker 导入场景（悬链面棋盘地板）
scenes/thinshell.tscn       薄壳动态虫洞实验场景（可移动球口对）
scenes/dynamic_ellis.tscn   动态 Ellis 虫洞（b₀(t) 呼吸，连续穿越）
scripts/main.gd             超曲面约束相机、房间边界/喉口、嵌入图、截图自检
scripts/menu.gd             场景选择页（卡片 + 1/2/3/4 快捷键 + 装饰嵌入曲线）
scripts/scene_router.gd     常驻返回菜单按钮 + M 快捷键
scripts/floor_2dchecker.gd  导入场景的相机/地板/HUD
scripts/thinshell_main.gd   薄壳口对的相机、穿越、移动、放置、HUD
scripts/dynamic_ellis_main.gd 动态 Ellis：b₀(t) 呼吸、HUD、截图
shaders/wormhole4d.gdshader  超曲面投影、测地线积分器、双房间、嵌入图
shaders/floor_2dchecker.gdshader  悬链面地板（2D checker）、星空、嵌入图
shaders/thinshell.gdshader  薄壳口对的光线转移、房间、准静态积分
shaders/dynamic_ellis.gdshader  动态 Ellis 剖面、房间、测地线积分
icon.svg
```

## 已验证（Godot 4.7.1 实机 + 截图目检）

- `build/menu.png`：场景选择页（三张卡片 + (w,ρ) 嵌入曲线装饰）；
- `build/check_main.png`：双房间场景，红房间中心蓝色喉口；
- `build/check_floor.png`：4D-002 的 2D 棋盘悬链面地板；
- `build/thinshell.png`：薄壳动态虫洞场景（青色 A / 品红 B 球口）；
- `build/thinshell_close.png`：口周围的局部 C∞ 流形形变（网格被拉伸）；
- `build/thinshell_pending.png`：只放置一个口时的**待定**状态（暗环、不转移）；
- `build/thinshell_travel.png`：从口 A 内部穿越到口 B 后的视角；
- `build/dynamic_vis_a.png`：动态 Ellis 可见相位（可见度 1.00）；
- `build/dynamic_vis_mid.png`：淡出中（可见度约 0.3，喉口缩小，房间颜色保留）；
- `build/dynamic_vis_b.png`：完全隐去（可见度 0、`b₀=0`，平直平面 `w=0`，房间仍为红色）；
- `build/dynamic_reappear.png`：重新出现中（入口移动后重新长出喉口）；
- `build/rooms.png`：红房间（w>0），中心蓝色喉口看到另一侧的蓝房间；
- `build/rooms-blue.png`：蓝房间（w<0），中心红色喉口看到另一侧的红房间；
- `build/diagram-clean.png`：嵌入图 (w,ρ)——悬浮曲线、平面投影与高度尺。
