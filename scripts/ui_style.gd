class_name UIStyle
extends RefCounted
## Half-Life 2 风格 UI：暗色半透明面板、琥珀色强调、方角边框、放大的字形。
## 供菜单、HUD、场景切换按钮共用。

const AMBER := Color(1.0, 0.66, 0.23)
const AMBER_BRIGHT := Color(1.0, 0.79, 0.40)
const INK := Color(0.88, 0.91, 0.90)
const MUTED := Color(0.61, 0.67, 0.69)
const PANEL := Color(0.022, 0.027, 0.029, 0.82)
const EDGE := Color(0.26, 0.30, 0.31, 0.92)

static var _font: Font = null


## HL2 的窄体无衬线；CJK 用系统回退，避免中文缺字。
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
		s.border_color = AMBER
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s


## 场景内 HUD：状态行 / 帮助框 / 顶部提示。字号整体放大。
static func apply_hud(root: Node) -> void:
	var ui := root.get_node_or_null("UILayer")
	if ui == null:
		return

	var coord := ui.get_node_or_null("CoordLabel") as RichTextLabel
	if coord != null:
		coord.add_theme_font_override("normal_font", font())
		coord.add_theme_font_override("bold_font", font())
		coord.add_theme_font_size_override("normal_font_size", 36)
		coord.add_theme_font_size_override("bold_font_size", 36)
		coord.add_theme_color_override("default_color", AMBER)
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
			panel(Color(0.015, 0.019, 0.021, 0.66), EDGE, 1, false, 12, 5))
		pos.modulate = Color.WHITE

	var help := ui.get_node_or_null("HelpLabel") as Label
	if help != null:
		help.add_theme_font_override("font", font())
		help.add_theme_font_size_override("font_size", 19)
		help.add_theme_color_override("font_color", Color(0.80, 0.84, 0.84))
		help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
		help.add_theme_constant_override("outline_size", 0)
		help.add_theme_stylebox_override("normal",
			panel(Color(0.012, 0.016, 0.018, 0.76), AMBER, 1, true, 18, 14))
		help.offset_top = -214.0
		help.offset_right = 1060.0

	var toast := ui.get_node_or_null("Toast") as Label
	if toast != null:
		toast.add_theme_font_override("font", font())
		toast.add_theme_font_size_override("font_size", 26)
		toast.add_theme_color_override("font_color", AMBER_BRIGHT)
		toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		toast.add_theme_constant_override("outline_size", 6)
