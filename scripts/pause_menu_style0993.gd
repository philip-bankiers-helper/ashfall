extends Node
## Narrow battle-menu panel: stacked icon cards, cyan primary action, restrained dark rows.
var cards:Array[MeshInstance3D]=[]
var glyphs:Array[Sprite3D]=[]
var desktop_content:Array[VBoxContainer]=[]
const CAPTIONS:=["RESUME","SETTINGS","INITIALIZE\nVERTICAL COMBAT SYSTEM","HOME"]
func setup(menu:Node)->void:
	for i in 4:
		var card:=MeshInstance3D.new();card.name="PauseCard"+str(i);card.mesh=QuadMesh.new();card.mesh.size=Vector2(.58,.21);card.position=Vector3(0,menu._menu_row_y(i),.005)
		var shader:=Shader.new();shader.code="""shader_type spatial;render_mode unshaded,cull_disabled;
uniform vec4 top_color:source_color=vec4(.08,.12,.16,1.);
uniform vec4 bottom_color:source_color=vec4(.025,.04,.055,1.);
uniform vec4 edge_color:source_color=vec4(.3,.4,.45,1.);
void fragment(){vec2 edge=min(UV,vec2(1.)-UV);float rim=1.-step(.008,min(edge.x,edge.y));ALBEDO=mix(mix(top_color.rgb,bottom_color.rgb,UV.y),edge_color.rgb,rim);}
"""
		card.material_override=ShaderMaterial.new();card.material_override.shader=shader;card.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;menu._panel.add_child(card);cards.append(card)
		var texture:Texture2D=load("res://assets/ui/pause0993_%d.svg"%i)
		var glyph:=Sprite3D.new();glyph.texture=texture;glyph.pixel_size=.0009;glyph.no_depth_test=false;glyph.position=card.position+Vector3(0,.034,.006);menu._panel.add_child(glyph);glyphs.append(glyph)
		var button:Button=menu._buttons[i];var box:=VBoxContainer.new();box.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);box.add_theme_constant_override("separation",3);box.alignment=BoxContainer.ALIGNMENT_CENTER;button.add_child(box);desktop_content.append(box)
		var image:=TextureRect.new();image.mouse_filter=Control.MOUSE_FILTER_IGNORE;image.texture=texture;image.custom_minimum_size=Vector2(0,30);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;box.add_child(image)
		var text:=Label.new();text.mouse_filter=Control.MOUSE_FILTER_IGNORE;text.text=CAPTIONS[i];text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.add_theme_font_size_override("font_size",16 if i==2 else 19);box.add_child(text)
func refresh(menu:Node)->void:
	var active:bool=menu.settings_page=="pause"
	var board:MeshInstance3D=menu._panel.get_node("SettingsBoard");board.mesh.size=Vector2(.70,1.25) if active else Vector2(1.3,1.48)
	menu._spatial_title.position.y=.54 if active else .61;menu._spatial_title.font_size=29 if active else 42
	if active:menu._spatial_title.text="BATTLE MENU";menu._spatial_title.modulate=Color.WHITE;menu._desktop_title.text="BATTLE MENU"
	else:menu._spatial_title.modulate=Color("40e8ef")
	menu._desktop_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if active else HORIZONTAL_ALIGNMENT_LEFT
	menu._desktop_title.get_parent().custom_minimum_size.x=300 if active else 440
	menu._desktop_hint.visible=not active
	for i in 4:
		cards[i].visible=active;glyphs[i].visible=active;desktop_content[i].visible=active
		var button:Button=menu._buttons[i];button.custom_minimum_size.y=94 if active else 48
		for state in ["normal","hover","focus","pressed"]:
			if active:
				var style:=StyleBoxFlat.new();style.bg_color=Color("057da5") if i==0 else Color("202830");style.border_color=Color("b4e7f3") if state!="normal" else (Color("52d7ef") if i==0 else Color("465360"));style.set_border_width_all(1);style.border_width_bottom=3;button.add_theme_stylebox_override(state,style)
			else:button.remove_theme_stylebox_override(state)
		if not active:continue
		cards[i].position.y=menu._menu_row_y(i);glyphs[i].position=cards[i].position+Vector3(0,.035,.008)
		var selected:bool=menu.selected==i
		cards[i].material_override.set_shader_parameter("top_color",Color("148fb6") if i==0 else Color("303b45"))
		cards[i].material_override.set_shader_parameter("bottom_color",Color("055776") if i==0 else Color("111a23"))
		cards[i].material_override.set_shader_parameter("edge_color",Color("b0edff") if selected else (Color("3d9eb9") if i==0 else Color("50606c")))
		menu._rows[i].text=CAPTIONS[i];menu._rows[i].position=Vector3(0,menu._menu_row_y(i)-.064,.014);menu._rows[i].font_size=17 if i==2 else 23;menu._rows[i].modulate=Color.WHITE;button.text=""
