
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

	var menuItems:FlxTypedGroup<FlxSprite>;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;

	var menuData:MainMenuFile;
	var optionShit:Array<MenuItemData>;
	var leftOption:MenuItemData;
	var rightOption:MenuItemData;

	var magenta:FlxSprite;
	var camFollow:FlxObject;

	var checkerPattern:FlxBackdrop;
	var checkerBitmap:BitmapData;

	var background:FlxSprite;

	static var showOutdatedWarning:Bool = true;

	var selectedSomethin:Bool = false;
	var timeNotMoving:Float = 0;

	#if mobile
	var editorsButton:mobile.ImageButton;
	#end

	// Variables para detectar gestos de deslizamiento.
	var gestureActive:Bool = false;
	var gestureStartX:Float = 0;
	var gestureStartY:Float = 0;
	var gestureConsumed:Bool = false;

	override function create():Void
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end

		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;

		// Cargar la configuración antes de construir los fondos.
		menuData = MainMenuData.load();

		if (menuData == null)
			menuData = MainMenuData.getDefault();

		if (menuData.items == null)
			menuData.items = [];

		if (menuData.items.length == 0)
			menuData.items.push(MainMenuData.newItem('freeplay', 'freeplay'));

		optionShit = menuData.items;
		leftOption = menuData.left;
		rightOption = menuData.right;

		if (menuData.spacing == null)
			menuData.spacing = 150;

		if (menuData.startY == null)
			menuData.startY = 40;

		var yScroll:Float = 0.25;

		// --------------------------------------------------
		// Fondo configurable
		// --------------------------------------------------

		var bgName:String = menuData.background;

		if (bgName == null || bgName.length == 0)
			bgName = 'menuBG';

		background = new FlxSprite(-80).loadGraphic(Paths.image(bgName));
		background.antialiasing = ClientPrefs.data.antialiasing;
		background.scrollFactor.set(0, yScroll);
		background.setGraphicSize(Std.int(background.width * 1.175));
		background.updateHitbox();
		background.screenCenter();
		add(background);
		mobile.WideScreen.fit(background);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		// --------------------------------------------------
		// Fondo magenta original
		// --------------------------------------------------

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFFD719B;
		add(magenta);
		mobile.WideScreen.fit(magenta);

		// --------------------------------------------------
		// Patrón de cuadros de Shadow Crystal
		//
		// Se muestra únicamente si checker está activo
		// y el menú no se ha marcado como personalizado.
		// --------------------------------------------------

		var useChecker:Bool = menuData.checker != false
			&& menuData.custom != true;

		if (useChecker)
			createCheckerPattern();

		// --------------------------------------------------
		// Opciones centrales
		// --------------------------------------------------

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		var centerCount:Int = 0;
		var leftCount:Int = 0;
		var rightCount:Int = 0;

		for (option in optionShit)
		{
			var column:String = getOptionColumn(option);

			switch (column)
			{
				case 'LEFT':
					leftCount++;

				case 'RIGHT':
					rightCount++;

				default:
					centerCount++;
			}
		}

		var centerIndex:Int = 0;
		var leftIndex:Int = 0;
		var rightIndex:Int = 0;

		for (option in optionShit)
		{
			var column:String = getOptionColumn(option);
			var item:FlxSprite;
			var itemY:Float;

			switch (column)
			{
				case 'LEFT':
					itemY = menuData.startY + leftIndex * menuData.spacing;
					item = createMenuItem(option, 36, itemY);
					leftIndex++;

				case 'RIGHT':
					itemY = menuData.startY + rightIndex * menuData.spacing;
					item = createMenuItem(option, 0, itemY);
					item.x = FlxG.width - item.width - 36;
					rightIndex++;

				default:
					itemY = menuData.startY + centerIndex * menuData.spacing;
					item = createMenuItem(option, 0, itemY);
					item.screenCenter(X);
					centerIndex++;
			}
		}

		// --------------------------------------------------
		// Opciones laterales especiales
		// --------------------------------------------------

		var story:FlxSprite = menuItems.members[0];

		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, 0, 0);

			#if mobile
			rightItem.x = FlxG.width - rightItem.width - 16;
			#else
			rightItem.x = Math.min(
				story.x + story.width + 40,
				FlxG.width - rightItem.width - 20
			);
			#end

			rightItem.y = menuData.startY
				+ (story.height - rightItem.height) / 2;
		}

		if (leftOption != null)
		{
			leftItem = createMenuItem(leftOption, 36, 0);
			leftItem.y = FlxG.height - leftItem.height - 50;
		}

		// --------------------------------------------------
		// Información de versión
		// --------------------------------------------------

		var psychVer:FlxText = new FlxText(
			12,
			FlxG.height - 44,
			0,
			'Psych Engine v' + psychEngineVersion,
			12
		);

		psychVer.scrollFactor.set();
		psychVer.setFormat(
			Paths.font('vcr.ttf'),
			16,
			FlxColor.WHITE,
			LEFT,
			FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK
		);
		add(psychVer);

		var fnfVer:FlxText = new FlxText(
			12,
			FlxG.height - 24,
			0,
			"Friday Night Funkin' v" + Application.current.meta.get('version'),
			12
		);

		fnfVer.scrollFactor.set();
		fnfVer.setFormat(
			Paths.font('vcr.ttf'),
			16,
			FlxColor.WHITE,
			LEFT,
			FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK
		);
		add(fnfVer);

		var shadowWidth:Float = FlxG.width - 12 #if mobile - 150 #end;

		var shadowVer:FlxText = new FlxText(
			0,
			FlxG.height - 24,
			shadowWidth,
			'Shadow Crystal Engine 1.0',
			12
		);

		shadowVer.scrollFactor.set();
		shadowVer.setFormat(
			Paths.font('vcr.ttf'),
			16,
			FlxColor.WHITE,
			RIGHT,
			FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK
		);
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
		if (showOutdatedWarning
			&& ClientPrefs.data.checkForUpdates
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
	}

	// --------------------------------------------------
	// Fondo de cuadros
	// --------------------------------------------------

	function createCheckerPattern():Void
	{
		var checkerSize:Int = 64;
		var patternSize:Int = checkerSize * 2;

		checkerBitmap = new BitmapData(
			patternSize,
			patternSize,
			false,
			0xFF777777
		);

		checkerBitmap.fillRect(
			new Rectangle(0, 0, checkerSize, checkerSize),
			0xFF777777
		);

		checkerBitmap.fillRect(
			new Rectangle(checkerSize, 0, checkerSize, checkerSize),
			0xFF999999
		);

		checkerBitmap.fillRect(
			new Rectangle(0, checkerSize, checkerSize, checkerSize),
			0xFF999999
		);

		checkerBitmap.fillRect(
			new Rectangle(checkerSize, checkerSize, checkerSize, checkerSize),
			0xFF777777
		);

		checkerPattern = new FlxBackdrop(
			checkerBitmap,
			FlxAxes.XY,
			0,
			0
		);

		checkerPattern.alpha = menuData.checkerAlpha == null
			? 0.20
			: menuData.checkerAlpha;

		checkerPattern.velocity.set(35, 35);
		checkerPattern.scrollFactor.set(0, 0);
		checkerPattern.antialiasing = false;

		add(checkerPattern);
	}

	// --------------------------------------------------
	// Columnas y opciones
	// --------------------------------------------------

	function getOptionColumn(option:MenuItemData):String
	{
		if (option.column == null)
			return 'CENTER';

		var value:String = option.column.toUpperCase();

		if (value != 'LEFT' && value != 'RIGHT')
			return 'CENTER';

		return value;
	}

	function createMenuItem(
		data:MenuItemData,
		x:Float,
		y:Float
	):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);

		if (Paths.fileExists('images/${data.image}.xml', TEXT))
		{
			menuItem.frames = Paths.getSparrowAtlas(data.image);

			menuItem.animation.addByPrefix(
				'idle',
				'${data.id} idle',
				24,
				true
			);

			menuItem.animation.addByPrefix(
				'selected',
				'${data.id} selected',
				24,
				true
			);

			if (menuItem.animation.exists('idle'))
				menuItem.animation.play('idle');
		}
		else
		{
			trace('Atlas no encontrado: ${data.image}');

			menuItem.makeGraphic(400, 100, 0xFF444444);

			var label:String = data.label == null || data.label.length == 0
				? data.id
				: data.label;

			var placeholderText:FlxText = new FlxText(
				0, 0, 400, label, 24
			);

			placeholderText.setFormat(
				Paths.font('vcr.ttf'),
				24,
				FlxColor.WHITE,
				CENTER,
				FlxTextBorderStyle.OUTLINE,
				FlxColor.BLACK
			);

			placeholderText.scrollFactor.set();
			menuItem.stamp(placeholderText);
			placeholderText.destroy();
		}

		menuItem.updateHitbox();
		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();

		if (data.enabled == false)
			menuItem.alpha = 0.45;

		menuItems.add(menuItem);

		return menuItem;
	}

	// --------------------------------------------------
	// Ejecutar acciones
	// --------------------------------------------------

	function runAction(option:MenuItemData, item:FlxSprite):Void
	{
		if (option == null || item == null)
		{
			selectedSomethin = false;
			return;
		}

		if (option.enabled == false)
		{
			selectedSomethin = false;
			return;
		}

		var args:String = option.args == null ? '' : option.args;

		switch (option.action)
		{
			case 'story_mode':
				MusicBeatState.switchState(new StoryMenuState());

			case 'freeplay':
				MusicBeatState.switchState(new FreeplayState());

			#if MODS_ALLOWED
			case 'mods':
				MusicBeatState.switchState(new ModsMenuState());
			#end

			#if ACHIEVEMENTS_ALLOWED
			case 'achievements':
				MusicBeatState.switchState(new AchievementsMenuState());
			#end

			case 'credits':
				MusicBeatState.switchState(new CreditsState());

			case 'options':
				OptionsState.onPlayState = false;

				if (PlayState.SONG != null)
				{
					PlayState.SONG.arrowSkin = null;
					PlayState.SONG.splashSkin = null;
					PlayState.stageUI = 'normal';
				}

				MusicBeatState.switchState(new OptionsState());

			case 'url':
				if (args.length > 0)
					CoolUtil.browserLoad(args);

				selectedSomethin = false;

			case 'state':
				var cls:Class<Dynamic> = Type.resolveClass(args);

				if (cls == null)
					cls = Type.resolveClass('states.' + args);

				if (cls != null)
				{
					MusicBeatState.switchState(
						cast Type.createInstance(cls, [])
					);
				}
				else
				{
					trace('Clase no encontrada: $args');
					selectedSomethin = false;
				}

			case 'none':
				trace('La opción ${option.id} no tiene acción.');
				selectedSomethin = false;

			default:
				trace('Acción desconocida: ${option.action}');
				selectedSomethin = false;
		}
	}

	// --------------------------------------------------
	// Actualización
	// --------------------------------------------------

	override function update(elapsed:Float):Void
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
		{
			FlxG.sound.music.volume = Math.min(
				FlxG.sound.music.volume + 0.5 * elapsed,
				0.8
			);
		}

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			// Navegación horizontal entre columnas.
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

			var mouseAllowed:Bool = allowMouse;
			var mouseMoved:Bool = FlxG.mouse.deltaScreenX != 0
				|| FlxG.mouse.deltaScreenY != 0;

			if (mouseAllowed && (mouseMoved || FlxG.mouse.justPressed))
			{
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite = getSelectedSprite();

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

						if (memb != null && FlxG.mouse.overlaps(memb))
						{
							var distance:Float = Math.sqrt(
								Math.pow(
									memb.getGraphicMidpoint().x - FlxG.mouse.screenX,
									2
								)
								+ Math.pow(
									memb.getGraphicMidpoint().y - FlxG.mouse.screenY,
									2
								)
							);

							if (dist < 0 || distance < dist)
							{
								dist = distance;
								distItem = i;
								mouseAllowed = true;
							}
						}
					}

					if (distItem != -1
						&& selectedItem != menuItems.members[distItem])
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

			// Detectar inicio de gesto.
			if (FlxG.mouse.justPressed)
			{
				gestureActive = true;
				gestureConsumed = false;
				gestureStartX = FlxG.mouse.screenX;
				gestureStartY = FlxG.mouse.screenY;
			}

			// Deslizar arriba/abajo para recorrer opciones.
			if (gestureActive && FlxG.mouse.justReleased)
			{
				var dx:Float = FlxG.mouse.screenX - gestureStartX;
				var dy:Float = FlxG.mouse.screenY - gestureStartY;

				if (Math.abs(dy) > 45 && Math.abs(dy) > Math.abs(dx))
				{
					changeItem(dy < 0 ? 1 : -1);
					gestureConsumed = true;
				}
				else if (Math.abs(dx) > 80)
				{
					if (dx < 0 && rightOption != null)
					{
						curColumn = RIGHT;
						changeItem();
					}
					else if (dx > 0 && leftOption != null)
					{
						curColumn = LEFT;
						changeItem();
					}

					gestureConsumed = true;
				}

				gestureActive = false;
			}

			#if mobile
			// Toques mediante el sistema móvil del fork.
			if (mobile.TouchInput.justTapped())
			{
				mobile.TouchInput.consumeTap();

				var selectedItem:FlxSprite = getSelectedSprite();
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
						acceptSelection();
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
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT)
				acceptSelection();

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
	}

	function getSelectedSprite():FlxSprite
	{
		switch (curColumn)
		{
			case LEFT:
				return leftItem;

			case RIGHT:
				return rightItem;

			default:
				if (menuItems == null || menuItems.members.length == 0)
					return null;

				curSelected = Std.int(Math.max(
					0,
					Math.min(curSelected, menuItems.members.length - 1)
				));

				return menuItems.members[curSelected];
		}
	}

	function getSelectedOption():MenuItemData
	{
		switch (curColumn)
		{
			case LEFT:
				return leftOption;

			case RIGHT:
				return rightOption;

			default:
				if (optionShit == null || optionShit.length == 0)
					return null;

				curSelected = Std.int(Math.max(
					0,
					Math.min(curSelected, optionShit.length - 1)
				));

				return optionShit[curSelected];
		}
	}

	function acceptSelection():Void
	{
		if (selectedSomethin)
			return;

		var item:FlxSprite = getSelectedSprite();
		var option:MenuItemData = getSelectedOption();

		if (item == null || option == null)
			return;

		if (option.enabled == false)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		FlxG.sound.play(Paths.sound('confirmMenu'));

		selectedSomethin = true;
		FlxG.mouse.visible = false;

		if (ClientPrefs.data.flashing)
			FlxFlicker.flicker(magenta, 1.1, 0.15, false);

		FlxFlicker.flicker(
			item,
			1,
			0.06,
			false,
			false,
			function(flick:FlxFlicker)
			{
				runAction(option, item);
			}
		);

		for (memb in menuItems)
		{
			if (memb == item)
				continue;

			FlxTween.tween(
				memb,
				{alpha: 0},
				0.4,
				{ease: FlxEase.quadOut}
			);
		}
	}

	// --------------------------------------------------
	// Selección
	// --------------------------------------------------

	function changeItem(change:Int = 0):Void
	{
		if (optionShit == null || optionShit.length == 0)
			return;

		if (change != 0)
			curColumn = CENTER;

		curSelected = FlxMath.wrap(
			curSelected + change,
			0,
			optionShit.length - 1
		);

		FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in menuItems)
		{
			if (item == null)
				continue;

			if (item.animation.exists('idle'))
				item.animation.play('idle');

			item.centerOffsets();
		}

		var selectedItem:FlxSprite = getSelectedSprite();

		if (selectedItem != null)
		{
			if (selectedItem.animation.exists('selected'))
				selectedItem.animation.play('selected');

			selectedItem.centerOffsets();
			camFollow.y = selectedItem.getGraphicMidpoint().y;
		}
	}
}
