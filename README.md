# 四维空间 SDF 引擎 + 虫洞（Godot 4）

当前主场景：**0.0.2 Ellis 底座 + 同空间双口传送**（`scenes/main.tscn` →
`scripts/main.gd` + `shaders/wormhole4d.gdshader`）。

> 底座是 0.0.2 的单超悬链面 `ρ = b₀·cosh(w/b₀)`：中央主喉口 B↔C 不变。
> 在**同一个宇宙 B (w=+6)** 里加了两个球形口 A/B：进入任一口 = 经喉（传送）
> 从另一口外侧出来；再沿宇宙 B 飞回入口，形成
> “口1 → 喉(传送) → 口2 → 宇宙B → 口1”。传送是用户明确要求的机制；
> 主喉口 `w=0` 仍是度规本身，不是传送。
> 旧 v51 平房间原型 `portal_room.*` 保留但不再是主场景。

## 当前实现（v52）：0.0.2 Ellis + 同空间双口传送

- **底座**：0.0.2 单超悬链面、悬链面地板、两个宇宙星空、V 嵌入图。
- **两个口**：A(青) `(0, +10.606, 3.86, +6)`、B(橙) `(0, -10.606, 3.86, +6)`，
  半径 `2.5`；都在宇宙 B，投影到同一张 Ellis 超曲面上。
- **传送**：相机/光线进入 4D 口球时，映射到另一口的同一角向点，并把速度/
  视线沿曲面切向的口法向反射；出口在另一口外侧。没有复用旧的 v36/v39
  portal 代码，是在 0.0.2 的 `surf_*` 上新增的实现。
- **闭环**：口A → 喉(传送) → 口B → 沿宇宙B飞回口A → 再次进入口A；HUD 计数。
- **手性**：每次传送左右手翻转，HUD 显示 `手性 +/−`。
- 截图：[build/v52_spawn.png](build/v52_spawn.png)、
  [build/v52_insideA.png](build/v52_insideA.png)。

自检：

```
Godot.exe --headless --path . --script res://tests/portal_throat_test.gd
Godot.exe --headless --path . --script res://tests/throat_test.gd
```

`tests/portal_throat_test.gd` 检查：A/B 在宇宙 B、在 0.0.2 曲面上、扫掠进入、
出口在 B 外、速度向外、闭环计数、`w` 偏移掠过、绕行宇宙 B 不碰口。
`tests/throat_test.gd` 保持 0.0.2 主喉口 8 项 PASS。

## 历史实现（v50）：单一母线双叶曲面

世界是**一张光滑 3D 旋转曲面**：

```
F(p) = |p_xyz| - f(p.w) = 0

f(w) = R_L*exp(-((w-a)/s)^2) + R_L*exp(-((w+a)/s)^2)
       + R_N*exp(-(w/sn)^2)
```

- 一条母线 \(ρ=f(w)\) 绕 \(w\) 轴旋转得到整张曲面；
- 母线上有两个鼓包（叶瓣）和一个细颈；
- 两个叶瓣是**同一张曲面**的两个位置；颈部是它们之间的连接；
- 没有球、没有 tube、没有并集、没有 rim、没有平房间、没有单独的 handle；
- 观察者/光线始终在这张曲面上：叶瓣 A → 颈部 → 叶瓣 B；没有位置映射/传送。

参数：`R_L=2.6`，`R_N=1.1`，`a=2.0`，`s=1.0`，`sn=1.2`。
颈部半径约 `1.19`，叶瓣半径约 `2.65`。

## 两个视图

- **第一人称**：站在叶瓣 A 的曲面上，沿同一张曲面穿过颈部到叶瓣 B。
- **V 母线图**：直接画 \(ρ=f(w)\) 的截面——两个叶瓣、颈部、相机位置（绿点）、颈部（蓝点）。

截图：

- [build/v50_diagram.png](build/v50_diagram.png)：V 母线图，双叶 + 颈部；
- [build/v50_fp.png](build/v50_fp.png)：第一人称曲面/隧道视图。

## 自检

```
Godot.exe --headless --path . --script res://tests/handle_test.gd
```

`tests/handle_test.gd`（10 项 PASS）覆盖：

- 路径上 `F=0`；
- 起点在叶瓣 A（`w<0`）、终点在叶瓣 B（`w>0`）；
- 路径穿过颈部 `w=0`；
- 颈部半径小于两个叶瓣；
- 两个叶瓣半径相同（同一张曲面）；
- `w` 连续、4D 位置连续；
- 起点/终点/颈部都满足 `F=0`，没有第二份拷贝。

`tests/throat_test.gd`（0.0.2 单喉口 B↔A）8 项 PASS，仍可用。

## 为什么不是 v45–v49

- **v45 双超悬链面**：两张 B↔C 曲面，`A→C→B`。
- **v46 体积手柄**：玩家在 tube 体积里。
- **v47 平房间 + 外挂 tube 边界**：平房间，桥在曲面外侧。
- **v48 0.0.2 B 面 + 内插 tube 边界**：B 面 + 管子，复合结构。
- **v49 两个 4D 球的平滑并集**：仍是球/并集，第一人称会看到球面/边界；
  你贴的图正是“蓝色球/管插进灰色曲面 + 硬 rim”的失败形态。
- **v50**：没有球/管/并集/rim；整个空间就是一条光滑母线旋转出的曲面，
  两个叶瓣 + 颈部是同一张曲面的连续形状。

## 0.0.2 主 B↔C

`scenes/main.tscn` 是 0.0.2 单超悬链面：一张曲面、一个主喉口、两侧 B/C 两个宇宙。
v52 在同一张曲面的宇宙 B 里加了 A/B 两个同空间口（传送）；主喉口 `w=0` 仍通 C。
v50 的同空间双叶曲面是另一张独立的（历史）曲面。

## 运行 / 操作

- Godot 4.3+ 导入 `project.godot`，F5（本机 4.7.1 已验证）。
- 主场景（0.0.2 + A/B 传送）截图：
  `Godot.exe --path . -- --shot=<png> [--shot-mode=0|1] [--shot-pos=x,y,z,w] [--shot-look=x,y,z,w] [--ss=1.5]`
- v51 平房间原型截图：
  `Godot.exe --path . -- --shot=<png> [--shot-pos=x,y,z] [--shot-look=x,y,z] [--ss=1.5]`

| 按键 | 作用 |
|---|---|
| 鼠标 / WASD / Space·C / 滚轮 | 转身 / 移动 / 升降 / 调速 |
| Q / E | 翻滚 |
| **F** | 超采样 1.0× / 1.5× / 2.0× |
| **V** | 主场景：第一人称 / 嵌入图 \(ρ=f(w)\)；图中标出 A/B 口 |

## 文件

```
scenes/main.tscn            当前主场景：0.0.2 Ellis + 同空间 A/B 传送
scripts/main.gd             0.0.2 底座 + A/B 4D 传送/闭环/HUD
shaders/wormhole4d.gdshader 0.0.2 超曲面 + A/B 递归传送视图
tests/portal_throat_test.gd A/B 传送/闭环自检
tests/throat_test.gd        0.0.2 单喉口 B↔A 连续性自检
scenes/portal_room.tscn     v51 平房间传送原型（非主场景）
scripts/portal_room.gd      v51 原型相机/传送/闭环
scripts/portal_math.gd      v51 原型球口映射、扫掠、反射
shaders/portal_room.gdshader v51 原型平直房间 + 传送视图
tests/portal_room_test.gd   v51 原型自检
scenes/handle.tscn          v50 单一母线双叶曲面（历史）
scripts/handle_main.gd      母线 f(w)、约束相机/测地线、V 视图
shaders/handle4d.gdshader   单一旋转曲面、第一人称、V 母线图
tests/handle_test.gd        双叶 A→B 连续性自检
docs/wormhole_geometry.md   主虫洞（Ellis）微分几何文档
docs/REJECTED_METHODS.md    已打回方案清单
```
