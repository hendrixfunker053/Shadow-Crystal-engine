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
 * Editor del menú principal.
 *  - Lista de items + vista previa del layout completo (arrastra un item con el mouse o el dedo para fijar su X/Y).
 *  - Por item: id, imagen, acción, args, X, Y y escala.
 *  - Pestaña Scripts: crea scripts del menú (scripts/mainmenu/) y states / substates propios (scripts/states/, scripts/substates/).
 *
 * Atajos: ARRIBA/ABAJO seleccionar, CTRL+S guardar, CTRL+Z deshacer, CTRL+D duplicar, ESC salir.
 * Todo tiene botón para poder usarlo sin teclado (Android).
 */
class MainMenuEditorState extends MusicBeatState
{
	// key, etiqueta, tipo (s = texto, n = número opcional)
	static final FIELDS:Array<Array<String>> = [
		['id', 'ID (prefijo de animación):', 's'],
		['image', 'Imagen (atlas sin extensión):', 's'],
		['args', 'Args (URL, nombre de state/substate o función):', 's'],
		['x', 'X (vacío = automático):', 'n'],
		['y', 'Y (vacío = automático):', 'n'],
		['scale', 'Escala (vacío = 1):', 'n']
	];

	// Vista previa
	static final P:Float = 0.42;
	static final FRAME_X:Float = 340;
	static final FRAME_Y:Float = 20;

	var mainData:MainMenuFile;
	var customMenu:Bool = false;
	var selected:Int = 0;

	var loading:Bool = false;
	var dirty:Bool = false;
	var exitArmed:Bool = false;
	var undoStack:Array<String> = [];
	var lastUndoPush:Float = -10;

	// vista
	var rows:FlxTypedGroup<FlxText>;
	var prevGroup:FlxGroup;
	var prevSprites:Array<FlxSprite> = [];
	var selBox:FlxSprite;
	var status:FlxText;

	// arrastre
	var dragging:Bool = false;
	var dragOffX:Float = 0;
	var dragOffY:Float = 0;

	// UI
	var UI_box:PsychUIBox;
	var fieldLabels:Array<FlxText> = [];
	var fieldInputs:Array<PsychUIInputText> = [];
	var actionDD:PsychUIDropDownMenu;
	var spacingInput:PsychUIInputText;
	var startYInput:PsychUIInputText;
	var customMenuBox:PsychUICheckBox;
	var scriptsText:FlxText;
	var stateNameInput:PsychUIInputText;

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

		var frameBg:FlxSprite = new FlxSprite(FRAME_X - 3, FRAME_Y - 3).makeGraphic(Std.int(FlxG.width * P) + 6, Std.int(FlxG.height * P) + 6, 0xFFAAAAAA);
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
			'ARRIBA/ABAJO: seleccionar | CTRL+S: guardar | CTRL+Z: deshacer | CTRL+D: duplicar | ESC: salir', 16);
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
		customMenu = MainMenuData.hasCustomMenu();
	}

	// =================================================================== UI

	function buildLeftColumn()
	{
		var title:FlxText = new FlxText(20, 18, 300, 'Main menu', 24);
		title.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(title);

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

		for (i in 0...FIELDS.length)
		{
			var lbl:FlxText = new FlxText(15, 8 + i * 48, 330, FIELDS[i][1]);
			var input:PsychUIInputText = new PsychUIInputText(15, 26 + i * 48, 320, '', 8);
			input.onChange = function(old:String, cur:String) onFieldChange(i, cur);
			fieldLabels.push(lbl);
			fieldInputs.push(input);
			tab.add(lbl);
			tab.add(input);
		}

		tab.add(new PsychUIButton(15, 300, 'Quitar X/Y (auto)', function() {
			var c:MenuItemData = cur();
			if (c == null) return;
			pushUndo();
			Reflect.deleteField(c, 'x');
			Reflect.deleteField(c, 'y');
			markDirty();
			refreshAll();
		}, 160, 22));

		tab.add(new FlxText(15, 332, 0, 'Acción:'));

		// El dropdown va último para dibujarse encima
		actionDD = new PsychUIDropDownMenu(15, 350, MainMenuData.MAIN_ACTIONS, function(index:Int, name:String) {
			if (loading || cur() == null) return;
			pushUndo();
			cur().action = name;
			markDirty();
			refreshRows();
		}, 320);
		tab.add(actionDD);

		// ---------------- pestaña Menu ----------------
		var menu = UI_box.getTab('Menu').menu;

		menu.add(new FlxText(15, 10, 0, 'Separación entre items (spacing):'));
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
		menu.add(spacingInput);

		menu.add(new FlxText(15, 60, 0, 'Y inicial (startY):'));
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
		menu.add(startYInput);

		menu.add(new PsychUIButton(15, 115, 'Alternar LEFT', function() toggleSide(true), 155, 25));
		menu.add(new PsychUIButton(180, 115, 'Alternar RIGHT', function() toggleSide(false), 155, 25));

		// Flag de pack.json: activa el panel rápido en el menú principal de este mod
		customMenuBox = new PsychUICheckBox(15, 160, 'Custom menu (panel rápido)', 250);
		customMenuBox.checked = customMenu;
		customMenuBox.onClick = function() {
			customMenu = customMenuBox.checked;
			markDirty();
		};
		menu.add(customMenuBox);

		menu.add(new FlxText(15, 195, 330,
			'Arrastra un item en la vista previa para fijar su X/Y.\n\n'
			+ 'Acciones propias:\n'
			+ '- state: Args = nombre de un state hecho con scripts (scripts/states/<nombre>) o una clase.\n'
			+ '- substate: igual, con scripts/substates/<nombre>.\n'
			+ '- script: Args es el nombre que recibe onMenuAction(nombre, id) en scripts/mainmenu/.'));

		// ---------------- pestaña Scripts ----------------
		var sc = UI_box.getTab('Scripts').menu;
		scriptsText = new FlxText(15, 10, 330, '');
		sc.add(scriptsText);

		sc.add(new FlxText(15, 150, 0, 'Script del menú principal (scripts/mainmenu/):'));
		sc.add(new PsychUIButton(15, 170, 'Nuevo Lua', function() newMenuScript(true), 100, 25));
		sc.add(new PsychUIButton(125, 170, 'Nuevo HScript', function() newMenuScript(false), 120, 25));
		sc.add(new PsychUIButton(255, 170, 'Refrescar', refreshScripts, 85, 25));

		sc.add(new FlxText(15, 215, 0, 'State / substate propio (nombre sin espacios):'));
		stateNameInput = new PsychUIInputText(15, 233, 320, 'MiMenu', 8);
		sc.add(stateNameInput);
		sc.add(new PsychUIButton(15, 265, 'State Lua', function() newState('states', true), 100, 25));
		sc.add(new PsychUIButton(125, 265, 'State HScript', function() newState('states', false), 110, 25));
		sc.add(new PsychUIButton(15, 295, 'Substate Lua', function() newState('substates', true), 100, 25));
		sc.add(new PsychUIButton(125, 295, 'Substate HScript', function() newState('substates', false), 150, 25));

		sc.add(new FlxText(15, 335, 330,
			'Los states y substates se abren con una acción "state"/"substate" del menú o con switchState(\'Nombre\') / openSubState(\'Nombre\') desde cualquier script.\n'
			+ 'Si el state se llama TitleState, MainMenuState, StoryMenuState, FreeplayState, CreditsState, OptionsState o ModsMenuState, REEMPLAZA al original.\n'
			+ 'Hooks: onCreate, onCreatePost, onUpdate, onUpdatePost, onBack, onDestroy.\n'
			+ 'Devuelve Function_Stop en onAccept (menú principal) para cancelar la acción.'));
	}

	// =================================================================== datos

	/** Slots del menú: items centrales, luego LEFT y RIGHT si existen. */
	function entries():Array<MenuItemData>
	{
		var a:Array<MenuItemData> = mainData.items.copy();
		if (mainData.left != null) a.push(mainData.left);
		if (mainData.right != null) a.push(mainData.right);
		return a;
	}

	function cur():MenuItemData
	{
		var e:Array<MenuItemData> = entries();
		return (selected >= 0 && selected < e.length) ? e[selected] : null;
	}

	/** C = central, L = left, R = right. */
	function slotKind(i:Int):String
	{
		if (i < mainData.items.length) return 'C';
		var extra:Int = i - mainData.items.length;
		return (extra == 0 && mainData.left != null) ? 'L' : 'R';
	}

	function clampSel()
	{
		selected = Std.int(Math.max(0, Math.min(selected, entries().length - 1)));
	}

	function addEntry()
	{
		pushUndo();
		mainData.items.push(MainMenuData.newItem('new_item', 'none'));
		selected = mainData.items.length - 1;
		markDirty();
		refreshAll();
	}

	function duplicateCurrent()
	{
		if (cur() == null || slotKind(selected) != 'C') return;
		pushUndo();
		var copy:MenuItemData = Reflect.copy(cur());
		mainData.items.insert(selected + 1, copy);
		selected++;
		markDirty();
		refreshAll();
	}

	function removeCurrent()
	{
		if (cur() == null) return;
		var k:String = slotKind(selected);

		if (k == 'C' && mainData.items.length <= 1)
		{
			setStatus('Debe quedar al menos un item central.');
			return;
		}

		pushUndo();
		switch (k)
		{
			case 'C': mainData.items.splice(selected, 1);
			case 'L': mainData.left = null;
			case 'R': mainData.right = null;
		}
		clampSel();
		markDirty();
		refreshAll();
	}

	function move(dir:Int)
	{
		if (slotKind(selected) != 'C') return;
		var to:Int = selected + dir;
		if (to < 0 || to >= mainData.items.length) return;
		pushUndo();
		var tmp:MenuItemData = mainData.items[selected];
		mainData.items[selected] = mainData.items[to];
		mainData.items[to] = tmp;
		selected = to;
		markDirty();
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

	function markDirty()
	{
		dirty = true;
		exitArmed = false;
	}

	function onFieldChange(i:Int, text:String)
	{
		if (loading) return;
		var c:MenuItemData = cur();
		if (c == null) return;

		var def:Array<String> = FIELDS[i];
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

		markDirty();
		refreshRows();
		refreshPreview();
	}

	// =================================================================== deshacer

	function snapshot():String
		return Json.stringify({main: mainData, customMenu: customMenu});

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
		customMenu = d.customMenu;
		customMenuBox.checked = customMenu;
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

		var packPath:String = MainMenuData.setCustomMenu(customMenu);
		dirty = false;
		setStatus('Guardado: $path\n' + (packPath != null ? 'Custom menu = $customMenu en pack.json' : '(pack.json no se pudo modificar: ¿hay un mod seleccionado?)'));
	}

	function reloadAll()
	{
		loadAll();
		customMenuBox.checked = customMenu;
		undoStack = [];
		dirty = false;
		selected = 0;
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

	function newMenuScript(lua:Bool)
	{
		var path:String = MainMenuData.createScriptTemplate(lua);
		setStatus(path != null ? 'Plantilla creada: $path' : 'No se pudo crear (ya existe o no hay mod seleccionado).');
		refreshScripts();
	}

	function newState(kind:String, lua:Bool)
	{
		var path:String = MainMenuData.createStateTemplate(kind, stateNameInput.text, lua);
		setStatus(path != null ? 'Plantilla creada: $path' : 'No se pudo crear (nombre vacío, ya existe o no hay mod seleccionado).');
		refreshScripts();
	}

	function refreshScripts()
	{
		var txt:String = '';
		for (kind in ['mainmenu', 'states', 'substates'])
		{
			var files:Array<String> = MainMenuData.scriptFiles(kind);
			txt += 'scripts/$kind: ${files.length}\n';
			for (f in files.slice(0, 3))
			{
				var at:Int = f.lastIndexOf('/scripts/');
				txt += '  - ' + (at >= 0 ? f.substr(at + 9) : f) + '\n';
			}
			if (files.length > 3) txt += '  ... y ${files.length - 3} más\n';
			txt += '\n';
		}
		scriptsText.text = txt;
	}

	// =================================================================== vista

	function setStatus(s:String) status.text = s;

	function refreshAll()
	{
		refreshRows();
		loadInspector();
		refreshPreview();
		refreshScripts();
	}

	function rowLabel(i:Int, e:MenuItemData):String
	{
		var prefix:String = switch (slotKind(i))
		{
			case 'L': 'LEFT  ';
			case 'R': 'RIGHT ';
			default: '${i + 1}. ';
		}
		return '$prefix${e.id}  [${e.action}]';
	}

	function refreshRows()
	{
		for (r in rows.members) r.destroy();
		rows.clear();

		var list:Array<MenuItemData> = entries();
		var visibleRows:Int = 14;
		var top:Int = Std.int(Math.max(0, Math.min(selected - 7, list.length - visibleRows)));

		for (i in top...Std.int(Math.min(list.length, top + visibleRows)))
		{
			var t:FlxText = new FlxText(20, 60 + (i - top) * 30, 300, rowLabel(i, list[i]), 20);
			t.setFormat(Paths.font("vcr.ttf"), 20, i == selected ? FlxColor.YELLOW : FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.ID = i;
			rows.add(t);
		}
	}

	function loadInspector()
	{
		loading = true;
		var c:MenuItemData = cur();

		for (i in 0...FIELDS.length)
		{
			var v:Dynamic = (c == null) ? null : Reflect.field(c, FIELDS[i][0]);
			fieldInputs[i].text = (v == null) ? '' : Std.string(v);
		}
		if (c != null) actionDD.selectedLabel = c.action;

		spacingInput.text = Std.string(mainData.spacing);
		startYInput.text = Std.string(mainData.startY);
		loading = false;
	}

	function clearPreview()
	{
		for (m in prevGroup.members)
			if (m != null) m.destroy();
		prevGroup.clear();
		prevSprites = [];
		selBox = null;
	}

	function makePreviewSprite(d:MenuItemData, isSelected:Bool):FlxSprite
	{
		var s:FlxSprite = new FlxSprite();
		var scale:Float = (d.scale != null && d.scale > 0) ? d.scale : 1;

		if (Paths.fileExists('images/${d.image}.xml', TEXT))
		{
			s.frames = Paths.getSparrowAtlas(d.image);
			s.animation.addByPrefix('idle', '${d.id} idle', 24, true);
			s.animation.addByPrefix('selected', '${d.id} selected', 24, true);
			if (isSelected && s.animation.exists('selected')) s.animation.play('selected');
			else if (s.animation.exists('idle')) s.animation.play('idle');
			else if (s.animation.exists('selected')) s.animation.play('selected');
			if (isSelected && !s.animation.exists('selected'))
				setStatus('Falta la animación "${d.id} selected" en ${d.image}.xml');
		}
		else
		{
			s.makeGraphic(400, 100, 0xFF444444);
			if (isSelected) setStatus('No se encontró el atlas: images/${d.image}.xml');
		}

		s.scale.set(scale * P, scale * P);
		s.updateHitbox();
		s.antialiasing = ClientPrefs.data.antialiasing;
		return s;
	}

	function refreshPreview()
	{
		clearPreview();

		var center:Array<FlxSprite> = [];
		var left:FlxSprite = null;
		var right:FlxSprite = null;

		for (i in 0...mainData.items.length)
			center.push(makePreviewSprite(mainData.items[i], selected == i));

		var slot:Int = mainData.items.length;
		if (mainData.left != null) left = makePreviewSprite(mainData.left, selected == slot++);
		if (mainData.right != null) right = makePreviewSprite(mainData.right, selected == slot++);

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

		if (selected >= 0 && selected < prevSprites.length)
		{
			var t:FlxSprite = prevSprites[selected];
			selBox = new FlxSprite(t.x - 2, t.y - 2).makeGraphic(Std.int(t.width) + 4, Std.int(t.height) + 4, 0x44FFFF00);
			prevGroup.add(selBox);
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
		if (FlxG.mouse.justPressed && insideFrame())
		{
			var i:Int = prevSprites.length - 1;
			while (i >= 0)
			{
				var spr:FlxSprite = prevSprites[i];
				if (FlxG.mouse.overlaps(spr))
				{
					var changed:Bool = selected != i;
					selected = i;
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

		if (!dragging) return;

		if (!FlxG.mouse.pressed)
		{
			dragging = false;
			refreshAll();
			return;
		}

		var spr:FlxSprite = (selected < prevSprites.length) ? prevSprites[selected] : null;
		var c:MenuItemData = cur();
		if (spr == null || c == null) return;

		var nx:Float = (FlxG.mouse.screenX - dragOffX - FRAME_X) / P;
		var ny:Float = (FlxG.mouse.screenY - dragOffY - FRAME_Y) / P;
		var snap:Bool = FlxG.keys.pressed.SHIFT;
		nx = snap ? Math.round(nx / 10) * 10 : Math.round(nx);
		ny = snap ? Math.round(ny / 10) * 10 : Math.round(ny);

		c.x = nx;
		c.y = ny;
		spr.x = FRAME_X + nx * P;
		spr.y = FRAME_Y + ny * P;
		if (selBox != null) selBox.setPosition(spr.x - 2, spr.y - 2);

		loading = true;
		fieldInputs[3].text = Std.string(nx);
		fieldInputs[4].text = Std.string(ny);
		loading = false;
		markDirty();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (PsychUIInputText.focusOn != null) return; // escribiendo

		updateDrag();
		if (dragging) return;

		if (FlxG.keys.justPressed.UP) select(-1);
		if (FlxG.keys.justPressed.DOWN) select(1);

		if (FlxG.mouse.justPressed)
			for (r in rows.members)
				if (r != null && FlxG.mouse.overlaps(r)) { selected = r.ID; refreshAll(); break; }

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
		selected = FlxMath.wrap(selected + change, 0, n - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		refreshAll();
	}
}
