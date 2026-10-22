
package states.editors;

import backend.MainMenuData;
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

	var data:MainMenuFile;
	var sel:Int = 0;
	var loading:Bool = false;

	var rows:FlxTypedGroup<FlxText>;
	var preview:FlxSprite;
	var status:FlxText;

	var UI_box:PsychUIBox;
	var idInput:PsychUIInputText;
	var imageInput:PsychUIInputText;
	var argsInput:PsychUIInputText;
	var actionDD:PsychUIDropDownMenu;

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

		data = MainMenuData.load();

		if (data == null)
			data = MainMenuData.load();

		if (data.items == null)
			data.items = [];

		if (data.items.length == 0)
			data.items.push(MainMenuData.newItem('freeplay', 'freeplay'));

		rows = new FlxTypedGroup<FlxText>();
		add(rows);

		status = new FlxText(
			20,
			FlxG.height - 60,
			FlxG.width - 40,
			'',
			18
		);
		status.setFormat(
			Paths.font("vcr.ttf"),
			18,
			FlxColor.WHITE,
			LEFT,
			FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK
		);
		add(status);

		var help:FlxText = new FlxText(
			20,
			FlxG.height - 30,
			FlxG.width - 40,
			'ARRIBA/ABAJO: seleccionar | CTRL+S: guardar | ESC: salir',
			16
		);
		help.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.GRAY, LEFT);
		add(help);

		buildUI();
		refreshAll();

		FlxG.mouse.visible = true;

		super.create();
	}

	function buildUI():Void
	{
		UI_box = new PsychUIBox(
			FlxG.width - 380,
			20,
			360,
			440,
			['Item']
		);
		UI_box.scrollFactor.set();
		add(UI_box);

		var tab = UI_box.getTab('Item').menu;

		tab.add(new FlxText(15, 10, 0, 'ID (prefijo de animación):'));

		idInput = new PsychUIInputText(15, 28, 320, '', 8);
		idInput.onChange = function(old:String, cur:String)
		{
			if (loading || slots().length == 0)
				return;

			current().id = cur;
			refreshRows();
			refreshPreview();
		};
		tab.add(idInput);

		tab.add(new FlxText(15, 60, 0, 'Imagen (atlas sin extensión):'));

		imageInput = new PsychUIInputText(15, 78, 320, '', 8);
		imageInput.onChange = function(old:String, cur:String)
		{
			if (loading || slots().length == 0)
				return;

			current().image = cur;
			refreshPreview();
		};
		tab.add(imageInput);

		tab.add(new FlxText(15, 110, 0, 'Args (URL o clase):'));

		argsInput = new PsychUIInputText(15, 128, 320, '', 8);
		argsInput.onChange = function(old:String, cur:String)
		{
			if (loading || slots().length == 0)
				return;

			current().args = cur;
		};
		tab.add(argsInput);

		tab.add(new PsychUIButton(15, 170, 'Añadir', function()
		{
			data.items.push(MainMenuData.newItem('new_item', 'none'));
			sel = slots().length - 1;
			refreshAll();
		}, 100, 25));

		tab.add(new PsychUIButton(125, 170, 'Borrar', function()
		{
			removeCurrent();
		}, 100, 25));

		tab.add(new PsychUIButton(235, 170, 'Recargar', function()
		{
			data = MainMenuData.load();

			if (data.items == null)
				data.items = [];

			if (data.items.length == 0)
				data.items.push(MainMenuData.newItem('freeplay', 'freeplay'));

			sel = 0;
			refreshAll();
		}, 100, 25));

		tab.add(new PsychUIButton(15, 205, 'Subir', function()
		{
			move(-1);
		}, 100, 25));

		tab.add(new PsychUIButton(125, 205, 'Bajar', function()
		{
			move(1);
		}, 100, 25));

		tab.add(new PsychUIButton(235, 205, 'Guardar', function()
		{
			save();
		}, 100, 25));

		tab.add(new PsychUIButton(15, 240, 'Alternar LEFT', function()
		{
			toggleSide(true);
		}, 155, 25));

		tab.add(new PsychUIButton(180, 240, 'Alternar RIGHT', function()
		{
			toggleSide(false);
		}, 155, 25));

		tab.add(new FlxText(15, 280, 0, 'Acción:'));

		actionDD = new PsychUIDropDownMenu(
			15,
			298,
			ACTIONS,
			function(index:Int, name:String)
			{
				if (loading || slots().length == 0)
					return;

				current().action = name;
				refreshRows();
			},
			320
		);
		tab.add(actionDD);
	}

	// --------------------------------------------------
	// Datos
	// --------------------------------------------------

	function slots():Array<{item:MenuItemData, kind:String}>
	{
		var result:Array<{item:MenuItemData, kind:String}> = [];

		if (data == null)
			return result;

		if (data.items != null)
		{
			for (item in data.items)
				result.push({item: item, kind: 'C'});
		}

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

	function removeCurrent():Void
	{
		var kind = currentKind();

		switch (kind)
		{
			case 'C':
				if (data.items.length <= 1)
				{
					setStatus('Debe quedar al menos un item.');
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
			return;

		var to:Int = sel + dir;

		if (to < 0 || to >= data.items.length)
			return;

		var tmp = data.items[sel];
		data.items[sel] = data.items[to];
		data.items[to] = tmp;

		sel = to;
		refreshAll();
	}

	function toggleSide(left:Bool):Void
	{
		if (left)
		{
			data.left = (data.left == null)
				? MainMenuData.newItem('options', 'options')
				: null;
		}
		else
		{
			data.right = (data.right == null)
				? MainMenuData.newItem('achievements', 'achievements')
				: null;
		}

		sel = Std.int(Math.max(0, Math.min(sel, slots().length - 1)));
		refreshAll();
	}

	function save():Void
	{
		var path:String = MainMenuData.save(data);

		if (path != null)
			setStatus('Guardado en: ' + path);
		else
			setStatus('Guardar no está soportado en esta plataforma.');
	}

	// --------------------------------------------------
	// Interfaz
	// --------------------------------------------------

	function setStatus(message:String):Void
	{
		status.text = message;
	}

	function refreshAll():Void
	{
		refreshRows();
		loadInspector();
		refreshPreview();
	}

	function refreshRows():Void
	{
		for (row in rows.members)
		{
			if (row != null)
				row.destroy();
		}

		rows.clear();

		var all = slots();

		for (i in 0...all.length)
		{
			var entry = all[i];

			var prefix:String = switch (entry.kind)
			{
				case 'L': 'LEFT  ';
				case 'R': 'RIGHT ';
				default: '${i + 1}. ';
			};

			var itemText:FlxText = new FlxText(
				20,
				20 + i * 30,
				440,
				'$prefix${entry.item.id}  [${entry.item.action}]',
				22
			);

			itemText.setFormat(
				Paths.font("vcr.ttf"),
				22,
				i == sel ? FlxColor.YELLOW : FlxColor.WHITE,
				LEFT,
				FlxTextBorderStyle.OUTLINE,
				FlxColor.BLACK
			);

			rows.add(itemText);
		}
	}

	function loadInspector():Void
	{
		if (slots().length == 0)
			return;

		loading = true;

		var item = current();

		idInput.text = item.id;
		imageInput.text = item.image;
		argsInput.text = item.args;
		actionDD.selectedLabel = item.action;

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
			setStatus('Escribe el nombre del atlas para mostrar la vista previa.');
			return;
		}

		if (!Paths.fileExists('images/${item.image}.xml', TEXT))
		{
			setStatus('No se encontró el atlas: images/${item.image}.xml');
			return;
		}

		preview = new FlxSprite(480, 120);
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
		{
			preview.animation.play('selected');
			setStatus('');
		}
		else if (preview.animation.exists('idle'))
		{
			preview.animation.play('idle');
			setStatus('Falta la animación "${item.id} selected".');
		}
		else
		{
			setStatus('No se encontraron las animaciones de "${item.id}".');
		}

		preview.antialiasing = ClientPrefs.data.antialiasing;
		preview.updateHitbox();

		if (preview.height > 300)
		{
			preview.setGraphicSize(0, 300);
			preview.updateHitbox();
		}

		insert(members.indexOf(rows), preview);
	}

	// --------------------------------------------------
	// Controles
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

		if (FlxG.mouse.justPressed)
		{
			for (i in 0...rows.members.length)
			{
				var row = rows.members[i];

				if (row != null && FlxG.mouse.overlaps(row))
				{
					sel = i;
					refreshRows();
					loadInspector();
					refreshPreview();
					break;
				}
			}
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
