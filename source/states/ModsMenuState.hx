package states;

import backend.WeekData;
import backend.Mods;

import flixel.FlxBasic;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.addons.transition.FlxTransitionableState;
import haxe.Json;

import options.ModSettingsSubState;

import openfl.display.BitmapData;

/**
 * Menú de mods de Psych con el diseño del Mod Menu de V-Slice:
 *  - Lista DISABLED (izquierda) y ENABLED (derecha). El orden de ENABLED es el orden de carga (arriba = más prioridad).
 *  - Mantén pulsado un mod (o arrástralo en PC) para moverlo entre listas o reordenarlo.
 *  - Botón de engranaje (abajo a la izquierda) = ajustes del mod seleccionado (data/settings.json -> ModSettingsSubState).
 *  - Formato 100% Psych: modsList.txt, pack.json, pack.png / pack-pixel.png, data/settings.json.
 *
 * Teclado / mando:
 *  - ARRIBA/ABAJO: mover selección      - IZQ/DER: cambiar de lista
 *  - ACCEPT: activar / desactivar        - SHIFT (o L1/R1) + ARRIBA/ABAJO: subir / bajar prioridad
 *  - E (o X en mando): ajustes del mod   - TAB (o Y en mando): DONE      - BACK: guardar y salir
 */
class ModsMenuState extends MusicBeatState
{
	// ===== Layout (bloque de 1280x720 centrado en pantallas anchas) =====
	public static inline var BOX_X_LEFT:Int = 198;
	public static inline var BOX_X_RIGHT:Int = 610;
	public static inline var BOX_Y:Int = 132;
	public static inline var BOX_W:Int = 378;
	public static inline var BOX_H:Int = 465;
	public static inline var LIST_TOP:Int = 52; // espacio del título de cada caja
	public static inline var LIST_BOTTOM:Int = 12;
	public static inline var ITEM_X:Int = 35;
	public static inline var ITEM_W:Int = 340;
	public static inline var ITEM_H:Int = 80;
	public static inline var ITEM_GAP:Int = 10;

	// ===== Tiempos =====
	static inline var HOLD_TIME:Float = 0.3; // segundos para empezar a arrastrar un mod con el dedo
	static inline var SHOCK_TIME:Float = 2.2; // duración de la electrocución al pulsar DONE (tocar para saltar)
	static inline var CRISPY_TIME:Float = 1.8; // tiempo que se ven chamuscados antes de salir

	// Posición de las chispas (ajusta si no cuadran con tu atlas)
	static inline var SPARKS_X:Float = 708;
	static inline var SPARKS_Y:Float = 120;

	// La música ambiente se queda sonando al recargar el menú; solo se restaura al salir
	static var ambienceOn:Bool = false;

	var ox:Float = 0;
	var modsList:ModsList = null;
	var startMod:String = null;

	// Decoración
	var bg:FlxSprite;
	var bgWires:FlxSprite;
	var battery:FlxSprite;
	var charBF:FlxSprite;
	var charGF:FlxSprite;
	var smokeBF:FlxSprite;
	var smokeGF:FlxSprite;
	var smokeCloud:FlxSprite;
	var sparks:ModsMenuSparks;
	var ambience:ModsMenuAmbience;

	// UI
	var enabledList:ModList;
	var disabledList:ModList;
	var itemsGroup:FlxTypedGroup<ModItem>;
	var dragLayer:FlxTypedGroup<ModItem>;
	var baseItem:ModItem;
	var buttons:Array<ModsMenuButton> = [];
	var gearButton:ModsMenuButton;
	var folderButton:ModsMenuButton;
	var doneButton:ModsMenuButton;
	var noModsTxt:FlxText;

	// Estado
	var selectedItem:ModItem = null;
	var waitingToRestart:Bool = false;
	var exiting:Bool = false;
	var sequenceStage:Int = 0; // 0 = nada, 1 = electrocución, 2 = chamuscados
	var shockTimer:FlxTimer = null;
	var folderSignatureAtStart:String = '';
	var rescanTimer:Float = 0;

	// Input de puntero (ratón / dedo)
	var grabbed:ModItem = null;
	var grabList:ModList = null;
	var grabIndex:Int = 0;
	var grabOffX:Float = 0;
	var grabOffY:Float = 0;
	var pressItem:ModItem = null;
	var pressList:ModList = null;
	var pressButton:ModsMenuButton = null;
	var pressX:Float = 0;
	var pressY:Float = 0;
	var pressTime:Float = 0;
	var scrolling:Bool = false;
	var _lastControllerMode:Bool = false;

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
		folderSignatureAtStart = folderSignature();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		if(!ambienceOn)
		{
			FlxG.sound.playMusic(Paths.music('modMenuAmbience'), 0);
			FlxG.sound.music.fadeIn(4, 0, 0.6);
			ambienceOn = true;
		}
		ambience = new ModsMenuAmbience();

		ox = mobile.WideScreen.offset;

		// ===== Fondo =====
		bg = new FlxSprite().loadGraphic(Paths.image('modsMenu/bg'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.setGraphicSize(0, FlxG.height);
		bg.updateHitbox();
		add(bg);
		bg.screenCenter();
		mobile.WideScreen.fit(bg);

		bgWires = new FlxSprite().loadGraphic(Paths.image('modsMenu/bgwires'));
		bgWires.antialiasing = ClientPrefs.data.antialiasing;
		bgWires.scale.set(0.7, 0.7);
		bgWires.updateHitbox();
		bgWires.alpha = 0.6;
		bgWires.setPosition(FlxG.width - bgWires.width, FlxG.height - bgWires.height);
		add(bgWires);

		// ===== Batería + BF y GF en la silla eléctrica (atlas prerenderizados) =====
		battery = new FlxSprite(965 + ox, 80);
		battery.frames = Paths.getSparrowAtlas('modsMenu/carbattery');
		battery.animation.addByPrefix('idle', 'idle', 12, true);
		battery.animation.play('idle');
		battery.animation.pause(); // solo parpadea durante la electrocución
		battery.antialiasing = ClientPrefs.data.antialiasing;
		battery.scale.set(0.75, 0.75);
		battery.updateHitbox();
		add(battery);

		charGF = makeChar('gf', 761 + ox, 127,
			[0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 6, 6, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0],
			[8, 9, 10, 11, 12, 13, 14, 15, 10, 16, 17, 18, 11, 18, 13, 10, 14, 8, 18, 19, 14, 8, 17, 13, 11, 8, 13, 11, 10, 15, 14, 16, 9],
			[20, 21, 22, 23, 24, 25, 26, 27]);
		add(charGF);

		charBF = makeChar('bf', 925 + ox, 224,
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 6, 6, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[8, 9, 10, 11, 12, 8, 13, 14, 12, 15, 11, 10, 13, 8, 13, 12, 11, 8, 9, 10, 11, 12, 8, 13, 14, 12, 15, 11, 10, 13, 8, 13, 12, 11, 8, 9, 10, 11, 12, 8, 13, 14, 12, 15, 11, 10, 13, 8, 13, 12, 11, 8, 9, 10, 11, 12, 8, 13, 14, 12],
			[16, 17, 18, 19, 20, 21, 22, 23]);
		add(charBF);

		// Humo de los chamuscados (aparece al terminar la electrocución)
		smokeBF = makeCrispySmoke(charBF.x + 70, charBF.y - 180, 13);
		smokeGF = makeCrispySmoke(charGF.x + 70, charGF.y - 180, 0);
		add(smokeBF);
		add(smokeGF);

		// Nube de humo grande
		smokeCloud = new FlxSprite(846 + ox, -170);
		smokeCloud.frames = Paths.getSparrowAtlas('modsMenu/smoke_cloud');
		smokeCloud.animation.addByPrefix('puff', 'f', 24, false);
		smokeCloud.animation.play('puff');
		smokeCloud.antialiasing = ClientPrefs.data.antialiasing;
		smokeCloud.visible = false;
		add(smokeCloud);

		sparks = new ModsMenuSparks(SPARKS_X + ox, SPARKS_Y);
		add(sparks);

		// ===== Título y textos =====
		var topText:FlxSprite = new FlxSprite().loadGraphic(Paths.image('modsMenu/top-text'));
		topText.antialiasing = ClientPrefs.data.antialiasing;
		topText.scale.set(0.66, 0.67);
		topText.updateHitbox();
		topText.x = ox + (1280 - topText.width) / 2;
		topText.y = 720 * 0.035;
		add(topText);

		var hintW:Float = (BOX_X_RIGHT + BOX_W) - BOX_X_LEFT;
		var hint:FlxText = new FlxText(ox + BOX_X_LEFT, 96, hintW, '', 26);
		#if mobile
		hint.text = Language.getPhrase('mods_hint_touch', 'TAP AND HOLD ON A MOD TO DRAG IT');
		#else
		hint.text = Language.getPhrase('mods_hint_mouse', 'CLICK AND DRAG A MOD TO MOVE IT');
		#end
		hint.setFormat(Paths.font("funkin.otf"), 26, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hint.borderSize = 2;
		add(hint);

		// ===== Cajas =====
		var boxL:FlxSprite = makeBox(ox + BOX_X_LEFT);
		var boxR:FlxSprite = makeBox(ox + BOX_X_RIGHT);
		add(boxL);
		add(boxR);
		addBoxTitle(boxL, Language.getPhrase('mods_disabled', 'DISABLED'));
		addBoxTitle(boxR, Language.getPhrase('mods_enabled', 'ENABLED'));

		var listH:Float = BOX_H - LIST_TOP - LIST_BOTTOM;
		disabledList = new ModList(ox + BOX_X_LEFT, BOX_Y + LIST_TOP, BOX_W, listH);
		enabledList = new ModList(ox + BOX_X_RIGHT, BOX_Y + LIST_TOP, BOX_W, listH);
		add(disabledList.track);
		add(disabledList.thumb);
		add(enabledList.track);
		add(enabledList.thumb);

		// ===== Items =====
		itemsGroup = new FlxTypedGroup<ModItem>();
		dragLayer = new FlxTypedGroup<ModItem>();

		for (mod in modsList.all)
		{
			var item:ModItem = new ModItem(mod);
			itemsGroup.add(item);
			if(modsList.disabled.contains(mod)) disabledList.items.push(item);
			else enabledList.items.push(item);

			if(startMod == mod) selectedItem = item;
		}

		// El juego base va fijo al final de ENABLED (prioridad más baja)
		baseItem = new ModItem('__base_game__', true);
		itemsGroup.add(baseItem);
		enabledList.items.push(baseItem);

		if(modsList.all.length < 1)
		{
			noModsTxt = new FlxText(disabledList.x + 20, disabledList.y + 20, BOX_W - 40,
				Language.getPhrase('no_mods_installed', 'NO MODS INSTALLED\nPRESS BACK TO EXIT OR INSTALL A MOD'), 20);
			noModsTxt.setFormat(Paths.font("funkin.otf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			noModsTxt.borderSize = 2;
			add(noModsTxt);
			FlxG.autoPause = false;
		}

		add(itemsGroup);

		// ===== Botones =====
		folderButton = new ModsMenuButton(ox + 368, 617, 'open-folder', 0.65, openModsFolder);
		doneButton = new ModsMenuButton(ox + 970, 617, 'done', 0.65, startDoneSequence);

		// Engranaje de ajustes (abajo a la izquierda, como en el Mod Menu de V-Slice)
		// En pantallas anchas (sobra margen a la izquierda) va grande; en 16:9 se hace más chico para no tapar la caja.
		var gearScale:Float = (ox >= 120) ? 0.72 : 0.52;
		var gearSize:Float = 200 * gearScale;
		gearButton = new ModsMenuButton((ox >= 120) ? 20 : 15, 720 - (268 * gearScale) - 37, 'settings', gearScale, openSettings);

		for (b in [folderButton, doneButton, gearButton])
		{
			add(b);
			buttons.push(b);
		}

		add(dragLayer);

		for (list in [disabledList, enabledList]) list.snapAll();

		if(selectedItem == null)
		{
			if(disabledList.items.length > 0) selectedItem = disabledList.items[0];
			else selectedItem = enabledList.items[0];
		}
		selectItem(selectedItem, true);

		_lastControllerMode = controls.controllerMode;

		#if mobile
		add(mobile.MobileButton.back(null, true));
		#end
		super.create();
	}

	// ===================================================================
	// Construcción de piezas
	// ===================================================================

	function makeBox(x:Float):FlxSprite
	{
		var box:FlxSprite = new FlxSprite(x, BOX_Y).loadGraphic(Paths.image('modsMenu/box'));
		box.antialiasing = ClientPrefs.data.antialiasing;
		box.setGraphicSize(BOX_W, BOX_H);
		box.updateHitbox();
		box.setPosition(x, BOX_Y);
		return box;
	}

	function addBoxTitle(box:FlxSprite, text:String):Void
	{
		var title:FlxText = new FlxText(box.x, box.y + 9, box.width, text, 25);
		title.setFormat(Paths.font("funkin.otf"), 25, FlxColor.WHITE, CENTER);
		title.borderStyle = FlxTextBorderStyle.OUTLINE;
		title.borderColor = FlxColor.BLACK;
		title.borderSize = 1.5;
		add(title);
	}

	function makeChar(name:String, x:Float, y:Float, idle:Array<Int>, shock:Array<Int>, crispy:Array<Int>):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite(x, y);
		spr.frames = Paths.getSparrowAtlas('modsMenu/char_' + name);
		spr.animation.add('idle', idle, 24, true);
		spr.animation.add('shock', shock, 24, true);
		spr.animation.add('crispy', crispy, 24, false);
		spr.animation.play('idle');
		spr.antialiasing = ClientPrefs.data.antialiasing;
		return spr;
	}

	function makeCrispySmoke(x:Float, y:Float, startFrame:Int):FlxSprite
	{
		var s:FlxSprite = new FlxSprite(x, y);
		s.frames = Paths.getSparrowAtlas('modsMenu/smoke');
		s.animation.addByPrefix('idle', 'retry_smoke', 24, true);
		s.animation.play('idle', false, false, startFrame);
		s.scale.set(0.5, 0.5);
		s.updateHitbox();
		s.alpha = 0.67;
		s.antialiasing = ClientPrefs.data.antialiasing;
		s.visible = false;
		return s;
	}

	// ===================================================================
	// Update
	// ===================================================================

	#if mobile
	override function destroy()
	{
		mobile.TouchInput.blockGestures = false;
		super.destroy();
	}
	#end

	override function update(elapsed:Float)
	{
		#if mobile
		mobile.TouchInput.blockGestures = true;
		#end

		if(exiting)
		{
			// Durante la secuencia de DONE, tocar / ACCEPT salta la electrocución
			if(sequenceStage == 1 && (FlxG.mouse.justPressed || controls.ACCEPT)) endShock();
			super.update(elapsed);
			return;
		}

		if(controls.BACK && grabbed == null)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			leaveMenu();
			return;
		}

		#if !mobile
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
		#end

		handlePointer(elapsed);
		handleKeys();

		disabledList.update(elapsed, grabbed);
		enabledList.update(elapsed, grabbed);

		ambience.update(elapsed);

		// Revisa la carpeta de mods (por si añadiste uno mientras estabas en "Open Mod Folder")
		rescanTimer += elapsed;
		if(rescanTimer >= 1.5)
		{
			rescanTimer = 0;
			if(grabbed == null && folderSignature() != folderSignatureAtStart) reload();
		}

		super.update(elapsed);
	}

	// ===================================================================
	// Input: ratón / dedo
	// ===================================================================

	function handlePointer(elapsed:Float):Void
	{
		var mx:Float = FlxG.mouse.x;
		var my:Float = FlxG.mouse.y;

		#if !mobile
		// Resaltado de botones al pasar el ratón
		for (b in buttons) b.setHover(!controls.controllerMode && b.enabled && FlxG.mouse.overlaps(b));
		#end

		if(FlxG.mouse.wheel != 0 && grabbed == null)
		{
			var wl:ModList = boxListAt(mx, my);
			if(wl != null) wl.scrollBy(-FlxG.mouse.wheel * (ITEM_H + ITEM_GAP) * 0.8, false);
		}

		if(FlxG.mouse.justPressed)
		{
			pressButton = buttonUnder();
			pressList = boxListAt(mx, my);
			pressItem = null;
			if(pressList != null && pressList.inView(mx, my))
			{
				var i:Int = pressList.indexAtY(my);
				if(i >= 0) pressItem = pressList.items[i];
			}
			pressX = mx;
			pressY = my;
			pressTime = 0;
			scrolling = false;

			if(pressItem != null)
			{
				selectItem(pressItem);
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
			}
		}

		if(FlxG.mouse.pressed)
		{
			pressTime += elapsed;

			if(grabbed != null) updateGrab(mx, my, elapsed);
			else if(pressList != null && pressButton == null)
			{
				var dx:Float = mx - pressX;
				var dy:Float = my - pressY;

				if(!scrolling && Math.abs(dy) > 12 && Math.abs(dy) > Math.abs(dx)) scrolling = true;
				else if(!scrolling && pressItem != null && !pressItem.isBase && (pressTime >= HOLD_TIME || Math.abs(dx) > 12))
					beginGrab(pressItem, pressList, mx, my);

				if(scrolling) pressList.scrollBy(-FlxG.mouse.deltaY, true);
			}
		}

		if(FlxG.mouse.justReleased)
		{
			if(grabbed != null) dropGrabbed(mx, my);
			else if(pressButton != null && pressButton == buttonUnder()) pressButton.press();

			pressItem = null;
			pressList = null;
			pressButton = null;
			scrolling = false;
		}
	}

	function buttonUnder():ModsMenuButton
	{
		for (b in buttons)
			if(b.enabled && b.visible && FlxG.mouse.overlaps(b)) return b;
		return null;
	}

	/** Lista cuya CAJA contiene el punto (incluye el título). */
	function boxListAt(px:Float, py:Float):ModList
	{
		for (list in [disabledList, enabledList])
			if(list.inBox(px, py)) return list;
		return null;
	}

	function beginGrab(item:ModItem, list:ModList, mx:Float, my:Float):Void
	{
		grabbed = item;
		grabList = list;
		grabIndex = list.items.indexOf(item);
		list.items.remove(item);

		itemsGroup.remove(item, true);
		dragLayer.add(item);
		item.clearClip();
		item.held = true;

		grabOffX = mx - item.x;
		grabOffY = my - item.y;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	function updateGrab(mx:Float, my:Float, elapsed:Float):Void
	{
		var t:Float = Math.min(1, 25 * elapsed);
		grabbed.x += ((mx - grabOffX) - grabbed.x) * t;
		grabbed.y += ((my - grabOffY) - grabbed.y) * t;

		var hover:ModList = boxListAt(mx, my);
		disabledList.gap = enabledList.gap = -1;
		if(hover == null)
			grabList.gap = grabIndex; // soltar fuera = vuelve a su sitio
		else
		{
			hover.gap = hover.insertIndexAtY(my, maxInsertIndex(hover));

			// Auto-scroll al arrastrar cerca de los bordes de la lista
			if(my < hover.y + 30) hover.scrollBy(-600 * elapsed, false);
			else if(my > hover.y + hover.h - 30) hover.scrollBy(600 * elapsed, false);
		}
	}

	function dropGrabbed(mx:Float, my:Float):Void
	{
		var item:ModItem = grabbed;
		var target:ModList = boxListAt(mx, my);
		var idx:Int;
		if(target == null)
		{
			target = grabList;
			idx = grabIndex;
		}
		else idx = target.insertIndexAtY(my, maxInsertIndex(target));

		dragLayer.remove(item, true);
		itemsGroup.add(item);
		item.held = false;
		target.items.insert(idx, item);
		enabledList.gap = disabledList.gap = -1;

		var changedList:Bool = (target != grabList);
		if(changedList || idx != grabIndex)
		{
			if(changedList)
			{
				if(item.mustRestart) waitingToRestart = true;
				sparks.playRandom();
			}
			else checkRestartOnMove(target, grabIndex, idx);
			syncModsList();
		}

		grabbed = null;
		grabList = null;
		selectItem(item);
	}

	function maxInsertIndex(list:ModList):Int
	{
		// El juego base siempre queda al final de ENABLED
		return (list == enabledList) ? list.items.length - 1 : list.items.length;
	}

	function checkRestartOnMove(list:ModList, from:Int, to:Int):Void
	{
		var a:Int = Std.int(Math.min(from, to));
		var b:Int = Std.int(Math.max(from, to));
		for (i in a...b + 1)
		{
			var it:ModItem = list.items[i];
			if(it != null && it.mustRestart) waitingToRestart = true;
		}
	}

	// ===================================================================
	// Input: teclado / mando
	// ===================================================================

	function handleKeys():Void
	{
		if(grabbed != null) return;

		var up:Bool = controls.UI_UP_P;
		var down:Bool = controls.UI_DOWN_P;
		var left:Bool = controls.UI_LEFT_P;
		var right:Bool = controls.UI_RIGHT_P;

		if(FlxG.keys.justPressed.TAB || FlxG.gamepads.anyJustPressed(Y))
		{
			startDoneSequence();
			return;
		}
		if(FlxG.keys.justPressed.E || FlxG.gamepads.anyJustPressed(X))
		{
			openSettings();
			return;
		}

		if(selectedItem == null)
		{
			if(up || down || left || right) selectItem(disabledList.items.length > 0 ? disabledList.items[0] : enabledList.items[0]);
			return;
		}

		var list:ModList = listOf(selectedItem);
		var idx:Int = list.items.indexOf(selectedItem);
		var shift:Bool = FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER) || FlxG.gamepads.anyPressed(RIGHT_SHOULDER);

		if(up || down)
		{
			var dir:Int = up ? -1 : 1;
			if(shift && list == enabledList && !selectedItem.isBase)
			{
				// Subir / bajar prioridad
				var newIdx:Int = Std.int(Math.max(0, Math.min(maxInsertIndex(list) - 1, idx + dir)));
				if(newIdx != idx)
				{
					list.items.remove(selectedItem);
					list.items.insert(newIdx, selectedItem);
					checkRestartOnMove(list, idx, newIdx);
					syncModsList();
					list.ensureVisible(newIdx);
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
				}
			}
			else
			{
				var n:Int = idx + dir;
				if(n >= 0 && n < list.items.length)
				{
					selectItem(list.items[n]);
					list.ensureVisible(n);
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
				}
			}
		}
		else if(left || right)
		{
			var other:ModList = left ? disabledList : enabledList;
			if(other != list && other.items.length > 0)
			{
				var n:Int = Std.int(Math.min(idx, other.items.length - 1));
				selectItem(other.items[n]);
				other.ensureVisible(n);
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			}
		}
		else if(controls.ACCEPT && !selectedItem.isBase)
		{
			toggleItem(selectedItem);
		}
	}

	function toggleItem(item:ModItem):Void
	{
		if(item.isBase) return;

		var from:ModList = listOf(item);
		var to:ModList = (from == enabledList) ? disabledList : enabledList;
		from.items.remove(item);
		to.items.insert(0, item); // al principio: se anima volando hasta la otra lista
		to.target = 0;

		if(item.mustRestart) waitingToRestart = true;
		syncModsList();
		selectItem(item);
		sparks.playRandom();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	// ===================================================================
	// Selección / ajustes
	// ===================================================================

	function listOf(item:ModItem):ModList
	{
		return enabledList.items.contains(item) ? enabledList : disabledList;
	}

	function selectItem(item:ModItem, scrollTo:Bool = false):Void
	{
		if(selectedItem != null) selectedItem.selected = false;
		selectedItem = item;
		if(item != null)
		{
			item.selected = true;
			if(scrollTo)
			{
				var l:ModList = listOf(item);
				l.ensureVisible(l.items.indexOf(item));
				l.scroll = l.target;
			}
		}
		gearButton.enabled = hasSettings(item);
	}

	function hasSettings(item:ModItem):Bool
	{
		return item != null && !item.isBase && item.settings != null && item.settings.length > 0;
	}

	function openSettings():Void
	{
		if(!hasSettings(selectedItem)) return;
		persistentUpdate = false;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		openSubState(new ModSettingsSubState(selectedItem.settings, selectedItem.folder, selectedItem.name));
	}

	function openModsFolder():Void
	{
		try
		{
			var gameRoot:String = mobile.StorageUtil.getGameDir();
			#if android
			// Shadow Crystal uses its own external folder instead of PsychEngine's legacy folder.
			if(mobile.StorageUtil.useExternal()) gameRoot = '/storage/emulated/0/.ShadowCrystal/';
			#end
			var modFolder:String = haxe.io.Path.addTrailingSlash(gameRoot) + 'mods';
			if(!FileSystem.exists(modFolder))
			{
				trace('created missing folder');
				FileSystem.createDirectory(modFolder);
			}
			CoolUtil.openFolder(modFolder);
		}
		catch(e:Dynamic)
		{
			trace('Could not open the mods folder: $e');
		}
	}

	// ===================================================================
	// DONE: secuencia de electrocución y salida
	// ===================================================================

	function startDoneSequence():Void
	{
		if(exiting) return;
		exiting = true;
		sequenceStage = 1;
		saveTxt(); // guardamos ya, por si se cierra el juego durante la secuencia

		FlxG.sound.play(Paths.sound('modsMenu/sparks/electrocution'), 0.8);
		charBF.animation.play('shock', true);
		charGF.animation.play('shock', true);
		battery.animation.resume();
		sparks.startElectrocution();

		shockTimer = new FlxTimer().start(SHOCK_TIME, function(_) endShock());
	}

	function endShock():Void
	{
		if(sequenceStage != 1) return;
		sequenceStage = 2;
		if(shockTimer != null) shockTimer.cancel();

		FlxG.camera.flash(FlxColor.WHITE, 0.4);
		sparks.endElectrocution();
		battery.animation.pause();

		charBF.animation.play('crispy', true);
		charGF.animation.play('crispy', true);

		smokeCloud.visible = true;
		smokeCloud.alpha = 1;
		smokeCloud.animation.play('puff', true);
		FlxTween.tween(smokeCloud, {alpha: 0}, 2.6, {ease: FlxEase.linear});
		FlxG.sound.play(Paths.sound('modsMenu/smoke-cloud'), 0.8);

		smokeBF.visible = smokeGF.visible = true;
		new FlxTimer().start(0.7, function(_) FlxG.sound.play(Paths.sound('modsMenu/crispy'), 0.8));
		new FlxTimer().start(CRISPY_TIME, function(_) leaveMenu());
	}

	function leaveMenu():Void
	{
		exiting = true;
		saveTxt();

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
	}

	function restoreMenuMusic():Void
	{
		ambienceOn = false;
		FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
		FlxG.sound.music.fadeIn(0.6, 0, 0.7);
	}

	// ===================================================================
	// modsList.txt
	// ===================================================================

	/** Copia el estado de las dos listas a modsList (enabled en orden de prioridad + disabled). */
	function syncModsList():Void
	{
		var en:Array<String> = [];
		var dis:Array<String> = [];
		for (it in enabledList.items) if(!it.isBase) en.push(it.folder);
		for (it in disabledList.items) dis.push(it.folder);
		modsList.enabled = en;
		modsList.disabled = dis;
		modsList.all = en.concat(dis);
	}

	function reload():Void
	{
		saveTxt();
		FlxG.autoPause = ClientPrefs.data.autoPause;
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.switchState(new ModsMenuState(selectedItem != null && !selectedItem.isBase ? selectedItem.folder : null));
	}

	function saveTxt():Void
	{
		syncModsList();

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

	function folderSignature():String
	{
		var sig:String = '';
		#if sys
		try
		{
			var dir:String = Paths.mods();
			if(FileSystem.exists(dir))
			{
				var names:Array<String> = FileSystem.readDirectory(dir);
				names.sort(function(a:String, b:String):Int return (a < b) ? -1 : ((a > b) ? 1 : 0));
				for (n in names)
					if(FileSystem.isDirectory(haxe.io.Path.join([dir, n]))) sig += n + '|';
			}
		}
		catch(e:Dynamic) {}
		#end
		return sig;
	}
}

// =======================================================================
// Lista con scroll (una por cada caja)
// =======================================================================
class ModList
{
	public var items:Array<ModItem> = [];
	public var x:Float;
	public var y:Float; // parte alta del área visible de items
	public var w:Float;
	public var h:Float;
	public var scroll:Float = 0;
	public var target:Float = 0;
	public var gap:Int = -1; // hueco de previsualización al arrastrar
	public var track:FlxSprite;
	public var thumb:FlxSprite;

	public function new(x:Float, y:Float, w:Float, h:Float)
	{
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;

		track = new FlxSprite(x + 15, y).makeGraphic(8, Std.int(h), 0xFF3A393E);
		track.alpha = 0.6;
		track.visible = false;

		thumb = new FlxSprite(x + 15, y).makeGraphic(8, 1, 0xFF57565A);
		thumb.alpha = 0.95;
		thumb.origin.set(0, 0);
		thumb.visible = false;
	}

	public inline function rowH():Float return ModsMenuState.ITEM_H + ModsMenuState.ITEM_GAP;

	public function contentHeight():Float
		return items.length > 0 ? items.length * rowH() - ModsMenuState.ITEM_GAP : 0;

	public function maxScroll():Float return Math.max(0, contentHeight() - h);

	public function clampTarget():Void
		target = Math.max(0, Math.min(maxScroll(), target));

	public function slotY(i:Int):Float
	{
		var slot:Int = (gap >= 0 && i >= gap) ? i + 1 : i;
		return y + slot * rowH() - scroll;
	}

	/** El punto está dentro de la caja completa (con título). */
	public function inBox(px:Float, py:Float):Bool
		return px >= x && px <= x + w && py >= y - ModsMenuState.LIST_TOP && py <= y + h + ModsMenuState.LIST_BOTTOM;

	/** El punto está dentro del área visible de items. */
	public function inView(px:Float, py:Float):Bool
		return px >= x && px <= x + w && py >= y && py <= y + h;

	public function indexAtY(py:Float):Int
	{
		var pos:Float = py - y + scroll;
		var i:Int = Math.floor(pos / rowH());
		if(i < 0 || i >= items.length) return -1;
		if(pos - i * rowH() > ModsMenuState.ITEM_H) return -1; // en el espacio entre items
		return i;
	}

	/** Posición donde se insertaría un item soltado a esa altura. */
	public function insertIndexAtY(py:Float, maxIndex:Int):Int
	{
		var i:Int = Math.floor((py - y + scroll) / rowH());
		return Std.int(Math.max(0, Math.min(maxIndex, i)));
	}

	public function ensureVisible(i:Int):Void
	{
		var top:Float = i * rowH();
		var bottom:Float = top + ModsMenuState.ITEM_H;
		if(top < target) target = top;
		else if(bottom > target + h) target = bottom - h;
		clampTarget();
	}

	public function scrollBy(delta:Float, instant:Bool):Void
	{
		target += delta;
		clampTarget();
		if(instant) scroll = target;
	}

	public function snapAll():Void
	{
		clampTarget();
		scroll = target;
		for (i in 0...items.length)
		{
			var it:ModItem = items[i];
			it.setPosition(x + ModsMenuState.ITEM_X, slotY(i));
			it.clipTo(y, y + h);
		}
		updateScrollbar();
	}

	public function update(elapsed:Float, grabbed:ModItem):Void
	{
		clampTarget();
		if(scroll != target)
		{
			scroll += (target - scroll) * Math.min(1, 16 * elapsed);
			if(Math.abs(target - scroll) < 0.2) scroll = target;
		}

		var t:Float = Math.min(1, 18 * elapsed);
		for (i in 0...items.length)
		{
			var it:ModItem = items[i];
			if(it == grabbed) continue;

			var tx:Float = x + ModsMenuState.ITEM_X;
			var ty:Float = slotY(i);
			it.x += (tx - it.x) * t;
			it.y += (ty - it.y) * t;
			if(Math.abs(tx - it.x) < 0.3) it.x = tx;
			if(Math.abs(ty - it.y) < 0.3) it.y = ty;

			it.clipTo(y, y + h);
		}
		updateScrollbar();
	}

	function updateScrollbar():Void
	{
		var need:Bool = contentHeight() > h;
		track.visible = thumb.visible = need;
		if(!need) return;

		var th:Float = Math.max(24, h * (h / contentHeight()));
		var frac:Float = maxScroll() > 0 ? scroll / maxScroll() : 0;
		thumb.scale.y = th;
		thumb.y = y + Math.max(0, Math.min(1, frac)) * (h - th);
	}
}

// =======================================================================
// Mod (fila de la lista). Lee el formato de mods de Psych.
// =======================================================================
class ModItem extends FlxSpriteGroup
{
	public var selectBg:FlxSprite;
	public var icon:FlxSprite;
	public var title:FlxText;
	public var descText:FlxText;
	public var totalFrames:Int = 0;

	// options (pack.json)
	public var name:String = 'Unknown Mod';
	public var desc:String = 'No description provided.';
	public var iconFps:Int = 10;
	public var pack:Dynamic = null;
	public var folder:String = 'unknownMod';
	public var mustRestart:Bool = false;
	public var settings:Array<Dynamic> = null;
	public var isBase:Bool = false;

	public var selected(default, set):Bool = false;
	public var held(default, set):Bool = false;

	public function new(folder:String, isBase:Bool = false)
	{
		super();

		this.folder = folder;
		this.isBase = isBase;

		selectBg = new FlxSprite().makeGraphic(ModsMenuState.ITEM_W, ModsMenuState.ITEM_H, FlxColor.WHITE);
		selectBg.alpha = 0;
		add(selectBg);

		icon = new FlxSprite(0, 0);
		icon.antialiasing = ClientPrefs.data.antialiasing;
		add(icon);

		var textX:Float = ModsMenuState.ITEM_H + 8;
		var textW:Float = ModsMenuState.ITEM_W - textX - 6;

		title = new FlxText(textX, 12, textW, "", 24);
		title.setFormat(Paths.font("funkin.otf"), 24, FlxColor.WHITE, LEFT);
		title.wordWrap = false;
		add(title);

		descText = new FlxText(textX, 50, textW, "", 15);
		descText.setFormat(Paths.font("funkin.otf"), 15, FlxColor.WHITE, LEFT);
		descText.fieldHeight = 42;
		descText.alpha = 0.7;
		add(descText);

		if(isBase)
		{
			this.name = Language.getPhrase('base_game', 'BASE GAME');
			this.desc = Language.getPhrase('base_game_desc', 'DEFAULT GAME CONTENT');
			icon.loadGraphic(Paths.image('modsMenu/base-icon'));
		}
		else
		{
			pack = Mods.getPack(folder);

			var path:String = Paths.mods('$folder/data/settings.json');
			if(FileSystem.exists(path))
			{
				try
				{
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

			var isPixel = false;
			var file:String = Paths.mods('$folder/pack.png');
			if(!FileSystem.exists(file))
			{
				file = Paths.mods('$folder/pack-pixel.png');
				isPixel = true;
			}

			var bmp:BitmapData = null;
			if(FileSystem.exists(file)) bmp = BitmapData.fromFile(file);
			else isPixel = false;

			if(bmp != null)
			{
				icon.loadGraphic(Paths.cacheBitmap(file, bmp), true, 150, 150);
				if(isPixel) icon.antialiasing = false;
			}
			else icon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);

			this.name = folder;
			if(pack != null)
			{
				if(pack.name != null) this.name = pack.name;
				if(pack.description != null) this.desc = pack.description;
				if(pack.iconFramerate != null) this.iconFps = pack.iconFramerate;
				this.mustRestart = (pack.restart == true);
			}

			if(bmp != null)
			{
				totalFrames = Math.floor(bmp.width / 150) * Math.floor(bmp.height / 150);
				if(totalFrames > 1)
				{
					icon.animation.add("icon", [for (i in 0...totalFrames) i], iconFps);
					icon.animation.play("icon");
				}
			}
		}

		icon.setGraphicSize(ModsMenuState.ITEM_H, ModsMenuState.ITEM_H);
		icon.updateHitbox();
		icon.setPosition(0, 0);

		title.text = this.name;
		var d:String = StringTools.replace(this.desc, '\n', ' ');
		if(d.length > 62) d = d.substr(0, 59) + '...';
		descText.text = d;
	}

	function set_selected(v:Bool):Bool
	{
		selected = v;
		refreshBg();
		return v;
	}

	function set_held(v:Bool):Bool
	{
		held = v;
		refreshBg();
		return v;
	}

	function refreshBg():Void
		selectBg.alpha = held ? 0.45 : (selected ? 0.25 : 0);

	/** Quita el recorte (al arrastrar el item por encima de todo). */
	public function clearClip():Void
	{
		for (m in members)
		{
			m.clipRect = null;
			m.visible = true;
		}
	}

	/** Recorta el item verticalmente al área visible de la lista. */
	public function clipTo(viewTop:Float, viewBottom:Float):Void
	{
		for (m in members)
		{
			var top:Float = m.y;
			var h:Float = m.height;
			var cutTop:Float = Math.max(0, viewTop - top);
			var cutBot:Float = Math.max(0, (top + h) - viewBottom);

			if(cutTop + cutBot >= h)
			{
				m.visible = false;
				continue;
			}
			m.visible = true;

			if(cutTop <= 0 && cutBot <= 0)
			{
				if(m.clipRect != null) m.clipRect = null;
				continue;
			}

			var sy:Float = (m.scale.y == 0) ? 1 : m.scale.y;
			m.clipRect = new FlxRect(0, cutTop / sy, m.frameWidth, (h - cutTop - cutBot) / sy);
		}
	}
}

// =======================================================================
// Botón con imagen (normal / -highlighted / -inverted) con rebote
// =======================================================================
class ModsMenuButton extends FlxSprite
{
	public var baseName:String;
	public var baseScale:Float;
	public var onClick:Void->Void = null;
	public var enabled(default, set):Bool = true;

	var cx:Float;
	var cy:Float;
	var hovered:Bool = false;
	var flashing:Bool = false;
	var scaleTween:FlxTween = null;

	public function new(x:Float, y:Float, name:String, scl:Float, onClick:Void->Void = null)
	{
		super(x, y);
		baseName = name;
		baseScale = scl;
		this.onClick = onClick;
		antialiasing = ClientPrefs.data.antialiasing;

		setSkin('');
		cx = x + (frameWidth * scl) / 2;
		cy = y + (frameHeight * scl) / 2;
		applyScale(scl);
	}

	function setSkin(suffix:String):Void
	{
		if(baseName == 'settings')
		{
			// optionsButton.xml uses options0000 ... options0016.
			// Idle always stays on frame 0000; pressing plays the full atlas animation.
			frames = Paths.getSparrowAtlas('optionsButton');
			animation.add('idle', [0], 1, false);
			animation.add('pressed', [for (i in 0...17) i], 24, false);
			animation.play('idle', true);
			animation.pause();
			if(animation.curAnim != null) animation.curAnim.curFrame = 0;
		}
		else
		{
			loadGraphic(Paths.image('modsMenu/' + baseName + suffix));
		}
		var s:Float = scale.x;
		scale.set(s, s);
		updateHitbox();
		if(cx != 0 || cy != 0) setPosition(cx - width / 2, cy - height / 2);
		refreshEnabledTint();
	}

	function applyScale(s:Float):Void
	{
		scale.set(s, s);
		updateHitbox();
		setPosition(cx - width / 2, cy - height / 2);
	}

	function tweenScaleTo(target:Float, time:Float):Void
	{
		if(scaleTween != null) scaleTween.cancel();
		scaleTween = FlxTween.num(scale.x, target, time, {ease: FlxEase.quadOut}, function(v:Float) applyScale(v));
	}

	function refreshEnabledTint():Void
	{
		// Tinting is done in code: a mod without settings gets a dark gear.
		if(baseName == 'settings') color = enabled ? FlxColor.WHITE : FlxColor.fromRGB(95, 95, 105);
		else alpha = enabled ? 1 : 0.4;
	}

	public function setHover(value:Bool):Void
	{
		if(baseName == 'settings') return; // no hover frame: keep options0000 until pressed
		if(value == hovered || !enabled) return;
		hovered = value;
		if(!flashing)
		{
			setSkin(hovered ? '-highlighted' : '');
			tweenScaleTo(baseScale * (hovered ? 1.1 : 1), 0.1);
		}
	}

	public function press():Void
	{
		if(!enabled) return;

		if(baseName == 'settings')
		{
			flashing = true;
			animation.play('pressed', true);
			animation.finishCallback = function(name:String)
			{
				animation.play('idle', true);
				animation.pause();
				if(animation.curAnim != null) animation.curAnim.curFrame = 0;
				flashing = false;
			};
			applyScale(baseScale * 0.92);
			tweenScaleTo(baseScale, 0.15);
			if(onClick != null) onClick();
			return;
		}

		flashing = true;
		setSkin('-inverted');
		applyScale(baseScale * 0.92);
		tweenScaleTo(baseScale * (hovered ? 1.1 : 1), 0.15);
		new FlxTimer().start(0.12, function(_)
		{
			flashing = false;
			setSkin(hovered ? '-highlighted' : '');
		});

		if(onClick != null) onClick();
	}

	function set_enabled(v:Bool):Bool
	{
		enabled = v;
		refreshEnabledTint();
		if(!v && hovered)
		{
			hovered = false;
			if(baseName != 'settings') setSkin('');
			applyScale(baseScale);
		}
		return v;
	}
}

// =======================================================================
// Chispas (aleatorias y de la electrocución)
// =======================================================================
class ModsMenuSparks extends FlxSprite
{
	// Rangos de frames [inicio, fin] en sparks.xml: spark 1..11, electrocution, end.
	// Son APROXIMADOS (el atlas Sparrow tiene 290 frames únicos y la timeline original 439).
	// Si alguna animación se ve cortada, ajusta estos números.
	static var RANGES:Array<Array<Int>> = [
		[0, 11], [12, 41], [42, 58], [59, 71], [72, 83], [84, 113], [114, 130], [131, 158], [159, 178], [179, 206], [207, 226],
		[227, 276], // electrocution
		[277, 289] // end
	];

	var nextRandom:Float;
	var previous:Int = -1;
	var busy:Bool = false;
	var shocking:Bool = false;

	public function new(x:Float, y:Float)
	{
		super(x, y);
		frames = Paths.getSparrowAtlas('modsMenu/sparks');
		antialiasing = ClientPrefs.data.antialiasing;

		for (i in 0...11) animation.add('s' + (i + 1), range(RANGES[i]), 24, false);
		animation.add('electrocution', range(RANGES[11]), 24, true);
		animation.add('end', range(RANGES[12]), 24, false);
		animation.finishCallback = function(name:String)
		{
			busy = false;
			if(!shocking) visible = false;
		};

		visible = false;
		nextRandom = FlxG.random.float(6, 20);
	}

	static function range(r:Array<Int>):Array<Int>
		return [for (i in r[0]...r[1] + 1) i];

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(!busy && !shocking)
		{
			nextRandom -= elapsed;
			if(nextRandom <= 0) playRandom();
		}
	}

	public function playRandom():Void
	{
		if(shocking) return;

		var n:Int = FlxG.random.int(1, 11);
		if(n == previous) n = (n % 11) + 1;
		previous = n;

		busy = true;
		visible = true;
		animation.play('s' + n, true);
		FlxG.sound.play(Paths.sound('modsMenu/sparks/spark-' + n), 0.7);
		nextRandom = FlxG.random.float(6, 20);
	}

	public function startElectrocution():Void
	{
		shocking = true;
		busy = true;
		visible = true;
		animation.play('electrocution', true);
	}

	public function endElectrocution():Void
	{
		shocking = false;
		animation.play('end', true);
	}
}

// =======================================================================
// Ambiente: sonidos aleatorios con peso (el número del nombre) + easter egg a los 3 min
// =======================================================================
class ModsMenuAmbience
{
	static inline var EASTER_EGG_TIME:Float = 180;

	// Archivos en assets/shared/sounds/modsMenu/ambience/<nombre>.ogg
	// El número delante es el peso (probabilidad). Peso <= 1 = easter egg que solo suena una vez.
	var pool:Array<String> = [
		'1_horse', '3_moo', '60_knocking', '60_scream',
		'200_roar1', '200_roar2', '200_roar3', '200_sob1', '200_sob2', '200_sob3',
		'400_creaking', '400_creaking2', '400_dragging', '400_moaning', '400_moaning2',
		'400_pulley1', '400_pulley2', '400_pulley3', '400_slam',
		'600_beep1', '600_beep2', '600_beep3', '600_beep4', '600_beep5', '600_beep6', '600_beep7', '600_beep8',
		'600_chains1', '600_chains2', '600_chains3'
	];

	var wait:Float = 7;
	var total:Float = 0;
	var eggPlayed:Bool = false;

	public function new() {}

	static function weightOf(name:String):Float
	{
		var w:Float = Std.parseFloat(name.split('_')[0]);
		return Math.isNaN(w) ? 1 : w;
	}

	public function update(elapsed:Float):Void
	{
		total += elapsed;
		if(!eggPlayed && total >= EASTER_EGG_TIME)
		{
			eggPlayed = true;
			FlxG.sound.play(Paths.sound('modsMenu/ambience/phantomarcade-trapped'), 0.8);
		}

		wait -= elapsed;
		if(wait <= 0)
		{
			wait = FlxG.random.float(6, 10);
			playRandom();
		}
	}

	function playRandom():Void
	{
		if(pool.length < 1) return;

		var sum:Float = 0;
		for (n in pool) sum += weightOf(n);

		var roll:Float = FlxG.random.float(0, sum);
		var chosen:String = pool[pool.length - 1];
		for (n in pool)
		{
			roll -= weightOf(n);
			if(roll <= 0)
			{
				chosen = n;
				break;
			}
		}

		FlxG.sound.play(Paths.sound('modsMenu/ambience/' + chosen), 0.7);

		// Los easter eggs solo pueden sonar una vez
		if(weightOf(chosen) <= 1) pool.remove(chosen);
	}
}
