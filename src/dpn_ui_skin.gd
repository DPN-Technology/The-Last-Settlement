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
	var red := RED if selected else RED_DIM
	canvas.draw_rect(rect,Color("#06070bc0"))
	canvas.draw_rect(Rect2(rect.position+Vector2(2,2),rect.size-Vector2(4,4)),PANEL)
	canvas.draw_rect(Rect2(rect.position+Vector2(2,2),Vector2(rect.size.x-4,34)),Color("#1c1119"))
	canvas.draw_rect(rect,Color("#5a333f"),false,1.0)
	canvas.draw_line(rect.position+Vector2(0,35),Vector2(rect.end.x,rect.position.y+35),Color("#572832"),1)
	canvas.draw_rect(Rect2(rect.position+Vector2(2,2),Vector2(rect.size.x-4,2)),red)
	canvas.draw_rect(Rect2(rect.position+Vector2(2,2),Vector2(3,30)),RED)
	canvas.draw_rect(Rect2(rect.position+Vector2(0,rect.size.y-4),Vector2(rect.size.x,2)),Color("#3e222d"))
	# Structural edge brackets read as technical hardware, not flat panels.
	for sx in [0.0,1.0]:
		for sy in [0.0,1.0]:
			var corner := Vector2(lerpf(rect.position.x,rect.end.x,sx),lerpf(rect.position.y,rect.end.y,sy))
			var dir_x := 1.0 if sx==0.0 else -1.0
			var dir_y := 1.0 if sy==0.0 else -1.0
			canvas.draw_line(corner+Vector2(2*dir_x,2*dir_y),corner+Vector2(15*dir_x,2*dir_y),red,2.0)
			canvas.draw_line(corner+Vector2(2*dir_x,2*dir_y),corner+Vector2(2*dir_x,13*dir_y),red,2.0)
	var lines := mini(7,int(rect.size.y/45.0))
	for i in range(lines):
		var yy := rect.position.y+51.0+float(i)*47.0
		if yy >= rect.end.y-20.0:
			break
		canvas.draw_line(Vector2(rect.end.x-12,yy),Vector2(rect.end.x-6,yy),Color("#a62f40",0.37),1.0)
	# A tiny red optical scanner only inside the panel title ribbon.
	var sweep := (sin(pulse*1.3)+1.0)*0.5
	var px := rect.position.x+20.0+sweep*maxf(1.0,rect.size.x-60.0)
	canvas.draw_line(Vector2(px,rect.position.y+4),Vector2(px+18,rect.position.y+4),Color("#fa5369",0.6),1.0)

static func backdrop(canvas: CanvasItem, size: Vector2, seconds: float) -> void:
	# World is never obscured. Tiny corner-code rain visually binds the UI to
	# the DPN identity without making interactive world information harder to read.
	canvas.draw_rect(Rect2(0,0,size.x,3),RED_DIM)
	for i in range(13):
		var x := 13.0+float(i)*20.0
		var y := 94.0+fposmod(seconds*11.0+float(i)*23.0,maxf(90.0,size.y-175.0))
		canvas.draw_string(ThemeDB.fallback_font,Vector2(x,y),"1" if i%3==0 else "0",HORIZONTAL_ALIGNMENT_LEFT,12.0,10,Color("#e33c51",0.14))

static func button(canvas: CanvasItem, rect: Rect2, label: String, hovered: bool, active: bool = false, dangerous: bool = false, enabled: bool = true, small: bool = false) -> void:
	var accent := RED if dangerous or active else (Color("#bd6772") if hovered else Color("#65404b"))
	var fill := Color("#35131f") if active else (Color("#2d1823") if hovered else SURFACE)
	if not enabled:
		fill=Color("#101017")
		accent=Color("#38303b")
	canvas.draw_rect(rect,fill)
	canvas.draw_rect(rect,accent,false,1.0)
	canvas.draw_rect(Rect2(rect.position+Vector2(0,1),Vector2(3,maxf(1.0,rect.size.y-2))),accent)
	canvas.draw_line(rect.position+Vector2(7,2),Vector2(rect.end.x-7,2),Color("#9b4759",0.36),1)
	if hovered and enabled:
		canvas.draw_line(Vector2(rect.position.x+5,rect.end.y-2),Vector2(rect.end.x-5,rect.end.y-2),RED,1.5)
	var color := TEXT if enabled else Color("#76686f")
	canvas.draw_string(ThemeDB.fallback_font,rect.position+Vector2(9,rect.size.y*0.5+(3.2 if small else 4.0)),label,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-17,10 if small else 11,color)

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
	var icon_color := RED if active else (TEXT if hover else Color("#ac9098"))
	nav_icon(canvas,rect.position+Vector2(8,rect.size.y*0.5-8),index,icon_color)
	canvas.draw_string(ThemeDB.fallback_font,rect.position+Vector2(33,rect.size.y*0.5+5),label,HORIZONTAL_ALIGNMENT_LEFT,maxf(10.0,rect.size.x-52.0),11,TEXT)
	canvas.draw_string(ThemeDB.fallback_font,Vector2(rect.end.x-6,rect.position.y+12),key_hint,HORIZONTAL_ALIGNMENT_RIGHT,16,9,RED if active else MUTED)
	if active:
		canvas.draw_rect(Rect2(rect.position+Vector2(3,rect.size.y-3),Vector2(rect.size.x-6,3)),RED)

static func resource(canvas: CanvasItem, rect: Rect2, label: String, reading: String, fraction: float, severity: Color, hover: bool) -> void:
	canvas.draw_rect(rect,Color("#23141f") if hover else Color("#0e1017"))
	canvas.draw_rect(rect,Color("#a64a5b") if hover else Color("#49313e"),false,1)
	canvas.draw_rect(Rect2(rect.position+Vector2(0,0),Vector2(3,rect.size.y)),severity)
	canvas.draw_string(ThemeDB.fallback_font,rect.position+Vector2(9,15),label,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-18,9,MUTED)
	canvas.draw_string(ThemeDB.fallback_font,rect.position+Vector2(9,35),reading,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-18,15,TEXT)
	meter(canvas,Rect2(rect.position+Vector2(7,rect.size.y-6),Vector2(maxf(3.0,rect.size.x-14),3)),fraction,severity)
	canvas.draw_circle(rect.position+Vector2(rect.size.x-10,10),2, severity)
