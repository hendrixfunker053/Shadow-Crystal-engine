
package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import lime.app.Application;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
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

	// Menú cargado desde data/mainmenu.json o con los valores predeterminados.
	var menuData:MainMenuFile;
	var optionShit:Array<MenuItemData>;
	var leftOption:MenuItemData;
	var rightOption:MenuItemData;

	var magenta:FlxSprite;
	var camFollow:FlxObject;

	var checkerPattern:FlxBackdrop;
	var checkerBitmap:BitmapData;

	static var showOutdatedWarning:Bool = true;

	override function create()
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

		var yScroll:Float = 0.25;

		// Fondo original.
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

		// Fondo magenta original.
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

		// Fondo de cuadros de Shadow Crystal.
		var checkerSize:Int = 64;
		var patternSize:Int = checkerSize * 2;

		checkerBitmap = new BitmapData(patternSize, patternSize, false, 0xFF777777);

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

		checkerPattern = new FlxBackdrop(checkerBitmap, FlxAxes.XY, 0, 0);
		checkerPattern.alpha = 0.20;
		checkerPattern.velocity.set(35, 35);
		checkerPattern.scrollFactor.set(0, 0);
		checkerPattern.antialiasing = false;
		add(checkerPattern);

		// Menú principal personalizado.
		menuData = MainMenuData.load();
		optionShit = menuData.items;
		leftOption = menuData.left;
		rightOption = menuData.right;

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		var menuSpacing:Float = menuData.spacing;
		var startMenuY:Float = menuData.startY;

		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(
				option,
				0,
				startMenuY + num * menuSpacing
			);
			item.screenCenter(X);
		}

		if (menuItems.members.length == 0)
		{
			trace('Error: el menú principal no contiene elementos.');
			return;
		}

		var story:FlxSprite = menuItems.members[0];

		// Logros: alineados a la derecha en móvil.
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

			rightItem.y = startMenuY + (story.height - rightItem.height) / 2;
		}

		// Opciones: abajo a la izquierda.
		if (leftOption != null)
		{
			leftItem = createMenuItem(leftOption, 36, 0);
			leftItem.y = FlxG.height - leftItem.height - 50;
		}

		// Versión de Psych Engine.
		var psychVer:FlxText = new FlxText(
			12,
			FlxG.height - 44,
			0,
			"Psych Engine v" + psychEngineVersion,
			12
		);
		psychVer.scrollFactor.set();
		psychVer.setFormat(
			Paths.font("vcr.ttf"),
			16,
			FlxColor.WHITE,
			LEFT,
			FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK
		);
		add(psychVer);

		// Versión de Friday Night Funkin'.
		var fnfVer:FlxText = new FlxText(
			12,
			FlxG.height - 24,
			0,
			"Friday Night Funkin' v" + Application.current.meta.get('version'),
			12
		);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(
			Paths.font("vcr.ttf"),
			16,
			FlxColor.WHITE,
			LEFT,
			FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK
		);
		add(fnfVer);

		// Shadow Crystal Engine.
		var shadowWidth:Float = FlxG.width - 12 #if mobile - 150 #end;
		var shadowVer:FlxText = new FlxText(
			0,
			FlxG.height - 24,
			shadowWidth,
			"Shadow Crystal Engine 1.0",
			12
		);
		shadowVer.scrollFactor.set();
		shadowVer.setFormat(
			Paths.font("vcr.ttf"),
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
		#end
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

		menuItem.updateHitbox();
		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItems.add(menuItem);

		return menuItem;
	}

	var selectedSomethin:Bool = false;
	var timeNotMoving:Float = 0;

	override function update(elapsed:Float)
	{
		if (!selectedSomethin && FlxG.sound.music != null
			&& FlxG.sound.music.volume < 0.8)
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

			var mouseAllowed:Bool = allowMouse;

			if (mouseAllowed && (
				(FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0)
				|| FlxG.mouse.justPressed
			))
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
								+ Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2)
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

			// Navegación por teclado y gamepad.
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
				};

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
			#end

			if (controls.BACK)
			{
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
		}

		super.update(elapsed);
	}

	function runAction(option:MenuItemData, item:FlxSprite)
	{
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
				MusicBeatState.switchState(new OptionsState());
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
				var cls:Class<Dynamic> = Type.resolveClass(option.args);

				if (cls == null)
					cls = Type.resolveClass('states.' + option.args);

				if (cls != null)
				{
					MusicBeatState.switchState(
						cast Type.createInstance(cls, [])
					);
				}
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

		if (selectedItem == null)
		{
			curColumn = CENTER;
			selectedItem = menuItems.members[curSelected];
		}

		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
		camFollow.y = selectedItem.getGraphicMidpoint().y;
	}
}
