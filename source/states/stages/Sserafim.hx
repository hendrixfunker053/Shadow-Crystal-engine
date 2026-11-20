package states.stages;

import flixel.addons.display.FlxBackdrop;
import flixel.text.FlxText;
import flixel.util.FlxAxes;
import flixel.util.FlxTimer;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.sound.FlxSound;
import haxe.Json;

import states.PlayState;

import objects.Note;

/**
 * LE SSERAFIM - Spaghetti (SP. COLLAB 1), integrado en el engine.
 * Reemplaza a: stages/sserafim.lua, data/spaghetti/*.lua, custom_events/*.lua y custom_notetypes/*.lua
 *
 * NOTA: stages/sserafim.json (posiciones de personajes, zoom) y los shaders .frag siguen siendo assets.
 */
class Sserafim extends BaseStage
{
	// ---- Sprites del stage ----
	var solidBG:FlxSprite;
	var bg:BGSprite;
	var perspectiveFloor:BGSprite;
	var perspectiveFloorCut:BGSprite;
	var backTables:BGSprite;
	var backTablesCutscene:BGSprite;
	var burgerCutscene:BGSprite;
	var backStools:BGSprite;
	var backLightColor:BGSprite;
	var backLightWhite:BGSprite;
	var truck:BGSprite;
	var truckDoor:BGSprite;
	var truckLight1:BGSprite;
	var truckLight2:BGSprite;
	var frontStool:BGSprite;
	var solidCover:FlxSprite;

	// Atlas (FlxAnimate) -> Dynamic para no depender del tipo exacto en tu fork
	var sserafimCutscene:Dynamic;
	var sserafimGf:Dynamic;
	var sserafimBf:Dynamic;
	var sserafimGfBody:FlxSprite;
	var yunjinIntroSpr:FlxSprite;

	var dust:Array<FlxBackdrop> = [];
	var dustAllowed:Bool = false;

	// ---- Shaders ----
	var stageSh:Dynamic;
	var charSh:Dynamic;
	var floorSh:Dynamic;
	var floorCutSh:Dynamic;
	var shTargets:Array<Dynamic> = [];
	var useShaders:Bool = false;

	// valores que se animan con tweens y se mandan al shader
	var sv = {dark: 0.0, truck: 0.0, pulse: 0.0, bri: 0.0, hue: 0.0, con: 0.0, sat: 0.0};
	var lastSh:Array<Float> = [-999, -999, -999, -999, -999, -999, -999];
	var lastLight:Array<Float> = [-1, -1, -1];
	var ultColor:Array<Float> = [1.0, 1.0, 1.0];
	var lastScrollX:Float = -999999.0;
	var lastScrollY:Float = -999999.0;
	var lastFlVis:Int = -1;

	// ---- Luces al compas ----
	var lucesOn:Bool = false;
	var lucesCols:Array<String> = [];
	var lucesDurs:Array<Float> = [];
	var lucesAmts:Array<Float> = [];

	// ---- Cutscene / final ----
	var viendoKick:Bool = false;
	var enCutscene:Bool = false;
	var cutsceneSkipped:Bool = false;
	var canSkipCutscene:Bool = false;
	var skipRevealStarted:Bool = false;
	var graceTimer:Float = 0.25;
	var skipTxt:FlxText;
	var cutSnd:FlxSound;
	var cutTimers:Array<FlxTimer> = [];
	var allTweens:Array<FlxTween> = [];
	var coverTw:FlxTween;
	var darkTw:FlxTween;
	var hsbTw:Array<FlxTween> = [];
	var seeYou1:FlxSprite;
	var seeYou2:FlxSprite;
	var finActivado:Bool = false;
	var finListo:Bool = false;

	// ---- Camara (FocusCamera / ZoomCamera / SetCameraBop) ----
	static final BASE_STAGE_ZOOM:Float = 0.5;
	var camHelper = {x: 660.0, y: 300.0};
	var camTweeneando:Bool = false;
	var camTwX:FlxTween;
	var camTwY:FlxTween;
	var zoomHelper = {z: 0.5};
	var zoomTweeneando:Bool = false;
	var zoomTw:FlxTween;
	var ultimoZoomBase:Float = 0.5;
	var bopIntensity:Float = 1.0;
	var bopRate:Int = 4;
	var bopOffset:Int = 0;
	final focusPoints:Array<Array<Float>> = [[1430.0, 528.4], [220.0, 361.3], [938.5, 92.8]]; // 0=Sakura(BF) 1=Kazuha(Dad) 2=GF

	// =============================================================================================
	override function create()
	{
		useShaders = ClientPrefs.data.shaders;

		// Fondo del restaurante
		solidBG = new FlxSprite(-5000, -3000).makeGraphic(1, 1, FlxColor.WHITE);
		solidBG.scale.set(10000, 10000);
		solidBG.updateHitbox();
		solidBG.scrollFactor.set(0, 0);
		add(solidBG);

		bg = new BGSprite('bg', -1853, -815, 0.75, 0.75);
		add(bg);

		// Dos pisos en perspectiva pre-cargados (evita hitches mid-cutscene)
		perspectiveFloor = new BGSprite('floor', -1921, 625, 1.0, 1.0);
		perspectiveFloor.origin.set(0, 0);
		add(perspectiveFloor);

		perspectiveFloorCut = new BGSprite('cutscene/floor-cutscene', -1921, 625, 1.0, 1.0);
		perspectiveFloorCut.origin.set(0, 0);
		perspectiveFloorCut.visible = false;
		add(perspectiveFloorCut);

		if (useShaders)
		{
			stageSh = game.createRuntimeShader('sserafim');
			charSh = game.createRuntimeShader('sserafim');
			floorSh = game.createRuntimeShader('piso');
			floorCutSh = game.createRuntimeShader('piso');
			shTargets = [stageSh, charSh, floorSh, floorCutSh];
			for (sh in shTargets)
			{
				if (sh == null) continue;
				sh.setFloat('isCharVal', (sh == charSh) ? 1.0 : 0.0);
				sh.setFloat('darkAmt', 0.0);
				sh.setFloat('truckStrength', 0.0);
				sh.setFloat('pulseStrength', 0.0);
				sh.setFloat('brightness', 0.0);
				sh.setFloat('hue', 0.0);
				sh.setFloat('contrast', 0.0);
				sh.setFloat('saturation', 0.0);
				sh.setFloatArray('lightColor', ultColor);
			}
			if (floorSh != null) floorSh.setFloat('floorSkewU', 0.0);
			if (floorCutSh != null) floorCutSh.setFloat('floorSkewU', 0.0);
			if (floorSh != null) perspectiveFloor.shader = floorSh;
			if (floorCutSh != null) perspectiveFloorCut.shader = floorCutSh;
		}

		backTables = new BGSprite('back-tables', -1857, 267, 0.93, 0.93);
		add(backTables);

		backTablesCutscene = new BGSprite('cutscene/counter-stretch', -1858, 377, 0.93, 0.93);
		backTablesCutscene.scale.set(400, 1);
		backTablesCutscene.updateHitbox();
		backTablesCutscene.visible = false;
		add(backTablesCutscene);

		burgerCutscene = new BGSprite('cutscene/burger-cutscene', -97, 237, 0.93, 0.93);
		burgerCutscene.visible = false;
		add(burgerCutscene);

		backStools = new BGSprite('back-stools', -1357, 426, 0.94, 0.94);
		add(backStools);

		// Luces de atras al compas
		backLightColor = new BGSprite('lights/back-light-color', -1241, -949, 0.93, 0.93);
		backLightColor.blend = ADD;
		backLightColor.color = 0xFFCC3300;
		backLightColor.alpha = 0;
		add(backLightColor);

		backLightWhite = new BGSprite('lights/back-light-white', -771, -599, 0.93, 0.93);
		backLightWhite.alpha = 0;
		add(backLightWhite);

		// Camion y puerta
		truck = new BGSprite('truck-stuff', -983, -707, 0.95, 0.95);
		add(truck);

		truckDoor = new BGSprite('truck-door', -980, -173, 0.95, 0.95);
		truckDoor.visible = false;
		add(truckDoor);

		truckLight2 = new BGSprite('lights/truck-light2', -781, -464, 0.95, 0.95);
		truckLight2.alpha = 0;
		add(truckLight2);

		truckLight1 = new BGSprite('lights/truck-light1', -962, -607, 0.95, 0.95);
		truckLight1.blend = ADD;
		truckLight1.alpha = 0;
		add(truckLight1);

		#if flxanimate
		// Cutscene del diner
		sserafimCutscene = new FlxAnimate(-348.2, -277.25);
		sserafimCutscene.showPivot = false;
		Paths.loadAnimateAtlas(sserafimCutscene, 'cutscene/cutsceneMain');
		sserafimCutscene.anim.addBySymbol('cutscene', 'cutsceneMain', 24, false);
		sserafimCutscene.anim.pause();
		sserafimCutscene.scrollFactor.set(0.94, 0.94);
		sserafimCutscene.visible = false;
		add(sserafimCutscene);
		#end

		// GF levantandose (cuerpo bakeado + manos al frente)
		sserafimGfBody = new FlxSprite(717.00, -85.10);
		var gfBodyFrames = Paths.getSparrowAtlas('cutscene/gfGetUpBody');
		if (gfBodyFrames != null)
		{
			sserafimGfBody.frames = gfBodyFrames;
			sserafimGfBody.animation.addByPrefix('static', 'static', 24, false);
			sserafimGfBody.animation.addByPrefix('getup', 'getup', 24, false);
		}
		sserafimGfBody.antialiasing = ClientPrefs.data.antialiasing;
		sserafimGfBody.scrollFactor.set(0.95, 0.95);
		sserafimGfBody.active = false;
		sserafimGfBody.visible = false;
		add(sserafimGfBody);

		#if flxanimate
		sserafimGf = new FlxAnimate(1073.0, 324.9);
		sserafimGf.showPivot = false;
		Paths.loadAnimateAtlas(sserafimGf, 'cutscene/gfGetUp');
		sserafimGf.anim.addBySymbolIndices('static', 'GF Get Up', [0], 24, false);
		var gfIdx:Array<Int> = [for (i in 1...124) i];
		sserafimGf.anim.addBySymbolIndices('getup', 'GF Get Up', gfIdx, 24, false);
		sserafimGf.scrollFactor.set(0.95, 0.95);
		sserafimGf.visible = false;
		add(sserafimGf);

		// Atlas de GF: oculta Clipper/Clipped para que cabeza/pelo queden detras del camion
		hideClipperLayers(sserafimGf, true);
		#end

		// Scrollfactors de los personajes base
		dadGroup.scrollFactor.set(0.97, 0.97);
		gfGroup.scrollFactor.set(0.95, 0.95);
		boyfriendGroup.scrollFactor.set(0.99, 0.99);

		// Precarga
		Paths.sound('cutscene/startCutscene');
		Paths.sound('cutscene/end1');
		Paths.sound('cutscene/end2');
		Paths.sound('doorKick1');
		Paths.sound('doorKick2');

		// Cutscene inicial (con skip) solo la primera vez y fuera del modo chart
		if (!seenCutscene && !PlayState.chartingMode) setStartCallback(startIntro);
		setEndCallback(endSongHook);
	}

	// =============================================================================================
	override function createPost()
	{
		#if flxanimate
		sserafimBf = new FlxAnimate(1249.5, 319.7);
		sserafimBf.showPivot = false;
		Paths.loadAnimateAtlas(sserafimBf, 'cutscene/bfGetUp');
		sserafimBf.anim.addBySymbolIndices('static', 'BF Get Up', [0], 24, false);
		var bfIdx:Array<Int> = [for (i in 1...129) i];
		sserafimBf.anim.addBySymbolIndices('getup', 'BF Get Up', bfIdx, 24, false);
		sserafimBf.scrollFactor.set(0.99, 0.99);
		sserafimBf.visible = false;
		add(sserafimBf);
		#end

		frontStool = new BGSprite('front-stool', -280, 818, 1.0, 1.0);
		frontStool.visible = !enCutscene;
		add(frontStool);
		game.variables.set('frontStool', frontStool); // lo usa data/spaghetti/lipsync.hx

		// Yunjin intro pre-bakeada (detras de la puerta)
		yunjinIntroSpr = new FlxSprite(-1033.0, -190.0);
		var yunjinIntroFrames = Paths.getSparrowAtlas('cutscene/yunjinIntro');
		if (yunjinIntroFrames != null)
		{
			yunjinIntroSpr.frames = yunjinIntroFrames;
			yunjinIntroSpr.animation.addByPrefix('doorclosed', 'doorclosed', 24, false);
			yunjinIntroSpr.animation.addByPrefix('kick1', 'kick1', 24, false);
			yunjinIntroSpr.animation.addByPrefix('kick2', 'kick2', 24, false);
		}
		yunjinIntroSpr.antialiasing = ClientPrefs.data.antialiasing;
		yunjinIntroSpr.scrollFactor.set(0.95, 0.95);
		yunjinIntroSpr.active = false;
		yunjinIntroSpr.visible = false;
		add(yunjinIntroSpr);
		game.variables.set('yunjinIntroSpr', yunjinIntroSpr); // lo usa lipsync.hx

		// Polvo/humo (empieza oculto hasta resetPolvo)
		function addDust(img:String, px:Float, py:Float, sf:Float, sc:Float, a:Float, vx:Float, col:Int):FlxBackdrop
		{
			var dustGraphic = Paths.image(img);
			if (dustGraphic == null) return null;
			var d = new FlxBackdrop(dustGraphic, FlxAxes.X);
			d.setPosition(px, py);
			d.scrollFactor.set(sf, sf);
			d.scale.set(sc, sc);
			d.alpha = a;
			d.velocity.x = vx;
			d.color = col;
			d.antialiasing = ClientPrefs.data.antialiasing;
			d.visible = false;
			d.active = false;
			dust.push(d);
			return d;
		}
		addDust('dust/dustMid', -650, -200, 1.1, 1.5, 0.8, 350, 0xFF98847D);
		addDust('dust/dustBack', -650, -250, 1.15, 1.5, 0.9, -300, 0xFF8B6C63);
		addDust('dust/dustMid', -650, -400, 1.2, 2.0, 0.8, -200, 0xFF6E645C);
		addDust('dust/dustBack', -650, -1300, 1.25, 3.5, 0.9, -150, 0xFF886A60);

		// Chicas extra + lip-sync: los crea data/spaghetti/lipsync.hx (HScript) en onCreatePost
		game.variables.set('sserCharShader', charSh);

		for (d in dust) add(d);

		solidCover = new FlxSprite(-5000, -3000).makeGraphic(1, 1, FlxColor.BLACK);
		solidCover.scale.set(10000, 10000);
		solidCover.updateHitbox();
		solidCover.scrollFactor.set(0, 0);
		solidCover.alpha = 0;
		add(solidCover);

		// Shaders en todos los sprites del stage y personajes
		if (useShaders)
		{
			for (o in [solidBG, bg, backTables, backTablesCutscene, burgerCutscene, backStools, truck, truckDoor, frontStool])
				if (o != null && stageSh != null) o.shader = stageSh;
			if (dad != null) dad.shader = charSh;
			if (boyfriend != null) boyfriend.shader = charSh;
			if (gf != null) gf.shader = charSh;
			for (o in [sserafimCutscene, sserafimGfBody, sserafimGf, sserafimBf])
				if (o != null) o.shader = charSh;
			syncShaders(true);
		}

		if (gf != null) gf.visible = false;

		// ---- HUD / notas (end_y_hud.lua + notetypes) ----
		if (game.comboGroup != null) game.comboGroup.visible = false; // sin popups de Sick/Good/Bad/Combo
		if (game.iconP2 != null) game.iconP2.visible = false;

		seeYou1 = new FlxSprite();
		var end1Graphic = Paths.image('end/end1');
		if (end1Graphic != null) seeYou1.loadGraphic(end1Graphic);
		else seeYou1.makeGraphic(1, 1, FlxColor.TRANSPARENT);
		seeYou1.scale.set(0.67, 0.67);
		seeYou1.updateHitbox();
		seeYou1.cameras = [camOther];
		seeYou1.scrollFactor.set(0, 0);
		seeYou1.screenCenter();
		seeYou1.visible = false;
		add(seeYou1);

		seeYou2 = new FlxSprite();
		var end2Graphic = Paths.image('end/end2');
		if (end2Graphic != null) seeYou2.loadGraphic(end2Graphic);
		else seeYou2.makeGraphic(1, 1, FlxColor.TRANSPARENT);
		seeYou2.scale.set(0.67, 0.67);
		seeYou2.updateHitbox();
		seeYou2.cameras = [camOther];
		seeYou2.scrollFactor.set(0, 0);
		seeYou2.setPosition(FlxG.width - 40 - seeYou2.width, FlxG.height - 40 - seeYou2.height);
		seeYou2.visible = false;
		add(seeYou2);

		hideP2Strums();
		if (!postHooked)
		{
			postHooked = true;
			FlxG.signals.postUpdate.add(postStageUpdate);
		}
		for (note in unspawnNotes)
		{
			if (note == null) continue;
			note.noAnimation = true;
			note.noMissAnimation = true;
			switch (note.noteType)
			{
				case 'non_scoreable': note.ignoreNote = true;
				case 'sakura-joint': note.animSuffix = '-joint';
				case 'sakura-bf1': note.animSuffix = '-bf1';
				case 'sakura-bf2': note.animSuffix = '-bf2';
			}
			if (!note.mustPress)
			{
				note.visible = false;
				note.multAlpha = 0;
			}
		}

		// SetCameraBop: desactiva el bop por defecto, lo hace este stage
		game.camZoomingMult = 0;
		ultimoZoomBase = defaultCamZoom;
		zoomHelper.z = defaultCamZoom;

		// ---- Cutscene: estado inicial (cutscene.lua onCreatePost) ----
		if (seenCutscene || PlayState.chartingMode)
		{
			if (!enCutscene) iniciarDesdeRestart();
		}
		else aplicarCutscene(true);
	}

	// =============================================================================================
	// Post-update: equivale a onUpdatePost() de los .lua (corre DESPUES de actualizar los personajes).
	// Antes esto estaba en update(), asi el frame de FlxAnimate quedaba desfasado 1 frame y el
	// lip-sync / cuerpo de la GF no coincidian con lo que se dibujaba.
	// =============================================================================================
	var postHooked:Bool = false;

	function postStageUpdate():Void
	{
		if (game == null || FlxG.state != game) return;
		if (paused) return;
		if (perspectiveFloor == null || perspectiveFloorCut == null) return;

		syncFloor();
		syncShaders(false);

		// polvo: si no esta permitido, ocultarlo
		if (!dustAllowed && dust.length > 0 && dust[0] != null && dust[0].visible) setDustVis(false);

		// GF levantandose: sincroniza el cuerpo bakeado con el atlas
		#if flxanimate
		if (sserafimGf != null && sserafimGfBody != null)
		{
			if (!sserafimGf.visible)
			{
				if (sserafimGfBody.visible) sserafimGfBody.visible = false;
			}
			else
			{
				if (!sserafimGfBody.visible) sserafimGfBody.visible = true;
				if (sserafimGfBody.alpha != sserafimGf.alpha) sserafimGfBody.alpha = sserafimGf.alpha;
				if (sserafimGf.anim != null && sserafimGfBody.animation.curAnim != null)
				{
					// FlxAnimate puede exponer un curFrame desfasado respecto al simbolo
					// que realmente se esta dibujando. Usa el frame de la instancia activa.
					var gfFrame:Int = Std.int(sserafimGf.anim.curFrame);
					var gfInstance:Dynamic = sserafimGf.anim.curInstance;
					if (gfInstance != null && gfInstance.symbol != null)
						gfFrame = Std.int(gfInstance.symbol._curFrame);
					if (gfFrame >= 0 && gfFrame < sserafimGfBody.animation.curAnim.numFrames && sserafimGfBody.animation.curAnim.curFrame != gfFrame)
						sserafimGfBody.animation.curAnim.curFrame = gfFrame;
				}
				var curSym:String = (sserafimGf.anim != null && sserafimGf.anim.curSymbol != null) ? Std.string(sserafimGf.anim.curSymbol.name) : '';
				if (!inCutscene && curSym.length > 5 && sserafimGf.anim.finished)
				{
					sserafimGf.visible = false;
					sserafimGf.active = false;
					sserafimGfBody.visible = false;
					if (gf != null)
					{
						gf.visible = true;
						gf.alpha = 1.0;
						gf.skipDance = false;
						gf.specialAnim = false;
						if (!StringTools.startsWith(gf.getAnimationName(), 'sing')) gf.dance();
					}
				}
			}
		}
		#end

		if (viendoKick && checkKick()) viendoKick = false;

		// opponentStrums siempre ocultas (end_y_hud.lua)
		hideP2Strums();

		// HUD oculto durante cutscenes (la healthbar aparecia por encima de la intro)
		if (inCutscene) hideHudForCutscene();

	}

	// Poner en true SOLO para depurar: muestra en pantalla el ultimo error del lip-sync.
	static final SHOW_LIPSYNC_ERRORS:Bool = false;
	var lipErrTxt:FlxText;

	function showLipsyncError(msg:String):Void
	{
		if (lipErrTxt == null)
		{
			lipErrTxt = new FlxText(10, 80, FlxG.width - 20, '', 16);
			lipErrTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.RED, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			lipErrTxt.cameras = [camOther];
			add(lipErrTxt);
		}
		lipErrTxt.text = msg;
		lipErrTxt.visible = true;
	}

	var hudSaved:Map<String, Bool> = new Map<String, Bool>();

	function hideHudForCutscene():Void
	{
		if (camHUD != null) camHUD.visible = false;
		for (n in ['healthBar', 'iconP1', 'iconP2', 'scoreTxt', 'timeBar', 'timeTxt'])
		{
			var o:Dynamic = Reflect.getProperty(game, n);
			if (o != null && o.visible == true && !hudSaved.exists(n))
			{
				hudSaved.set(n, true);
				o.visible = false;
			}
		}
	}

	function restoreHudAfterCutscene():Void
	{
		if (camHUD != null) camHUD.visible = !ClientPrefs.data.hideHud;
		for (n in hudSaved.keys())
		{
			var o:Dynamic = Reflect.getProperty(game, n);
			if (o != null) o.visible = !ClientPrefs.data.hideHud;
		}
		hudSaved = new Map<String, Bool>();
		// iconP2 (Kazuha) se mantiene oculto hasta el sserafimKick final
		if (game.iconP2 != null) game.iconP2.visible = false;
	}

	// =============================================================================================
	// Update
	// =============================================================================================
	override function update(elapsed:Float)
	{
		// (sync del stage, GF, polvo y lip-sync se hace en postStageUpdate(), como onUpdatePost del Lua)

		// Camara con tween manual (FocusCamera)
		if (camTweeneando)
		{
			camGame.scroll.x = camHelper.x - camGame.width * 0.5;
			camGame.scroll.y = camHelper.y - camGame.height * 0.5;
		}

		// Zoom con tween manual (ZoomCamera): conserva el bop encima del zoom base
		if (zoomTweeneando)
		{
			var curBase:Float = zoomHelper.z;
			var bopDelta:Float = Math.max(0.0, camGame.zoom - ultimoZoomBase);
			ultimoZoomBase = curBase;
			defaultCamZoom = curBase;
			camGame.zoom = curBase + bopDelta;
		}

		// Skip de la cutscene
		updateSkip(elapsed);
	}

	// =============================================================================================
	// Beat
	// =============================================================================================
	override function beatHit()
	{
		if (lucesOn && lucesCols.length > 0 && lucesDurs.length > 0 && lucesAmts.length > 0)
		{
			var b:Int = Std.int(Math.max(0, curBeat));
			flashAtras(lucesAmts[b % lucesAmts.length], lucesDurs[b % lucesDurs.length], lucesCols[b % lucesCols.length]);
		}

		// SetCameraBop
		if (game.camZooming && ClientPrefs.data.camZooms && bopRate > 0 && bopIntensity > 0 && ((curBeat + bopOffset) % bopRate == 0))
		{
			var defZ:Float = defaultCamZoom;
			if (camGame.zoom < 1.35 * defZ)
			{
				camGame.zoom += 0.015 * bopIntensity * defZ;
				camHUD.zoom += 0.03 * bopIntensity;
			}
		}
	}

	// =============================================================================================
	// Eventos
	// =============================================================================================
	function parse(value1:String):Dynamic
	{
		if (value1 == null || value1.indexOf('{') < 0) return null;
		try { return Json.parse(value1); }
		catch (e:Dynamic) { return null; }
	}

	function num(o:Dynamic, field:String, def:Float):Float
	{
		if (o == null || !Reflect.hasField(o, field)) return def;
		var v:Dynamic = Reflect.field(o, field);
		var f:Float = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? def : f;
	}

	function str(o:Dynamic, field:String, def:String):String
	{
		if (o == null || !Reflect.hasField(o, field)) return def;
		return Std.string(Reflect.field(o, field));
	}

	function bool(o:Dynamic, field:String, def:Bool):Bool
	{
		if (o == null || !Reflect.hasField(o, field)) return def;
		var v:Dynamic = Reflect.field(o, field);
		return (v == true || Std.string(v) == 'true');
	}

	function boolArray(o:Dynamic, field:String):Array<Bool>
	{
		var out:Array<Bool> = [];
		if (o == null || !Reflect.hasField(o, field)) return out;
		var arr:Array<Dynamic> = Reflect.field(o, field);
		for (v in arr) out.push(v == true || Std.string(v) == 'true');
		return out;
	}

	override function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float)
	{
		var j:Dynamic = parse(value1);
		switch (eventName)
		{
			case 'sserafimDark':
				ponerDark(num(j, 'amount', 0), num(j, 'duration', 0));

			case 'sserafimLights':
				flashCamion(num(j, 'amount', 0), num(j, 'duration', 0.5));

			case 'sserafimPulseLights':
				lucesOn = bool(j, 'enabled', false);
				if (j != null && Reflect.hasField(j, 'colors') && Reflect.hasField(j, 'durations') && Reflect.hasField(j, 'intensities'))
				{
					lucesCols = []; lucesDurs = []; lucesAmts = [];
					var cs:Array<Dynamic> = Reflect.field(j, 'colors');
					var ds:Array<Dynamic> = Reflect.field(j, 'durations');
					var ins:Array<Dynamic> = Reflect.field(j, 'intensities');
					for (c in cs) lucesCols.push(Std.string(c));
					for (d in ds) lucesDurs.push(Std.parseFloat(Std.string(d)));
					for (i in ins) lucesAmts.push(Std.parseFloat(Std.string(i)));
				}

			case 'sserafimCover':
				ponerCover(bool(j, 'visible', false));

			case 'sserafimFlash':
				camGame.flash(FlxColor.WHITE, num(j, 'duration', 1.0), null, true);

			case 'sserafimKick':
				if (bool(j, 'final', false))
				{
					FlxG.sound.play(Paths.sound('doorKick2'), 1.0);
					if (!ClientPrefs.data.hideHud && game.iconP2 != null) game.iconP2.visible = true;
					if (gf != null)
					{
						gf.visible = true;
						gf.alpha = 1.0;
						gf.skipDance = false;
						gf.specialAnim = false;
						gf.dance();
					}
					#if flxanimate
					if (sserafimGf != null) { sserafimGf.visible = false; sserafimGf.active = false; }
					if (sserafimBf != null) { sserafimBf.visible = false; sserafimBf.active = false; }
					#end
					if (sserafimGfBody != null) sserafimGfBody.visible = false;
					viendoKick = true;
					limpiarPolvo();
					callGirls('yunjinKickFinal');
				}
				else
				{
					FlxG.sound.play(Paths.sound('doorKick1'), 1.0);
					callGirls('yunjinKickPrimero');
				}

			// sserafimShow / sserafimSing / sserafimBeautiful: los maneja data/spaghetti/lipsync.hx (onEvent)

			case 'sserafimGuitarVibration':
				var dur:Float = num(j, 'duration', 0.5);
				if (dur > 0) camGame.shake(0.002, dur);

			case 'sserafimEnd':
				startEnd();

			case 'FocusCamera':
				focusCamera(j);

			case 'ZoomCamera':
				zoomCamera(j);

			case 'SetCameraBop':
				if (j != null)
				{
					bopIntensity = num(j, 'intensity', 1.0);
					bopRate = Math.floor(num(j, 'rate', 4));
					bopOffset = Math.floor(num(j, 'offset', 0));
				}
				game.camZoomingMult = 0;

			case 'SetHealthIcon':
				if (j != null)
				{
					var id:String = str(j, 'id', '');
					if (id != '')
					{
						var ch:Int = Std.int(num(j, 'char', 1));
						var icon = (ch == 0) ? game.iconP1 : game.iconP2;
						if (icon != null)
						{
							icon.changeIcon(id);
							if (Reflect.hasField(j, 'flipX')) icon.flipX = bool(j, 'flipX', false);
						}
					}
				}
		}
	}

	// =============================================================================================
	// Camara
	// =============================================================================================
	function camTarget(onTarget:Bool, snap:Bool):Void
	{
		FlxG.camera.target = onTarget ? camFollow : null;
		if (snap) FlxG.camera.snapToTarget();
	}

	function moverCam(tx:Float, ty:Float, dur:Float, ease:String):Void
	{
		if (camTwX != null) camTwX.cancel();
		if (camTwY != null) camTwY.cancel();
		camFollow.x = tx;
		camFollow.y = ty;

		if (dur <= 0)
		{
			camTweeneando = false;
			camTarget(true, true);
			return;
		}

		var rate:Float = game.playbackRate;
		if (rate <= 0) rate = 1;
		var adjDur:Float = dur / rate;

		camHelper.x = camGame.scroll.x + camGame.width * 0.5;
		camHelper.y = camGame.scroll.y + camGame.height * 0.5;
		camTweeneando = true;
		camTarget(false, false);
		camTwX = FlxTween.tween(camHelper, {x: tx}, adjDur, {ease: getEase(ease), onComplete: function(_) { camTweeneando = false; camTarget(true, false); }});
		camTwY = FlxTween.tween(camHelper, {y: ty}, adjDur, {ease: getEase(ease)});
	}

	function hacerZoom(zoomVal:Float, dur:Float, direct:Bool, ease:String):Void
	{
		if (zoomTw != null) zoomTw.cancel();
		var targetZoom:Float = zoomVal * (direct ? 1.0 : BASE_STAGE_ZOOM);
		if (dur <= 0)
		{
			zoomTweeneando = false;
			zoomHelper.z = targetZoom;
			ultimoZoomBase = targetZoom;
			defaultCamZoom = targetZoom;
			camGame.zoom = targetZoom;
			return;
		}

		var rate:Float = game.playbackRate;
		if (rate <= 0) rate = 1;

		ultimoZoomBase = defaultCamZoom;
		zoomHelper.z = ultimoZoomBase;
		zoomTweeneando = true;
		zoomTw = FlxTween.tween(zoomHelper, {z: targetZoom}, dur / rate, {ease: getEase(ease), onComplete: function(_) { zoomTweeneando = false; defaultCamZoom = zoomHelper.z; }});
	}

	function armarEase(easeName:String, easeDir:String):String
	{
		var e:String = (easeName != null ? easeName : 'linear').toLowerCase();
		var d:String = (easeDir != null ? easeDir : 'Out').toLowerCase();
		if (e == 'linear' || e == 'instant' || e == 'classic') return 'linear';
		if (e == 'cubic') e = 'cube';
		var suf:String = 'Out';
		if (d == 'in') suf = 'In';
		else if (d == 'inout') suf = 'InOut';
		return e + suf;
	}

	function focusCamera(j:Dynamic):Void
	{
		if (j == null) return;
		var ch:Int = Std.int(num(j, 'char', 0));
		var ox:Float = num(j, 'x', 0);
		var oy:Float = num(j, 'y', 0);
		var durSteps:Float = num(j, 'duration', 4);
		var easeName:String = str(j, 'ease', 'CLASSIC');
		var easeDir:String = str(j, 'easeDir', 'Out');

		var pt:Array<Float> = (ch >= 0 && ch < focusPoints.length) ? focusPoints[ch] : [0.0, 0.0];
		var tx:Float = (ch == -1) ? ox : (pt[0] + ox);
		var ty:Float = (ch == -1) ? oy : (pt[1] + oy);

		game.isCameraOnForcedPos = true;

		switch (easeName.toUpperCase())
		{
			case 'CLASSIC':
				if (camTwX != null) camTwX.cancel();
				if (camTwY != null) camTwY.cancel();
				camTweeneando = false;
				camTarget(true, false);
				camFollow.x = tx;
				camFollow.y = ty;
			case 'INSTANT':
				moverCam(tx, ty, 0, 'linear');
			default:
				moverCam(tx, ty, (Conductor.stepCrochet * durSteps) / 1000.0, armarEase(easeName, easeDir));
		}
	}

	function zoomCamera(j:Dynamic):Void
	{
		if (j == null || !Reflect.hasField(j, 'zoom')) return;
		var z:Float = num(j, 'zoom', 1);
		var durSteps:Float = num(j, 'duration', 4);
		var direct:Bool = (str(j, 'mode', 'direct') == 'direct');
		var easeName:String = str(j, 'ease', 'linear');
		var easeDir:String = str(j, 'easeDir', 'Out');

		if (easeName == 'INSTANT') hacerZoom(z, 0, direct, 'linear');
		else hacerZoom(z, (Conductor.stepCrochet * durSteps) / 1000.0, direct, armarEase(easeName, easeDir));
	}

	// =============================================================================================
	// Tweens / helpers
	// =============================================================================================
	function getEase(name:String):Float->Float
	{
		if (name == null) return FlxEase.linear;
		var f:Dynamic = Reflect.getProperty(FlxEase, name);
		return (f != null) ? f : FlxEase.linear;
	}

	function track(t:FlxTween):FlxTween
	{
		allTweens.push(t);
		return t;
	}

	// =============================================================================================
	// Shaders y efectos del stage (portado de sserafim.lua)
	// =============================================================================================
	function syncShaders(forceAll:Bool):Void
	{
		if (!useShaders) return;
		var d = sv.dark; var tr = sv.truck; var pu = sv.pulse;
		var br = sv.bri; var hu = sv.hue; var co = sv.con; var sa = sv.sat;
		if (!forceAll && d == lastSh[0] && tr == lastSh[1] && pu == lastSh[2]
			&& br == lastSh[3] && hu == lastSh[4] && co == lastSh[5] && sa == lastSh[6]) return;
		lastSh = [d, tr, pu, br, hu, co, sa];
		for (sh in shTargets)
		{
			if (sh == null) continue;
			sh.setFloat('darkAmt', d);
			sh.setFloat('truckStrength', tr);
			sh.setFloat('pulseStrength', pu);
			sh.setFloat('brightness', br);
			sh.setFloat('hue', hu);
			sh.setFloat('contrast', co);
			sh.setFloat('saturation', sa);
		}
	}

	function setLightColor(r:Float, g:Float, b:Float):Void
	{
		if (!useShaders) return;
		if (r == lastLight[0] && g == lastLight[1] && b == lastLight[2]) return;
		lastLight = [r, g, b];
		for (sh in shTargets) if (sh != null) sh.setFloatArray('lightColor', [r, g, b]);
	}

	function syncFloor():Void
	{
		var sx:Float = camGame.scroll.x;
		var sy:Float = camGame.scroll.y;
		var visMask:Int = (perspectiveFloor.visible ? 1 : 0) | (perspectiveFloorCut.visible ? 2 : 0);
		if (sx == lastScrollX && sy == lastScrollY && visMask == lastFlVis) return;
		lastScrollX = sx;
		lastScrollY = sy;
		lastFlVis = visMask;
		if (visMask == 0) return;

		var botX:Float = 760.0 + sx * (1.0 - 1.05);
		var botY:Float = 1375.0 + sy * (1.0 - 1.05);
		var topX:Float = 790.0 + sx * (1.0 - 0.93);
		var topY:Float = 625.0 + sy * (1.0 - 0.93);
		var distX:Float = topX - botX;
		var alt:Float = botY - topY;
		var px:Float = (botX + topX) * 0.5 - 2681.0;
		var syScale:Float = alt / 754.0;
		var skew:Float = distX / 5362.0;

		if (perspectiveFloor.visible)
		{
			perspectiveFloor.setPosition(px, topY);
			perspectiveFloor.scale.y = syScale;
			if (useShaders && floorSh != null) floorSh.setFloat('floorSkewU', skew);
		}
		if (perspectiveFloorCut.visible)
		{
			perspectiveFloorCut.setPosition(px, topY);
			perspectiveFloorCut.scale.y = syScale;
			if (useShaders && floorCutSh != null) floorCutSh.setFloat('floorSkewU', skew);
		}
	}

	function hexRgb(hexStr:String):{hex6:String, rgb:Array<Float>}
	{
		var clean:String = (hexStr != null ? hexStr : 'FFFFFFFF');
		clean = StringTools.replace(StringTools.replace(clean, '0x', ''), '#', '');
		if (clean.length == 6) clean = 'FF' + clean;
		var r:Float = Std.parseInt('0x' + clean.substr(2, 2)) / 255.0;
		var g:Float = Std.parseInt('0x' + clean.substr(4, 2)) / 255.0;
		var b:Float = Std.parseInt('0x' + clean.substr(6, 2)) / 255.0;
		return {hex6: clean.substr(2, 6), rgb: [r, g, b]};
	}

	function ponerCover(vis:Bool):Void
	{
		if (solidCover == null) return;
		solidCover.alpha = vis ? 1.0 : 0.0;
	}

	function fadeCover(a:Float, dur:Float, ease:String):Void
	{
		if (solidCover == null) return;
		if (coverTw != null) coverTw.cancel();
		coverTw = FlxTween.tween(solidCover, {alpha: a}, dur, {ease: getEase(ease)});
	}

	function ponerDark(amt:Float, dur:Float):Void
	{
		if (darkTw != null) darkTw.cancel();
		if (dur <= 0) sv.dark = amt;
		else darkTw = FlxTween.tween(sv, {dark: amt}, dur, {ease: FlxEase.sineInOut});
	}

	function ponerHsb(b:Float, h:Float, c:Float, s:Float, dur:Float, ease:String):Void
	{
		for (t in hsbTw) if (t != null) t.cancel();
		hsbTw = [];
		if (dur <= 0)
		{
			sv.bri = b; sv.hue = h; sv.con = c; sv.sat = s;
		}
		else
		{
			hsbTw.push(FlxTween.tween(sv, {bri: b, hue: h, con: c, sat: s}, dur, {ease: getEase(ease != null ? ease : 'sineOut')}));
		}
	}

	var truckTw:FlxTween;
	var truckL1Tw:FlxTween;
	var truckL2Tw:FlxTween;

	function flashCamion(amt:Float, dur:Float):Void
	{
		if (truckTw != null) truckTw.cancel();
		if (truckL1Tw != null) truckL1Tw.cancel();
		if (truckL2Tw != null) truckL2Tw.cancel();
		truckLight1.alpha = amt;
		truckLight2.alpha = amt;
		sv.truck = amt;
		truckL1Tw = FlxTween.tween(truckLight1, {alpha: 0}, dur, {ease: FlxEase.cubeInOut});
		truckL2Tw = FlxTween.tween(truckLight2, {alpha: 0}, dur, {ease: FlxEase.cubeInOut});
		truckTw = FlxTween.tween(sv, {truck: 0}, dur, {ease: FlxEase.cubeInOut});
	}

	var bkColTw:FlxTween;
	var bkWhtTw:FlxTween;
	var bkShTw:FlxTween;

	function flashAtras(amt:Float, dur:Float, colHex:String):Void
	{
		if (bkColTw != null) bkColTw.cancel();
		if (bkWhtTw != null) bkWhtTw.cancel();
		if (bkShTw != null) bkShTw.cancel();
		var c = hexRgb(colHex);
		ultColor = c.rgb;
		backLightColor.color = FlxColor.fromString('0xFF' + c.hex6);
		backLightColor.alpha = amt * 0.8;
		backLightWhite.alpha = amt * 0.7;
		sv.pulse = amt * 0.8;
		setLightColor(c.rgb[0], c.rgb[1], c.rgb[2]);
		bkColTw = FlxTween.tween(backLightColor, {alpha: 0}, dur, {ease: FlxEase.cubeInOut});
		bkWhtTw = FlxTween.tween(backLightWhite, {alpha: 0}, dur, {ease: FlxEase.cubeInOut});
		bkShTw = FlxTween.tween(sv, {pulse: 0}, dur, {ease: FlxEase.cubeInOut});
	}

	// ---- Polvo ----
	function setDustVis(vis:Bool):Void
	{
		dustAllowed = vis;
		for (d in dust) if (d != null) { d.visible = vis; d.active = vis; }
	}

	function resetPolvo():Void
	{
		if (truckDoor != null) truckDoor.visible = false;
		ponerDark(0, 0);
		ponerHsb(-24, 6, -26, -74, 0, 'linear');

		dustAllowed = true;
		var rs = function(idx:Int, py:Float, vx:Float)
		{
			var d = (idx < dust.length) ? dust[idx] : null;
			if (d != null)
			{
				FlxTween.cancelTweensOf(d);
				FlxTween.cancelTweensOf(d.velocity);
				d.setPosition(-650, py);
				d.velocity.x = vx;
				d.alpha = 1;
				d.visible = true;
				d.active = true;
			}
		};
		rs(0, -400, 350);
		rs(1, -450, -300);
		rs(2, -600, -200);
		rs(3, -1500, -150);

		syncShaders(true);
		callGirls('resetYunjinPuerta');
	}

	function limpiarPolvo():Void
	{
		ponerHsb(0, 0, 0, 0, 24.0, 'sineOut');
		var dis = function(idx:Int, dy:Float, dur:Float)
		{
			var d = (idx < dust.length) ? dust[idx] : null;
			if (d != null)
			{
				FlxTween.tween(d, {alpha: 0, y: d.y + dy}, dur, {ease: FlxEase.sineOut, onComplete: function(_) { d.visible = false; d.active = false; }});
				FlxTween.tween(d.velocity, {x: 0}, dur, {ease: FlxEase.sineOut});
			}
		};
		dis(0, 100, 20.0);
		dis(1, 200, 16.0);
		dis(2, 150, 24.0);
		dis(3, 100, 16.0);
	}

	function checkKick():Bool
	{
		var y:Dynamic = game.variables.get('yunjin');
		if (y == null) return false;
		var curA:String = y.getAnimationName();
		var cf:Int = 0;
		#if flxanimate
		if (y.isAnimateAtlas && y.atlas != null && y.atlas.anim != null)
		{
			var ai:Dynamic = y.atlas.anim;
			if (ai.curInstance != null && ai.curInstance.symbol != null) cf = Std.int(ai.curInstance.symbol._curFrame);
			else { try { cf = Std.int(Reflect.getProperty(ai, 'curFrame')); } catch (e:Dynamic) { cf = 0; } }
		}
		#end
		if ((curA == 'kick2' && cf >= 23) || curA != 'kick2')
		{
			if (truckDoor != null) truckDoor.visible = true;
			return true;
		}
		return false;
	}

	// =============================================================================================
	// Cutscene (portado de cutscene.lua + funciones del stage)
	// =============================================================================================
	function aplicarCutscene(cutOn:Bool):Void
	{
		enCutscene = cutOn;
		// startIntro puede ejecutarse antes de createPost(), donde se crea frontStool.
		// Protegemos las referencias y sincronizamos su visibilidad al terminar createPost().
		if (truck != null) truck.visible = !cutOn;
		if (truckDoor != null) truckDoor.visible = false;
		if (backTables != null) backTables.visible = !cutOn;
		if (backStools != null) backStools.visible = !cutOn;
		if (frontStool != null) frontStool.visible = !cutOn;
		if (backTablesCutscene != null) backTablesCutscene.visible = cutOn;
		if (burgerCutscene != null) burgerCutscene.visible = cutOn;
		#if flxanimate
		if (sserafimCutscene != null)
		{
			sserafimCutscene.visible = cutOn;
			sserafimCutscene.active = cutOn;
		}
		#end
		if (perspectiveFloor != null) perspectiveFloor.visible = !cutOn;
		if (perspectiveFloorCut != null) perspectiveFloorCut.visible = cutOn;
		if (gf != null)
		{
			gf.visible = false;
			gf.alpha = 1.0;
		}

		// FIX: startIntro() puede correr antes de createPost(), cuando 'girls' aun es null.
		// Al terminar createPost() se vuelve a llamar aplicarCutscene(true), asi que queda sincronizado.
		if (cutOn)
		{
			girlsVis(false, false, false, false, false);
			setDustVis(false);
		}
		else girlsVis(true, false, false, false, false);
		lastScrollX = -999999.0; // fuerza resync del piso
		syncFloor();
	}

	function playCutsceneMain():Void
	{
		#if flxanimate
		if (sserafimCutscene == null) return;
		sserafimCutscene.visible = true;
		sserafimCutscene.active = true;
		sserafimCutscene.anim.play('cutscene', true, false, 0);
		sserafimCutscene.anim.resume();
		#end
	}

	function playGfBfGetUp(f:Int):Void
	{
		#if flxanimate
		if (sserafimGf != null)
		{
			sserafimGf.visible = true;
			sserafimGf.active = true;
			sserafimGf.anim.play('getup', true, false, f);
			sserafimGf.anim.resume();
		}

		if (sserafimGfBody != null && sserafimGfBody.animation.exists('getup'))
		{
			sserafimGfBody.visible = true;
			sserafimGfBody.animation.play('getup', true, false, f);
		}

		if (sserafimBf != null)
		{
			sserafimBf.visible = true;
			sserafimBf.active = true;
			sserafimBf.anim.play('getup', true, false, f);
			sserafimBf.anim.resume();
		}
		#end
	}

	function playGfBfStatic():Void
	{
		#if flxanimate
		if (sserafimGf != null)
		{
			sserafimGf.visible = true;
			sserafimGf.active = true;
			sserafimGf.anim.play('static', true, false, 0);
		}
		if (sserafimGfBody != null && sserafimGfBody.animation.exists('static'))
		{
			sserafimGfBody.visible = true;
			sserafimGfBody.animation.play('static', true, false, 0);
		}
		if (sserafimBf != null)
		{
			sserafimBf.visible = true;
			sserafimBf.active = true;
			sserafimBf.anim.play('static', true, false, 0);
		}
		#end
	}

	function iniciarDesdeRestart():Void
	{
		aplicarCutscene(false);
		resetPolvo();
		hacerZoom(0.55, 1.0, true, 'circOut');
		moverCam(1070, 470, 1.0, 'circOut');
		playGfBfGetUp(23);
	}

	function hideP2Strums():Void
	{
		// BaseStage.game is Dynamic in this engine fork. Read the strum group
		// through Reflect, then cast its members to an iterable array.
		if (game == null) return;
		var strumGroup:Dynamic = Reflect.field(game, "opponentStrums");
		if (strumGroup == null) return;
		var strumMembers:Array<Dynamic> = cast Reflect.field(strumGroup, "members");
		if (strumMembers == null) return;
		for (strum in strumMembers)
		{
			if (strum == null) continue;
			strum.visible = false;
			strum.alpha = 0;
		}
	}

	function terminarCutscene():Void
	{
		enCutscene = false;
		cutsceneSkipped = true;
		inCutscene = false;
		canPause = true;
		restoreHudAfterCutscene();
		if (skipTxt != null) skipTxt.visible = false;
		hideP2Strums();
		startCountdown();
	}

	function startTimer(sec:Float, cb:Void->Void):Void
	{
		cutTimers.push(new FlxTimer().start(sec, function(_) cb()));
	}

	function limpiarTimers():Void
	{
		for (t in cutTimers) if (t != null) t.cancel();
		cutTimers = [];
	}

	function startIntro():Void
	{
		enCutscene = true;
		cutsceneSkipped = false;
		canSkipCutscene = false;
		skipRevealStarted = false;
		graceTimer = 0.25;

		inCutscene = true;
		canPause = false;
		camHUD.visible = false;
		aplicarCutscene(true);

		#if mobile
		var skipMsg:String = 'Tap to Skip';
		#else
		var skipMsg:String = 'Press ACCEPT to Skip';
		#end
		skipTxt = new FlxText(0, 0, 0, skipMsg, 34);
		skipTxt.setFormat(Paths.font('vcr.ttf'), 34, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		skipTxt.borderSize = 2;
		skipTxt.cameras = [camOther];
		skipTxt.alpha = 0;
		skipTxt.x = camOther.width - skipTxt.width - 36;
		skipTxt.y = camOther.height - 64;
		add(skipTxt);

		playCutsceneMain();
		hacerZoom(0.5, 0, true, 'linear');
		moverCam(660, -200, 0, 'linear');
		camGame.fade(FlxColor.BLACK, 3.0, true, null, true);

		hacerZoom(0.7, 3.0, true, 'circOut');
		moverCam(660, 300, 3.0, 'circOut');

		var fps:Float = 24.0;
		startTimer(20.0 / fps, function() cutSnd = FlxG.sound.play(Paths.sound('cutscene/startCutscene'), 1.0));
		startTimer(245.0 / fps, function() ponerDark(0.2, 0.01));
		startTimer(251.0 / fps, function() ponerDark(0, 0.8));
		startTimer(406.0 / fps, function() ponerDark(0.2, 0.01));
		startTimer(411.0 / fps, function() ponerDark(0, 0.8));
		startTimer(499.0 / fps, function()
		{
			cutsceneSkipped = true;
			canSkipCutscene = false;
			if (skipTxt != null) FlxTween.tween(skipTxt, {alpha: 0}, 0.5, {ease: FlxEase.quadIn});
			ponerHsb(55, 0, -30, 0, 49.0 / 24.0, 'sineOut');
		});
		startTimer(548.0 / fps, function() ponerHsb(66, 10, -17, 0, 15.0 / 24.0, 'expoIn'));
		startTimer(563.0 / fps, function()
		{
			ponerHsb(0, 0, 0, 0, 0, 'linear');
			camGame.fade(FlxColor.WHITE, 30.0 / 24.0, true, null, true);
			ponerCover(true);
			aplicarCutscene(false);
		});
		startTimer(650.0 / fps, function()
		{
			hacerZoom(0.7, 0, true, 'linear');
			hacerZoom(0.55, 3.0, true, 'circOut');
			moverCam(1070, 470, 0, 'linear');
			resetPolvo();
			fadeCover(0, 3.0, 'sineOut');
			playGfBfStatic();
		});
		startTimer(710.0 / fps, function() playGfBfGetUp(0));
		startTimer(730.0 / fps, function() terminarCutscene());
	}

	function saltarIntro():Void
	{
		if (cutsceneSkipped) return;
		cutsceneSkipped = true;
		canSkipCutscene = false;

		camOther.fade(FlxColor.BLACK, 0.5, false, null, true);
		if (cutSnd != null) cutSnd.fadeOut(0.5, 0);
		new FlxTimer().start(0.5, function(_)
		{
			camOther.fade(FlxColor.BLACK, 0.5, true, null, true);
			limpiarTimers();
			if (cutSnd != null) cutSnd.stop();
			if (coverTw != null) coverTw.cancel();
			ponerCover(false);
			iniciarDesdeRestart();
			terminarCutscene();
		});
	}

	function updateSkip(elapsed:Float):Void
	{
		if (!enCutscene || cutsceneSkipped || skipTxt == null) return;
		if (graceTimer > 0)
		{
			graceTimer = Math.max(0, graceTimer - elapsed);
			return;
		}

		var touched:Bool = (FlxG.mouse != null && FlxG.mouse.justPressed);
		#if mobile
		if (!touched && FlxG.touches != null)
			for (t in FlxG.touches.list) if (t != null && t.justPressed) { touched = true; break; }
		#end

		// FIX: game.controls puede ser null en este fork -> caer a Controls.instance
		var ctl:Dynamic = (game != null) ? Reflect.getProperty(game, 'controls') : null;
		if (ctl == null) ctl = backend.Controls.instance;
		var accept:Bool = (ctl != null && ctl.ACCEPT == true);

		if (touched || accept)
		{
			if (!canSkipCutscene)
			{
				if (!skipRevealStarted)
				{
					skipRevealStarted = true;
					FlxTween.tween(skipTxt, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
					new FlxTimer().start(0.5, function(_) canSkipCutscene = true);
				}
			}
			else saltarIntro();
		}
	}

	// =============================================================================================
	// Final "SEE YOU"
	// =============================================================================================
	function startEnd():Void
	{
		if (finActivado) return;
		finActivado = true;
		finListo = false;
		FlxG.sound.play(Paths.sound('cutscene/end1'), 1.0);
		new FlxTimer().start(0.05, function(_)
		{
			if (seeYou1 != null) seeYou1.visible = true;
			ponerCover(true);
			camHUD.visible = false;
			inCutscene = true;
			canPause = false;
		});
		new FlxTimer().start(4.0, function(_)
		{
			if (seeYou1 != null) seeYou1.visible = false;
			if (seeYou2 != null) seeYou2.visible = true;
			FlxG.sound.play(Paths.sound('cutscene/end2'), 1.0);
		});
		new FlxTimer().start(8.0, function(_)
		{
			if (seeYou1 != null) seeYou1.visible = false;
			if (seeYou2 != null) seeYou2.visible = false;
		});
		new FlxTimer().start(9.0, function(_)
		{
			finListo = true;
			endSong();
		});
	}

	/** Reemplaza onEndSong de end_y_hud.lua: no deja terminar la cancion hasta que acabe el SEE YOU */
	function endSongHook():Void
	{
		if (finActivado && !finListo) return;
		endSong();
	}

	// =============================================================================================
	// Pausa: congela tweens/timers propios
	// =============================================================================================
	override function openSubState(SubState:flixel.FlxSubState)
	{
		if (paused) setPausedState(true);
	}

	override function closeSubState()
	{
		if (paused) setPausedState(false);
	}

	function setPausedState(p:Bool):Void
	{
		for (t in cutTimers) if (t != null) t.active = !p;
	}

	// ---------------------------------------------------------------------------------------------
	// Puente hacia data/spaghetti/lipsync.hx (HScript)
	// ---------------------------------------------------------------------------------------------
	function callGirls(fn:String, ?args:Array<Dynamic>):Void
	{
		if (game != null) game.callOnHScript(fn, args != null ? args : []);
	}

	function girlsVis(a:Bool, b:Bool, c:Bool, d:Bool, e:Bool):Void
	{
		if (game == null) return;
		var v:Array<Bool> = [a, b, c, d, e];
		game.variables.set('sserGirlsVis', v); // lipsync.hx lo lee al crearse
		game.callOnHScript('visibilidadChicas', [v]);
	}

	static function setVis(o:Dynamic, v:Bool):Void
	{
		try { o.visible = v; }
		catch (e:Dynamic) { Reflect.setProperty(o, 'visible', v); }
	}

	// Oculta capas Clipper/Clipped de un atlas (cabeza/pelo de la GF quedan detras del camion)
	static function hideClipperLayers(spr:Dynamic, killClippedToo:Bool):Void
	{
		if (spr == null || spr.anim == null) return;
		if (spr.anim.metadata != null)
		{
			spr.anim.metadata.skipFilters = true;
			spr.anim.metadata.showHiddenLayers = false;
		}

		var clearSym = function(sym:Dynamic)
		{
			try {
			if (sym == null || sym.timeline == null) return;
			var normalType:Dynamic = null;
			var layers:Dynamic = sym.timeline.getList();
			for (layer in (layers : Array<Dynamic>))
			{
				if (layer == null) continue;
				var lt:String = (layer.type != null) ? Type.enumConstructor(layer.type) : '';
				if (killClippedToo)
				{
					if (lt == 'Clipper' || lt == 'Clipped' || layer._clipper != null)
					{
						if (normalType == null && layer.type != null)
							normalType = Type.createEnum(Type.getEnum(layer.type), 'Normal');
						layer._clipper = null;
						if (normalType != null) layer.type = normalType;
						layer._correctClip = true;
						setVis(layer, false);
					}
				}
				else if (lt == 'Clipper')
				{
					layer._correctClip = true;
					setVis(layer, false);
				}
				else if (lt == 'Clipped' || layer._clipper != null)
				{
					if (normalType == null && layer.type != null)
						normalType = Type.createEnum(Type.getEnum(layer.type), 'Normal');
					layer._clipper = null;
					if (normalType != null) layer.type = normalType;
				}
			}
			} catch (e:Dynamic) { trace('[Sserafim] hideClipperLayers: ' + e); }
		};

		if (spr.anim.symbolDictionary != null)
		{
			var dict:Dynamic = spr.anim.symbolDictionary;
			for (sym in (dict : haxe.Constraints.IMap<String, Dynamic>))
				clearSym(sym);
		}
		clearSym(spr.anim.curSymbol);
	}

	override function destroy()
	{
		if (postHooked) FlxG.signals.postUpdate.remove(postStageUpdate);
		postHooked = false;
		limpiarTimers();
		super.destroy();
	}
}
