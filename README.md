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
| 03 虫洞沙盒 | `scenes/wormhole_map.tscn` | 平台/柱子沙盒 · 动态 Ellis 喉口 · 左键创建/删除 |
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

## 虫洞沙盒地图（03）

`scenes/wormhole_map.tscn` 是你新做的沙盒环境：约 28 m 的 Ellis 房间、两块平台和
一根中央柱；虫洞创建沿用 **04 的动态 Ellis**，不是 03 的球口/portal。

| 按键 | 作用 |
|---|---|
| 左键 | 在视线前方 8 m 创建/移动虫洞入口 `C` |
| 右键 / **X** | 删除虫洞，`b₀→0`，空间回到平直 |
| 飞进入口 | 沿同一张 Ellis 流形连续穿过到另一个房间（无 portal 转移） |
| **V / F / M** | 嵌入图 / 超采样 / 场景菜单 |

模型说明：

- 初始 `b₀=0`：空间是平直平面 `w=0`，但保留你所在侧的红/蓝房间颜色。
- 左键后 `b₀` 从 0 平滑长到 3，Ellis 喉口在 `C` 处出现；剖面仍是
  `ρ=b₀·cosh(w/b₀)`，光线沿瞬时 Ellis 测地线传播。
- 再次左键移动入口；右键/X 删除后回到平直。入口移动/消失不会把玩家拖向喉口
  （玩家保持绝对位置，只重算 `w`）。
- 墙面/地板/平台共用同一套**世界坐标三维立方格点**（格距 2 m，用 `(x,y,z)` 而不是
  每个面的 `(x,y,w)`）；格纹坐标取命中前一点与盒面的解析交点，掠射平台不会因步进
  量化出现同心条带。
- 限制：`b₀=0` 是 GR pinch-off 极限，不是完整 4D Einstein 解；目前一次一个虫洞。

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
scenes/wormhole_map.tscn    虫洞沙盒地图（大地图 + 平台/柱子，鼠标创建虫洞）
scenes/dynamic_ellis.tscn   动态 Ellis 虫洞（入口移动 + 周期性显隐）
scripts/main.gd             超曲面约束相机、房间边界/喉口、嵌入图、截图自检
scripts/menu.gd             场景选择页（卡片 + 1/2/3/4 快捷键 + 装饰嵌入曲线）
scripts/scene_router.gd     常驻返回菜单按钮 + M 快捷键
scripts/floor_2dchecker.gd  导入场景的相机/地板/HUD
scripts/wormhole_map.gd     虫洞沙盒：地图 SDF、鼠标放置、口对生命周期
scripts/dynamic_ellis_main.gd 动态 Ellis：入口移动/显隐、平直切换、HUD
shaders/wormhole4d.gdshader  超曲面投影、测地线积分器、双房间、嵌入图
shaders/floor_2dchecker.gdshader  悬链面地板（2D checker）、星空、嵌入图
shaders/wormhole_map.gdshader  沙盒地图 SDF、口对转移、局部 C∞ 形变
shaders/dynamic_ellis.gdshader  动态 Ellis 剖面、房间、测地线积分
icon.svg
```

## 已验证（Godot 4.7.1 实机 + 截图目检）

- `build/menu.png`：场景选择页（三张卡片 + (w,ρ) 嵌入曲线装饰）；
- `build/check_main.png`：双房间场景，红房间中心蓝色喉口；
- `build/check_floor.png`：4D-002 的 2D 棋盘悬链面地板；
- `build/map_empty.png`：虫洞沙盒空地图（房间 + 平台 + 中央柱，2 m 三维格点）；
- `build/map_created.png`：左键创建虫洞入口后的沙盒（喉口 + 对面房间）；
- `build/dynamic_vis_a.png`：动态 Ellis 可见相位（可见度 1.00）；
- `build/dynamic_vis_mid.png`：淡出中（可见度约 0.3，喉口缩小，房间颜色保留）；
- `build/dynamic_vis_b.png`：完全隐去（可见度 0、`b₀=0`，平直平面 `w=0`，房间仍为红色）；
- `build/dynamic_reappear.png`：重新出现中（入口移动后重新长出喉口）；
- `build/rooms.png`：红房间（w>0），中心蓝色喉口看到另一侧的蓝房间；
- `build/rooms-blue.png`：蓝房间（w<0），中心红色喉口看到另一侧的红房间；
- `build/diagram-clean.png`：嵌入图 (w,ρ)——悬浮曲线、平面投影与高度尺。
