class_name UIStyle
extends RefCounted
## Portal 2 / Aperture 风格 UI：
## 暗色半透明面板、白色无衬线字、Aperture 蓝、选中行用浅灰亮条。
## 供菜单、HUD、暂停菜单共用。

const BLUE := Color(0.35, 0.72, 0.93)
const BLUE_BRIGHT := Color(0.62, 0.87, 1.0)
const ORANGE := Color(0.97, 0.60, 0.20)
const INK := Color(0.91, 0.94, 0.93)
const MUTED := Color(0.60, 0.66, 0.68)
const SELECT := Color(0.87, 0.89, 0.88)
const SELECT_TEXT := Color(0.07, 0.09, 0.10)
const PANEL := Color(0.050, 0.062, 0.067, 0.88)
const EDGE := Color(0.40, 0.46, 0.48, 0.92)

static var _font: Font = null


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
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(0)
	if accent:
		s.border_width_left = 4
		s.border_color = BLUE
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s


## 场景内 HUD：状态行 / 帮助框 / 顶部提示。
static func apply_hud(root: Node) -> FourDAxis:
	var ui := root.get_node_or_null("UILayer")
	if ui == null:
		return

	var coord := ui.get_node_or_null("CoordLabel") as RichTextLabel
	if coord != null:
		coord.add_theme_font_override("normal_font", font())
		coord.add_theme_font_override("bold_font", font())
		coord.add_theme_font_size_override("normal_font_size", 36)
		coord.add_theme_font_size_override("bold_font_size", 36)
		coord.add_theme_color_override("default_color", INK)
		coord.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		coord.add_theme_constant_override("outline_size", 7)

	var pos := ui.get_node_or_null("PosLabel") as Label
	if pos != null:
		pos.add_theme_font_override("font", font())
		pos.add_theme_font_size_override("font_size", 21)
		pos.add_theme_color_override("font_color", INK)
		pos.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		pos.add_theme_constant_override("outline_size", 4)
		pos.add_theme_stylebox_override("normal",
			panel(Color(0.014, 0.019, 0.021, 0.74), EDGE, 1, false, 16, 5))
		pos.modulate = Color.WHITE
		pos.anchor_left = 0.0
		pos.anchor_right = 1.0
		pos.anchor_top = 1.0
		pos.anchor_bottom = 1.0
		pos.offset_left = 0.0
		pos.offset_right = 0.0
		pos.offset_top = -38.0
		pos.offset_bottom = 0.0

	var help := ui.get_node_or_null("HelpLabel") as Label
	if help != null:
		help.add_theme_font_override("font", font())
		help.add_theme_font_size_override("font_size", 19)
		help.add_theme_color_override("font_color", Color(0.82, 0.86, 0.86))
		help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		help.add_theme_constant_override("outline_size", 0)
		help.visible = false

	var toast := ui.get_node_or_null("Toast") as Label
	if toast != null:
		toast.add_theme_font_override("font", font())
		toast.add_theme_font_size_override("font_size", 26)
		toast.add_theme_color_override("font_color", INK)
		toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		toast.add_theme_constant_override("outline_size", 6)

	# 左下角四维坐标系（朝向 + 位置）
	var gizmo := ui.get_node_or_null("FourDAxis") as FourDAxis
	if gizmo == null:
		gizmo = FourDAxis.new()
		gizmo.name = "FourDAxis"
		gizmo.font = font()
		gizmo.anchor_top = 1.0
		gizmo.anchor_bottom = 1.0
		gizmo.offset_left = 16.0
		gizmo.offset_right = 276.0
		gizmo.offset_top = -256.0
		gizmo.offset_bottom = -46.0
		ui.add_child(gizmo)

	# 底部中央物品栏（虫洞枪）
	var inv := ui.get_node_or_null("InventoryBar") as InventoryBar
	if inv == null:
		inv = InventoryBar.new()
		inv.name = "InventoryBar"
		inv.font = font()
		inv.anchor_left = 0.5
		inv.anchor_right = 0.5
		inv.anchor_top = 1.0
		inv.anchor_bottom = 1.0
		inv.offset_left = -340.0
		inv.offset_right = 340.0
		inv.offset_top = -156.0
		inv.offset_bottom = -46.0
		inv.clip_contents = true
		ui.add_child(inv)

	return gizmo


## 菜单/暂停菜单的列表行：普通状态透明，悬停为 Portal 2 的浅灰亮条。
static func row_style(hover: bool, selected: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if hover or selected:
		s.bg_color = SELECT
		s.border_color = SELECT
	else:
		s.bg_color = Color(0.025, 0.032, 0.035, 0.55)
		s.border_color = Color(0.30, 0.35, 0.37, 0.55)
	s.set_border_width_all(0)
	s.border_width_bottom = 1
	s.set_corner_radius_all(0)
	if hover or selected:
		s.border_width_left = 4
	return s
