class_name UIStyle
extends RefCounted
## Portal 2 / Aperture 风格 UI：
## 暗色半透明面板、白色无衬线字、Aperture 蓝、选中行用浅灰亮条。
## 所有尺寸按 1600×900 设计，并按窗口分辨率整体缩放。

const BLUE := Color(0.35, 0.72, 0.93)
const BLUE_BRIGHT := Color(0.62, 0.87, 1.0)
const ORANGE := Color(0.97, 0.60, 0.20)
const INK := Color(0.91, 0.94, 0.93)
const MUTED := Color(0.60, 0.66, 0.68)
const SELECT := Color(0.87, 0.89, 0.88)
const SELECT_TEXT := Color(0.07, 0.09, 0.10)
const PANEL := Color(0.050, 0.062, 0.067, 0.88)
const EDGE := Color(0.40, 0.46, 0.48, 0.92)

const DESIGN_W := 1600.0
const DESIGN_H := 900.0

static var _font: Font = null


## 以 1600×900 为基准的 UI 缩放；4K 窗口会得到 2.4。
static func ui_scale(root: Node) -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ui-scale="):
			return clampf(float(a.substr(11)), 0.5, 4.0)
	var vp := root.get_viewport().get_visible_rect().size
	return clampf(minf(vp.x / DESIGN_W, vp.y / DESIGN_H), 1.0, 2.5)


## Portal 2 的 DIN 风格窄体；中文用系统回退。
static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray([
			"Bahnschrift", "Arial Narrow", "Segoe UI", "Microsoft YaHei UI",
		])
		f.font_weight = 600
		f.allow_system_fallback = true
		_font = f
	return _font


static func panel(fill: Color = PANEL, edge: Color = EDGE, border: int = 1,
		accent: bool = false, margin_h: int = 14, margin_v: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(0)
	if accent:
		box.border_width_left = maxi(3, border * 4)
		box.border_color = BLUE
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	return box


## 场景内 HUD：状态行 / 顶部提示 / 四维仪表 / 物品栏。
static func apply_hud(root: Node) -> FourDAxis:
	var ui := root.get_node_or_null("UILayer")
	if ui == null:
		return null
	var k := ui_scale(root)

	var coord := ui.get_node_or_null("CoordLabel") as RichTextLabel
	if coord != null:
		coord.add_theme_font_override("normal_font", font())
		coord.add_theme_font_override("bold_font", font())
		coord.add_theme_font_size_override("normal_font_size", int(round(36.0 * k)))
		coord.add_theme_font_size_override("bold_font_size", int(round(36.0 * k)))
		coord.add_theme_color_override("default_color", INK)
		coord.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		coord.add_theme_constant_override("outline_size", int(round(7.0 * k)))

	var pos := ui.get_node_or_null("PosLabel") as Label
	if pos != null:
		pos.add_theme_font_override("font", font())
		pos.add_theme_font_size_override("font_size", int(round(21.0 * k)))
		pos.add_theme_color_override("font_color", INK)
		pos.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		pos.add_theme_constant_override("outline_size", int(round(4.0 * k)))
		pos.add_theme_stylebox_override("normal",
			panel(Color(0.014, 0.019, 0.021, 0.74), EDGE, maxi(1, int(round(k))),
				false, int(round(16.0 * k)), int(round(5.0 * k))))
		pos.modulate = Color.WHITE
		pos.anchor_left = 0.0
		pos.anchor_right = 1.0
		pos.anchor_top = 1.0
		pos.anchor_bottom = 1.0
		pos.offset_left = 0.0
		pos.offset_right = 0.0
		pos.offset_top = -38.0 * k
		pos.offset_bottom = 0.0

	var help := ui.get_node_or_null("HelpLabel") as Label
	if help != null:
		help.visible = false

	var toast := ui.get_node_or_null("Toast") as Label
	if toast != null:
		toast.add_theme_font_override("font", font())
		toast.add_theme_font_size_override("font_size", int(round(26.0 * k)))
		toast.add_theme_color_override("font_color", INK)
		toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		toast.add_theme_constant_override("outline_size", int(round(6.0 * k)))
		toast.anchor_left = 0.5
		toast.anchor_right = 0.5
		toast.offset_left = -460.0 * k
		toast.offset_right = 460.0 * k
		toast.offset_top = 112.0 * k
		toast.offset_bottom = 150.0 * k

	# 左下角四维坐标系（朝向 + 位置）
	var gizmo := ui.get_node_or_null("FourDAxis") as FourDAxis
	if gizmo == null:
		gizmo = FourDAxis.new()
		gizmo.name = "FourDAxis"
		gizmo.font = font()
		ui.add_child(gizmo)
	gizmo.ui_scale = k
	gizmo.anchor_top = 1.0
	gizmo.anchor_bottom = 1.0
	gizmo.offset_left = 16.0 * k
	gizmo.offset_right = 276.0 * k
	gizmo.offset_top = -256.0 * k
	gizmo.offset_bottom = -46.0 * k
	gizmo.queue_redraw()

	# 底部中央物品栏（五格拨轮）
	var inv := ui.get_node_or_null("InventoryBar") as InventoryBar
	if inv == null:
		inv = InventoryBar.new()
		inv.name = "InventoryBar"
		inv.font = font()
		inv.clip_contents = true
		ui.add_child(inv)
	inv.ui_scale = k
	inv.anchor_left = 0.5
	inv.anchor_right = 0.5
	inv.anchor_top = 1.0
	inv.anchor_bottom = 1.0
	inv.offset_left = -340.0 * k
	inv.offset_right = 340.0 * k
	inv.offset_top = -156.0 * k
	inv.offset_bottom = -46.0 * k
	inv.queue_redraw()

	return gizmo


## 菜单/暂停菜单的列表行：普通状态透明，悬停为 Portal 2 的浅灰亮条。
static func row_style(hover: bool, selected: bool = false, k: float = 1.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if hover or selected:
		box.bg_color = SELECT
		box.border_color = SELECT
	else:
		box.bg_color = Color(0.025, 0.032, 0.035, 0.55)
		box.border_color = Color(0.30, 0.35, 0.37, 0.55)
	box.set_border_width_all(0)
	box.border_width_bottom = maxi(1, int(round(k)))
	box.set_corner_radius_all(0)
	if hover or selected:
		box.border_width_left = maxi(2, int(round(4.0 * k)))
	return box
