class_name UiTheme
extends RefCounted
## Dark iron-and-leather UI theme, built in code so it stays easy to tweak.

const INK := Color("15110d")
const TEXT := Color("efe3c8")
const MUTED := Color("a8997c")
const GOLD := Color("c9a24a")
const CRIMSON := Color("8c1c2b")
const BAD := Color("ff8a7a")
const GOOD := Color("9ad07a")


static func box(bg: Color, border: Color, border_w: int = 2, radius: int = 8, pad: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18

	var panel := box(Color(0.09, 0.08, 0.07, 0.93), Color("5a4a30"))
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	t.set_stylebox("normal", "Button", box(Color("3a2e23"), INK, 2, 8, 8))
	t.set_stylebox("hover", "Button", box(Color("4a3b2c"), Color("6b5a3a"), 2, 8, 8))
	t.set_stylebox("pressed", "Button", box(Color("2a2119"), GOLD, 2, 8, 8))
	t.set_stylebox("disabled", "Button", box(Color("2a2622"), INK, 2, 8, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("7a6f60"))
	t.set_color("font_outline_color", "Button", INK)
	t.set_constant("outline_size", "Button", 3)
	t.set_constant("h_separation", "Button", 6)
	t.set_constant("icon_max_width", "Button", 40)

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 4)

	var sb_scroll := StyleBoxFlat.new()
	sb_scroll.bg_color = Color(1, 1, 1, 0.05)
	t.set_stylebox("scroll", "VScrollBar", sb_scroll)
	var grab := box(Color("5a4a30"), Color("5a4a30"), 0, 4, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	return t


static func style_primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(CRIMSON, INK, 2, 8, 10))
	b.add_theme_stylebox_override("hover", box(Color("a82536"), GOLD, 2, 8, 10))
	b.add_theme_stylebox_override("pressed", box(Color("64121e"), GOLD, 2, 8, 10))


## Green "go ahead" button (Continue).
static func style_good(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(Color("2f6b2a"), INK, 2, 8, 10))
	b.add_theme_stylebox_override("hover", box(Color("3d8a36"), GOLD, 2, 8, 10))
	b.add_theme_stylebox_override("pressed", box(Color("244f20"), GOLD, 2, 8, 10))


## Bright red button for leaving the game (Back to title).
static func style_danger(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(Color("b3261e"), INK, 2, 8, 10))
	b.add_theme_stylebox_override("hover", box(Color("d33a2f"), Color("ffd0c0"), 2, 8, 10))
	b.add_theme_stylebox_override("pressed", box(Color("8a1c16"), Color("ffd0c0"), 2, 8, 10))


static func style_selected(b: Button, on: bool) -> void:
	if on:
		b.add_theme_stylebox_override("normal", box(Color("4a3b2c"), GOLD, 3, 8, 8))
	else:
		b.remove_theme_stylebox_override("normal")
