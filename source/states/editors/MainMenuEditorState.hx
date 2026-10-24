package states.editors;

import backend.MainMenuData;
import backend.ui.PsychUIBox;
import backend.ui.PsychUIButton;
import backend.ui.PsychUICheckBox;
import backend.ui.PsychUIDropDownMenu;
import backend.ui.PsychUIInputText;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import haxe.Json;

/**
 * Editor del menú principal y de los menús custom (Options / FreePlay / Credits).
 *
 *  - Main:     lista de items, vista previa del layout completo (arrastra con el mouse/dedo para fijar x/y).
 *  - Options:  entradas de data/options_menu.json
 *  - FreePlay: canciones de data/freeplay_menu.json
 *  - Credits:  entradas de data/credits_menu.json
 *  - Scripts:  crea plantillas Lua / HScript en mods/<mod>/scripts/<menu>/
 *
 * Atajos: ARRIBA/ABAJO seleccionar, 1-4 cambiar de menú, CTRL+S guardar, CTRL+Z deshacer, CTRL+D duplicar, ESC salir.
 * Todo tiene botón para poder usarlo sin teclado (Android).
 */
class MainMenuEditorState extends MusicBeatState
{
	static final MODES:Array<String> = ['Main', 'Options', 'FreePlay', 'Credits'];
	static final KINDS:Array<String> = ['mainmenu', 'options', 'freeplay', 'credits'];

	// key, etiqueta, tipo (s = texto, n = número opcional)
	static final FIELDS:Array<Array<Array<String>>> = [
		[
			['id', 'ID (prefijo de animación):', 's'],
			['image', 'Imagen (atlas sin extensión):', 's'],
			['args', 'Args (URL, clase o función de script):', 's'],
			['x', 'X (vacío = automático):', 'n'],
			['y', 'Y (vacío = automático):', 'n'],
			['scale', 'Escala (vacío = 1):', 'n']
		],
		[
			['label', 'Texto de la opción:', 's'],
			['args', 'Args (clase, URL o función de script):', 's']
		],
		[
			['name', 'Canción (carpeta de data/):', 's'],
			['icon', 'Icono de salud:', 's'],
			['color', 'Color de fondo (#RRGGBB):', 's'],
			['difficulties', 'Dificultades (easy,normal,hard):', 's'],
			['mod', 'Mod de la canción (opcional):', 's']
		],
		[
			['name', 'Nombre:', 's'],
			['desc', 'Descripción:', 's'],
			['icon', 'Icono (images/credits/<icono>.png):', 's'],
			['color', 'Color de fondo (#RRGGBB):', 's'],
			['url', 'URL al aceptar:', 's']
		]
	];

	// Vista previa
	static final P:Float = 0.42;
	static final FRAME_X:Float = 340;
	static final FRAME_Y:Float = 20;

	var mode:Int = 0;
	var sels:Array<Int> = [0, 0, 0, 0];

	var mainData:MainMenuFile;
	var custom:Map<String, Dynamic> = new Map();
	var touched:Map<String, Bool> = new Map();
	var customMenu:Bool = false;

	var loading:Bool = false;
	var dirty:Bool = false;
	var exitArmed:Bool = false;
	var undoStack:Array<String> = [];
	var lastUndoPush:Float = -10;

	// vista
	var rows:FlxTypedGroup<FlxText>;
	var prevGroup:FlxGroup;
	var frameBg:FlxSprite;
	var prevSprites:Array<FlxSprite> = [];
	var prevSlots:Array<Int> = [];
	var selBox:FlxSprite;
	var status:FlxText;
	var modeButtons:Array<PsychUIButton> = [];

	// arrastre
	var dragging:Bool = false;
	var dragOffX:Float = 0;
	var dragOffY:Float = 0;

	// UI
	var UI_box:PsychUIBox;
	var fieldLabels:Array<FlxText> = [];
	var fieldInputs:Array<PsychUIInputText> = [];
	var headerBox:PsychUICheckBox;
	var actionLabel:FlxText;
	var actionMainDD:PsychUIDropDownMenu;
	var actionOptDD:PsychUIDropDownMenu;
	var autoPosButton:PsychUIButton;

	var spacingInput:PsychUIInputText;
	var startYInput:PsychUIInputText;
	var customMenuBox:PsychUICheckBox;
	var enabledBox:PsychUICheckBox;
	var bgInput:PsychUIInputText;
	var mainOnlyWidgets:Array<FlxSprite> = [];
	var otherOnlyWidgets:Array<FlxSprite> = [];
	var freeplayOnlyWidgets:Array<FlxSprite> = [];
	var scriptsText:FlxText;

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Main Menu Editor", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		loadAll();

		frameBg = new FlxSprite(FRAME_X - 3, FRAME_Y - 3).makeGraphic(Std.int(FlxG.width * P) + 6, Std.int(FlxG.height * P) + 6, 0xFFAAAAAA);
		add(frameBg);
		var inner:FlxSprite = new FlxSprite(FRAME_X, FRAME_Y).makeGraphic(Std.int(FlxG.width * P), Std.int(FlxG.height * P), 0xFF222222);
		add(inner);

		prevGroup = new FlxGroup();
		add(prevGroup);

		rows = new FlxTypedGroup<FlxText>();
		add(rows);

		status = new FlxText(FRAME_X, FRAME_Y + FlxG.height * P + 12, FlxG.width * P, '', 16);
		status.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(status);

		var help:FlxText = new FlxText(20, FlxG.height - 30, FlxG.width - 40,
			'ARRIBA/ABAJO: seleccionar | 1-4: menú | CTRL+S: guardar | CTRL+Z: deshacer | CTRL+D: duplicar | ESC: salir', 16);
		help.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, LEFT);
		add(help);

		buildLeftColumn();
		buildUI();
		refreshAll();

		FlxG.mouse.visible = true;
		super.create();
	}

	function loadAll()
	{
		MainMenuData.forceOriginal = false; // el editor siempre edita el menú del mod
		mainData = MainMenuData.load();
		for (k in ['options', 'freeplay', 'credits'])
		{
			custom.set(k, MainMenuData.loadCustom(k));
			touched.set(k, false);
		}
		customMenu = MainMenuData.hasCustomMenu();
	}

	// =================================================================== UI

	function buildLeftColumn()
	{
		for (i in 0...MODES.length)
		{
			var b:PsychUIButton = new PsychUIButton(20 + i * 78, 15, MODES[i], function() setMode(i), 74, 25);
			modeButtons.push(b);
			add(b);
		}

		add(new PsychUIButton(20, 495, 'Añadir', addEntry, 95, 25));
		add(new PsychUIButton(120, 495, 'Duplicar', duplicateCurrent, 95, 25));
		add(new PsychUIButton(220, 495, 'Borrar', removeCurrent, 95, 25));
		add(new PsychUIButton(20, 525, 'Subir', function() move(-1), 95, 25));
		add(new PsychUIButton(120, 525, 'Bajar', function() move(1), 95, 25));
		add(new PsychUIButton(220, 525, 'Deshacer', undo, 95, 25));
		add(new PsychUIButton(20, 555, 'Guardar', save, 95, 25));
		add(new PsychUIButton(120, 555, 'Recargar', reloadAll, 95, 25));
		add(new PsychUIButton(220, 555, 'Salir', exitEditor, 95, 25));
	}

	function buildUI()
	{
		UI_box = new PsychUIBox(FlxG.width - 380, 20, 360, 560, ['Item', 'Menu', 'Scripts']);
		UI_box.scrollFactor.set();
		add(UI_box);

		// ---------------- pestaña Item ----------------
		var tab = UI_box.getTab('Item').menu;

		for (i in 0...6)
		{
			var lbl:FlxText = new FlxText(15, 8 + i * 48, 330, '');
			var input:PsychUIInputText = new PsychUIInputText(15, 26 + i * 48, 320, '', 8);
			input.onChange = function(old:String, cur:String) onFieldChange(i, cur);
			fieldLabels.push(lbl);
			fieldInputs.push(input);
			tab.add(lbl);
			tab.add(input);
		}

		autoPosButton = new PsychUIButton(15, 300, 'Quitar X/Y (auto)', function() {
			var c:Dynamic = cur();
			if (c == null) return;
			pushUndo();
			Reflect.deleteField(c, 'x');
			Reflect.deleteField(c, 'y');
			markDirty();
			refreshAll();
		}, 160, 22);
		tab.add(autoPosButton);

		headerBox = new PsychUICheckBox(15, 300, 'Es un título (no seleccionable)', 280);
		headerBox.onClick = function() {
			if (loading || cur() == null) return;
			pushUndo();
			Reflect.setField(cur(), 'header', headerBox.checked);
			markDirty();
			refreshRows();
		};
		tab.add(headerBox);

		actionLabel = new FlxText(15, 332, 0, 'Acción:');
		tab.add(actionLabel);

		// Los dropdowns van últimos para dibujarse encima
		actionOptDD = new PsychUIDropDownMenu(15, 350, MainMenuData.OPTION_ACTIONS, function(index:Int, name:String) onActionChosen(name), 320);
		tab.add(actionOptDD);
		actionMainDD = new PsychUIDropDownMenu(15, 350, MainMenuData.MAIN_ACTIONS, function(index:Int, name:String) onActionChosen(name), 320);
		tab.add(actionMainDD);

		// ---------------- pestaña Menu ----------------
		var menu = UI_box.getTab('Menu').menu;

		// Main
		var l1:FlxText = new FlxText(15, 10, 0, 'Separación entre items (spacing):');
		spacingInput = new PsychUIInputText(15, 28, 150, '', 8);
		spacingInput.onChange = function(old:String, cur:String) {
			if (loading) return;
			var v:Float = Std.parseFloat(cur);
			if (Math.isNaN(v)) return;
			pushUndoDebounced();
			mainData.spacing = v;
			markDirty();
			refreshPreview();
		};
		var l2:FlxText = new FlxText(15, 60, 0, 'Y inicial (startY):');
		startYInput = new PsychUIInputText(15, 78, 150, '', 8);
		startYInput.onChange = function(old:String, cur:String) {
			if (loading) return;
			var v:Float = Std.parseFloat(cur);
			if (Math.isNaN(v)) return;
			pushUndoDebounced();
			mainData.startY = v;
			markDirty();
			refreshPreview();
		};
		var bL:PsychUIButton = new PsychUIButton(15, 115, 'Alternar LEFT', function() toggleSide(true), 155, 25);
		var bR:PsychUIButton = new PsychUIButton(180, 115, 'Alternar RIGHT', function() toggleSide(false), 155, 25);

		// Flag de pack.json: activa el panel rápido en el menú principal de este mod
		customMenuBox = new PsychUICheckBox(15, 160, 'Custom menu (panel rápido)', 250);
		customMenuBox.checked = customMenu;
		customMenuBox.onClick = function() {
			customMenu = customMenuBox.checked;
			markDirty();
		};

		var mainHint:FlxText = new FlxText(15, 195, 330,
			'Arrastra un item en la vista previa para fijar su X/Y. Acción "script": el campo Args es el nombre que recibe onMenuAction(nombre, id) en tus scripts.');

		var mainWs:Array<FlxSprite> = [l1, spacingInput, l2, startYInput, bL, bR, customMenuBox, mainHint];
		for (o in mainWs)
		{
			menu.add(o);
			mainOnlyWidgets.push(o);
		}

		// Options / FreePlay / Credits
		enabledBox = new PsychUICheckBox(15, 10, 'Usar este menú custom en el juego', 300);
		enabledBox.onClick = function() {
			if (loading || mode == 0) return;
			pushUndo();
			Reflect.setField(custom.get(KINDS[mode]), 'enabled', enabledBox.checked);
			touched.set(KINDS[mode], true);
			markDirty();
		};
		var otherHint:FlxText = new FlxText(15, 45, 330,
			'Si está desactivado, el juego usa el menú original. El archivo se guarda en data/<menú>_menu.json del mod.');
		var bgLabel:FlxText = new FlxText(15, 100, 0, 'Imagen de fondo de FreePlay (opcional):');
		bgInput = new PsychUIInputText(15, 118, 320, '', 8);
		bgInput.onChange = function(old:String, cur:String) {
			if (loading || mode != 2) return;
			pushUndoDebounced();
			Reflect.setField(custom.get('freeplay'), 'bg', cur);
			touched.set('freeplay', true);
			markDirty();
		};
		var otherWs:Array<FlxSprite> = [enabledBox, otherHint];
		for (o in otherWs)
		{
			menu.add(o);
			otherOnlyWidgets.push(o);
		}
		var fpWs:Array<FlxSprite> = [bgLabel, bgInput];
		for (o in fpWs)
		{
			menu.add(o);
			freeplayOnlyWidgets.push(o);
		}

		// ---------------- pestaña Scripts ----------------
		var sc = UI_box.getTab('Scripts').menu;
		scriptsText = new FlxText(15, 10, 330, '');
		sc.add(scriptsText);
		sc.add(new PsychUIButton(15, 330, 'Nuevo Lua', function() newScript(true), 100, 25));
		sc.add(new PsychUIButton(125, 330, 'Nuevo HScript', function() newScript(false), 120, 25));
		sc.add(new PsychUIButton(255, 330, 'Refrescar', refreshScripts, 85, 25));
		sc.add(new FlxText(15, 365, 330,
			'Hooks comunes: onCreate, onCreatePost, onUpdate, onUpdatePost, onSelect, onAccept, onBack.\n'
			+ 'Devuelve Function_Stop en onAccept para cancelar la acción.\n'
			+ 'Los scripts se cargan de mods/<mod>/scripts/<menú>/ (.lua y .hx).'));
	}

	// =================================================================== datos

	/** Items del modo actual como Dynamic (en Main: items + left + right). */
	function entries():Array<Dynamic>
	{
		if (mode == 0)
		{
			var a:Array<Dynamic> = [for (i in mainData.items) i];
			if (mainData.left != null) a.push(mainData.left);
			if (mainData.right != null) a.push(mainData.right);
			return a;
		}
		var kind:String = KINDS[mode];
		return Reflect.field(custom.get(kind), MainMenuData.listKeyOf(kind));
	}

	function sel():Int return sels[mode];

	function cur():Dynamic
	{
		var e:Array<Dynamic> = entries();
		return (sel() >= 0 && sel() < e.length) ? e[sel()] : null;
	}

	function slotKind(i:Int):String
	{
		if (mode != 0) return 'C';
		if (i < mainData.items.length) return 'C';
		var extra:Int = i - mainData.items.length;
		return (extra == 0 && mainData.left != null) ? 'L' : 'R';
	}

	function clampSel()
	{
		sels[mode] = Std.int(Math.max(0, Math.min(sel(), entries().length - 1)));
	}

	function listArray():Array<Dynamic>
	{
		if (mode == 0) return cast mainData.items;
		var kind:String = KINDS[mode];
		return Reflect.field(custom.get(kind), MainMenuData.listKeyOf(kind));
	}

	function newEntry():Dynamic
	{
		return switch (mode)
		{
			case 0: MainMenuData.newItem('new_item', 'none');
			case 1: {label: 'Nueva opción', action: 'state', args: ''};
			case 2: {name: 'cancion', icon: 'face', color: '#FFFFFF', difficulties: 'normal', mod: ''};
			default: {name: 'Nuevo', header: false, desc: '', icon: '', color: '#FFFFFF', url: ''};
		}
	}

	function addEntry()
	{
		pushUndo();
		var list:Array<Dynamic> = listArray();
		list.push(newEntry());
		sels[mode] = list.length - 1;
		touchMode();
		refreshAll();
	}

	function duplicateCurrent()
	{
		if (cur() == null || slotKind(sel()) != 'C') return;
		pushUndo();
		var list:Array<Dynamic> = listArray();
		var copy:Dynamic = Reflect.copy(cur());
		list.insert(sel() + 1, copy);
		sels[mode] = sel() + 1;
		touchMode();
		refreshAll();
	}

	function removeCurrent()
	{
		if (cur() == null) return;
		var k:String = slotKind(sel());

		if (k == 'C' && listArray().length <= 1)
		{
			setStatus('Debe quedar al menos una entrada.');
			return;
		}

		pushUndo();
		switch (k)
		{
			case 'C': listArray().splice(sel(), 1);
			case 'L': mainData.left = null;
			case 'R': mainData.right = null;
		}
		clampSel();
		touchMode();
		refreshAll();
	}

	function move(dir:Int)
	{
		if (slotKind(sel()) != 'C') return;
		var list:Array<Dynamic> = listArray();
		var to:Int = sel() + dir;
		if (to < 0 || to >= list.length) return;
		pushUndo();
		var tmp:Dynamic = list[sel()];
		list[sel()] = list[to];
		list[to] = tmp;
		sels[mode] = to;
		touchMode();
		refreshAll();
	}

	function toggleSide(left:Bool)
	{
		pushUndo();
		if (left) mainData.left = (mainData.left == null) ? MainMenuData.newItem('options', 'options') : null;
		else mainData.right = (mainData.right == null) ? MainMenuData.newItem('achievements', 'achievements') : null;
		clampSel();
		markDirty();
		refreshAll();
	}

	function touchMode()
	{
		if (mode > 0) touched.set(KINDS[mode], true);
		markDirty();
	}

	function markDirty()
	{
		dirty = true;
		exitArmed = false;
	}

	function onFieldChange(i:Int, text:String)
	{
		if (loading) return;
		var c:Dynamic = cur();
		var def:Array<String> = (i < FIELDS[mode].length) ? FIELDS[mode][i] : null;
		if (c == null || def == null) return;

		pushUndoDebounced();
		if (def[2] == 'n')
		{
			var v:Float = Std.parseFloat(text);
			if (text == null || text.length < 1) Reflect.deleteField(c, def[0]);
			else if (!Math.isNaN(v)) Reflect.setField(c, def[0], v);
			else return;
		}
		else
			Reflect.setField(c, def[0], text);

		touchMode();
		refreshRows();
		refreshPreview();
	}

	function onActionChosen(name:String)
	{
		if (loading || cur() == null) return;
		pushUndo();
		Reflect.setField(cur(), 'action', name);
		touchMode();
		refreshRows();
	}

	// =================================================================== deshacer

	function snapshot():String
	{
		return Json.stringify({
			main: mainData,
			options: custom.get('options'),
			freeplay: custom.get('freeplay'),
			credits: custom.get('credits'),
			customMenu: customMenu
		});
	}

	function pushUndo()
	{
		undoStack.push(snapshot());
		if (undoStack.length > 60) undoStack.shift();
		lastUndoPush = FlxG.game.ticks / 1000;
	}

	/** Para texto: agrupa lo que se escribe en tandas de 1 segundo. */
	function pushUndoDebounced()
	{
		if (FlxG.game.ticks / 1000 - lastUndoPush > 1) pushUndo();
	}

	function undo()
	{
		if (undoStack.length < 1)
		{
			setStatus('Nada que deshacer.');
			return;
		}
		var d:Dynamic = Json.parse(undoStack.pop());
		mainData = d.main;
		custom.set('options', d.options);
		custom.set('freeplay', d.freeplay);
		custom.set('credits', d.credits);
		customMenu = d.customMenu;
		customMenuBox.checked = customMenu;
		for (k in ['options', 'freeplay', 'credits']) touched.set(k, true);
		clampSel();
		markDirty();
		refreshAll();
		setStatus('Deshecho.');
	}

	// =================================================================== guardar / salir

	function save()
	{
		var path:String = MainMenuData.save(mainData);
		if (path == null)
		{
			setStatus('Guardar no está soportado en esta plataforma.');
			return;
		}

		var msg:String = 'Guardado: $path';
		for (k in ['options', 'freeplay', 'credits'])
		{
			var d:Dynamic = custom.get(k);
			if (touched.get(k) || Reflect.field(d, 'enabled') == true)
				msg += '\n' + MainMenuData.saveCustom(k, d);
		}

		var packPath:String = MainMenuData.setCustomMenu(customMenu);
		msg += (packPath != null ? '\nCustom menu = $customMenu en pack.json' : '\n(pack.json no se pudo modificar)');
		dirty = false;
		setStatus(msg);
	}

	function reloadAll()
	{
		loadAll();
		customMenuBox.checked = customMenu;
		undoStack = [];
		dirty = false;
		sels = [0, 0, 0, 0];
		refreshAll();
		setStatus('Recargado desde el disco.');
	}

	function exitEditor()
	{
		if (dirty && !exitArmed)
		{
			exitArmed = true;
			setStatus('Hay cambios sin guardar. Pulsa Salir / ESC otra vez para salir sin guardar.');
			return;
		}
		FlxG.mouse.visible = false;
		MusicBeatState.switchState(new MasterEditorMenu());
	}

	// =================================================================== scripts

	function newScript(lua:Bool)
	{
		var path:String = MainMenuData.createScriptTemplate(KINDS[mode], lua);
		setStatus(path != null ? 'Plantilla creada: $path' : 'No se pudo crear (ya existe o la plataforma no lo permite).');
		refreshScripts();
	}

	function refreshScripts()
	{
		var files:Array<String> = MainMenuData.scriptFiles(KINDS[mode]);
		var txt:String = 'Scripts de "${KINDS[mode]}": ${files.length}\n';
		for (f in files.slice(0, 8))
		{
			var at:Int = f.lastIndexOf('/scripts/');
			txt += '\n- ' + (at >= 0 ? f.substr(at + 1) : f);
		}
		if (files.length > 8) txt += '\n... y ${files.length - 8} más';
		if (files.length == 0) txt += '\n(ninguno todavía; usa "Nuevo Lua" o "Nuevo HScript")';
		scriptsText.text = txt;
	}

	// =================================================================== vista

	function setStatus(s:String) status.text = s;

	function setMode(m:Int)
	{
		if (m == mode) return;
		mode = m;
		clampSel();
		refreshAll();
	}

	function refreshAll()
	{
		refreshRows();
		loadInspector();
		refreshPreview();
		refreshScripts();
	}

	function rowLabel(i:Int, e:Dynamic):String
	{
		return switch (mode)
		{
			case 0:
				var prefix:String = switch (slotKind(i)) { case 'L': 'LEFT  '; case 'R': 'RIGHT '; default: '${i + 1}. '; }
				'$prefix${e.id}  [${e.action}]';
			case 1: '${i + 1}. ${e.label}  [${e.action}]';
			case 2: '${i + 1}. ${e.name}';
			default: (e.header == true ? '# ' : '${i + 1}. ') + e.name;
		}
	}

	function refreshRows()
	{
		for (r in rows.members) r.destroy();
		rows.clear();

		for (i => b in modeButtons)
			b.alpha = (i == mode) ? 1 : 0.6;

		var list:Array<Dynamic> = entries();
		var visibleRows:Int = 14;
		var top:Int = Std.int(Math.max(0, Math.min(sel() - 7, list.length - visibleRows)));

		for (i in top...Std.int(Math.min(list.length, top + visibleRows)))
		{
			var t:FlxText = new FlxText(20, 60 + (i - top) * 30, 300, rowLabel(i, list[i]), 20);
			t.setFormat(Paths.font("vcr.ttf"), 20, i == sel() ? FlxColor.YELLOW : FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.ID = i;
			rows.add(t);
		}
	}

	function loadInspector()
	{
		loading = true;
		var c:Dynamic = cur();
		var defs:Array<Array<String>> = FIELDS[mode];

		for (i in 0...6)
		{
			var used:Bool = i < defs.length;
			fieldLabels[i].visible = fieldInputs[i].visible = used;
			fieldInputs[i].active = used;
			if (!used) continue;

			fieldLabels[i].text = defs[i][1];
			var v:Dynamic = (c == null) ? null : Reflect.field(c, defs[i][0]);
			fieldInputs[i].text = (v == null) ? '' : Std.string(v);
		}

		var hasAction:Bool = mode == 0 || mode == 1;
		actionLabel.visible = hasAction;
		actionMainDD.visible = actionMainDD.active = (mode == 0);
		actionOptDD.visible = actionOptDD.active = (mode == 1);
		autoPosButton.visible = autoPosButton.active = (mode == 0);
		headerBox.visible = headerBox.active = (mode == 3);

		if (c != null)
		{
			if (mode == 0) actionMainDD.selectedLabel = c.action;
			if (mode == 1) actionOptDD.selectedLabel = c.action;
			if (mode == 3) headerBox.checked = c.header == true;
		}

		// pestaña Menu
		for (o in mainOnlyWidgets) o.visible = (mode == 0);
		for (o in otherOnlyWidgets) o.visible = (mode != 0);
		for (o in freeplayOnlyWidgets) o.visible = (mode == 2);
		spacingInput.active = startYInput.active = (mode == 0);
		enabledBox.active = (mode != 0);
		bgInput.active = (mode == 2);

		spacingInput.text = Std.string(mainData.spacing);
		startYInput.text = Std.string(mainData.startY);
		if (mode != 0)
		{
			var d:Dynamic = custom.get(KINDS[mode]);
			enabledBox.checked = Reflect.field(d, 'enabled') == true;
			if (mode == 2)
			{
				var bgv:Dynamic = Reflect.field(d, 'bg');
				bgInput.text = bgv == null ? '' : Std.string(bgv);
			}
		}
		loading = false;
	}

	function clearPreview()
	{
		for (m in prevGroup.members)
			if (m != null) m.destroy();
		prevGroup.clear();
		prevSprites = [];
		prevSlots = [];
		selBox = null;
	}

	function makePreviewSprite(d:MenuItemData, selected:Bool):FlxSprite
	{
		var s:FlxSprite = new FlxSprite();
		var scale:Float = (d.scale != null && d.scale > 0) ? d.scale : 1;

		if (Paths.fileExists('images/${d.image}.xml', TEXT))
		{
			s.frames = Paths.getSparrowAtlas(d.image);
			s.animation.addByPrefix('idle', '${d.id} idle', 24, true);
			s.animation.addByPrefix('selected', '${d.id} selected', 24, true);
			if (selected && s.animation.exists('selected')) s.animation.play('selected');
			else if (s.animation.exists('idle')) s.animation.play('idle');
			else if (s.animation.exists('selected')) s.animation.play('selected');
			if (selected && !s.animation.exists('selected'))
				setStatus('Falta la animación "${d.id} selected" en ${d.image}.xml');
		}
		else
		{
			s.makeGraphic(400, 100, 0xFF444444);
			if (selected) setStatus('No se encontró el atlas: images/${d.image}.xml');
		}

		s.scale.set(scale * P, scale * P);
		s.updateHitbox();
		s.antialiasing = ClientPrefs.data.antialiasing;
		return s;
	}

	function refreshPreview()
	{
		clearPreview();
		if (mode == 0) previewMain();
		else previewOther();
	}

	function previewMain()
	{
		var center:Array<FlxSprite> = [];
		var left:FlxSprite = null;
		var right:FlxSprite = null;
		var s:Int = sel();
		var slot:Int = 0;

		for (i in 0...mainData.items.length)
		{
			var spr:FlxSprite = makePreviewSprite(mainData.items[i], s == slot);
			center.push(spr);
			prevSlots.push(slot++);
		}
		if (mainData.left != null)
		{
			left = makePreviewSprite(mainData.left, s == slot);
			prevSlots.push(slot++);
		}
		if (mainData.right != null)
		{
			right = makePreviewSprite(mainData.right, s == slot);
			prevSlots.push(slot++);
		}

		MainMenuData.place(mainData, center, left, right, FlxG.width * P, FlxG.height * P, false, P);

		prevSprites = center.copy();
		if (left != null) prevSprites.push(left);
		if (right != null) prevSprites.push(right);

		for (spr in prevSprites)
		{
			spr.x += FRAME_X;
			spr.y += FRAME_Y;
			prevGroup.add(spr);
		}

		if (s >= 0 && s < prevSprites.length)
		{
			var t:FlxSprite = prevSprites[s];
			selBox = new FlxSprite(t.x - 2, t.y - 2).makeGraphic(Std.int(t.width) + 4, Std.int(t.height) + 4, 0x44FFFF00);
			prevGroup.add(selBox);
		}
	}

	function previewOther()
	{
		var c:Dynamic = cur();
		var d:Dynamic = custom.get(KINDS[mode]);
		var w:Float = FlxG.width * P;
		var h:Float = FlxG.height * P;

		var color:FlxColor = 0xFF353535;
		if (c != null && mode >= 2) color = MainMenuData.parseColor(c.color, 0xFF353535);
		var tint:FlxSprite = new FlxSprite(FRAME_X, FRAME_Y).makeGraphic(Std.int(w), Std.int(h), color);
		tint.alpha = 0.55;
		prevGroup.add(tint);

		var list:Array<Dynamic> = entries();
		var lineH:Float = 34;
		var firstY:Float = FRAME_Y + h / 2 - lineH / 2 - sel() * lineH;
		for (i => e in list)
		{
			var y:Float = firstY + i * lineH;
			if (y < FRAME_Y || y > FRAME_Y + h - lineH) continue;
			var name:String = Std.string(mode == 1 ? e.label : e.name);
			var t:FlxText = new FlxText(FRAME_X, y, w, name, i == sel() ? 28 : 22);
			t.setFormat(Paths.font("vcr.ttf"), i == sel() ? 28 : 22, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.alpha = (i == sel()) ? 1 : 0.5;
			prevGroup.add(t);
		}

		if (c != null && mode == 3 && c.desc != null && c.desc != '')
		{
			var box:FlxSprite = new FlxSprite(FRAME_X, FRAME_Y + h - 40).makeGraphic(Std.int(w), 40, FlxColor.BLACK);
			box.alpha = 0.6;
			prevGroup.add(box);
			var dt:FlxText = new FlxText(FRAME_X + 6, FRAME_Y + h - 34, w - 12, Std.string(c.desc), 16);
			dt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
			prevGroup.add(dt);
		}
		if (mode == 2 && c != null)
		{
			var dd:FlxText = new FlxText(FRAME_X, FRAME_Y + 6, w - 10, '< ' + Std.string(c.difficulties).toUpperCase() + ' >', 18);
			dd.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			prevGroup.add(dd);
		}
		if (Reflect.field(d, 'enabled') != true)
		{
			var off:FlxText = new FlxText(FRAME_X + 6, FRAME_Y + 6, w, '(desactivado: el juego usa el menú original)', 14);
			off.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.YELLOW, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			prevGroup.add(off);
		}
	}

	// =================================================================== input

	function insideFrame():Bool
	{
		return FlxG.mouse.screenX >= FRAME_X && FlxG.mouse.screenX <= FRAME_X + FlxG.width * P
			&& FlxG.mouse.screenY >= FRAME_Y && FlxG.mouse.screenY <= FRAME_Y + FlxG.height * P;
	}

	function updateDrag()
	{
		if (mode != 0) return;

		if (FlxG.mouse.justPressed && insideFrame())
		{
			var i:Int = prevSprites.length - 1;
			while (i >= 0)
			{
				var spr:FlxSprite = prevSprites[i];
				if (FlxG.mouse.overlaps(spr))
				{
					var changed:Bool = sels[0] != prevSlots[i];
					sels[0] = prevSlots[i];
					dragOffX = FlxG.mouse.screenX - spr.x;
					dragOffY = FlxG.mouse.screenY - spr.y;
					dragging = true;
					pushUndo();
					if (changed) { refreshRows(); loadInspector(); refreshPreview(); }
					break;
				}
				i--;
			}
		}

		if (dragging)
		{
			if (!FlxG.mouse.pressed)
			{
				dragging = false;
				refreshAll();
				return;
			}

			var slot:Int = sels[0];
			var spr:FlxSprite = (slot < prevSprites.length) ? prevSprites[slot] : null;
			var c:Dynamic = cur();
			if (spr == null || c == null) return;

			var nx:Float = (FlxG.mouse.screenX - dragOffX - FRAME_X) / P;
			var ny:Float = (FlxG.mouse.screenY - dragOffY - FRAME_Y) / P;
			var snap:Bool = FlxG.keys.pressed.SHIFT;
			nx = snap ? Math.round(nx / 10) * 10 : Math.round(nx);
			ny = snap ? Math.round(ny / 10) * 10 : Math.round(ny);

			Reflect.setField(c, 'x', nx);
			Reflect.setField(c, 'y', ny);
			spr.x = FRAME_X + nx * P;
			spr.y = FRAME_Y + ny * P;
			if (selBox != null) selBox.setPosition(spr.x - 2, spr.y - 2);

			loading = true;
			fieldInputs[3].text = Std.string(nx);
			fieldInputs[4].text = Std.string(ny);
			loading = false;
			markDirty();
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (PsychUIInputText.focusOn != null) return; // escribiendo

		updateDrag();
		if (dragging) return;

		if (FlxG.keys.justPressed.UP) select(-1);
		if (FlxG.keys.justPressed.DOWN) select(1);
		if (FlxG.keys.justPressed.ONE) setMode(0);
		if (FlxG.keys.justPressed.TWO) setMode(1);
		if (FlxG.keys.justPressed.THREE) setMode(2);
		if (FlxG.keys.justPressed.FOUR) setMode(3);

		if (FlxG.mouse.justPressed)
			for (r in rows.members)
				if (r != null && FlxG.mouse.overlaps(r)) { sels[mode] = r.ID; refreshAll(); break; }

		if (FlxG.keys.pressed.CONTROL)
		{
			if (FlxG.keys.justPressed.S) save();
			if (FlxG.keys.justPressed.Z) undo();
			if (FlxG.keys.justPressed.D) duplicateCurrent();
		}

		if (FlxG.keys.justPressed.ESCAPE || controls.BACK) exitEditor();
	}

	function select(change:Int)
	{
		var n:Int = entries().length;
		if (n < 1) return;
		sels[mode] = FlxMath.wrap(sel() + change, 0, n - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		refreshAll();
	}
}
