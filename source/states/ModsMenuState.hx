package states;

import backend.WeekData;
import backend.Mods;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flxanimate.PsychFlxAnimate as FlxAnimate; // spritemaps de Adobe Animate (la versión de Psych, la que espera Paths.loadAnimateAtlas)
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
import openfl.utils.Assets;
import flixel.sound.FlxSound;

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
	/** Reproduce sonidos opcionales sin bloquear el menú si el archivo no está empaquetado. */
	public static function playSafeSound(name:String, volume:Float = 1):FlxSound
	{
		try
		{
			return FlxG.sound.play(Paths.sound(name), volume);
		}
		catch (e:Dynamic)
		{
			trace('No se pudo reproducir el sonido "$name": $e');
		}
		return null;
	}

	static var _uiFont:String = null;

	/** Fuente del Mod Menu de V-Slice (assets/fonts/FunkinLingLong.otf); si no existe usa funkin.otf. */
	public static function uiFont():String
	{
		if(_uiFont == null)
		{
			var f:String = Paths.font('FunkinLingLong.otf');
			_uiFont = (FileSystem.exists(f) || Assets.exists(f)) ? f : Paths.font('funkin.otf');
		}
		return _uiFont;
	}

	// ===== Layout (bloque de 1280x720 centrado en pantallas anchas) =====
	public static inline var BOX_X_LEFT:Int = 40;
	public static inline var BOX_X_RIGHT:Int = 471; // = BOX_X_LEFT + BOX_W + 35
	public static inline var BOX_Y:Int = 137;
	public static inline var BOX_W:Int = 396;
	public static inline var BOX_H:Int = 489;
	public static inline var LIST_TOP:Int = 60; // espacio del título de cada caja
	public static inline var LIST_BOTTOM:Int = 15;
	public static inline var ITEM_X:Int = 40;
	public static inline var ITEM_W:Int = 326;
	public static inline var ITEM_H:Int = 96;
	public static inline var ITEM_GAP:Int = 16;

	// ===== Tiempos =====
	static inline var HOLD_TIME:Float = 0.3; // segundos para empezar a arrastrar un mod con el dedo
	static inline var SHOCK_TIME:Float = 81 / 24; // duración de la electrocución (frames de V-Slice a 24 fps)
	static inline var SHOCK_SOUND_TAIL_MS:Float = (83 / 24) * 1000; // punto del audio de electrocución donde empieza su final
	static inline var CRISPY_TIME:Float = 2.5; // tiempo que se ven chamuscados antes de salir

	// Posición de las chispas (ajusta si no cuadran con tu atlas)
	static inline var SPARKS_X:Float = 690;
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
	var charBF:ModsMenuChar;
	var charGF:ModsMenuChar;
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

	// Estado
	var selectedItem:ModItem = null;
	var waitingToRestart:Bool = false;
	var exiting:Bool = false;
	var sequenceStage:Int = 0; // 0 = nada, 1 = electrocución, 2 = chamuscados
	var shockTimer:FlxTimer = null;
	var shockSound:FlxSound = null;
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
		battery = new FlxSprite(947 + ox, 80);
		battery.frames = Paths.getSparrowAtlas('modsMenu/carbattery');
		battery.animation.addByPrefix('idle', 'idle', 12, true);
		battery.animation.play('idle');
		battery.animation.pause(); // solo parpadea durante la electrocución
		battery.antialiasing = ClientPrefs.data.antialiasing;
		battery.scale.set(0.75, 0.75);
		battery.updateHitbox();
		// (battery, BF, GF, humo y chispas se añaden más abajo, encima de los paneles)

		charGF = makeChar('gf', 743 + ox, 79, // antes 127: más arriba para quedar a la altura de BF (sube/baja este número para ajustar)
			[0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 6, 6, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0],
			[8, 9, 10, 11, 12, 13, 14, 15, 10, 16, 17, 18, 11, 18, 13, 10, 14, 8, 18, 19, 14, 8, 17, 13, 11, 8, 13, 11, 10, 15, 14, 16, 9],
			[20, 21, 22, 23, 24, 25, 26, 27]);

		charBF = makeChar('bf', 907 + ox, 224,
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 6, 6, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[8, 9, 10, 11, 12, 8, 13, 14, 12, 15, 11, 10, 13, 8, 13, 12, 11, 8, 9, 10, 11, 12, 8, 13, 14, 12, 15, 11, 10, 13, 8, 13, 12, 11, 8, 9, 10, 11, 12, 8, 13, 14, 12, 15, 11, 10, 13, 8, 13, 12, 11, 8, 9, 10, 11, 12, 8, 13, 14, 12],
			[16, 17, 18, 19, 20, 21, 22, 23]);

		// Personajes de mods: misma posición que en V-Slice (BF = batería + (-119, 50), GF = BF - 166)
		charBF.modHomeX = battery.x - 119;
		charBF.modHomeY = battery.y + 50;
		charGF.modHomeX = charBF.modHomeX - 166;
		charGF.modHomeY = charBF.modHomeY;

		// Humo de los chamuscados (aparece al terminar la electrocución)
		smokeBF = makeCrispySmoke(charBF.x + 70, charBF.y - 180, 13);
		smokeGF = makeCrispySmoke(charGF.x + 70, charGF.y - 180, 0);

		// Nube de humo grande
		smokeCloud = new FlxSprite(828 + ox, -170);
		smokeCloud.frames = Paths.getSparrowAtlas('modsMenu/smoke_cloud');
		smokeCloud.animation.addByPrefix('puff', 'f', 24, false);
		smokeCloud.animation.play('puff');
		smokeCloud.antialiasing = ClientPrefs.data.antialiasing;
		smokeCloud.visible = false;

		sparks = new ModsMenuSparks(SPARKS_X + ox, SPARKS_Y);

		// ===== Título y textos =====
		var topText:FlxSprite = new FlxSprite().loadGraphic(Paths.image('modsMenu/top-text'));
		topText.antialiasing = ClientPrefs.data.antialiasing;
		topText.scale.set(0.66, 0.67);
		topText.updateHitbox();
		topText.x = ox + (1280 - topText.width) / 2;
		topText.y = 720 * 0.035;
		add(topText);

		var hintW:Float = (BOX_X_RIGHT + BOX_W) - BOX_X_LEFT;
		var hint:FlxText = new FlxText(ox + BOX_X_LEFT, 94, hintW, '', 32);
		#if mobile
		hint.text = Language.getPhrase('mods_hint_touch', 'TAP AND HOLD ON A MOD TO DRAG IT');
		#else
		hint.text = Language.getPhrase('mods_hint_mouse', 'CLICK AND DRAG A MOD TO MOVE IT');
		#end
		hint.setFormat(uiFont(), 32, FlxColor.WHITE, CENTER);
		hint.scale.set(1, 0.8);
		hint.letterSpacing = 5;
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

		if(modsList.all.length < 1) FlxG.autoPause = false;

		add(itemsGroup);

		// ===== Capa de personajes: encima de los paneles (GF debajo, BF encima) =====
		add(battery);
		add(charGF);
		add(charBF);
		add(smokeBF);
		add(smokeGF);
		add(smokeCloud);
		add(sparks);

		// ===== Botones =====
		folderButton = new ModsMenuButton(ox + BOX_X_LEFT + 181, 646, 'open-folder', 0.65, openModsFolder);
		doneButton = new ModsMenuButton(ox + 852, 646, 'done', 0.65, startDoneSequence);

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

		// Personajes según los mods ENABLED al abrir el menú
		applyCharacter(charBF, 'bf');
		applyCharacter(charGF, 'gf');
		placeSmoke(smokeBF, charBF);
		placeSmoke(smokeGF, charGF);

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
		var title:FlxText = new FlxText(box.x, box.y + 14, box.width, text, 32);
		title.setFormat(uiFont(), 32, FlxColor.WHITE, CENTER);
		add(title);
	}

	function makeChar(name:String, x:Float, y:Float, idle:Array<Int>, shock:Array<Int>, crispy:Array<Int>):ModsMenuChar
	{
		var spr:ModsMenuChar = new ModsMenuChar(x, y, name);
		spr.setBuiltin(idle, shock, crispy);
		return spr;
	}

	/** Primer mod ENABLED (de arriba a abajo = más prioridad) que trae ese personaje; '' = el del juego. */
	function pickCharMod(name:String):String
	{
		for (it in enabledList.items)
		{
			if(it.isBase) continue;
			if(ModsMenuChar.modHasChar(it.folder, name)) return it.folder;
		}
		return '';
	}

	/** Pone en `c` el personaje del mod que corresponda. Devuelve true si cambió respecto al anterior. */
	function applyCharacter(c:ModsMenuChar, name:String):Bool
	{
		var before:String = c.modFolder;
		var mod:String = pickCharMod(name);
		if(mod == before) return false;
		if(mod == '' || !c.loadMod(mod)) c.applyBuiltin();
		return c.modFolder != before;
	}

	function placeSmoke(smoke:FlxSprite, c:ModsMenuChar):Void
	{
		smoke.scale.set(c.smokeScaleX, c.smokeScaleY);
		smoke.updateHitbox();
		smoke.setPosition(c.x + 70 + c.smokeOffX, c.y - 180 + c.smokeOffY);
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

