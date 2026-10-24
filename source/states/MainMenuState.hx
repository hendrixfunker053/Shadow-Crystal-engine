package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import lime.app.Application;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import backend.MainMenuData;
import backend.MenuScripts;
import objects.quickpanel.QuickPanelState;

enum MainMenuColumn
{
	LEFT;
	CENTER;
	RIGHT;
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '1.0.4';
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;

	var allowMouse:Bool = #if mobile false #else true #end;

	public var menuItems:FlxTypedGroup<FlxSprite>;
	public var leftItem:FlxSprite;
	public var rightItem:FlxSprite;

	// Scripts Lua / HScript de mods/<mod>/scripts/mainmenu/
	public var scripts:MenuScripts = null;

	// Menú cargado desde data/mainmenu.json (o el de por defecto)
	var menuData:MainMenuFile;
	var optionShit:Array<MenuItemData>;
	var leftOption:MenuItemData;
	var rightOption:MenuItemData;

	// Panel rápido: solo existe si el mod tiene "Custom menu": true en su pack.json
	var quickPanel:QuickPanelState = null;

	var magenta:FlxSprite;
	var camFollow:FlxObject;

	var checkerPattern:FlxBackdrop;
	var checkerBitmap:BitmapData;

	static var showOutdatedWarning:Bool = true;

	override function create()
	{
		super.create();

		// El mod reemplaza todo el menú principal con scripts/states/MainMenuState.(lua|hx)
		if (MainMenuData.overridden('MainMenuState'))
		{
			MusicBeatState.switchState(new ScriptedState('MainMenuState'));
			return;
		}

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;

		var yScroll:Float = 0.25;

		// Fondo original
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		mobile.WideScreen.fit(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		// Fondo magenta original
		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);
		mobile.WideScreen.fit(magenta);

		// Fondo de cuadros de Shadow Crystal
		var checkerSize:Int = 64;
		var patternSize:Int = checkerSize * 2;

		checkerBitmap = new BitmapData(patternSize, patternSize, false, 0xFF777777);

		checkerBitmap.fillRect(new Rectangle(0, 0, checkerSize, checkerSize), 0xFF777777);
		checkerBitmap.fillRect(new Rectangle(checkerSize, 0, checkerSize, checkerSize), 0xFF999999);
		checkerBitmap.fillRect(new Rectangle(0, checkerSize, checkerSize, checkerSize), 0xFF999999);
		checkerBitmap.fillRect(new Rectangle(checkerSize, checkerSize, checkerSize, checkerSize), 0xFF777777);

		checkerPattern = new FlxBackdrop(checkerBitmap, FlxAxes.XY, 0, 0);
		checkerPattern.alpha = 0.20;
		checkerPattern.velocity.set(35, 35);
		checkerPattern.scrollFactor.set(0, 0);
		checkerPattern.antialiasing = false;
		add(checkerPattern);

		// Menú principal (data/mainmenu.json)
		menuData = MainMenuData.load();
		optionShit = menuData.items;
		leftOption = menuData.left;
		rightOption = menuData.right;

		scripts = new MenuScripts(this, 'mainmenu');
		scripts.getItems = function() return menuItems == null ? [] : cast menuItems.members.copy();
		scripts.getSelected = function() return curSelected;
		scripts.selectItem = function(i:Int) {
			curColumn = CENTER;
			curSelected = FlxMath.wrap(i, 0, optionShit.length - 1);
			changeItem();
		};
		scripts.load();
		scripts.call('onCreate');

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		for (num => option in optionShit)
			createMenuItem(option, 0, 0);

		if (rightOption != null)
			rightItem = createMenuItem(rightOption, 0, 0);

		if (leftOption != null)
			leftItem = createMenuItem(leftOption, 0, 0);

		// Mismo layout que usa el editor (MainMenuData.place); x/y del json lo anulan
		var centerItems:Array<FlxSprite> = [for (i in 0...optionShit.length) menuItems.members[i]];
		MainMenuData.place(menuData, centerItems, leftItem, rightItem, FlxG.width, FlxG.height, #if mobile true #else false #end);

		// Versión de Psych Engine
		var psychVer:FlxText = new FlxText(12, FlxG.height - 44, 0,
			"Psych Engine v" + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);

		// Versión de Friday Night Funkin'
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 24, 0,
			"Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);

		// Shadow Crystal Engine
		var shadowWidth:Float = FlxG.width - 12 #if mobile - 150 #end;
		var shadowVer:FlxText = new FlxText(0, FlxG.height - 24, shadowWidth,
			"Shadow Crystal Engine 1.0", 12);
		shadowVer.scrollFactor.set();
		shadowVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(shadowVer);

		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		var leDate = Date.now();

		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates
			&& substates.OutdatedSubState.updateVersion != psychEngineVersion)
		{
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		FlxG.camera.follow(camFollow, null, 0.15);

		#if mobile
		var backButton:mobile.MobileButton = mobile.MobileButton.back(null, false);
		add(backButton);

		editorsButton = new mobile.ImageButton(16, 50, 'editorButton', 0.6);
		add(editorsButton);
		#end

		scripts.call('onCreatePost');

		// Panel rápido (solo si pack.json tiene "Custom menu": true)
		if (MainMenuData.hasCustomMenu())
		{
			quickPanel = new QuickPanelState();
			add(quickPanel);
		}
	}

	function createMenuItem(data:MenuItemData, x:Float, y:Float):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);

		if (Paths.fileExists('images/${data.image}.xml', TEXT))
		{
			menuItem.frames = Paths.getSparrowAtlas(data.image);
			menuItem.animation.addByPrefix('idle', '${data.id} idle', 24, true);
			menuItem.animation.addByPrefix('selected', '${data.id} selected', 24, true);
			menuItem.animation.play('idle');
		}
		else
		{
			trace('Atlas no encontrado: ${data.image}');
			menuItem.makeGraphic(400, 100, 0xFF444444);
		}
		if (data.scale != null && data.scale > 0 && data.scale != 1)
			menuItem.scale.set(data.scale, data.scale);
		menuItem.updateHitbox();

		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItems.add(menuItem);

		return menuItem;
	}

	var selectedSomethin:Bool = false;

	#if mobile
	var editorsButton:mobile.ImageButton;
	#end

	var timeNotMoving:Float = 0;

	override function update(elapsed:Float)
	{
		// Mientras el panel rápido está abierto (o arrastrándose) el menú de debajo no responde
		scripts.call('onUpdate', [elapsed]);

		var panelBusy:Bool = quickPanel != null && quickPanel.isBusy();
		if (quickPanel != null)
			quickPanel.panel.blocked = selectedSomethin;

		if (!panelBusy && FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume = Math.min(
				FlxG.sound.music.volume + 0.5 * elapsed, 0.8);
		}

		if (!selectedSomethin && !panelBusy)
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			var mouseAllowed:Bool = allowMouse;

			if (mouseAllowed && ((FlxG.mouse.deltaScreenX != 0
				&& FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed))
			{
				mouseAllowed = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite;

				switch (curColumn)
				{
					case CENTER:
						selectedItem = menuItems.members[curSelected];
					case LEFT:
						selectedItem = leftItem;
					case RIGHT:
						selectedItem = rightItem;
				}

				if (leftItem != null && FlxG.mouse.overlaps(leftItem))
				{
					mouseAllowed = true;

					if (selectedItem != leftItem)
					{
						curColumn = LEFT;
						changeItem();
					}
				}
				else if (rightItem != null && FlxG.mouse.overlaps(rightItem))
				{
					mouseAllowed = true;

					if (selectedItem != rightItem)
					{
						curColumn = RIGHT;
						changeItem();
					}
				}
				else
				{
					var dist:Float = -1;
					var distItem:Int = -1;

					for (i in 0...optionShit.length)
					{
						var memb:FlxSprite = menuItems.members[i];

						if (FlxG.mouse.overlaps(memb))
						{
							var distance:Float = Math.sqrt(
								Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2)
								+ Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));

							if (dist < 0 || distance < dist)
							{
								dist = distance;
								distItem = i;
								mouseAllowed = true;
							}
						}
					}

					if (distItem != -1 && selectedItem != menuItems.members[distItem])
					{
						curColumn = CENTER;
						curSelected = distItem;
						changeItem();
					}
				}
			}
			else
			{
				timeNotMoving += elapsed;

				if (timeNotMoving > 2)
					FlxG.mouse.visible = false;
			}

			// Navegación por teclado y gamepad
			switch (curColumn)
			{
				case CENTER:
					if (controls.UI_LEFT_P && leftOption != null)
					{
						curColumn = LEFT;
						changeItem();
					}
					else if (controls.UI_RIGHT_P && rightOption != null)
					{
						curColumn = RIGHT;
						changeItem();
					}

				case LEFT:
					if (controls.UI_RIGHT_P)
					{
						curColumn = CENTER;
						changeItem();
					}

				case RIGHT:
					if (controls.UI_LEFT_P)
					{
						curColumn = CENTER;
						changeItem();
					}
			}

			var touchAccept:Bool = false;

			#if mobile
			if (mobile.TouchInput.justTapped())
			{
				mobile.TouchInput.consumeTap();

				var selectedItem:FlxSprite = switch (curColumn)
				{
					case CENTER: menuItems.members[curSelected];
					case LEFT: leftItem;
					case RIGHT: rightItem;
				}

				var tappedItem:FlxSprite = null;

				if (leftItem != null && mobile.TouchInput.tappedOn(leftItem))
				{
					tappedItem = leftItem;

					if (tappedItem != selectedItem)
						curColumn = LEFT;
				}
				else if (rightItem != null && mobile.TouchInput.tappedOn(rightItem))
				{
					tappedItem = rightItem;

					if (tappedItem != selectedItem)
						curColumn = RIGHT;
				}
				else
				{
					for (i in 0...optionShit.length)
					{
						if (mobile.TouchInput.tappedOn(menuItems.members[i]))
						{
							tappedItem = menuItems.members[i];

							if (tappedItem != selectedItem)
							{
								curColumn = CENTER;
								curSelected = i;
							}

							break;
						}
					}
				}

				if (tappedItem != null)
				{
					if (tappedItem == selectedItem)
						touchAccept = true;
					else
						changeItem();
				}
			}

			if (editorsButton.justTapped)
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end

			if (controls.BACK)
			{
				scripts.call('onBack');
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || touchAccept
				|| (FlxG.mouse.justPressed && mouseAllowed))
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));

				selectedSomethin = true;
				FlxG.mouse.visible = false;

				if (ClientPrefs.data.flashing)
					FlxFlicker.flicker(magenta, 1.1, 0.15, false);

				var item:FlxSprite;
				var option:MenuItemData;

				switch (curColumn)
				{
					case CENTER:
						option = optionShit[curSelected];
						item = menuItems.members[curSelected];
					case LEFT:
						option = leftOption;
						item = leftItem;
					case RIGHT:
						option = rightOption;
						item = rightItem;
				}

				FlxFlicker.flicker(item, 1, 0.06, false, false,
					function(flick:FlxFlicker)
				{
					runAction(option, item);
				});

				for (memb in menuItems)
				{
					if (memb == item)
						continue;

					FlxTween.tween(memb, {alpha: 0}, 0.4,
						{ease: FlxEase.quadOut});
				}
			}

			#if desktop
			if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}

		super.update(elapsed);
		scripts.call('onUpdatePost', [elapsed]);
	}

	function cancelAction(item:FlxSprite)
	{
		selectedSomethin = false;
		item.visible = true;
		for (memb in menuItems)
		{
			FlxTween.cancelTweensOf(memb);
			memb.alpha = 1;
		}
		changeItem();
	}

	function runAction(option:MenuItemData, item:FlxSprite)
	{
		// onAccept(action, id, index): Function_Stop cancela la acción por defecto
		if (scripts.call('onAccept', [option.action, option.id, curSelected]))
		{
			cancelAction(item);
			return;
		}

		switch (option.action)
		{
			case 'substate':
				// args = nombre de un substate propio (scripts/substates/<args>) o una clase FlxSubState
				cancelAction(item);
				if (MainMenuData.stateScriptExists('substates', option.args))
				{
					persistentUpdate = false;
					openSubState(new ScriptedSubState(option.args));
				}
				else
				{
					var subCls:Class<Dynamic> = MainMenuData.resolveClassAny([option.args]);
					if (subCls != null)
					{
						persistentUpdate = false;
						openSubState(cast Type.createInstance(subCls, []));
					}
					else
						trace('SubState no encontrado: ${option.args}');
				}

			case 'script':
				// onMenuAction(nombre, id): el nombre es el campo "args" del item
				scripts.call('onMenuAction', [option.args, option.id]);
				cancelAction(item);

			case 'story_mode':
				MainMenuData.goState('StoryMenuState', function() return new StoryMenuState());

			case 'freeplay':
				MainMenuData.goState('FreeplayState', function() return new FreeplayState());

			#if MODS_ALLOWED
			case 'mods':
				MainMenuData.forceOriginal = false; // si vas a cambiar de mod, vuelves al menú del mod elegido
				MainMenuData.goState('ModsMenuState', function() return new ModsMenuState());
			#end

			#if ACHIEVEMENTS_ALLOWED
			case 'achievements':
				MusicBeatState.switchState(new AchievementsMenuState());
			#end

			case 'credits':
				MainMenuData.goState('CreditsState', function() return new CreditsState());

			case 'options':
				MainMenuData.goState('OptionsState', function() return new OptionsState());
				OptionsState.onPlayState = false;

				if (PlayState.SONG != null)
				{
					PlayState.SONG.arrowSkin = null;
					PlayState.SONG.splashSkin = null;
					PlayState.stageUI = 'normal';
				}

			case 'url':
				CoolUtil.browserLoad(option.args);
				selectedSomethin = false;
				item.visible = true;

			case 'state':
				// args = nombre de un state propio (scripts/states/<args>) o una clase (states.X)
				var cls:Class<Dynamic> = Type.resolveClass(option.args);
				if (cls == null) cls = Type.resolveClass('states.' + option.args);

				if (MainMenuData.stateScriptExists('states', option.args))
					MusicBeatState.switchState(new ScriptedState(option.args));
				else if (cls != null)
					MusicBeatState.switchState(cast Type.createInstance(cls, []));
				else
				{
					trace('Clase no encontrada: ${option.args}');
					selectedSomethin = false;
					item.visible = true;
				}

			default:
				trace('Menu Item ${option.id} doesn\'t do anything');
				selectedSomethin = false;
				item.visible = true;
		}
	}

	function changeItem(change:Int = 0)
	{
		if (change != 0)
			curColumn = CENTER;

		curSelected = FlxMath.wrap(
			curSelected + change, 0, optionShit.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in menuItems)
		{
			item.animation.play('idle');
			item.centerOffsets();
		}

		var selectedItem:FlxSprite;

		switch (curColumn)
		{
			case CENTER:
				selectedItem = menuItems.members[curSelected];
			case LEFT:
				selectedItem = leftItem;
			case RIGHT:
				selectedItem = rightItem;
		}

		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
		camFollow.y = selectedItem.getGraphicMidpoint().y;

		if (scripts != null)
			scripts.call('onSelect', [Std.string(curColumn), curSelected]);
	}

	override function closeSubState()
	{
		super.closeSubState();
		persistentUpdate = true;
	}

	override function destroy()
	{
		if (scripts != null)
		{
			scripts.destroy();
			scripts = null;
		}
		super.destroy();
	}
}
