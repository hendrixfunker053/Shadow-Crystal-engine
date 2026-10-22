package states.editors;

import backend.MainMenuData;
import backend.ui.PsychUIBox;
import backend.ui.PsychUIButton;
import backend.ui.PsychUICheckBox;
import backend.ui.PsychUIDropDownMenu;
import backend.ui.PsychUIInputText;

class MainMenuEditorState extends MusicBeatState
{
	static final ACTIONS:Array<String> = [
		'story_mode', 'freeplay', 'mods', 'achievements', 'credits', 'options', 'url', 'state', 'none'
	];

	var data:MainMenuFile;
	var sel:Int = 0;
	var loading:Bool = false;
	var customMenu:Bool = false;

	var rows:FlxTypedGroup<FlxText>;
	var preview:FlxSprite;
	var status:FlxText;

	var UI_box:PsychUIBox;
	var idInput:PsychUIInputText;
	var imageInput:PsychUIInputText;
	var argsInput:PsychUIInputText;
	var actionDD:PsychUIDropDownMenu;
	var customMenuBox:PsychUICheckBox;
	var mobileLayout:Bool = false;

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

		#if mobile
		mobileLayout = true;
		#end
		data = MainMenuData.load();
		customMenu = MainMenuData.hasCustomMenu();

		rows = new FlxTypedGroup<FlxText>();
		add(rows);

		status = new FlxText(12, FlxG.height - 64, FlxG.width - 24, '', FlxG.width < 700 ? 12 : 18);
		status.setFormat(Paths.font("vcr.ttf"), FlxG.width < 700 ? 12 : 18, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(status);

		var help:FlxText = new FlxText(20, FlxG.height - 30, FlxG.width - 40,
			#if mobile 'TOCA UN ELEMENTO | BOTONES DEL EDITOR | GUARDAR | VOLVER' #else 'ARRIBA/ABAJO: seleccionar | CTRL+S: guardar | ESC: salir' #end, 16);
		help.setFormat(Paths.font("vcr.ttf"), FlxG.width < 700 ? 10 : 16, FlxColor.GRAY, LEFT);
		add(help);

		buildUI();
		refreshAll();

		FlxG.mouse.visible = true;
		#if mobile
		add(mobile.MobileButton.back());
		#end
		super.create();
	}

	function buildUI()
	{
		var panelWidth:Float = Math.min(360, FlxG.width - 24);
		var panelX:Float = Math.max(12, FlxG.width - panelWidth - 12);
		var panelHeight:Float = Math.min(440, FlxG.height - 100);
		UI_box = new PsychUIBox(panelX, 12, panelWidth, panelHeight, ['Item']);
		UI_box.scrollFactor.set();
		add(UI_box);

		var tab = UI_box.getTab('Item').menu;

		tab.add(new FlxText(15, 10, 0, 'ID (prefijo de animación):'));
		idInput = new PsychUIInputText(15, 28, Math.max(120, panelWidth - 40), '', 8);
		idInput.onChange = function(old:String, cur:String) {
			if (loading) return;
			current().id = cur;
			refreshRows();
			refreshPreview();
		};
		tab.add(idInput);

		tab.add(new FlxText(15, 60, 0, 'Imagen (atlas sin extensión):'));
		imageInput = new PsychUIInputText(15, 78, Math.max(120, panelWidth - 40), '', 8);
		imageInput.onChange = function(old:String, cur:String) {
			if (loading) return;
			current().image = cur;
			refreshPreview();
		};
		tab.add(imageInput);

		tab.add(new FlxText(15, 110, 0, 'Args (URL o clase):'));
		argsInput = new PsychUIInputText(15, 128, Math.max(120, panelWidth - 40), '', 8);
		argsInput.onChange = function(old:String, cur:String) {
			if (loading) return;
			current().args = cur;
		};
		tab.add(argsInput);

		tab.add(new PsychUIButton(15, 170, 'Añadir', function() {
			data.items.push(MainMenuData.newItem('new_item', 'none'));
			sel = data.items.length - 1;
			refreshAll();
		}, 100, 25));

		tab.add(new PsychUIButton(125, 170, 'Borrar', removeCurrent, 100, 25));
		tab.add(new PsychUIButton(235, 170, 'Recargar', function() {
			data = MainMenuData.load();
			customMenu = MainMenuData.hasCustomMenu();
			customMenuBox.checked = customMenu;
			sel = 0;
			refreshAll();
		}, 100, 25));

		tab.add(new PsychUIButton(15, 205, 'Subir', function() move(-1), 100, 25));
		tab.add(new PsychUIButton(125, 205, 'Bajar', function() move(1), 100, 25));
		tab.add(new PsychUIButton(235, 205, 'Guardar', save, 100, 25));

		tab.add(new PsychUIButton(15, 240, 'Alternar LEFT', function() toggleSide(true), 155, 25));
		tab.add(new PsychUIButton(180, 240, 'Alternar RIGHT', function() toggleSide(false), 155, 25));

		// Flag de pack.json: activa el panel rápido en el menú principal de este mod
		customMenuBox = new PsychUICheckBox(15, 282, 'Custom menu (panel rápido)', 250);
		customMenuBox.checked = customMenu;
		customMenuBox.onClick = function() customMenu = customMenuBox.checked;
		tab.add(customMenuBox);

		tab.add(new FlxText(15, 316, 0, 'Acción:'));
		// El dropdown va último para que se dibuje encima
		actionDD = new PsychUIDropDownMenu(15, 334, ACTIONS, function(index:Int, name:String) {
			if (loading) return;
			current().action = name;
			refreshRows();
		}, 320);
		tab.add(actionDD);
	}

	// ---------- datos ----------

	function slots():Array<{item:MenuItemData, kind:String}>
	{
		var a:Array<{item:MenuItemData, kind:String}> = [for (i in data.items) {item: i, kind: 'C'}];
		if (data.left != null) a.push({item: data.left, kind: 'L'});
		if (data.right != null) a.push({item: data.right, kind: 'R'});
		return a;
	}

	function current():MenuItemData return slots()[sel].item;
	function currentKind():String return slots()[sel].kind;

	function removeCurrent()
	{
		switch (currentKind())
		{
			case 'C':
				if (data.items.length <= 1) { setStatus('Debe quedar al menos un item.'); return; }
				data.items.splice(sel, 1);
			case 'L': data.left = null;
			case 'R': data.right = null;
		}
		sel = Std.int(Math.max(0, Math.min(sel, slots().length - 1)));
		refreshAll();
	}

	function move(dir:Int)
	{
		if (currentKind() != 'C') return;
		var to:Int = sel + dir;
		if (to < 0 || to >= data.items.length) return;
		var tmp = data.items[sel];
		data.items[sel] = data.items[to];
		data.items[to] = tmp;
		sel = to;
		refreshAll();
	}

	function toggleSide(left:Bool)
	{
		if (left) data.left = (data.left == null) ? MainMenuData.newItem('options', 'options') : null;
		else data.right = (data.right == null) ? MainMenuData.newItem('achievements', 'achievements') : null;
		sel = Std.int(Math.max(0, Math.min(sel, slots().length - 1)));
		refreshAll();
	}

	function save()
	{
		var path:String = MainMenuData.save(data);
		if (path == null)
		{
			setStatus('Guardar no está soportado en esta plataforma.');
			return;
		}

		var packPath:String = MainMenuData.setCustomMenu(customMenu);
		setStatus('Guardado: $path' + (packPath != null ? '\nCustom menu = $customMenu en $packPath' : '\n(pack.json no se pudo modificar)'));
	}

	// ---------- UI ----------

	function setStatus(s:String) status.text = s;

	function refreshAll()
	{
		refreshRows();
		loadInspector();
		refreshPreview();
	}

	function refreshRows()
	{
		for (r in rows.members) r.destroy();
		rows.clear();

		for (i => s in slots())
		{
			var prefix:String = switch (s.kind) { case 'L': 'LEFT  '; case 'R': 'RIGHT '; default: '${i + 1}. '; }
				var rowX:Float = 16;
			var rowWidth:Float = Math.max(100, Math.min(FlxG.width * 0.48, 440));
			var rowSize:Int = FlxG.width < 700 ? 16 : 22;
			var rowY:Float = 16 + i * (FlxG.width < 700 ? 34 : 30);
			var t:FlxText = new FlxText(rowX, rowY, rowWidth, '$prefix${s.item.id}  [${s.item.action}]', rowSize);
			t.setFormat(Paths.font("vcr.ttf"), rowSize, i == sel ? FlxColor.YELLOW : FlxColor.WHITE, LEFT,
				FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			rows.add(t);
		}
	}

	function loadInspector()
	{
		loading = true;
		var c:MenuItemData = current();
		idInput.text = c.id;
		imageInput.text = c.image;
		argsInput.text = c.args;
		actionDD.selectedLabel = c.action;
		loading = false;
	}

	function refreshPreview()
	{
		if (preview != null)
		{
			remove(preview);
			preview.destroy();
			preview = null;
		}

		var c:MenuItemData = current();
		if (!Paths.fileExists('images/${c.image}.xml', TEXT))
		{
			setStatus('No se encontró el atlas: images/${c.image}.xml');
			return;
		}

		preview = new FlxSprite(480, 120);
		preview.frames = Paths.getSparrowAtlas(c.image);
		preview.animation.addByPrefix('selected', '${c.id} selected', 24, true);
		preview.animation.addByPrefix('idle', '${c.id} idle', 24, true);

		if (preview.animation.exists('selected')) { preview.animation.play('selected'); setStatus(''); }
		else if (preview.animation.exists('idle')) { preview.animation.play('idle'); setStatus('Falta la animación "${c.id} selected".'); }
		else setStatus('No hay animaciones "${c.id} idle" / "${c.id} selected" en ese atlas.');

		preview.antialiasing = ClientPrefs.data.antialiasing;
		preview.updateHitbox();
		if (preview.height > 300)
		{
			preview.setGraphicSize(0, 300);
			preview.updateHitbox();
		}
		insert(members.indexOf(rows), preview);
	}

	// ---------- input ----------

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (PsychUIInputText.focusOn != null) return; // escribiendo

		if (FlxG.keys.justPressed.UP) select(-1);
		if (FlxG.keys.justPressed.DOWN) select(1);

		if (FlxG.mouse.justPressed)
			for (i => r in rows.members)
				if (FlxG.mouse.overlaps(r)) { sel = i; refreshAll(); break; }

		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) save();

		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MasterEditorMenu());
		}
	}

	function select(change:Int)
	{
		sel = FlxMath.wrap(sel + change, 0, slots().length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		refreshAll();
	}
}
