# 四维空间 SDF 引擎 + 虫洞（Godot 4）

当前主场景：**v45 光滑双喉口超悬链面**（`scenes/main.tscn` → `scripts/main.gd` +
`shaders/wormhole4d.gdshader`）。

> **状态说明**：v45 修掉了 v44 的 C⁰ 接缝（min 硬并集、法向跳变），
> 但 B 侧仍然是两个超悬链面实体的**外包络/桥**，不是参考图的“平地板 + 两个分离球泡”。
> 下一步是“平 B 房间 + 两个真实 4D 颈部 + 共享 C 超悬链面”，
> 详见 [docs/REJECTED_METHODS.md](docs/REJECTED_METHODS.md)。

## 当前方法（v45）

每张喉口仍是 0.0.2 的 Morris–Thorne 超悬链面：

```
F_i(p) = |p_xyz - C_i| - R*cosh(w/R) = 0      (i=1,2)
```

世界不是 `min(F1,F2)` 硬并集，而是 C∞ 光滑最小值：

```
F(p) = smin(F1(p), F2(p); κ)
smin(a,b;κ) = min(a,b) - κ * log(1 + exp(-|a-b|/κ))
```

- 喉口附近一项权重饱和 → 精确的 Ellis 超悬链面；
- 两份重叠区用宽度 `κ` 的光滑颈连接，法向/切空间连续；
- 玩家/光线在这张 C∞ 超曲面上做约束投影测地线积分；
- 两个喉口在 `w=0` 是半径 `R=3` 的球面；`B` 侧 (w<0) 有地板，`C` 侧 (w>0) 是天空；
- 全程没有位置映射/反射/传送。

参数：`R=3`，`κ=0.35`，`C1=(-5,9.24,0)`，`C2=(5,9.24,0)`，`W0=-6`。

## 数学

三维空间度规（Ellis 虫洞）：

```
ds² = dl² + (l² + R²) dΩ²
l = R*sinh(w/R)
ρ = |xyz| = R*cosh(w/R)
```

这是 `R⁴` 中的精确等距嵌入；观察者和光线都被约束在这张 3D 超曲面上。
完整推导、曲率、测地线、临界碰撞参数、Gauss/Codazzi 几何见
[docs/wormhole_geometry.md](docs/wormhole_geometry.md)。

## 自检

```
Godot.exe --headless --path . --script res://tests/catenoid_test.gd
```

v45 自检覆盖：
- 两个喉口 `F1/F2≈0`，且光滑世界 `F(喉口)≈0`；
- B 地板存在、C 侧无地板；
- 接缝法向连续（约 0.15°；v44 是 13.5°）；
- 相切点法向连续（约 1.6°；v44 是 73.8°）；
- 跨接缝速度连续（约 0.38°）；
- `world_f(world_project(p))≈0`（残差 ~1e-7）；
- 121 采样世界线 `A→C→B` 的 `w` 连续，法向连续。

当前渲染截图：`build/v45_test.png`（B 侧深景，可见外包络桥）、
`build/v45_close.png`（近景，桥更明显）。

## 已知问题 / 下一步

- **v44/v45 的 B 侧外包络/桥**：世界是两份超悬链面实体的外包络，不是“房间 + 两个独立口”；
  相机在两口正前方时必然落在桥上。已写入 `docs/REJECTED_METHODS.md` §8。
- **下一步（正确方向）**：平 B 房间 + 两个真实 4D 颈部 + 共享 C 超悬链面；
  颈部是空间的一部分，玩家连续穿过，不做位置映射。详见同文档“正确方向（下一步）”。
- v39 球面薄壳映射、v40 体积手柄、v44 `min` 并集均已打回，只作为历史保留。

## 运行 / 构建

- Godot 4.3+ 导入 `project.godot`，F5（本机 4.7.1 已验证）；`./build.sh "…Godot.exe"` 出单文件 exe。
- 截图验证：
  `Godot.exe --path . -- --shot=<png> [--shot-pos=x,y,z,w] [--shot-look=x,y,z,w] [--ss=1.5]`

## 操作

| 按键 | 作用 |
|---|---|
| 鼠标 / WASD / Space·C / 滚轮 | 切空间内转身 / 移动 / 升降 / 调速 |
| Q / E | 翻滚 |
| **V** | 视图：① 第一人称 ② 嵌入图 (w, ρ) |
| **F** | 超采样 1.0× / 1.5× / 2.0× |

## 文件

```
scenes/main.tscn            v45 主场景
scripts/main.gd             光滑双喉口、约束相机、投影测地线、地板碰撞
shaders/wormhole4d.gdshader 光滑 smin 世界、地板、天空、4D 标识、嵌入图
tests/catenoid_test.gd      v45 自检：喉口、法向、速度、投影残差、世界线
tests/portal_test.gd        v39 历史自检（球面薄壳映射，已打回）
tests/volume_test.gd        v40 历史自检（体积手柄，已打回）
docs/wormhole_geometry.md   主虫洞（Ellis）微分几何文档
docs/REJECTED_METHODS.md    已打回方案 + 下一正确方向
scenes/volume.tscn          v40 体积手柄实验（非主场景）
```
