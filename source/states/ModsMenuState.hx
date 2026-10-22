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
	var gfWire:FlxSprite = null; // cable que sale de la silla de GF (gfwire de V-Slice)
	var fgWires:FlxAnimate = null; // cables del frente (foreground-wires de V-Slice)
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
	var crispyTimer:Float = 0; // tiempo desde que salen chamuscados (como V-Slice)
	var playedCrispySFX:Bool = false;
	var crispyBoth:Bool = false;
	var gfPausedIdle:Bool = false;

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
		// (bgWires se coloca y se añade más abajo, detrás de la batería y de BF/GF, como en V-Slice)

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
		// Orden de V-Slice: bgWires (10) < batería (20) < gfWire (21) < GF (25) < BF (30) < fgWires (35)
		bgWires.setPosition(battery.x + 75, battery.y + 170);
		add(bgWires);
		add(battery);

		gfWire = makeGfWire();
		if(gfWire != null) add(gfWire);

		add(charGF);
		add(charBF);

		// Cables del frente: misma posición y escala que V-Slice (BF.x - 144, BF.y - 90 con BF = batería + (-119, 50))
		fgWires = makeForegroundWires();
		if(fgWires != null)
		{
			fgWires.setPosition(battery.x - 263, battery.y - 40);
			add(fgWires);
		}

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
		if(gfWire != null) gfWire.visible = (charGF.modFolder == ''); // un GF de mod trae sus propios cables

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

	/**
	 * Cables del frente de V-Slice. Archivos en assets/shared/images/modsMenu/foreground-wires/ (Animation.json + spritemap1.json + spritemap1.png).
	 * Etiquetas de la línea de tiempo: idle (1 frame), idle pinhead (1), shock (5 frames, en bucle), end (60 frames, sin bucle).
	 */
	function makeForegroundWires():FlxAnimate
	{
		try
		{
			var a:FlxAnimate = new FlxAnimate();
			Paths.loadAnimateAtlas(a, 'modsMenu/foreground-wires');

			addLabelAnim(a, 'idle', 'idle', [0], true);
			addLabelAnim(a, 'idle-pinhead', 'idle pinhead', [1], true);
			addLabelAnim(a, 'shock', 'shock', [2, 3, 4, 5, 6], true);
			addLabelAnim(a, 'end', 'end', [for (i in 7...67) i], false);

			a.scale.set(0.7, 0.7);
			a.antialiasing = ClientPrefs.data.antialiasing;
			a.anim.play('idle', true);
			return a;
		}
		catch(e:Dynamic)
		{
			trace('No se pudieron cargar los cables del frente (modsMenu/foreground-wires): $e');
			return null;
		}
	}

	/** Registra una animación por etiqueta de la línea de tiempo; si la librería no tiene addByFrameLabel usa los índices de frames. */
	function addLabelAnim(a:FlxAnimate, name:String, label:String, indices:Array<Int>, loop:Bool):Void
	{
		var an = a.anim;
		var addLabel:Dynamic = Reflect.field(an, 'addByFrameLabel');
		if(addLabel != null)
		{
			try
			{
				Reflect.callMethod(an, addLabel, [name, label, 24, loop]);
				var m:Dynamic = Reflect.field(an, 'animsMap');
				if(m == null || m.exists(name)) return;
			}
			catch(e:Dynamic) {}
		}
		an.addBySymbolIndices(name, 'wires foreground all', indices, 24, loop);
	}

	/** Cable de GF: assets/shared/images/modsMenu/gfwire.png + .xml (animaciones: idle0, idle empty chair0, shock). */
	function makeGfWire():FlxSprite
	{
		try
		{
			var w:FlxSprite = new FlxSprite(battery.x - 117, battery.y - 18);
			w.frames = Paths.getSparrowAtlas('modsMenu/gfwire');
			if(w.frames == null) return null;

			w.animation.addByPrefix('idle', 'idle0', 24, false);
			w.animation.addByPrefix('idle-emptychair', 'idle empty chair0', 24, false);
			w.animation.addByPrefix('shock', 'shock', 24, false);
			w.animation.play('idle');
			w.scale.set(0.7, 0.7);
			w.updateHitbox();
			w.antialiasing = ClientPrefs.data.antialiasing;
			return w;
		}
		catch(e:Dynamic)
		{
			trace('No se pudo cargar el cable de GF (modsMenu/gfwire): $e');
			return null;
		}
	}

	function playWires(name:String):Void
	{
		if(fgWires == null) return;
		try { fgWires.anim.play(name, true); }
		catch(e:Dynamic) { trace('Animación de cables "$name" falló: $e'); }
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
			updateCrispy(elapsed);
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
			// Si el toque cae sobre un botón (ej. el engranaje, que se superpone a la caja DISABLED), el botón tiene prioridad:
			// no se selecciona ni se arrastra el mod que quede debajo.
			pressList = (pressButton != null) ? null : boxListAt(mx, my);
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
		else if(controls.ACCEPT && !selectedItem.isBase && !FlxG.mouse.pressed && !FlxG.mouse.justReleased)
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
		#if mobile
		// El update de este menú pone blockGestures = true en cada frame; con el substate abierto
		// ya no corre, así que hay que soltarlo aquí o los gestos de deslizar quedan bloqueados.
		mobile.TouchInput.blockGestures = false;
		#end
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
		openSubState(new ModSettingsSubState(selectedItem.settings, selectedItem.folder, selectedItem.name));
	}

	/**
	 * Abre la carpeta "mods" de la carpeta de juego REAL (la que usa el juego según el Storage Type):
	 *  - Data:     <Android/data/paquete/files>/mods  -> se abre con DataFolder (el proveedor de documentos),
	 *              porque Android 11+ no deja a los gestores de archivos entrar a Android/data.
	 *  - Media / Obb / External: se abre la ruta directa con CoolUtil.openFolder.
	 *  Si External está elegido pero no hay permiso, Storage.getDirFor() ya cae a la carpeta Data, y aquí se sigue ese mismo resultado.
	 */
	function openModsFolder():Void
	{
		try
		{
			var gameRoot:String = mobile.StorageUtil.getGameDir();
			var modFolder:String = haxe.io.Path.addTrailingSlash(gameRoot) + 'mods';
			if(!FileSystem.exists(modFolder))
			{
				trace('created missing folder');
				FileSystem.createDirectory(modFolder);
			}

			#if android
			var inAppData:Bool = false;
			try
			{
				var getDirPathFor = lime.system.JNI.createStaticMethod('org/psychengine/mobile/Storage', 'getDirPathFor', '(Ljava/lang/String;)Ljava/lang/String;');
				var appDir:String = getDirPathFor('Data');
				inAppData = haxe.io.Path.removeTrailingSlashes(appDir) == haxe.io.Path.removeTrailingSlashes(gameRoot);
			}
			catch(e:Dynamic) { trace('No se pudo leer la carpeta Data: $e'); }

			if(inAppData)
			{
				try
				{
					var open = lime.system.JNI.createStaticMethod('org/psychengine/mobile/DataFolder', 'open', '(Ljava/lang/String;)V');
					open('mods');
					return;
				}
				catch(e:Dynamic) { trace('DataFolder.open falló, usando CoolUtil.openFolder: $e'); }
			}
			#end

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

		shockSound = playSafeSound('modsMenu/sparks/electrocution', 0.8);
		charBF.playAnim('shock', true, true); // V-Slice empieza la electrocución en un frame aleatorio
		charGF.playAnim('shock', true, true);
		battery.animation.resume();
		playWires('shock');
		if(gfWire != null)
		{
			gfWire.visible = true;
			if(gfWire.animation.exists('shock')) gfWire.animation.play('shock', true);
		}
		sparks.startElectrocution();

		// Igual que V-Slice: la electrocución dura 81/24 s (no depende de la duración reportada por el audio)
		shockTimer = new FlxTimer().start(SHOCK_TIME, function(_) endShock());
	}

	function endShock():Void
	{
		if(sequenceStage != 1) return;
		sequenceStage = 2;
		if(shockTimer != null) shockTimer.cancel();

		// === Igual que playElectrocutionSequence() de V-Slice ===
		// 1) Al terminar la electrocución: BF y GF se ponen BLANCOS (silueta), la pantalla se oscurece (0xFF232327)
		//    y desaparecen batería, cables y botones durante 2 frames.
		var bgColor:FlxColor = bg.color;
		charBF.whiteout = true;
		charGF.whiteout = true;

		var blackFlash:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF232327);
		blackFlash.scrollFactor.set();
		var at:Int = members.indexOf(battery);
		if(at >= 0) insert(at, blackFlash);
		else add(blackFlash);

		battery.visible = false;
		bgWires.visible = false;
		if(fgWires != null) fgWires.visible = false;
		if(gfWire != null) gfWire.visible = false; // como V-Slice: no vuelve a mostrarse tras el flash
		for (b in buttons) b.visible = false;

		// 2) 2 frames después: flash blanco de 1 frame, se cambian los personajes y sale el humo
		new FlxTimer().start(2 / 24, function(_)
		{
			FlxG.camera.flash(FlxColor.WHITE, 1 / 24, function()
			{
				remove(blackFlash, true);
				blackFlash.destroy();
			});

			var bfChanged:Bool = applyCharacter(charBF, 'bf');
			var gfChanged:Bool = applyCharacter(charGF, 'gf');
			placeSmoke(smokeBF, charBF);
			placeSmoke(smokeGF, charGF);

			// El fondo vuelve de oscuro a su color en 1 s
			FlxTween.color(bg, 1, 0xFF232327, bgColor);

			for (b in buttons) b.visible = true;
			battery.visible = true;
			battery.animation.play('idle', true);
			battery.animation.pause();
			bgWires.visible = true;
			if(fgWires != null) fgWires.visible = true;

			charBF.whiteout = false;
			charGF.whiteout = false;

			smokeCloud.visible = true;
			smokeCloud.alpha = 1;
			smokeCloud.animation.play('puff', true);
			FlxTween.tween(smokeCloud, {alpha: 0}, 62 / 24, {ease: FlxEase.linear}); // 62 frames a 24 fps
			playSafeSound('modsMenu/smoke-cloud', 0.8);

			// El audio de electrocución salta a su parte final justo aquí (como sparks.endElectrocution() de V-Slice)
			if(shockSound != null && shockSound.playing) shockSound.time = SHOCK_SOUND_TAIL_MS;
			sparks.endElectrocution();

			var bfCrispy:Bool = !bfChanged && charBF.hasAnim('crispy');
			var gfCrispy:Bool = !gfChanged && charGF.hasAnim('crispy');
			if(bfCrispy) charBF.playAnim('crispy', true);
			else charBF.playAnim('idle', true);

			gfPausedIdle = false;
			if(gfCrispy) charGF.playAnim('crispy', true);
			else
			{
				// GF sin chamuscar: se queda congelada en idle y se reanuda a los 0.3 s
				charGF.playAnim('idle', true);
				charGF.pauseAnim();
				gfPausedIdle = true;
			}

			smokeBF.visible = bfCrispy;
			smokeGF.visible = gfCrispy;
			crispyBoth = bfCrispy && gfCrispy;

			// Como V-Slice: si alguno quedó chamuscado, los cables hacen su animación final
			if(bfCrispy || gfCrispy) playWires('end');

			crispyTimer = 0;
			playedCrispySFX = false;
			sequenceStage = 3;
		});
	}

	/** Fase "chamuscados" (como el update de V-Slice): el SFX crispy suena a 0.7 s, GF se reanuda a 0.3 s y se sale a los 2.5 s. */
	function updateCrispy(elapsed:Float):Void
	{
		if(sequenceStage != 3) return;

		crispyTimer += elapsed;

		if(crispyBoth && crispyTimer >= 0.7 && !playedCrispySFX)
		{
			playedCrispySFX = true;
			playSafeSound('modsMenu/crispy', 0.8);
		}

		if(gfPausedIdle && crispyTimer >= 0.3)
		{
			gfPausedIdle = false;
			charGF.resumeAnim();
		}

		if(crispyTimer >= CRISPY_TIME)
		{
			sequenceStage = 4;
			leaveMenu();
		}
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
	static inline var TRACK_TOP:Float = 42; // la barra sube 42 px por encima de la lista (como V-Slice)
	public var track:FlxSprite;
	public var thumb:FlxSprite;

	public function new(x:Float, y:Float, w:Float, h:Float)
	{
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;

		track = new FlxSprite(x + 12, y - TRACK_TOP).makeGraphic(10, Std.int(h + TRACK_TOP), 0xFF3A393E);
		track.alpha = 0.6;
		track.visible = false;

		thumb = new FlxSprite(x + 12, y - TRACK_TOP).makeGraphic(10, 1, 0xFF57565A);
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

		var trackH:Float = h + TRACK_TOP;
		var th:Float = Math.max(24, trackH * (h / contentHeight()));
		var frac:Float = maxScroll() > 0 ? scroll / maxScroll() : 0;
		thumb.scale.y = th;
		thumb.y = (y - TRACK_TOP) + Math.max(0, Math.min(1, frac)) * (trackH - th);
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
		var textW:Float = ModsMenuState.ITEM_W - textX - 6; // = 216, igual que DESC_WIDTH de V-Slice

		title = new FlxText(textX, 0, textW, "", 30);
		title.setFormat(ModsMenuState.uiFont(), 30, FlxColor.WHITE, LEFT);
		title.wordWrap = false;
		add(title);

		descText = new FlxText(textX, 36, textW, "", 20);
		descText.setFormat(ModsMenuState.uiFont(), 20, FlxColor.WHITE, LEFT);
		descText.fieldHeight = ModsMenuState.ITEM_H - 36;
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
// Personaje del menú (BF / GF). Puede ser:
//  - el del juego: atlas prerenderizado 'modsMenu/char_<bf|gf>' con animaciones por índices de frames, o
//  - uno de un mod, en mods/<mod>/images/modsMenu/:
//      char_<bf|gf>/Animation.json + spritemap1.json/.png  -> spritemap de Adobe Animate (si existe, tiene prioridad)
//      char_<bf|gf>.png + char_<bf|gf>.xml                 -> Sparrow (si no hay spritemap)
//      char_<bf|gf>.json (opcional)                        -> escala, offsets, animaciones, humo (formato de V-Slice)
// Animaciones: idle, electrocuted (= 'shock'), crispy, crispy-loop.
// =======================================================================
class ModsMenuChar extends FlxSprite
{
	public var charName:String;
	public var modFolder:String = ''; // '' = personaje del juego
	public var isAtlas(default, null):Bool = false;
	public var curName:String = '';

	/** Silueta blanca (el PureColor de V-Slice al final de la electrocución). */
	public var whiteout(default, set):Bool = false;
	var atlasWhite:Bool = false;

	// Posición del personaje del mod (la del juego es la del constructor)
	public var modHomeX:Float = 0;
	public var modHomeY:Float = 0;

	// Humo de chamuscado
	public var smokeOffX:Float = 0;
	public var smokeOffY:Float = 0;
	public var smokeScaleX:Float = 0.5;
	public var smokeScaleY:Float = 0.5;

	var homeX:Float;
	var homeY:Float;
	var atlas:FlxAnimate = null;
	var animOffsets:Map<String, Array<Float>> = new Map();
	var atlasAnims:Map<String, Bool> = new Map(); // animaciones registradas en el spritemap
	var globalOffX:Float = 0;
	var globalOffY:Float = 0;
	var curOffX:Float = 0;
	var curOffY:Float = 0;
	var startFrame:Int = 0;
	var startFrameUsed:Bool = false;
	var idleLoops:Bool = true;
	var idleWait:Float = 2;

	var bIdle:Array<Int>;
	var bShock:Array<Int>;
	var bCrispy:Array<Int>;

	public function new(x:Float, y:Float, name:String)
	{
		super(x, y);
		homeX = x;
		homeY = y;
		charName = name;
		antialiasing = ClientPrefs.data.antialiasing;
	}

	public static function modHasChar(folder:String, name:String):Bool
	{
		var base:String = Paths.mods(folder + '/images/modsMenu/char_' + name);
		return FileSystem.exists(base + '/Animation.json') || (FileSystem.exists(base + '.xml') && FileSystem.exists(base + '.png'));
	}

	public function setBuiltin(idle:Array<Int>, shock:Array<Int>, crispy:Array<Int>):Void
	{
		bIdle = idle;
		bShock = shock;
		bCrispy = crispy;
		applyBuiltin();
	}

	function resetState():Void
	{
		if(atlas != null)
		{
			atlas.destroy();
			atlas = null;
		}
		isAtlas = false;
		animation.destroyAnimations();
		animOffsets = new Map();
		atlasAnims = new Map();
		globalOffX = globalOffY = curOffX = curOffY = 0;
		smokeOffX = smokeOffY = 0;
		smokeScaleX = smokeScaleY = 0.5;
		startFrame = 0;
		startFrameUsed = false;
		idleLoops = true;
		idleWait = 2;
		scale.set(1, 1);
		setPosition(homeX, homeY);
		curName = '';
		modFolder = '';
	}

	/** Vuelve al personaje incluido en el juego. */
	public function applyBuiltin():Void
	{
		resetState();
		frames = Paths.getSparrowAtlas('modsMenu/char_' + charName);
		animation.add('idle', bIdle, 24, true);
		animation.add('shock', bShock, 24, true);
		animation.add('crispy', bCrispy, 24, false);
		playAnim('idle', true);
	}

	/** Carga el personaje de un mod. Devuelve false (y no cambia nada raro) si falla. */
	public function loadMod(folder:String):Bool
	{
		var base:String = Paths.mods(folder + '/images/modsMenu/char_' + charName);
		var useAtlas:Bool = FileSystem.exists(base + '/Animation.json');
		if(!useAtlas && !(FileSystem.exists(base + '.xml') && FileSystem.exists(base + '.png'))) return false;

		var data:Dynamic = null;
		if(FileSystem.exists(base + '.json'))
		{
			try { data = Json.parse(File.getContent(base + '.json')); }
			catch(e:Dynamic) { trace('JSON del personaje inválido ($base.json): $e'); }
		}

		try
		{
			resetState();
			modFolder = folder;
			setPosition(modHomeX, modHomeY);

			if(useAtlas)
			{
				var a:FlxAnimate = new FlxAnimate();
				// Paths resuelve las rutas con el mod "actual"; lo cambiamos solo durante la carga
				var prev:String = Mods.currentModDirectory;
				Mods.currentModDirectory = folder;
				try { Paths.loadAnimateAtlas(a, 'modsMenu/char_' + charName); }
				catch(e:Dynamic)
				{
					Mods.currentModDirectory = prev;
					a.destroy();
					throw e;
				}
				Mods.currentModDirectory = prev;
				atlas = a;
				isAtlas = true;
			}
			else
			{
				var png:String = base + '.png';
				var graphic:FlxGraphic = Paths.cacheBitmap(png, BitmapData.fromFile(png));
				frames = FlxAtlasFrames.fromSparrow(graphic, File.getContent(base + '.xml'));
			}

			var defs:Array<Dynamic> = (data != null && data.animations != null) ? data.animations : defaultDefs();
			for (d in defs) addDef(d);

			var sc:Float = (data != null && data.scale != null) ? data.scale : 0.7;
			scale.set(sc, sc);
			if(data != null)
			{
				if(data.offsets != null) { globalOffX = data.offsets[0]; globalOffY = data.offsets[1]; }
				if(data.smokeOffsets != null) { smokeOffX = data.smokeOffsets[0]; smokeOffY = data.smokeOffsets[1]; }
				if(data.smokeScale != null) { smokeScaleX = data.smokeScale[0]; smokeScaleY = data.smokeScale[1]; }
				var sf:Dynamic = data.startingFrame;
				if(sf != null)
				{
					if(Std.isOfType(sf, Int) || Std.isOfType(sf, Float)) startFrame = Std.int(sf);
					else if(Reflect.field(sf, charName) != null) startFrame = Std.int(Reflect.field(sf, charName));
				}
			}

			playAnim('idle', true);
			return true;
		}
		catch(e:Dynamic)
		{
			trace('No se pudo cargar el personaje "$charName" del mod "$folder": $e');
			return false;
		}
	}

	static function defaultDefs():Array<Dynamic>
	{
		return [
			{name: 'idle', prefix: 'idle', looped: false},
			{name: 'electrocuted', prefix: 'electrocuted', looped: true},
			{name: 'crispy', prefix: 'crispy', looped: false},
			{name: 'crispy-loop', prefix: 'crispy loop', looped: true}
		];
	}

	function addDef(d:Dynamic):Void
	{
		var n:String = d.name;
		if(n == 'electrocuted') n = 'shock'; // el menú usa 'shock' internamente
		var prefix:String = (d.prefix != null) ? d.prefix : d.name;
		var fps:Int = (d.frameRate != null) ? Std.int(d.frameRate) : ((d.fps != null) ? Std.int(d.fps) : 24);
		var loop:Bool = (d.looped == true);
		var indices:Array<Int> = (d.frameIndices != null) ? d.frameIndices : d.indices;

		if(d.offsets != null && d.offsets.length >= 2) animOffsets.set(n, [d.offsets[0], d.offsets[1]]);
		if(n == 'idle') idleLoops = loop;

		var hasIdx:Bool = indices != null && indices.length > 0;
		if(isAtlas)
		{
			var an = atlas.anim;
			try
			{
				if(hasIdx) an.addBySymbolIndices(n, prefix, indices, fps, loop);
				else an.addBySymbol(n, prefix, fps, loop);
				atlasAnims.set(n, true);
			}
			catch(e:Dynamic) { trace('Símbolo "$prefix" no encontrado en el spritemap: $e'); }

			// Si no hay símbolo con ese nombre, se prueba como etiqueta de la línea de tiempo (solo si la librería lo soporta)
			if(!atlasHas(n))
			{
				var addLabel:Dynamic = Reflect.field(an, 'addByFrameLabel');
				if(addLabel != null)
				{
					try
					{
						Reflect.callMethod(an, addLabel, [n, prefix, fps, loop]);
						atlasAnims.set(n, true);
					}
					catch(e:Dynamic) {}
				}
			}
		}
		else
		{
			if(hasIdx) animation.addByIndices(n, prefix, indices, '', fps, loop);
			else animation.addByPrefix(n, prefix, fps, loop);
		}
	}

	/** Comprueba si el spritemap tiene esa animación (FlxAnim de flxanimate no trae `exists`). */
	function atlasHas(name:String):Bool
	{
		if(atlas == null) return false;
		var m:Dynamic = Reflect.field(atlas.anim, 'animsMap');
		if(m != null) return m.exists(name);
		return atlasAnims.exists(name);
	}

	public function hasAnim(name:String):Bool
		return isAtlas ? atlasHas(name) : animation.exists(name);

	function set_whiteout(v:Bool):Bool
	{
		whiteout = v;
		if(v) setColorTransform(0, 0, 0, 1, 255, 255, 255, 0);
		else setColorTransform();
		return v;
	}

	public function pauseAnim():Void
	{
		if(isAtlas) atlas.anim.pause();
		else animation.pause();
	}

	public function resumeAnim():Void
	{
		if(isAtlas) atlas.anim.resume();
		else animation.resume();
	}

	public function playAnim(name:String, force:Bool = true, randomFrame:Bool = false):Void
	{
		if(!hasAnim(name))
		{
			if(name == 'idle' || !hasAnim('idle')) return;
			name = 'idle'; // animación que el personaje no tiene: se queda en idle
		}

		var frame:Int = 0;
		if(name == 'idle' && !startFrameUsed && startFrame > 0)
		{
			frame = startFrame;
			startFrameUsed = true;
		}

		// V-Slice: la animación de electrocución arranca en un frame aleatorio
		if(randomFrame && !isAtlas)
		{
			var anim = animation.getByName(name);
			if(anim != null && anim.numFrames > 1) frame = FlxG.random.int(0, anim.numFrames - 1);
		}

		curName = name;
		var off:Array<Float> = animOffsets.get(name);
		curOffX = (off != null) ? off[0] : 0;
		curOffY = (off != null) ? off[1] : 0;

		if(isAtlas) atlas.anim.play(name, force, false, frame);
		else animation.play(name, force, false, frame);
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if(isAtlas) atlas.update(elapsed);

		var done:Bool = isAtlas ? atlas.anim.finished : animation.finished;
		if(!done) return;

		if(curName == 'crispy' && hasAnim('crispy-loop')) playAnim('crispy-loop', true);
		else if(curName == 'idle' && !idleLoops)
		{
			// idle sin bucle: se repite de vez en cuando (parpadeo)
			idleWait -= elapsed;
			if(idleWait <= 0)
			{
				playAnim('idle', true);
				idleWait = FlxG.random.float(1, 6);
			}
		}
	}

	override function draw():Void
	{
		if(!isAtlas)
		{
			super.draw();
			return;
		}
		if(!visible || alpha <= 0) return;

		if(atlasWhite != whiteout)
		{
			atlasWhite = whiteout;
			if(whiteout) atlas.setColorTransform(0, 0, 0, 1, 255, 255, 255, 0);
			else atlas.setColorTransform();
		}

		atlas.setPosition(x - (curOffX - globalOffX), y - (curOffY - globalOffY));
		atlas.scale.copyFrom(scale);
		atlas.alpha = alpha;
		atlas.antialiasing = antialiasing;
		atlas.scrollFactor.copyFrom(scrollFactor);
		atlas.cameras = cameras;
		atlas.draw();
	}

	override function getScreenPosition(?result:FlxPoint, ?camera:FlxCamera):FlxPoint
	{
		var out:FlxPoint = super.getScreenPosition(result, camera);
		out.x -= curOffX - globalOffX;
		out.y -= curOffY - globalOffY;
		return out;
	}

	override function destroy():Void
	{
		if(atlas != null)
		{
			atlas.destroy();
			atlas = null;
		}
		super.destroy();
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
		ModsMenuState.playSafeSound('modsMenu/sparks/spark-' + n, 0.7);
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
			ModsMenuState.playSafeSound('modsMenu/ambience/phantomarcade-trapped', 0.8);
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

		ModsMenuState.playSafeSound('modsMenu/ambience/' + chosen, 0.7);

		// Los easter eggs solo pueden sonar una vez
		if(weightOf(chosen) <= 1) pool.remove(chosen);
	}
}
