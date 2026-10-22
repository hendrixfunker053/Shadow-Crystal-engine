
package states.editors;

import backend.MainMenuData;
import backend.MainMenuData.MainMenuFile;
import backend.MainMenuData.MenuItemData;
import backend.ui.PsychUIBox;
import backend.ui.PsychUIButton;
import backend.ui.PsychUIDropDownMenu;
import backend.ui.PsychUIInputText;

class MainMenuEditorState extends MusicBeatState
{
	static final ACTIONS:Array<String> = [
		'story_mode',
		'freeplay',
		'mods',
		'achievements',
		'credits',
		'options',
		'url',
		'state',
		'none'
	];

	static final COLUMNS:Array<String> = [
		'CENTER',
		'LEFT',
		'RIGHT'
	];

	var data:MainMenuFile;
	var sel:Int = 0;
	var loading:Bool = false;

	var rows:FlxTypedGroup<FlxText>;
	var preview:FlxSprite;
	var status:FlxText;
	var header:FlxText;
	var listBackground:FlxSprite;

	var UI_box:PsychUIBox;

	var idInput:PsychUIInputText;
	var imageInput:PsychUIInputText;
	var argsInput:PsychUIInputText;
	var labelInput:PsychUIInputText;
	var backgroundInput:PsychUIInputText;
	var luaInput:PsychUIInputText;
	var hscriptInput:PsychUIInputText;

	var actionDD:PsychUIDropDownMenu;
	var columnDD:PsychUIDropDownMenu;

	var customButton:PsychUIButton;
	var checkerButton:PsychUIButton;
	var leftButton:PsychUIButton;
	var rightButton:PsychUIButton;

	var gestureStartY:Float = 0;
	var gestureStartX:Float = 0;
	var gestureActive:Bool = false;

	var listX:Float = 20;
	var listY:Float = 100;
	var listW:Float = 400;
	var rowHeight:Float = 48;
	var visibleRows:Int = 8;
	var firstVisible:Int = 0;

	override function create():Void
	{
		super.create();

		FlxG.camera.bgColor = 0xFF10111B;
		FlxG.mouse.visible = true;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Main Menu Editor", null);
		#end

		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF292A38;
		bg.alpha = 0.55;
		bg.scrollFactor.set();
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		add(bg);

		data = MainMenuData.load();

		if (data == null)
			data = MainMenuData.getDefault();

		if (data.items == null)
			data.items = [];

		if (data.items.length == 0)
			data.items.push(MainMenuData.newItem('freeplay', 'freeplay'));

		// Encabezado
		header = new FlxText(20, 15, FlxG.width - 40,
			'SHADOW CRYSTAL  /  MAIN MENU EDITOR', 26);

		header.setFormat(
			Paths.font('vcr.ttf'),
			26,
			0xFFB9A4FF,
			LEFT,
			FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK
		);
		add(header);

		// Fondo de la lista
		listBackground = new FlxSprite();
		listBackground.makeGraphic(420, 440, 0xDD171925);
		listBackground.scrollFactor.set();
		add(listBackground);

		rows = new FlxTypedGroup<FlxText>();
		add(rows);

		// Estado
		status = new FlxText(20, FlxG.height - 55, FlxG.width - 40, '', 14);
		status.setFormat(
			Paths.font('vcr.ttf'),
			14,
			FlxColor.WHITE,
			LEFT,
			FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK
		);
		add(status);

		layoutEditor();
		buildUI();
		refreshAll();

		FlxG.mouse.visible = true;
	}

	function layoutEditor():Void
	{
		// La lista ocupa el espacio izquierdo.
		listX = 20;
		listY = 100;

		listW = Std.int(Math.max(230, Math.min(420, FlxG.width * 0.38)));

		var availableHeight:Float = FlxG.height - 190;
		visibleRows = Std.int(Math.max(3, availableHeight / rowHeight));

		listBackground.x = listX;
		listBackground.y = listY;
		listBackground.setGraphicSize(
			Std.int(listW),
			Std.int(visibleRows * rowHeight + 12)
		);
		listBackground.updateHitbox();
	}

	function buildUI():Void
	{
		// Inspector lateral
		var panelWidth:Int = Std.int(Math.max(300, Math.min(360, FlxG.width - listW - 60)));

		UI_box = new PsychUIBox(
			FlxG.width - panelWidth - 20,
			70,
			panelWidth,
			Std.int(FlxG.height - 145),
			['Opción', 'Menú', 'Scripts']
		);

		UI_box.scrollFactor.set();
		add(UI_box);

		buildItemTab();
		buildMenuTab();
		buildScriptsTab();

		// Vista previa centrada entre lista e inspector.
		preview = null;
	}

	function buildItemTab():Void
	{
		var tab = UI_box.getTab('Opción').menu;

		tab.add(new FlxText(12, 8, 300, 'ID / prefijo de animación'));

		idInput = new PsychUIInputText(12, 28, 300, '', 32);
		idInput.onChange = function(old:String, cur:String)
		{
			if (loading || slots().length == 0)
				return;

			current().id = cur;
			refreshRows();
			refreshPreview();
		};
		tab.add(idInput);

		tab.add(new FlxText(12, 60, 300, 'Nombre visible'));

		labelInput = new PsychUIInputText(12, 80, 300, '', 48);
		labelInput.onChange = function(old:String, cur:String)
		{
			if (loading || slots().length == 0)
				return;

			current().label = cur;
			refreshRows();
		};
		tab.add(labelInput);

		tab.add(new FlxText(12, 112, 300, 'Imagen / atlas'));

		imageInput = new PsychUIInputText(12, 132, 300, '', 128);
		imageInput.onChange = function(old:String, cur:String)
		{
			if (loading || slots().length == 0)
				return;

			current().image = cur;
			refreshPreview();
		};
		tab.add(imageInput);

		tab.add(new FlxText(12, 164, 300, 'Argumentos / URL / clase'));

		argsInput = new PsychUIInputText(12, 184, 300, '', 128);
		argsInput.onChange = function(old:String, cur:String)
		{
			if (loading || slots().length == 0)
				return;

			current().args = cur;
		};
		tab.add(argsInput);

		tab.add(new FlxText(12, 216, 300, 'Acción'));

		actionDD = new PsychUIDropDownMenu(
			12, 236, ACTIONS,
			function(index:Int, name:String)
			{
				if (loading || slots().length == 0)
					return;

				current().action = name;
				refreshRows();
			},
			300
		);
		tab.add(actionDD);

		tab.add(new FlxText(12, 268, 300, 'Columna'));

		columnDD = new PsychUIDropDownMenu(
			12, 288, COLUMNS,
			function(index:Int, name:String)
			{
				if (loading || slots().length == 0)
					return;

				current().column = name;
			},
			300
		);
		tab.add(columnDD);

		tab.add(new PsychUIButton(12, 325, 'Añadir opción', function()
		{
			addItem();
		}, 145, 32));

		tab.add(new PsychUIButton(167, 325, 'Eliminar', function()
		{
			removeCurrent();
		}, 145, 32));

		tab.add(new PsychUIButton(12, 365, 'Subir', function()
		{
			move(-1);
		}, 95, 32));

		tab.add(new PsychUIButton(113, 365, 'Bajar', function()
		{
			move(1);
		}, 95, 32));

		tab.add(new PsychUIButton(214, 365, 'Guardar', function()
		{
			save();
		}, 98, 32));

		tab.add(new PsychUIButton(12, 405, 'Alternar LEFT', function()
		{
			toggleSide(true);
		}, 145, 32));

		tab.add(new PsychUIButton(167, 405, 'Alternar RIGHT', function()
		{
			toggleSide(false);
		}, 145, 32));
	}

	function buildMenuTab():Void
	{
		var tab = UI_box.getTab('Menú').menu;

		tab.add(new FlxText(12, 8, 300, 'Fondo (ruta sin extensión)'));

		backgroundInput = new PsychUIInputText(12, 28, 300, '', 128);
		backgroundInput.onChange = function(old:String, cur:String)
		{
			if (loading)
				return;

			data.background = cur;
		};
		tab.add(backgroundInput);

		customButton = new PsychUIButton(12, 72, 'Alternar menú CUSTOM', function()
		{
			data.custom = !data.custom;
			updateMenuButtons();
			setStatus('Menú personalizado: ' + (data.custom ? 'sí' : 'no'));
		}, 300, 36);
		tab.add(customButton);

		checkerButton = new PsychUIButton(12, 118, 'Alternar patrón de cuadros', function()
		{
			data.checker = !data.checker;
			updateMenuButtons();
			setStatus('Patrón de cuadros: ' + (data.checker ? 'sí' : 'no'));
		}, 300, 36);
		tab.add(checkerButton);

		leftButton = new PsychUIButton(12, 164, 'Alternar LEFT', function()
		{
			toggleSide(true);
		}, 145, 32);
		tab.add(leftButton);

		rightButton = new PsychUIButton(167, 164, 'Alternar RIGHT', function()
		{
			toggleSide(false);
		}, 145, 32);
		tab.add(rightButton);

		tab.add(new FlxText(12, 208, 300, 'Separación vertical'));

		tab.add(new PsychUIButton(12, 230, '− 15 px', function()
		{
			data.spacing = Math.max(40, data.spacing - 15);
			setStatus('Separación: ' + data.spacing);
		}, 145, 32));

		tab.add(new PsychUIButton(167, 230, '+ 15 px', function()
		{
			data.spacing = Math.min(400, data.spacing + 15);
			setStatus('Separación: ' + data.spacing);
		}, 145, 32));

		tab.add(new FlxText(12, 276, 300, 'Posición vertical inicial'));

		tab.add(new PsychUIButton(12, 298, '− 10 px', function()
		{
			data.startY -= 10;
			setStatus('Posición inicial: ' + data.startY);
		}, 145, 32));

		tab.add(new PsychUIButton(167, 298, '+ 10 px', function()
		{
			data.startY += 10;
			setStatus('Posición inicial: ' + data.startY);
		}, 145, 32));

		tab.add(new PsychUIButton(12, 350, 'Recargar JSON', function()
		{
			data = MainMenuData.load();
			sel = 0;
			firstVisible = 0;
			refreshAll();
			setStatus('Configuración recargada.');
		}, 145, 36));

		tab.add(new PsychUIButton(167, 350, 'Guardar JSON', function()
		{
			save();
		}, 145, 36));
	}

	function buildScriptsTab():Void
	{
		var tab = UI_box.getTab('Scripts').menu;

		tab.add(new FlxText(12, 8, 300, 'Ruta del script Lua'));

		luaInput = new PsychUIInputText(12, 28, 300, '', 128);
		luaInput.onChange = function(old:String, cur:String)
		{
			if (loading)
				return;

			if (data.luaScripts == null)
				data.luaScripts = [];

			data.luaScripts = cur.length == 0 ? [] : [cur];
		};
		tab.add(luaInput);

		tab.add(new FlxText(12, 68, 300, 'Ruta del script HScript'));

		hscriptInput = new PsychUIInputText(12, 88, 300, '', 128);
		hscriptInput.onChange = function(old:String, cur:String)
		{
			if (loading)
				return;

			if (data.hscriptScripts == null)
				data.hscriptScripts = [];

			data.hscriptScripts = cur.length == 0 ? [] : [cur];
		};
		tab.add(hscriptInput);

		tab.add(new FlxText(
			12, 132, 300,
			'Los archivos se referencian en el JSON.\n'
			+ 'Su ejecución requiere el cargador de scripts del motor.',
			14
		));

		tab.add(new PsychUIButton(12, 190, 'Guardar referencias', function()
		{
			save();
		}, 300, 36));
	}

	// --------------------------------------------------
	// Opciones
	// --------------------------------------------------

	function slots():Array<{item:MenuItemData, kind:String}>
	{
		var result:Array<{item:MenuItemData, kind:String}> = [];

		if (data == null)
			return result;

		if (data.items != null)
			for (item in data.items)
				result.push({item: item, kind: 'C'});

		if (data.left != null)
			result.push({item: data.left, kind: 'L'});

		if (data.right != null)
			result.push({item: data.right, kind: 'R'});

		return result;
	}

	function current():MenuItemData
	{
		var all = slots();

		if (all.length == 0)
		{
			data.items.push(MainMenuData.newItem('freeplay', 'freeplay'));
			all = slots();
			sel = 0;
		}

		sel = Std.int(Math.max(0, Math.min(sel, all.length - 1)));
		return all[sel].item;
	}

	function currentKind():String
	{
		var all = slots();

		if (all.length == 0)
			return 'C';

		sel = Std.int(Math.max(0, Math.min(sel, all.length - 1)));
		return all[sel].kind;
	}

	function addItem():Void
	{
		var item = MainMenuData.newItem('new_item', 'none');
		item.label = 'Nueva opción';
		item.column = 'CENTER';

		data.items.push(item);
		sel = data.items.length - 1;
		firstVisible = Std.int(Math.max(0, sel - visibleRows + 1));

		refreshAll();
		setStatus('Opción añadida.');
	}

	function removeCurrent():Void
	{
		switch (currentKind())
		{
			case 'C':
				if (data.items.length <= 1)
				{
					setStatus('Debe quedar al menos una opción central.');
					return;
				}
				data.items.splice(sel, 1);

			case 'L':
				data.left = null;

			case 'R':
				data.right = null;
		}

		sel = Std.int(Math.max(0, Math.min(sel, slots().length - 1)));
		refreshAll();
	}

	function move(dir:Int):Void
	{
		if (currentKind() != 'C')
		{
			setStatus('Solo puedes reordenar opciones centrales.');
			return;
		}

		var to:Int = sel + dir;

		if (to < 0 || to >= data.items.length)
			return;

		var temp = data.items[sel];
		data.items[sel] = data.items[to];
		data.items[to] = temp;

		sel = to;
		refreshAll();
	}

	function toggleSide(left:Bool):Void
	{
		if (left)
		{
			data.left = data.left == null
				? MainMenuData.newItem('options', 'options')
				: null;
		}
		else
		{
			data.right = data.right == null
				? MainMenuData.newItem('achievements', 'achievements')
				: null;
		}

		refreshAll();
	}

	function save():Void
	{
		var path = MainMenuData.save(data);

		if (path != null)
			setStatus('Guardado: ' + path);
		else
			setStatus('Guardar no está disponible en esta plataforma.');
	}

	// --------------------------------------------------
	// Interfaz y vista previa
	// --------------------------------------------------

	function setStatus(message:String):Void
	{
		status.text = message;
	}

	function updateMenuButtons():Void
	{
		if (customButton != null)
			customButton.label = 'CUSTOM: ' + (data.custom ? 'ACTIVO' : 'INACTIVO');

		if (checkerButton != null)
			checkerButton.label = 'CUADROS: ' + (data.checker ? 'ACTIVOS' : 'INACTIVOS');
	}

	function refreshAll():Void
	{
		refreshRows();
		loadInspector();
		refreshPreview();
		updateMenuButtons();
	}

	function refreshRows():Void
	{
		for (row in rows.members)
			if (row != null)
				row.destroy();

		rows.clear();

		var all = slots();

		if (all.length == 0)
			return;

		if (sel < firstVisible)
			firstVisible = sel;

		if (sel >= firstVisible + visibleRows)
			firstVisible = sel - visibleRows + 1;

		firstVisible = Std.int(Math.max(0, firstVisible));

		var end = Std.int(Math.min(all.length, firstVisible + visibleRows));

		for (i in firstVisible...end)
		{
			var entry = all[i];

			var prefix = switch (entry.kind)
			{
				case 'L': 'LEFT';
				case 'R': 'RIGHT';
				default: '${i + 1}';
			};

			var name = entry.item.label != null && entry.item.label.length > 0
				? entry.item.label
				: entry.item.id;

			var marker = i == sel ? '> ' : '  ';
			var text = '$marker$prefix  $name';

			var row = new FlxText(
				listX + 12,
				listY + 8 + (i - firstVisible) * rowHeight,
				listW - 24,
				text,
				18
			);

			var selectedColor = i == sel ? 0xFFCFB9FF : FlxColor.WHITE;

			row.setFormat(
				Paths.font('vcr.ttf'),
				18,
				selectedColor,
				LEFT,
				FlxTextBorderStyle.OUTLINE,
				FlxColor.BLACK
			);

			row.ID = i;
			rows.add(row);
		}
	}

	function loadInspector():Void
	{
		if (slots().length == 0)
			return;

		loading = true;

		var item = current();

		idInput.text = item.id;
		labelInput.text = item.label == null ? item.id : item.label;
		imageInput.text = item.image;
		argsInput.text = item.args == null ? '' : item.args;
		actionDD.selectedLabel = item.action;
		columnDD.selectedLabel = item.column == null ? 'CENTER' : item.column;

		backgroundInput.text = data.background == null ? 'menuBG' : data.background;

		luaInput.text = data.luaScripts != null && data.luaScripts.length > 0
			? data.luaScripts[0]
			: '';

		hscriptInput.text = data.hscriptScripts != null && data.hscriptScripts.length > 0
			? data.hscriptScripts[0]
			: '';

		loading = false;
	}

	function refreshPreview():Void
	{
		if (preview != null)
		{
			remove(preview);
			preview.destroy();
			preview = null;
		}

		if (slots().length == 0)
			return;

		var item = current();

		if (item.image == null || item.image.length == 0)
		{
			setStatus('Indica la ruta del atlas para la vista previa.');
			return;
		}

		if (!Paths.fileExists('images/${item.image}.xml', TEXT))
		{
			setStatus('No se encontró el atlas: images/${item.image}.xml');
			return;
		}

		preview = new FlxSprite();
		preview.frames = Paths.getSparrowAtlas(item.image);

		preview.animation.addByPrefix(
			'selected',
			'${item.id} selected',
			24,
			true
		);

		preview.animation.addByPrefix(
			'idle',
			'${item.id} idle',
			24,
			true
		);

		if (preview.animation.exists('selected'))
			preview.animation.play('selected');
		else if (preview.animation.exists('idle'))
			preview.animation.play('idle');
		else
			setStatus('No se encontraron animaciones para ${item.id}.');

		preview.antialiasing = ClientPrefs.data.antialiasing;
		preview.updateHitbox();

		var previewX:Float = listX + listW + 15;
		var previewAreaWidth:Float = FlxG.width - previewX - UI_box.width - 35;

		preview.x = previewX + Math.max(0, (previewAreaWidth - preview.width) / 2);
		preview.y = FlxG.height * 0.48 - preview.height / 2;

		var maxHeight:Float = FlxG.height * 0.38;

		if (preview.height > maxHeight && maxHeight > 0)
		{
			preview.setGraphicSize(0, Std.int(maxHeight));
			preview.updateHitbox();
		}

		add(preview);
	}

	// --------------------------------------------------
	// Navegación por teclado y gestos táctiles
	// --------------------------------------------------

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (PsychUIInputText.focusOn != null)
			return;

		if (FlxG.keys.justPressed.UP)
			select(-1);

		if (FlxG.keys.justPressed.DOWN)
			select(1);

		if (FlxG.keys.justPressed.PAGEUP)
			select(-visibleRows);

		if (FlxG.keys.justPressed.PAGEDOWN)
			select(visibleRows);

		if (FlxG.mouse.justPressed)
		{
			gestureStartX = FlxG.mouse.x;
			gestureStartY = FlxG.mouse.y;
			gestureActive = true;

			for (row in rows.members)
			{
				if (row != null && FlxG.mouse.overlaps(row))
				{
					sel = row.ID;
					refreshAll();
					break;
				}
			}
		}

		if (gestureActive && FlxG.mouse.justReleased)
		{
			var deltaY = FlxG.mouse.y - gestureStartY;
			var deltaX = FlxG.mouse.x - gestureStartX;

			if (Math.abs(deltaY) > 35 && Math.abs(deltaY) > Math.abs(deltaX))
			{
				select(deltaY < 0 ? 1 : -1);
			}
			else if (Math.abs(deltaX) > 80)
			{
				// Deslizar horizontalmente cambia la selección.
				select(deltaX < 0 ? 1 : -1);
			}

			gestureActive = false;
		}

		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S)
			save();

		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MasterEditorMenu());
		}
	}

	function select(change:Int):Void
	{
		var all = slots();

		if (all.length == 0)
			return;

		sel = FlxMath.wrap(sel + change, 0, all.length - 1);

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		refreshRows();
		loadInspector();
		refreshPreview();
	}
}
