# scripts/ui/cheat_console.gd
class_name CheatConsole
extends CanvasLayer

const SaveManager = preload("res://scripts/core/save_manager.gd")
const ProgressionSystem = preload("res://scripts/core/progression_system.gd")
const GarageData = preload("res://scripts/core/garage_data.gd")
const ArsenalExpanded = preload("res://scripts/weapons/arsenal_expanded.gd")

signal cheat_executed(command: String, args: Array)

var save_manager: SaveManager

var is_open: bool = false
var god_mode: bool = false
var infinite_ammo: bool = false
var infinite_nitro: bool = false

var panel: PanelContainer
var output_label: RichTextLabel
var line_edit: LineEdit

func _ready() -> void:
	layer = 100
	visible = false
	_build_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F4:
			toggle()
			get_viewport().set_input_as_handled()

func toggle() -> void:
	is_open = not is_open
	visible = is_open
	if is_open and line_edit:
		line_edit.grab_focus()
		line_edit.clear()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.6
	add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.theme_override_constants.separation = 8
	panel.add_child(vbox)
	
	var header := Label.new()
	header.text = "GRIDLETHAL DEVELOPER CHEAT CONSOLE [F4 TO CLOSE]"
	header.add_theme_color_override("font_color", Color(1.0, 0.4, 0.0))
	vbox.add_child(header)
	
	output_label = RichTextLabel.new()
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.scroll_following = true
	output_label.bbcode_enabled = true
	output_label.text = "[color=#888888]Type [color=#ffaa00]'help'[/color] for list of cheat commands.[/color]\n"
	vbox.add_child(output_label)
	
	var hbox := HBoxContainer.new()
	vbox.add_child(hbox)
	
	var prompt := Label.new()
	prompt.text = "> "
	hbox.add_child(prompt)
	
	line_edit = LineEdit.new()
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.placeholder_text = "Enter cheat command..."
	line_edit.text_submitted.connect(_on_command_submitted)
	hbox.add_child(line_edit)

func _on_command_submitted(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	line_edit.clear()
	execute_command(trimmed)

func execute_command(cmd_str: String) -> String:
	var tokens := cmd_str.split(" ", false)
	if tokens.is_empty():
		return ""
	var cmd := tokens[0].to_lower()
	var args: Array = []
	for i in range(1, tokens.size()):
		args.append(tokens[i])
		
	var sm: SaveManager = save_manager
	if not sm:
		sm = SaveManager.new()
		
	var log_msg := ""
	
	if cmd == "help":
		log_msg = "[color=#00e5ff]AVAILABLE COMMANDS:[/color]\n"
		log_msg += "  cash <amount>          - Grant cash\n"
		log_msg += "  gold <amount>          - Grant gold\n"
		log_msg += "  scrap <amount>         - Grant scrap\n"
		log_msg += "  level <lvl>            - Set player level (1-100)\n"
		log_msg += "  unlock_cars            - Unlock all 12 vehicles\n"
		log_msg += "  unlock_weapons         - Unlock all 26 weapons\n"
		log_msg += "  god                    - Toggle hull invulnerability\n"
		log_msg += "  infinite_ammo          - Toggle unlimited ammo\n"
		log_msg += "  infinite_nitro         - Toggle infinite nitro boost\n"
		log_msg += "  clear                  - Clear console output"
	elif cmd == "cash" or cmd == "add_cash":
		var amt: int = int(args[0]) if args.size() > 0 else 50000
		sm.save_data["cash"] = int(sm.save_data.get("cash", 0)) + amt
		sm.save_slot(sm.current_slot)
		log_msg = "[color=#00ff88]Granted $%s cash. Current Cash: $%s[/color]" % [str(amt), str(sm.save_data["cash"])]
	elif cmd == "gold" or cmd == "add_gold":
		var amt: int = int(args[0]) if args.size() > 0 else 100
		sm.save_data["gold"] = int(sm.save_data.get("gold", 0)) + amt
		sm.save_slot(sm.current_slot)
		log_msg = "[color=#ffcc00]Granted %d gold. Current Gold: %d[/color]" % [amt, sm.save_data["gold"]]
	elif cmd == "scrap" or cmd == "add_scrap":
		var amt: int = int(args[0]) if args.size() > 0 else 500
		sm.save_data["scrap"] = int(sm.save_data.get("scrap", 0)) + amt
		sm.save_slot(sm.current_slot)
		log_msg = "[color=#00e5ff]Granted %d scrap. Current Scrap: %d[/color]" % [amt, sm.save_data["scrap"]]
	elif cmd == "level" or cmd == "set_level":
		var lvl: int = clamp(int(args[0]) if args.size() > 0 else 50, 1, 100)
		sm.save_data["player_level"] = lvl
		sm.save_data["player_xp"] = ProgressionSystem.get_xp_for_level(lvl)
		sm.save_slot(sm.current_slot)
		log_msg = "[color=#00ff88]Player level set to %d (XP: %d)[/color]" % [lvl, sm.save_data["player_xp"]]
	elif cmd == "unlock_cars" or cmd == "unlock_all_cars":
		var owned: Dictionary = sm.save_data.get("owned_cars", {})
		for c_id in GarageData.CAR_RECIPES.keys():
			if not owned.has(c_id):
				owned[c_id] = {
					"paint_color": "#ee1808", "finish": "metallic", "rim_style": "default",
					"has_spoiler": true, "upgrades": {
						"engine": 5, "turbo": 5, "transmission": 5, "brakes": 5,
						"suspension": 5, "tyres": 5, "armour": 5, "nitro": 5,
						"cooling": 5, "weight_reduction": 5
					},
					"equipped_weapons": {
						"primary": "twin_mg", "roof": "rocket_pod", "rear": "mine_dropper", "passive": "armour_plating"
					}
				}
		sm.save_slot(sm.current_slot)
		log_msg = "[color=#00ff88]All 12 vehicles unlocked with MAX Tier-5 upgrades![/color]"
	elif cmd == "unlock_weapons" or cmd == "unlock_all_weapons":
		sm.save_data["unlocked_weapons"] = ArsenalExpanded.ALL_WEAPONS.keys()
		sm.save_slot(sm.current_slot)
		log_msg = "[color=#00ff88]All 26 weapons unlocked in inventory![/color]"
	elif cmd == "god" or cmd == "god_mode":
		god_mode = not god_mode
		log_msg = "[color=#ff5500]God Mode (Hull Invulnerability): %s[/color]" % ("ON" if god_mode else "OFF")
	elif cmd == "infinite_ammo":
		infinite_ammo = not infinite_ammo
		log_msg = "[color=#ffaa00]Infinite Ammo: %s[/color]" % ("ON" if infinite_ammo else "OFF")
	elif cmd == "infinite_nitro":
		infinite_nitro = not infinite_nitro
		log_msg = "[color=#00ffff]Infinite Nitro: %s[/color]" % ("ON" if infinite_nitro else "OFF")
	elif cmd == "clear":
		if output_label:
			output_label.text = ""
		return ""
	else:
		log_msg = "[color=#ff4444]Unknown command '%s'. Type 'help' for commands.[/color]" % cmd
		
	if output_label:
		output_label.append_text("> " + cmd_str + "\n" + log_msg + "\n")
		
	cheat_executed.emit(cmd, args)
	return log_msg
