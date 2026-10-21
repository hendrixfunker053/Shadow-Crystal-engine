package states;

/**
 * Mods menu state.
 *
 * Keeps the existing Psych Engine mod loading, ordering, enable/disable,
 * settings, restart, controller, mouse and mobile-touch behavior.
 *
 * Visual assets are loaded from images/modsMenu/ and images/modsMenuButtons.
 * The companion funkin.ui.modmenu classes belong to a different engine-side
 * implementation, so this state intentionally keeps its compatible local
 * ModItem and MenuButton classes instead of mixing incompatible APIs.
 */

import backend.WeekData;
import backend.Mods;

import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import flash.geom.Rectangle;
import haxe.Json;

import flixel.util.FlxSpriteUtil;
import objects.AttachedSprite;
import options.ModSettingsSubState;

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;

import openfl.display.BitmapData;
import lime.utils.Assets;

class ModsMenuState extends MusicBeatState
{
	// === Decoración (assets en images/modsMenu/) ===
	var bg:FlxSprite;
	var wires:FlxSprite;
	var smoke:FlxSprite;
	var smokeTimer:FlxTimer;
	var sparks:FlxSprite;
	var headerText:FlxSprite;
	var battery:FlxSprite;
	var charBF:FlxSprite;
	var charGF:FlxSprite;

	// La música ambiente se queda sonando al recargar el menú; solo se restaura al salir
	static var ambienceOn:Bool = false;

	var icon:FlxSprite;
	var modName:FlxText;
	var modDesc:FlxText;
	var modRestartText:FlxText;
	var modsList:ModsList = null;

	var bgList:FlxSprite;
	var buttonReload:MenuButton;
	//var buttonModFolder:MenuButton;
	var buttonEnableAll:MenuButton;
	var buttonDisableAll:MenuButton;
	var buttons:Array<MenuButton> = [];
	var settingsButton:MenuButton;

	var bgTitle:FlxSprite;
	var bgDescription:FlxSprite;
	var bgButtons:FlxSprite;

	var modsGroup:FlxTypedGroup<ModItem>;
	var curSelectedMod:Int = 0;
	
	var hoveringOnMods:Bool = true;
	var curSelectedButton:Int = 0; ///-1 = Enable/Disable All, -2 = Reload
	var modNameInitialY:Float = 0;

	var noModsSine:Float = 0;
	var noModsTxt:FlxText;

	var _lastControllerMode:Bool = false;
	var startMod:String = null;
	// -------------------------------------------------------------------------
	// State lifecycle and menu construction
	// -------------------------------------------------------------------------
	public function new(startMod:String = null)
	{
		this.startMod = startMod;
		super();
	}
	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		persistentUpdate = false;

		modsList = Mods.parseList();
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		if(!ambienceOn)
		{
			FlxG.sound.playMusic(Paths.music('modMenuAmbience'), 0.6);
			ambienceOn = true;
		}

		// Los elementos de la derecha se anclan al borde derecho (por si la pantalla es más ancha que 1280)
		var ox:Float = Math.max(0, FlxG.width - 1280);

		// Fondo
		bg = new FlxSprite().loadGraphic(Paths.image('modsMenu/bg'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.setGraphicSize(0, FlxG.height);
		bg.updateHitbox();
		add(bg);
		bg.screenCenter();
		mobile.WideScreen.fit(bg);

		// Cables de fondo (esquina inferior derecha)
		wires = new FlxSprite().loadGraphic(Paths.image('modsMenu/bgwires'));
		wires.antialiasing = ClientPrefs.data.antialiasing;
		wires.alpha = 0.5;
		wires.setPosition(FlxG.width - wires.width, FlxG.height - wires.height);
		add(wires);

		// Batería sobre la silla (parpadea)
		battery = new FlxSprite(965 + ox, 80);
		battery.frames = Paths.getSparrowAtlas('modsMenu/carbattery');
		battery.animation.addByPrefix('idle', 'idle', 2, true);
		battery.animation.play('idle');
		battery.antialiasing = ClientPrefs.data.antialiasing;
		battery.scale.set(0.75, 0.75);
		battery.updateHitbox();
		add(battery);

		// GF primero y BF después: BF queda en una capa por encima de GF.
		// Atlas prerenderizados a escala 0.7 desde los Animate (idle / shock / crispy / crispyLoop)
		charGF = makeChar('gf', 760 + ox, 57,
			[0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 6, 6, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0, 8, 9, 10, 11, 12, 13, 14, 15, 10, 16, 17, 18, 11, 18, 13, 10, 14, 8, 18, 19, 14, 8, 17, 13, 11, 8, 13, 11, 10, 15, 14, 16, 9, 20, 20, 20, 21, 21, 21, 22, 22, 22, 22, 23, 23, 23, 23, 23, 23, 23, 24, 24, 25, 25, 26, 27, 27, 28, 29, 29, 30, 31, 32, 32, 33, 33, 33, 34, 35, 35, 36, 36, 36, 37, 32, 32, 33, 33, 33, 34, 35, 35, 36, 36, 36, 37, 32, 32, 33, 33, 33, 34, 35, 35, 36, 36, 36, 37, 32, 32, 33, 33],
			30, 63, 93);
		add(charGF);
		charBF = makeChar('bf', 924 + ox, 224,
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 6, 6, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 9, 10, 11, 12, 8, 13, 14, 12, 15, 11, 10, 13, 8, 13, 12, 11, 8, 9, 10, 11, 12, 8, 13, 14, 12, 15, 11, 10, 13, 8, 13, 12, 11, 8, 9, 10, 11, 12, 8, 13, 14, 12, 15, 11, 10, 13, 8, 13, 12, 11, 8, 9, 10, 11, 12, 8, 13, 14, 12, 16, 16, 16, 17, 17, 17, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19, 20, 20, 21, 21, 22, 22, 22, 23, 23, 23, 24, 24, 24, 25, 25, 25, 26, 26, 26, 27, 27, 27, 24, 24, 24, 25, 25, 25, 26, 26, 26, 27, 27, 27, 24, 24, 24, 25, 25, 25, 26, 26, 26],
			65, 125, 152);
		add(charBF);

		// Chispas (sparks): cada 'sparkN' corresponde al sonido spark-N; 'electrocution' al sonido grande
		sparks = new FlxSprite();
		sparks.frames = Paths.getSparrowAtlas('modsMenu/sparks');
		var sparkSeq:Array<Int> = [0, 1, 2, 3, 4, 1, 5, 6, 7, 8, 8, 9, 9, 1, 1, 10, 10, 1, 11, 12, 1, 13, 14, 15, 1, 16, 1, 1, 17, 18, 19, 20, 21, 22, 1, 17, 1, 1, 1, 1, 1, 1, 23, 1, 24, 1, 1, 25, 26, 27, 28, 1, 25, 29, 30, 1, 1, 31, 32, 1, 33, 34, 35, 1, 36, 37, 38, 1, 39, 40, 1, 1, 41, 42, 42, 1, 43, 44, 45, 46, 1, 47, 47, 1, 48, 49, 1, 50, 50, 1, 51, 52, 53, 54, 1, 55, 56, 56, 57, 58, 56, 59, 1, 1, 55, 56, 60, 61, 1, 62, 1, 63, 64, 65, 1, 66, 67, 68, 69, 69, 70, 70, 1, 1, 71, 71, 1, 72, 73, 1, 74, 75, 76, 1, 77, 1, 1, 78, 79, 80, 81, 82, 83, 1, 78, 1, 1, 1, 1, 1, 1, 84, 1, 85, 1, 1, 86, 87, 88, 89, 1, 86, 90, 91, 1, 1, 92, 93, 1, 94, 95, 96, 1, 97, 98, 99, 1, 100, 101, 1, 1, 102, 103, 103, 1, 104, 105, 106, 107, 1, 108, 108, 1, 109, 110, 1, 111, 111, 1, 112, 113, 1, 114, 115, 116, 1, 117, 117, 1, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 1, 130, 1, 127, 129, 131, 1, 132, 132, 133, 1, 134, 135, 136, 136, 137, 138, 139, 139, 1, 140, 1, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 155, 156, 157, 1, 158, 159, 159, 160, 160, 161, 161, 1, 1, 162, 163, 1, 164, 165, 166, 1, 167, 167, 1, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 1, 180, 1, 177, 179, 181, 1, 182, 182, 183, 1, 184, 185, 186, 186, 187, 188, 189, 189, 1, 190, 1, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 205, 206, 207, 1, 208, 209, 209, 210, 210, 211, 211, 1, 1, 212, 213, 214, 1, 215, 216, 217, 1, 218, 219, 1, 220, 221, 222, 223, 224, 1, 225, 1, 226, 227, 1, 228, 229, 230, 231, 1, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 1, 249, 1, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 1, 262, 263, 264, 265, 266, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 286, 288, 1, 289, 1, 289, 1, 1, 1];
		var sparkStarts:Array<Int> = [0, 18, 64, 90, 109, 127, 173, 199, 241, 271, 313, 343, 419];
		for (i in 0...11)
			sparks.animation.add('spark' + (i + 1), [for (f in sparkStarts[i]...sparkStarts[i + 1]) sparkSeq[f]], 24, false);
		sparks.animation.add('electrocution', [for (f in sparkStarts[11]...sparkStarts[12]) sparkSeq[f]], 24, false);
		sparks.animation.finishCallback = function(_:String) sparks.visible = false;
		sparks.antialiasing = ClientPrefs.data.antialiasing;
		sparks.scale.set(1.659, 1.659); // atlas a 0.8 -> 0.8 * 1.659 = 1.327 (escala de la instancia en el Animate)
		sparks.updateHitbox();
		sparks.setPosition(487 + ox, 26);
		sparks.visible = false;
		add(sparks);

		// smoke-cloud: nube que sube desde las sillas al electrocutar
		smoke = new FlxSprite();
		smoke.frames = Paths.getSparrowAtlas('modsMenu/smoke_cloud');
		smoke.animation.add('puff', [0, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 18, 19, 19, 20, 20], 24, false);
		smoke.animation.finishCallback = function(_:String) smoke.visible = false;
		smoke.antialiasing = ClientPrefs.data.antialiasing;
		smoke.scale.set(1.4, 1.4); // atlas a 0.5 -> 0.5 * 1.4 = 0.7
		smoke.updateHitbox();
		smoke.setPosition(1364 + ox - 684, 510 - 984); // origen del Animate (1364,510) + bbox*0.7
		smoke.visible = false;
		add(smoke);

		// Título "CHOOSE YOUR MODS" en el margen superior
		headerText = new FlxSprite(40, 6).loadGraphic(Paths.image('modsMenu/top-text'));
		headerText.antialiasing = ClientPrefs.data.antialiasing;
		headerText.scale.set(0.45, 0.45);
		headerText.updateHitbox();
		add(headerText);

		// Panel de la lista (misma geometría que antes: 340x440 en 40,40)
		bgList = new FlxSprite(40, 40).loadGraphic(Paths.image('modsMenu/box'));
		bgList.antialiasing = ClientPrefs.data.antialiasing;
		bgList.setGraphicSize(340, 440);
		bgList.updateHitbox();
		bgList.alpha = 0.85;

		modsGroup = new FlxTypedGroup<ModItem>();

		for (i => mod in modsList.all)
		{
			if(startMod == mod) curSelectedMod = i;

			var modItem:ModItem = new ModItem(mod);
			if(modsList.disabled.contains(mod))
			{
				modItem.icon.color = 0xFFFF6666;
				modItem.text.color = FlxColor.GRAY;
			}
			modsGroup.add(modItem);
		}

		//
		var buttonX = bgList.x;
		var buttonWidth = Std.int(bgList.width);
		var buttonHeight = 80;

		buttonReload = new MenuButton(buttonX, bgList.y + bgList.height + 20, buttonWidth, buttonHeight, Language.getPhrase('reload_button', 'RELOAD'), reload);
		add(buttonReload);
		
		var myY = buttonReload.y + buttonReload.bg.height + 20;
		/*buttonModFolder = new MenuButton(buttonX, myY, buttonWidth, buttonHeight, "MODS FOLDER", function() {
			var modFolder = Paths.mods();
			if(!FileSystem.exists(modFolder))
			{
				trace('created missing folder');
				FileSystem.createDirectory(modFolder);
			}
			CoolUtil.openFolder(modFolder);
		});
		add(buttonModFolder);*/

		buttonEnableAll = new MenuButton(buttonX, myY, buttonWidth, buttonHeight, Language.getPhrase('enable_all_button', 'ENABLE ALL'), function() {
			buttonEnableAll.ignoreCheck = false;
			for (mod in modsGroup.members)
			{
				if(modsList.disabled.contains(mod.folder))
				{
					modsList.disabled.remove(mod.folder);
					modsList.enabled.push(mod.folder);
					mod.icon.color = FlxColor.WHITE;
					mod.text.color = FlxColor.WHITE;
				}
			}
			updateModDisplayData();
			checkToggleButtons();
			playSpark(true, true);
		});
		buttonEnableAll.bg.color = FlxColor.GREEN;
		buttonEnableAll.focusChangeCallback = function(focus:Bool) if(!focus) buttonEnableAll.bg.color = FlxColor.GREEN;
		add(buttonEnableAll);

		buttonDisableAll = new MenuButton(buttonX, myY, buttonWidth, buttonHeight, Language.getPhrase('disable_all_button', 'DISABLE ALL'), function() {
			buttonDisableAll.ignoreCheck = false;
			for (mod in modsGroup.members)
			{
				if(modsList.enabled.contains(mod.folder))
				{
					modsList.enabled.remove(mod.folder);
					modsList.disabled.push(mod.folder);
					mod.icon.color = 0xFFFF6666;
					mod.text.color = FlxColor.GRAY;
				}
			}
			updateModDisplayData();
			checkToggleButtons();
			playSpark(true);
		});
		buttonDisableAll.bg.color = 0xFFFF6666;
		buttonDisableAll.focusChangeCallback = function(focus:Bool) if(!focus) buttonDisableAll.bg.color = 0xFFFF6666;
		add(buttonDisableAll);
		checkToggleButtons();

		if(modsList.all.length < 1)
		{
			buttonDisableAll.visible = buttonDisableAll.enabled = false;
			buttonEnableAll.visible = true;

			var myX = bgList.x + bgList.width + 20;
			noModsTxt = new FlxText(myX, 0, 380, Language.getPhrase('no_mods_installed', 'NO MODS INSTALLED\nPRESS BACK TO EXIT OR INSTALL A MOD'), 48);
			if(FlxG.random.bool(0.1)) noModsTxt.text += '\nBITCH.'; //meanie
			noModsTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			noModsTxt.borderSize = 2;
			add(noModsTxt);
			noModsTxt.screenCenter(Y);

			var txt = new FlxText(bgList.x + 15, bgList.y + 15, bgList.width - 30, Language.getPhrase('no_mods_found', "No Mods found."), 16);
			txt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE);
			add(txt);

			FlxG.autoPause = false;
			changeSelectedMod();
			return super.create();
		}
		//

		var infoW:Int = 400; // columna de info (el resto de la derecha es para BF y GF)

		bgTitle = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgList.x + bgList.width + 20, 40).makeGraphic(infoW, 180, FlxColor.TRANSPARENT), 0, 0, infoW, 180, 15, 15, 0, 0, FlxColor.BLACK);
		bgTitle.alpha = 0.6;
		add(bgTitle);

		icon = new FlxSprite(bgTitle.x + 15, bgTitle.y + 15);
		add(icon);

		modName = new FlxText(icon.x + 165, bgTitle.y + 15, infoW - 195, "", 24);
		modName.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		modName.borderSize = 2;
		add(modName);

		bgDescription = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgTitle.x, bgTitle.y + 200).makeGraphic(infoW, 450, FlxColor.TRANSPARENT), 0, 0, infoW, 450, 0, 0, 15, 15, FlxColor.BLACK);
		bgDescription.alpha = 0.6;
		add(bgDescription);
		
		modDesc = new FlxText(bgDescription.x + 15, bgDescription.y + 15, bgDescription.width - 30, "", 20);
		modDesc.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, LEFT);
		add(modDesc);

		var myHeight = 100;
		modRestartText = new FlxText(bgDescription.x + 15, bgDescription.y + bgDescription.height - myHeight - 50, bgDescription.width - 30, Language.getPhrase('mod_restart', '* Moving or Toggling On/Off this Mod will restart the game.'), 14);
		modRestartText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, RIGHT);
		add(modRestartText);

		bgButtons = FlxSpriteUtil.drawRoundRectComplex(new FlxSprite(bgDescription.x, bgDescription.y + bgDescription.height - myHeight).makeGraphic(infoW, myHeight, FlxColor.TRANSPARENT), 0, 0, infoW, myHeight, 0, 0, 15, 15, FlxColor.WHITE);
		bgButtons.color = FlxColor.BLACK;
		bgButtons.alpha = 0.2;
		add(bgButtons);

		// 5 botones de 66px en una barra de 400px
		var btnSize:Int = 66;
		var btnStep:Int = 76;
		var buttonsX = bgButtons.x + (infoW - (btnStep * 4 + btnSize)) / 2;
		var buttonsY = bgButtons.y + (myHeight - btnSize) / 2;

		var button = new MenuButton(buttonsX, buttonsY, btnSize, btnSize, Paths.image('modsMenuButtons'), function() moveModToPosition(0), 54, 54); //Move to the top
		button.icon.animation.add('icon', [0]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		
		var button = new MenuButton(buttonsX + btnStep, buttonsY, btnSize, btnSize, Paths.image('modsMenuButtons'), function() moveModToPosition(curSelectedMod - 1), 54, 54); //Move up
		button.icon.animation.add('icon', [1]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		
		var button = new MenuButton(buttonsX + btnStep * 2, buttonsY, btnSize, btnSize, Paths.image('modsMenuButtons'), function() moveModToPosition(curSelectedMod + 1), 54, 54); //Move down
		button.icon.animation.add('icon', [2]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		
		if(modsList.all.length < 2)
		{
			for (button in buttons)
				button.enabled = false;
		}

		settingsButton = new MenuButton(buttonsX + btnStep * 3, buttonsY, btnSize, btnSize, Paths.image('modsMenuButtons'), function() //Settings
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			if(curMod != null && curMod.settings != null && curMod.settings.length > 0)
			{
				openSubState(new ModSettingsSubState(curMod.settings, curMod.folder, curMod.name));
			}
		}, 54, 54);

		settingsButton.icon.animation.add('icon', [3]);
		settingsButton.icon.animation.play('icon', true);
		add(settingsButton);
		buttons.push(settingsButton);

		if(modsGroup.members[curSelectedMod].settings == null || modsGroup.members[curSelectedMod].settings.length < 1)
			settingsButton.enabled = false;

		var button = new MenuButton(buttonsX + btnStep * 4, buttonsY, btnSize, btnSize, Paths.image('modsMenuButtons'), function() //On/Off
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			var mod:String = curMod.folder;
			if(!modsList.disabled.contains(mod)) //Enable
			{
				modsList.enabled.remove(mod);
				modsList.disabled.push(mod);
			}
			else //Disable
			{
				modsList.disabled.remove(mod);
				modsList.enabled.push(mod);
			}
			curMod.icon.color = modsList.disabled.contains(mod) ? 0xFFFF6666 : FlxColor.WHITE;
			curMod.text.color = modsList.disabled.contains(mod) ? FlxColor.GRAY : FlxColor.WHITE;

			if(curMod.mustRestart) waitingToRestart = true;
			updateModDisplayData();
			checkToggleButtons();
			playSpark();
		}, 54, 54);
		button.icon.animation.add('icon', [4]);
		button.icon.animation.play('icon', true);
		add(button);
		buttons.push(button);
		button.focusChangeCallback = function(focus:Bool) {
			if(!focus)
				button.bg.color = modsList.enabled.contains(modsGroup.members[curSelectedMod].folder) ? FlxColor.GREEN : 0xFFFF6666;
		};

		#if !mobile
		// Botón "OPEN MOD FOLDER" debajo de BF y GF. Va al final del array para que la navegación con teclado/mando siga el orden del layout.
		var folderButton = new MenuButton(840 + ox, 662, 400, 48, Paths.image('modsMenu/open-folder'), function() {
			var modFolder = Paths.mods();
			if(!FileSystem.exists(modFolder))
			{
				trace('created missing folder');
				FileSystem.createDirectory(modFolder);
			}
			CoolUtil.openFolder(modFolder);
		});
		folderButton.icon.antialiasing = ClientPrefs.data.antialiasing;
		folderButton.icon.setGraphicSize(360);
		folderButton.icon.updateHitbox();
		folderButton.icon.x = folderButton.bg.x + (folderButton.bg.width - folderButton.icon.width) / 2;
		folderButton.icon.y = folderButton.bg.y + (folderButton.bg.height - folderButton.icon.height) / 2;
		add(folderButton);
		buttons.push(folderButton);
		#end

		if(modsList.all.length < 1)
		{
			for (btn in buttons) btn.enabled = false;
			button.focusChangeCallback = null;
		}
		
		add(bgList);
		add(modsGroup);
		_lastControllerMode = controls.controllerMode;

		changeSelectedMod();
		#if mobile
		add(mobile.MobileButton.back(null, true));
		#end
		super.create();
	}

	// -------------------------------------------------------------------------
	// Character and effects helpers
	// -------------------------------------------------------------------------
	// seq = índices de los frames únicos del atlas para cada frame de la animación original (24 fps)
	// idleEnd / shockEnd = último frame de idle y de shock; loopStart = frame donde empieza 'crispy loop'
	function makeChar(name:String, x:Float, y:Float, seq:Array<Int>, idleEnd:Int, shockEnd:Int, loopStart:Int):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite(x, y);
		spr.frames = Paths.getSparrowAtlas('modsMenu/char_' + name);
		var last:Int = seq.length - 1;
		spr.animation.add('idle', [for (i in 0...(idleEnd + 1)) seq[i]], 24, true);
		spr.animation.add('shock', [for (i in (idleEnd + 1)...(shockEnd + 1)) seq[i]], 24, false);
		spr.animation.add('crispy', [for (i in (shockEnd + 1)...(last + 1)) seq[i]], 24, false);
		spr.animation.add('crispyLoop', [for (i in loopStart...(last + 1)) seq[i]], 24, true);
		spr.animation.finishCallback = function(anim:String) {
			if(anim == 'shock') spr.animation.play('idle', true);
			else if(anim == 'crispy') spr.animation.play('crispyLoop', true);
		};
		spr.animation.play('idle');
		spr.antialiasing = ClientPrefs.data.antialiasing;
		return spr;
	}

	// big = sonido/chispa grande (Enable All / Disable All); crispy = BF y GF quedan chamuscados (Enable All)
	function playSpark(big:Bool = false, crispy:Bool = false)
	{
		var sparkAnim:String;
		if(big)
		{
			FlxG.sound.play(Paths.sound('modsMenu/sparks/electrocution'), 0.7);
			sparkAnim = 'electrocution';
		}
		else
		{
			var n:Int = FlxG.random.int(1, 11);
			FlxG.sound.play(Paths.sound('modsMenu/sparks/spark-' + n), 0.7);
			sparkAnim = 'spark' + n;
		}
		if(sparks != null)
		{
			sparks.visible = true;
			sparks.animation.play(sparkAnim, true);
		}
		shockChars(crispy);
	}

	// BF y GF se electrocutan (o quedan crispy) y sale la nube de humo
	function shockChars(crispy:Bool = false)
	{
		if(charBF == null || charGF == null || smoke == null) return;

		var anim:String = crispy ? 'crispy' : 'shock';
		charBF.animation.play(anim, true);
		charGF.animation.play(anim, true);
		if(crispy) FlxG.sound.play(Paths.sound('modsMenu/crispy'), 0.7);

		if(smokeTimer != null) smokeTimer.cancel();
		smokeTimer = new FlxTimer().start(crispy ? 0.9 : 0.5, function(_) {
			FlxG.sound.play(Paths.sound('modsMenu/smoke-cloud'), 0.6);
			smoke.visible = true;
			smoke.animation.play('puff', true);
		});
	}

	function restoreMenuMusic()
	{
		ambienceOn = false;
		FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
		FlxG.sound.music.fadeIn(0.6, 0, 0.7);
	}
	
	var nextAttempt:Float = 1;
	var holdingMod:Bool = false;
	var mouseOffsets:FlxPoint = new FlxPoint();
	var holdingElapsed:Float = 0;
	var gottaClickAgain:Bool = false;

	var holdTime:Float = 0;

	#if mobile
	var dragAccum:Float = 0;
	var touchHoldTime:Float = 0;

	override function destroy()
	{
		mobile.TouchInput.blockGestures = false;
		super.destroy();
	}
	#end

	// -------------------------------------------------------------------------
	// Input, navigation and update loop
	// -------------------------------------------------------------------------
	override function update(elapsed:Float)
	{
		#if mobile
		mobile.TouchInput.blockGestures = true;
		if (FlxG.mouse.justPressed) touchHoldTime = 0;
		else if (FlxG.mouse.pressed) touchHoldTime += elapsed;
		#end
		if(controls.BACK && hoveringOnMods)
		{
			saveTxt();

			FlxG.sound.play(Paths.sound('cancelMenu'));
			if(waitingToRestart)
			{
				//MusicBeatState.switchState(new TitleState());
				ambienceOn = false;
				TitleState.initialized = false;
				TitleState.closedState = false;
				FlxG.sound.music.fadeOut(0.3);
				if(FreeplayState.vocals != null)
				{
					FreeplayState.vocals.fadeOut(0.3);
					FreeplayState.vocals = null;
				}
				FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);
			}
			else
			{
				restoreMenuMusic();
				MusicBeatState.switchState(new MainMenuState());
			}

			persistentUpdate = false;
			FlxG.autoPause = ClientPrefs.data.autoPause;
			FlxG.mouse.visible = false;
			return;
		}

		if(Math.abs(FlxG.mouse.deltaX) > 10 || Math.abs(FlxG.mouse.deltaY) > 10)
		{
			controls.controllerMode = false;
			if(!FlxG.mouse.visible) FlxG.mouse.visible = true;
		}
		
		if(controls.controllerMode != _lastControllerMode)
		{
			if(controls.controllerMode) FlxG.mouse.visible = false;
			_lastControllerMode = controls.controllerMode;
		}

		if(controls.UI_DOWN_R || controls.UI_UP_R) holdTime = 0;

		#if mobile
		if (hoveringOnMods && !holdingMod && modsList.all.length > 1 && mobile.TouchInput.isDragging())
		{
			dragAccum += mobile.TouchInput.dragDeltaY();
			while (dragAccum >= 80)
			{
				dragAccum -= 80;
				changeSelectedMod(-1);
			}
			while (dragAccum <= -80)
			{
				dragAccum += 80;
				changeSelectedMod(1);
			}
		}
		else dragAccum = 0;
		#end

		if(modsList.all.length > 0)
		{
			if(controls.controllerMode && holdingMod)
			{
				holdingMod = false;
				holdingElapsed = 0;
				updateItemPositions();
			}

			var lastMode = hoveringOnMods;
			if(modsList.all.length > 1)
			{
				if(FlxG.mouse.justPressed)
				{
					for (i in centerMod-2...centerMod+3)
					{
						var mod = modsGroup.members[i];
						if(mod != null && mod.visible && FlxG.mouse.overlaps(mod))
						{
							hoveringOnMods = true;
							var button = getButton();
							button.ignoreCheck = button.onFocus = false;
							mouseOffsets.x = FlxG.mouse.x - mod.x;
							mouseOffsets.y = FlxG.mouse.y - mod.y;
							curSelectedMod = i;
							changeSelectedMod();
							break;
						}
					}
					hoveringOnMods = true;
					var button = getButton();
					button.ignoreCheck = button.onFocus = false;
					gottaClickAgain = false;
				}

				if(hoveringOnMods)
				{
					var shiftMult:Int = (FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER) || FlxG.gamepads.anyPressed(RIGHT_SHOULDER)) ? 4 : 1;
					if(controls.UI_DOWN_P)
						changeSelectedMod(shiftMult);
					else if(controls.UI_UP_P)
						changeSelectedMod(-shiftMult);
					else if(FlxG.mouse.wheel != 0)
						changeSelectedMod(-FlxG.mouse.wheel * shiftMult, true);
					else if(FlxG.keys.justPressed.HOME || FlxG.keys.justPressed.END ||
						FlxG.gamepads.anyJustPressed(LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER))
					{
						if(FlxG.keys.justPressed.END || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER)) curSelectedMod = modsList.all.length-1;
						else curSelectedMod = 0;
						changeSelectedMod();
					}
					else if(controls.UI_UP || controls.UI_DOWN)
					{
						var lastHoldTime:Float = holdTime;
						holdTime += elapsed;
						if(holdTime > 0.5 && Math.floor(lastHoldTime * 8) != Math.floor(holdTime * 8)) changeSelectedMod(shiftMult * (controls.UI_UP ? -1 : 1));
					}
					else if(FlxG.mouse.pressed && !gottaClickAgain)
					{
						var curMod:ModItem = modsGroup.members[curSelectedMod];
						if(curMod != null)
						{
							if(!holdingMod && FlxG.mouse.justMoved && FlxG.mouse.overlaps(curMod) #if mobile && touchHoldTime > 0.4 && !mobile.TouchInput.isDragging() #end) holdingMod = true;

							if(holdingMod)
							{
								var moved:Bool = false;
								for (i in centerMod-2...centerMod+3)
								{
									var mod = modsGroup.members[i];
									if(mod != null && mod.visible && FlxG.mouse.overlaps(mod) && curSelectedMod != i)
									{
										moveModToPosition(i);
										moved = true;
										break;
									}
								}
								
								if(!moved)
								{
									var factor:Float = -1;
									if(FlxG.mouse.y < bgList.y)
										factor = Math.abs(Math.max(0.2, Math.min(0.5, 0.5 - (bgList.y - FlxG.mouse.y) / 100)));
									else if(FlxG.mouse.y > bgList.y + bgList.height)
										factor = Math.abs(Math.max(0.2, Math.min(0.5, 0.5 - (FlxG.mouse.y - bgList.y - bgList.height) / 100)));
		
									if(factor >= 0)
									{
										holdingElapsed += elapsed;
										if(holdingElapsed >= factor)
										{
											holdingElapsed = 0;
											var newPos = curSelectedMod;
											if(FlxG.mouse.y < bgList.y) newPos--;
											else newPos++;
											moveModToPosition(Std.int(Math.max(0, Math.min(modsGroup.length - 1, newPos))));
										}
									}
								}
								curMod.x = FlxG.mouse.x - mouseOffsets.x;
								curMod.y = FlxG.mouse.y - mouseOffsets.y;
							}
						}
						
					}
					else if(FlxG.mouse.justReleased && holdingMod)
					{
						holdingMod = false;
						holdingElapsed = 0;
						updateItemPositions();
					}
				}
			}

			if(lastMode == hoveringOnMods)
			{
				if(hoveringOnMods)
				{
					if(controls.UI_RIGHT_P)
					{
						hoveringOnMods = false;
						var button = getButton();
						button.ignoreCheck = button.onFocus = false;
						curSelectedButton = 0;
						changeSelectedButton();
					}
				}
				else 
				{
					if(controls.BACK)
					{
						hoveringOnMods = true;
						var button = getButton();
						button.ignoreCheck = button.onFocus = false;
						changeSelectedMod();
					}
					else if(controls.ACCEPT)
					{
						var button = getButton();
						if(button.onClick != null) button.onClick();
					}
					else if(curSelectedButton < 0)
					{
						if(controls.UI_UP_P)
						{
							switch(curSelectedButton)
							{
								case -2:
									curSelectedMod = 0;
									hoveringOnMods = true;
									var button = getButton();
									button.ignoreCheck = button.onFocus = false;
									changeSelectedMod();
								case -1:
									changeSelectedButton(-1);
							}
						}
						else if(controls.UI_DOWN_P)
						{
							switch(curSelectedButton)
							{
								case -2:
									changeSelectedButton(1);
								case -1:
									curSelectedMod = 0;
									hoveringOnMods = true;
									var button = getButton();
									button.ignoreCheck = button.onFocus = false;
									changeSelectedMod();
							}
						}
						else if(controls.UI_RIGHT_P)
						{
							var button = getButton();
							button.ignoreCheck = button.onFocus = false;
							curSelectedButton = 0;
							changeSelectedButton();
						}
					}
					else if(controls.UI_LEFT_P)
						changeSelectedButton(-1);
					else if(controls.UI_RIGHT_P)
						changeSelectedButton(1);
				}
			}
		}
		else
		{
			noModsSine += 180 * elapsed;
			noModsTxt.alpha = 1 - Math.sin((Math.PI * noModsSine) / 180);
			
			// Keep refreshing mods list every 2 seconds until you add a mod on the folder
			nextAttempt -= elapsed;
			if(nextAttempt < 0)
			{
				nextAttempt = 1;
				@:privateAccess
				Mods.updateModList();
				modsList = Mods.parseList();
				if(modsList.all.length > 0)
				{
					trace('mod(s) found! reloading');
					reload();
				}
			}
		}
		super.update(elapsed);
	}

	// -------------------------------------------------------------------------
	// Selection, ordering and mod-list persistence
	// -------------------------------------------------------------------------
	function changeSelectedButton(add:Int = 0)
	{
		var max = buttons.length - 1;
		
		var button = getButton();
		button.ignoreCheck = button.onFocus = false;

		curSelectedButton += add;
		if(curSelectedButton < -2)
			curSelectedButton = -2;
		else if(curSelectedButton > max)
			curSelectedButton = max;

		var button = getButton();
		button.ignoreCheck = button.onFocus = true;

		var curMod:ModItem = modsGroup.members[curSelectedMod];
		if(curMod != null) curMod.selectBg.visible = false;
		if(curSelectedButton < 0)
		{
			bgButtons.color = FlxColor.BLACK;
			bgButtons.alpha = 0.2;
		}
		else
		{
			bgButtons.color = FlxColor.WHITE;
			bgButtons.alpha = 0.8;
		}

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function getButton()
	{
		switch(curSelectedButton)
		{
			case -2: return buttonReload;
			case -1: return buttonEnableAll.enabled ? buttonEnableAll : buttonDisableAll;
		}

		if(modsList.all.length < 1) return buttonReload; //prevent possible crash from my irresponsibility
		return buttons[Std.int(Math.max(0, Math.min(buttons.length-1, curSelectedButton)))];
	}

	function changeSelectedMod(add:Int = 0, isMouseWheel:Bool = false)
	{
		var max = modsList.all.length - 1;
		if(max < 0) return;

		if(hoveringOnMods)
		{
			var button = getButton();
			button.ignoreCheck = button.onFocus = false;
		}

		var lastSelected = curSelectedMod;
		curSelectedMod += add;

		var limited:Bool = false;
		if(curSelectedMod < 0)
		{
			curSelectedMod = 0;
			limited = true;
		}
		else if(curSelectedMod > max)
		{
			curSelectedMod = max;
			limited = true;
		}
		
		if(!isMouseWheel && limited && Math.abs(add) == 1)
		{
			if(add < 0) // pressed up on first mod
			{
				curSelectedMod = lastSelected;
				hoveringOnMods = false;
				curSelectedButton = -1;
				changeSelectedButton();
				return;
			}
			else // pressed down on last mod
			{
				curSelectedMod = lastSelected;
				hoveringOnMods = false;
				curSelectedButton = -2;
				changeSelectedButton();
				return;
			}
		}
		
		holdingMod = false;
		holdingElapsed = 0;
		gottaClickAgain = true;
		updateModDisplayData();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		
		if(hoveringOnMods)
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			if(curMod != null) curMod.selectBg.visible = true;
			bgButtons.color = FlxColor.BLACK;
			bgButtons.alpha = 0.2;
		}
	}

	function updateModDisplayData()
	{
		var curMod:ModItem = modsGroup.members[curSelectedMod];
		if(curMod == null) return;

		// Batería: encendida y animada si el mod está activado, apagada y quieta si no
		if(battery != null)
		{
			var isOn:Bool = !modsList.disabled.contains(curMod.folder);
			battery.color = isOn ? FlxColor.WHITE : 0xFF555555;
			if(isOn) battery.animation.resume();
			else battery.animation.pause();
		}

		if(Math.abs(centerMod - curSelectedMod) > 2)
		{
			if(centerMod < curSelectedMod)
				centerMod = curSelectedMod - 2;
			else centerMod = curSelectedMod + 2;
		}
		updateItemPositions();

		icon.loadGraphic(curMod.icon.graphic, true, 150, 150);
		icon.antialiasing = curMod.icon.antialiasing;

		if(curMod.totalFrames > 0)
		{
			icon.animation.add("icon", [for (i in 0...curMod.totalFrames) i], curMod.iconFps);
			icon.animation.play("icon");
			icon.animation.curAnim.curFrame = curMod.icon.animation.curAnim.curFrame;
		}

		modName.size = curMod.name.length > 34 ? 18 : (curMod.name.length > 20 ? 21 : 24);
		modName.text = curMod.name;
		modName.y = bgTitle.y + (bgTitle.height - modName.height) / 2;
		modRestartText.visible = curMod.mustRestart;
		modDesc.text = curMod.desc;

		for (button in buttons) if(button.focusChangeCallback != null) button.focusChangeCallback(button.onFocus);
		settingsButton.enabled = (curMod.settings != null && curMod.settings.length > 0);
	}

	var centerMod:Int = 2;
	function updateItemPositions()
	{
		var maxVisible = Math.max(4, centerMod + 2);
		var minVisible = Math.max(0, centerMod - 2);
		for (i => mod in modsGroup.members)
		{
			if(mod == null)
			{
				trace('Mod #$i is null, maybe it was ' + modsList.all[i]);
				continue;
			}

			mod.visible = (i >= minVisible && i <= maxVisible);
			mod.x = bgList.x + 5;
			mod.y = bgList.y + (86 * (i - centerMod + 2)) + 5;
			
			mod.alpha = 0.6;
			if(i == curSelectedMod) mod.alpha = 1;
			mod.selectBg.visible = (i == curSelectedMod && hoveringOnMods);
		}
	}

	var waitingToRestart:Bool = false;
	function moveModToPosition(?mod:String = null, position:Int = 0)
	{
		if(mod == null) mod = modsList.all[curSelectedMod];
		if(position >= modsList.all.length) position = 0;
		else if(position < 0) position = modsList.all.length-1;

		trace('Moved mod $mod to position $position');
		var id:Int = modsList.all.indexOf(mod);
		if(position == id) return;

		var curMod:ModItem = modsGroup.members[id];
		if(curMod == null) return;

		if(curMod.mustRestart || modsGroup.members[position].mustRestart) waitingToRestart = true;

		modsGroup.remove(curMod, true);
		modsList.all.remove(mod);
		//if(position > id) position--;
		modsGroup.insert(position, curMod);
		modsList.all.insert(position, mod);

		curSelectedMod = position;
		updateModDisplayData();
		updateItemPositions();
		
		if(!hoveringOnMods)
		{
			var curMod:ModItem = modsGroup.members[curSelectedMod];
			if(curMod != null) curMod.selectBg.visible = false;
		}
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function checkToggleButtons()
	{
		buttonEnableAll.visible = buttonEnableAll.enabled = modsList.disabled.length > 0;
		buttonDisableAll.visible = buttonDisableAll.enabled = !buttonEnableAll.visible;
	}

	function reload()
	{
		saveTxt();
		FlxG.autoPause = ClientPrefs.data.autoPause;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		var curMod:ModItem = modsGroup.members[curSelectedMod];
		MusicBeatState.switchState(new ModsMenuState(curMod != null ? curMod.folder : null));
	}
	
	function saveTxt()
	{
		var fileStr:String = '';
		for (mod in modsList.all)
		{
			if(mod.trim().length < 1) continue;

			if(fileStr.length > 0) fileStr += '\n';

			var on = '1';
			if(modsList.disabled.contains(mod)) on = '0';
			fileStr += '$mod|$on';
		}

		var path:String = 'modsList.txt';
		File.saveContent(path, fileStr);
		Mods.parseList();
		Mods.loadTopMod();
	}
}

/** A mod entry using the existing Psych Engine asset and metadata APIs. */
class ModItem extends FlxSpriteGroup
{
	public var selectBg:FlxSprite;
	public var icon:FlxSprite;
	public var text:FlxText;
	public var totalFrames:Int = 0;

	// options
	public var name:String = 'Unknown Mod';
	public var desc:String = 'No description provided.';
	public var iconFps:Int = 10;
	public var bgColor:FlxColor = 0xFF665AFF;
	public var pack:Dynamic = null;
	public var folder:String = 'unknownMod';
	public var mustRestart:Bool = false;
	public var settings:Array<Dynamic> = null;

	public function new(folder:String)
	{
		super();

		this.folder = folder;
		pack = Mods.getPack(folder);

		var path:String = Paths.mods('$folder/data/settings.json');
		if(FileSystem.exists(path))
		{
			try
			{
				//trace('trying to load settings: $folder');
				settings = tjson.TJSON.parse(File.getContent(path));
			}
			catch(e:Dynamic)
			{
				var errorTitle = 'Mod name: ' + Mods.currentModDirectory;
				var errorMsg = 'An error occurred: $e';
				#if windows
				lime.app.Application.current.window.alert(errorMsg, errorTitle);
				#end
				trace('$errorTitle - $errorMsg');
			}
		}

		selectBg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		selectBg.alpha = 0.8;
		selectBg.visible = false;
		add(selectBg);

		icon = new FlxSprite(5, 5);
		icon.antialiasing = ClientPrefs.data.antialiasing;
		add(icon);

		text = new FlxText(95, 38, 230, "", 16);
		text.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		text.y -= Std.int(text.height / 2);
		add(text);

		var isPixel = false;
		var file:String = Paths.mods('$folder/pack.png');
		if (!FileSystem.exists(file))
		{
			file = Paths.mods('$folder/pack-pixel.png');
			isPixel = true;
		}
		
		var bmp:BitmapData = null;
		if (FileSystem.exists(file)) bmp = BitmapData.fromFile(file);
		else isPixel = false;

		if(FileSystem.exists(file))
		{
			icon.loadGraphic(Paths.cacheBitmap(file, bmp), true, 150, 150);
			if(isPixel) icon.antialiasing = false;
		}
		else icon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);
		icon.scale.set(0.5, 0.5);
		icon.updateHitbox();
		
		this.name = folder;
		if(pack != null)
		{
			if(pack.name != null) this.name = pack.name;
			if(pack.description != null) this.desc = pack.description;
			if(pack.iconFramerate != null) this.iconFps = pack.iconFramerate;
			if(pack.color != null)
			{
				this.bgColor = FlxColor.fromRGB(pack.color[0] != null ? pack.color[0] : 170,
											  pack.color[1] != null ? pack.color[1] : 0,
											  pack.color[2] != null ? pack.color[2] : 255);
			}
			this.mustRestart = (pack.restart == true);
		}
		text.text = this.name;

		if(bmp != null)
		{
			totalFrames = Math.floor(bmp.width / 150) * Math.floor(bmp.height / 150);
			icon.animation.add("icon", [for (i in 0...totalFrames) i], iconFps);
			icon.animation.play("icon");
		}
		selectBg.scale.set(width + 5, height + 5);
		selectBg.updateHitbox();
	}
}

/** Menu button used by this state; preserves mouse/controller focus behavior. */
class MenuButton extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var textOn:Alphabet;
	public var textOff:Alphabet;
	public var icon:FlxSprite;
	public var onClick:Void->Void = null;
	public var enabled(default, set):Bool = true;
	public function new(x:Float, y:Float, width:Int, height:Int, ?text:String = null, ?img:FlxGraphic = null, onClick:Void->Void = null, animWidth:Int = 0, animHeight:Int = 0)
	{
		super(x, y);
		
		bg = FlxSpriteUtil.drawRoundRect(new FlxSprite().makeGraphic(width, height, FlxColor.TRANSPARENT), 0, 0, width, height, 15, 15, FlxColor.WHITE);
		bg.color = FlxColor.BLACK;
		add(bg);

		if(text != null)
		{
			textOn = new Alphabet(0, 0, "", false);
			textOn.setScale(0.6);
			textOn.text = text;
			textOn.alpha = 0.6;
			textOn.visible = false;
			centerOnBg(textOn);
			textOn.y -= 30;
			add(textOn);
			
			textOff = new Alphabet(0, 0, "", true);
			textOff.setScale(0.52);
			textOff.text = text;
			textOff.alpha = 0.6;
			centerOnBg(textOff);
			add(textOff);
		}
		else if(img != null)
		{
			icon = new FlxSprite();
			if(animWidth > 0 || animHeight > 0) icon.loadGraphic(img, true, animWidth, animHeight);
			else icon.loadGraphic(img);
			centerOnBg(icon);
			add(icon);
		}

		this.onClick = onClick;
		setButtonVisibility(false);
	}

	public var focusChangeCallback:Bool->Void = null;
	public var onFocus(default, set):Bool = false;
	public var ignoreCheck:Bool = false;
	private var _needACheck:Bool = false;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(!enabled)
		{
			onFocus = false;
			return;
		}

		if(!ignoreCheck && !Controls.instance.controllerMode && (FlxG.mouse.justPressed || FlxG.mouse.justMoved) && FlxG.mouse.visible)
			onFocus = FlxG.mouse.overlaps(this);
		
		if(onFocus && onClick != null && FlxG.mouse.justPressed)
			onClick();

		if(_needACheck)
		{
			_needACheck = false;
			if(!Controls.instance.controllerMode)
				setButtonVisibility(FlxG.mouse.overlaps(this));
		}
	}

	function set_onFocus(newValue:Bool)
	{
		var lastFocus:Bool = onFocus;
		onFocus = newValue;
		if(onFocus != lastFocus && enabled) setButtonVisibility(onFocus);
		return newValue;
	}

	function set_enabled(newValue:Bool)
	{
		enabled = newValue;
		setButtonVisibility(false);
		alpha = enabled ? 1 : 0.4;

		_needACheck = enabled;
		return newValue;
	}

	public function setButtonVisibility(focusVal:Bool)
	{
		alpha = 1;
		bg.color = focusVal ? FlxColor.WHITE : FlxColor.BLACK;
		bg.alpha = focusVal ? 0.8 : 0.6;

		var focusAlpha = focusVal ? 1 : 0.6;
		if(textOn != null && textOff != null)
		{
			textOn.alpha = textOff.alpha = focusAlpha;
			textOn.visible = focusVal;
			textOff.visible = !focusVal;
		}
		else if(icon != null)
		{
			icon.alpha = focusAlpha;
			icon.color = focusVal ? FlxColor.BLACK : FlxColor.WHITE;
		}

		if(!enabled) alpha = 0.4;
		if(focusChangeCallback != null) focusChangeCallback(focusVal);
	}

	public function centerOnBg(spr:FlxSprite)
	{
		spr.x = bg.width/2 - spr.width/2;
		spr.y = bg.height/2 - spr.height/2;
	}
}
