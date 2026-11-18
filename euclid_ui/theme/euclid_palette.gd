class_name EuclidPalette
extends RefCounted

# Euclid's Elements - Dark Mode Geometric Palette
const BG_VOID := Color("#0D0E11")
const BG_PANEL := Color("#15171C")
const BG_SUBPANEL := Color("#101216")
const BG_HOVER := Color("#222630")
const BG_ACTIVE := Color("#1D2028")

const LINE_DIM := Color("#2D323E")
const LINE_MID := Color("#545B6E")
const LINE_MAIN := Color("#D8DCE6")

const TEXT_DIM := Color("#8890A4")
const TEXT_MAIN := Color("#D8DCE6")

const ACCENT_GOLD := Color("#C9A96E")
const ACCENT_GOLD_DIM := Color(0.788, 0.663, 0.431, 0.18)
const ACCENT_CYAN := Color("#7FB3D5")
const ACCENT_CYAN_DIM := Color(0.498, 0.702, 0.835, 0.18)
const ACCENT_RED := Color("#D46A6A")

const LINE_THIN: float = 1.0
const LINE_MED: float = 1.5
const LINE_BOLD: float = 2.0


static func get_font() -> Font:
	return ThemeDB.fallback_font


static func draw_euclid_frame(canvas: CanvasItem, rect: Rect2, fill: Color = BG_PANEL, border: Color = LINE_DIM, corner_ticks: bool = true) -> void:
	canvas.draw_rect(rect, fill, true)
	canvas.draw_rect(rect, border, false, LINE_THIN)
	if corner_ticks and rect.size.x >= 24.0 and rect.size.y >= 24.0:
		var tick: float = 5.0
		var tl: Vector2 = rect.position
		var tr := Vector2(rect.end.x, rect.position.y)
		var bl := Vector2(rect.position.x, rect.end.y)
		var br: Vector2 = rect.end
		canvas.draw_line(tl, tl + Vector2(tick, 0.0), LINE_MID, LINE_THIN)
		canvas.draw_line(tl, tl + Vector2(0.0, tick), LINE_MID, LINE_THIN)
		canvas.draw_line(tr, tr + Vector2(-tick, 0.0), LINE_MID, LINE_THIN)
		canvas.draw_line(tr, tr + Vector2(0.0, tick), LINE_MID, LINE_THIN)
		canvas.draw_line(bl, bl + Vector2(tick, 0.0), LINE_MID, LINE_THIN)
		canvas.draw_line(bl, bl + Vector2(0.0, -tick), LINE_MID, LINE_THIN)
		canvas.draw_line(br, br + Vector2(-tick, 0.0), LINE_MID, LINE_THIN)
		canvas.draw_line(br, br + Vector2(0.0, -tick), LINE_MID, LINE_THIN)
