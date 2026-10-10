class_name DPNUISkin
extends RefCounted

# DPN command-interface design system. One renderer for all primary surfaces:
# graphite-black glass, crimson telemetry, precise trim and purposeful states.
# Decorative geometry is GPU-light; hitboxes are owned by SettlementUILayout.
const BLACK := Color("#07080c")
const PANEL := Color("#0c0e14")
const SURFACE := Color("#14151d")
const ELEVATED := Color("#1b1d27")
const EDGE := Color("#46343e")
const RED := Color("#e2374c")
const RED_DIM := Color("#852431")
const TEXT := Color("#f1e8e7")
const MUTED := Color("#a69b9c")
const GREEN := Color("#82cf9e")
const AMBER := Color("#f0b873")
const ICONS := ["build","region","govern","industry","factions","nation","save","load","guide"]


static func frame(canvas: CanvasItem, rect: Rect2, pulse: float = 0.0, selected: bool = false) -> void:
	# DPN armored-glass command surface: deep black with restrained signal detail.
	# Keep the center high-contrast for actual gameplay copy and interaction.
	var red := RED if selected else RED_DIM
	var inner := rect.grow(-3.0)
	canvas.draw_rect(rect,Color("#05060a",0.97))
	canvas.draw_rect(inner,PANEL)
	canvas.draw_rect(Rect2(rect.position+Vector2(3,3),Vector2(rect.size.x-6,32)),Color("#1d1018"))
	canvas.draw_rect(Rect2(rect.position+Vector2(3,35),Vector2(4,maxf(0.0,rect.size.y-39))),Color("#3a1621",0.56))
	canvas.draw_rect(rect,Color("#61313f"),false,1.0)
	canvas.draw_rect(inner,Color("#2c1b27"),false,1.0)
	canvas.draw_line(Vector2(rect.position.x+4,rect.position.y+35),Vector2(rect.end.x-4,rect.position.y+35),Color("#7f2838",0.85),1.0)
	canvas.draw_rect(Rect2(rect.position+Vector2(3,2),Vector2(maxf(1.0,rect.size.x-6),2)),red)
	canvas.draw_rect(Rect2(rect.position+Vector2(3,4),Vector2(3,28)),RED)
	canvas.draw_rect(Rect2(rect.position+Vector2(4,rect.size.y-5),Vector2(maxf(1.0,rect.size.x-8),2)),Color("#762637",0.6))
	# Fine panel telemetry replaces broad distracting pink outlines.
	for i in range(1,mini(14,int(rect.size.y/37.0))):
		var yy := rect.position.y+35.0+float(i)*37.0
		if yy >= rect.end.y-13.0:
			break
		canvas.draw_line(Vector2(rect.end.x-17,yy),Vector2(rect.end.x-7,yy),Color("#df344d",0.31),1.0)
		canvas.draw_line(Vector2(rect.position.x+11,yy),Vector2(rect.position.x+17,yy),Color("#892735",0.24),1.0)
	# Double-cut industrial corner brackets, rather than a plain 1px rectangle.
	for sx in [0.0,1.0]:
		for sy in [0.0,1.0]:
			var corner := Vector2(lerpf(rect.position.x,rect.end.x,sx),lerpf(rect.position.y,rect.end.y,sy))
			var dir_x := 1.0 if sx==0.0 else -1.0
			var dir_y := 1.0 if sy==0.0 else -1.0
			canvas.draw_line(corner+Vector2(2*dir_x,2*dir_y),corner+Vector2(18*dir_x,2*dir_y),red,2.0)
			canvas.draw_line(corner+Vector2(2*dir_x,2*dir_y),corner+Vector2(2*dir_x,16*dir_y),red,2.0)
			canvas.draw_line(corner+Vector2(6*dir_x,6*dir_y),corner+Vector2(11*dir_x,6*dir_y),Color("#fa576b",0.45),1.0)
	# An animated diagnostic scanner lives solely in the 4px title rail.
	var sweep := (sin(pulse*1.3)+1.0)*0.5
	var px := rect.position.x+20.0+sweep*maxf(1.0,rect.size.x-67.0)
	canvas.draw_line(Vector2(px,rect.position.y+3),Vector2(px+12,rect.position.y+3),Color("#ff586b",0.74),2.0)
	# Microcode remains in the unobtrusive header margin, never over text.
	for i in range(4):
		var bx := rect.end.x-37.0+float(i)*7.0
		canvas.draw_line(Vector2(bx,rect.position.y+9),Vector2(bx,rect.position.y+13.0+float(i%2)*3.0),Color("#b53246",0.53),1.0)

static func backdrop(canvas: CanvasItem, size: Vector2, seconds: float) -> void:
	# World is never obscured. Tiny corner-code rain visually binds the UI to
	# the DPN identity without making interactive world information harder to read.
	canvas.draw_rect(Rect2(0,0,size.x,3),RED_DIM)
	for i in range(13):
		var x := 13.0+float(i)*20.0
		var y := 94.0+fposmod(seconds*11.0+float(i)*23.0,maxf(90.0,size.y-175.0))
		canvas.draw_string(ThemeDB.fallback_font,Vector2(x,y),"1" if i%3==0 else "0",HORIZONTAL_ALIGNMENT_LEFT,12.0,10,Color("#e33c51",0.14))


static func button(canvas: CanvasItem, rect: Rect2, label: String, hovered: bool, active: bool = false, dangerous: bool = false, enabled: bool = true, small: bool = false) -> void:
	var highlighted := enabled and (hovered or active)
	var accent := RED if dangerous or active else (Color("#e2606e") if hovered else Color("#70404d"))
	var fill := Color("#36121e") if active else (Color("#28131d") if hovered else SURFACE)
	if not enabled:
		fill=Color("#101017")
		accent=Color("#38303b")
	canvas.draw_rect(rect,Color("#07080c"))
	canvas.draw_rect(rect.grow(-1),fill)
	canvas.draw_rect(rect,accent,false,1.0)
	canvas.draw_rect(Rect2(rect.position+Vector2(1,2),Vector2(3,maxf(1.0,rect.size.y-4))),accent)
	canvas.draw_line(rect.position+Vector2(8,2),Vector2(rect.end.x-8,2),Color("#c34b5f",0.54 if highlighted else 0.21),1.0)
	canvas.draw_line(Vector2(rect.position.x+8,rect.end.y-3),Vector2(rect.end.x-8,rect.end.y-3),accent if highlighted else Color("#44303a"),1.0)
	# Angular highlighted corners are also visible on keyboard-selected actions.
	if highlighted:
		canvas.draw_line(rect.position+Vector2(2,10),rect.position+Vector2(10,2),accent,1.3)
		canvas.draw_line(rect.end-Vector2(2,10),rect.end-Vector2(10,2),accent,1.3)
	var color := TEXT if enabled else Color("#76686f")
	canvas.draw_string(ThemeDB.fallback_font,rect.position+Vector2(9,rect.size.y*0.5+(3.2 if small else 4.0)),label,HORIZONTAL_ALIGNMENT_LEFT,maxf(6.0,rect.size.x-17.0),10 if small else 11,color)

static func list_row(canvas: CanvasItem, rect: Rect2, active: bool, hovered: bool, danger: bool = false) -> void:
	var fill := Color("#34131d") if active else (Color("#28202a") if hovered else Color("#101118"))
	canvas.draw_rect(rect,fill)
	canvas.draw_rect(rect,Color("#79404b") if active else Color("#302a35"),false,1.0)
	canvas.draw_rect(Rect2(rect.position,Vector2(3,rect.size.y)),RED if active or danger else Color("#59313c"))
	if hovered:
		canvas.draw_line(Vector2(rect.position.x+7,rect.end.y-2),Vector2(rect.end.x-7,rect.end.y-2),Color("#e44057",0.53),1.0)

static func meter(canvas: CanvasItem, rect: Rect2, value: float, severity: Color) -> void:
	var fraction := clampf(value,0.0,1.0)
	canvas.draw_rect(rect,Color("#29202b"))
	canvas.draw_rect(Rect2(rect.position,Vector2(rect.size.x*fraction,rect.size.y)),severity)
	canvas.draw_rect(rect,Color("#69404b"),false,1.0)
	for i in range(1,10):
		var x := rect.position.x+rect.size.x*float(i)/10.0
		canvas.draw_line(Vector2(x,rect.position.y),Vector2(x,rect.end.y),Color("#07080c",0.6),1.0)

static func nav_icon(canvas: CanvasItem, at: Vector2, index: int, color: Color) -> void:
	var center := at+Vector2(8,8)
	match index:
		0:
			canvas.draw_rect(Rect2(center-Vector2(5,2),Vector2(10,9)),color,false,1.2)
			canvas.draw_line(center+Vector2(-7,-2),center+Vector2(0,-7),color,1.2)
			canvas.draw_line(center+Vector2(0,-7),center+Vector2(7,-2),color,1.2)
		1:
			canvas.draw_arc(center,6.0,0.0,TAU,24,color,1.4)
			canvas.draw_line(center+Vector2(-9,0),center+Vector2(9,0),color,1.2)
			canvas.draw_line(center+Vector2(0,-9),center+Vector2(0,9),color,1.2)
		2:
			for i in range(3):
				canvas.draw_rect(Rect2(center+Vector2(-6+float(i)*5.0,-4),Vector2(3,10)),color,false,1)
			canvas.draw_line(center+Vector2(-8,-6),center+Vector2(8,-6),color,1.3)
		3:
			canvas.draw_rect(Rect2(center+Vector2(-7,-2),Vector2(14,9)),color,false,1.3)
			canvas.draw_line(center+Vector2(-7,-2),center+Vector2(-2,-6),color,1)
			canvas.draw_line(center+Vector2(-2,-6),center+Vector2(1,-2),color,1)
			canvas.draw_line(center+Vector2(1,-2),center+Vector2(5,-6),color,1)
		4:
			for point in [Vector2(0,-6),Vector2(-6,5),Vector2(6,5)]:
				canvas.draw_circle(center+point,2.4,color)
			canvas.draw_line(center+Vector2(0,-6),center+Vector2(-6,5),color,1)
			canvas.draw_line(center+Vector2(0,-6),center+Vector2(6,5),color,1)
		5:
			canvas.draw_arc(center,7,0,TAU,28,color,1.2)
			canvas.draw_line(center+Vector2(-7,0),center+Vector2(7,0),color,1)
			canvas.draw_line(center+Vector2(0,-7),center+Vector2(0,7),color,1)
		6,7:
			canvas.draw_rect(Rect2(center-Vector2(6,6),Vector2(12,12)),color,false,1.3)
			canvas.draw_line(center+Vector2(0,4 if index==6 else -4),center+Vector2(0,-4 if index==6 else 4),color,1.4)
			canvas.draw_line(center+Vector2(-3,1 if index==6 else -1),center+Vector2(0,-4 if index==6 else 4),color,1.2)
			canvas.draw_line(center+Vector2(3,1 if index==6 else -1),center+Vector2(0,-4 if index==6 else 4),color,1.2)
		8:
			canvas.draw_rect(Rect2(center-Vector2(6,7),Vector2(12,14)),color,false,1.2)
			canvas.draw_line(center+Vector2(-3,-2),center+Vector2(3,-2),color,1)
			canvas.draw_line(center+Vector2(-3,2),center+Vector2(3,2),color,1)


static func nav_station(canvas: CanvasItem, rect: Rect2, index: int, label: String, key_hint: String, active: bool, hover: bool) -> void:
	button(canvas,rect,"",hover,active,false,true,true)
	var icon_color := RED if active else (TEXT if hover else Color("#aa8f96"))
	canvas.draw_rect(Rect2(rect.position+Vector2(3,4),Vector2(2,rect.size.y-8)),RED if active else Color("#492631"))
	nav_icon(canvas,rect.position+Vector2(8,rect.size.y*0.5-8),index,icon_color)
	canvas.draw_string(ThemeDB.fallback_font,rect.position+Vector2(33,rect.size.y*0.5+5),label,HORIZONTAL_ALIGNMENT_LEFT,maxf(10.0,rect.size.x-52.0),11,TEXT)
	canvas.draw_string(ThemeDB.fallback_font,Vector2(rect.end.x-6,rect.position.y+12),key_hint,HORIZONTAL_ALIGNMENT_RIGHT,16,9,RED if active else MUTED)
	if active:
		canvas.draw_rect(Rect2(rect.position+Vector2(4,rect.size.y-3),Vector2(rect.size.x-8,3)),RED)
		canvas.draw_rect(Rect2(rect.position+Vector2(7,3),Vector2(rect.size.x-14,2)),Color("#ff7280",0.68))
	elif hover:
		canvas.draw_rect(Rect2(rect.position+Vector2(6,rect.size.y-3),Vector2(rect.size.x-12,2)),Color("#b84658",0.72))


static func resource(canvas: CanvasItem, rect: Rect2, label: String, reading: String, fraction: float, severity: Color, hover: bool) -> void:
	# Compact instrument: prominent value, restrained diagnostics and truthful severity.
	canvas.draw_rect(rect,Color("#25131e") if hover else Color("#0b0e14"))
	canvas.draw_rect(rect,Color("#bb5062") if hover else Color("#4b2837"),false,1.0)
	canvas.draw_rect(Rect2(rect.position+Vector2(1,2),Vector2(3,rect.size.y-4)),severity)
	canvas.draw_line(rect.position+Vector2(8,2),Vector2(rect.end.x-8,2),Color("#aa394d",0.50 if hover else 0.23),1.0)
	canvas.draw_string(ThemeDB.fallback_font,rect.position+Vector2(9,15),label,HORIZONTAL_ALIGNMENT_LEFT,maxf(8.0,rect.size.x-18.0),9,MUTED)
	canvas.draw_string(ThemeDB.fallback_font,rect.position+Vector2(9,35),reading,HORIZONTAL_ALIGNMENT_LEFT,maxf(8.0,rect.size.x-18.0),15,TEXT)
	meter(canvas,Rect2(rect.position+Vector2(7,rect.size.y-6),Vector2(maxf(3.0,rect.size.x-14.0),3)),fraction,severity)
	canvas.draw_circle(rect.position+Vector2(rect.size.x-10,10),2.2,severity)
	if hover:
		canvas.draw_line(Vector2(rect.position.x+9,rect.end.y-9),Vector2(rect.end.x-9,rect.end.y-9),Color("#ec4d63",0.4),1.0)
