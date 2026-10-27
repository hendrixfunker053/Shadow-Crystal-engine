package states;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
#if mobile
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
#end

/**
 * Easter egg: "The Egg Room" (port nativo del mod Lua a Haxe).
 *
 * Se abre desde MainMenuState tocando 17 veces el texto "Shadow Crystal Engine".
 * Solo se usa a Kris. En mobile se muestran controles táctiles (joystick + Z + X).
 *
 * Controles:
 *   Flechas / WASD (UI) / joystick -> moverse
 *   Z / ACCEPT           -> interactuar / avanzar texto
 *   X / SHIFT            -> correr (mantener)
 *   Izquierda / Derecha  -> elegir Yes / No
 *   ESC / BACK           -> salir
 */
class EggRoomState extends MusicBeatState
{
	// ------------------------------------------------------------------
	//  Logro
	// ------------------------------------------------------------------
	public static inline var ACHIEVEMENT_ID:String = 'there_is_a_man_here';

	#if ACHIEVEMENTS_ALLOWED
	/**
	 * Registra el logro en la lista de Achievements. Es seguro llamarlo varias veces.
	 * Se llama desde MainMenuState, AchievementsMenuState y desde este state,
	 * así aparece en el menú de logros aunque Achievements.hx no se haya tocado.
	 *
	 * El icono sale de assets/shared/images/achievements/there_is_a_man_here(-pixel).png
	 */
	public static function registerAchievement():Void
	{
		if (Achievements.achievements.exists(ACHIEVEMENT_ID))
			return;

		var maxID:Int = -1;
		for (a in Achievements.achievements)
		{
			if (a.ID != null && a.ID > maxID)
				maxID = a.ID;
		}

		Achievements.achievements.set(ACHIEVEMENT_ID, {
			name: "Well, there is a man here",
			description: "Persist on the signature. Somewhere in between, a man waits behind a tree.",
			hidden: false,
			ID: maxID + 1
		});
	}
	#end

	// ------------------------------------------------------------------
	//  Ajustes rápidos
	// ------------------------------------------------------------------
	static inline var DEBUG_TOUCH:Bool = false; // pon false cuando el joystick funcione
	static inline var TEXT_SIZE:Int = 16; // tamaño del texto de los diálogos
	static inline var WORLD_ZOOM:Float = 0.75; // mismo defaultZoom que la stage original
	static inline var WALK_SPEED:Float = 300;
	static inline var RUN_SPEED:Float = 550;
	static inline var EGGS_SAVE_KEY:String = 'eggRoomEggs';

	static final MUSIC:Array<String> = ['chapter1_2', 'chapter3', 'chapter4', 'chapter5'];

	// ------------------------------------------------------------------
	//  Cámaras
	// ------------------------------------------------------------------
	var camWorld:FlxCamera;
	var camHUD:FlxCamera;
	var camFollow:FlxObject;

	// ------------------------------------------------------------------
	//  Mundo
	// ------------------------------------------------------------------
	var ground:FlxSprite;
	var treeStump:FlxSprite;
	var treeBrush:FlxSprite;
	var treeLeaves:FlxSprite;
	var treeParticle:FlxSprite;
	var char:FlxSprite;
	var charBox:FlxObject;

	// Colisiones (se portaron tal cual del roomScript.lua)
	var wallsLeft:Array<FlxObject> = [];
	var wallsRight:Array<FlxObject> = [];
	var wallsUp:Array<FlxObject> = [];
	var wallsDown:Array<FlxObject> = [];

	var treeBoxTop:FlxObject;
	var treeBoxBottom:FlxObject;
	var treeBoxLeft:FlxObject;
	var treeBoxRight:FlxObject;

	var manBoxTop:FlxObject;
	var manBoxBottom:FlxObject;
	var manBoxLeft:FlxObject;
	var manBoxRight:FlxObject;
	var manBoxFull:FlxObject;
	var manPieces:Array<FlxObject> = []; // las cosas que se apartan cuando hablas con él

	var exitBox:FlxObject;

	// ------------------------------------------------------------------
	//  UI de diálogo (camHUD)
	// ------------------------------------------------------------------
	var textBox:FlxSprite;
	var boxText:FlxText;
	var yesText:FlxText;
	var noText:FlxText;
	var soul:FlxSprite;

	var dialogues:Array<String> = [];

	// ------------------------------------------------------------------
	//  Estado del juego
	// ------------------------------------------------------------------
	var canControl:Bool = true;
	var moveSpeed:Float = 350;
	var direction:String = 'up';
	var spokenTo:Int = 0;
	var inDialogue:Bool = false;
	var dia:Int = 0;
	var select:Int = 0;
	var selecting:Bool = false;
	var eggs:Int = 0;
	var leaving:Bool = false;

	var charBehindTree:Null<Bool> = null;
	var eggMusic:FlxSound = null;

	// Animación del árbol (sin timers para no dejar nada vivo al salir)
	var particleT:Float = 1;
	var particleFlying:Bool = false;
	var brushT:Float = 0.5;
	var leavesT:Float = 0.75;

	// ------------------------------------------------------------------
	//  Input táctil (siempre declarado; solo se rellena en mobile)
	// ------------------------------------------------------------------
	var tLeft:Bool = false;
	var tRight:Bool = false;
	var tUp:Bool = false;
	var tDown:Bool = false;
	var tZ:Bool = false;
	var tX:Bool = false;
	var pLeft:Bool = false;
	var pRight:Bool = false;
	var pZ:Bool = false;

	var tZJust:Bool = false; // Z táctil recién presionada (o toque sobre la caja de texto)

	var tMenuJust:Bool = false; // botón menú (arriba a la izquierda) -> salir

	#if mobile
	var joyBase:FlxSprite;
	var joyThumb:FlxSprite;
	var touchZ:FlxSprite;
	var touchZOn:FlxSprite;
	var touchX:FlxSprite;
	var touchXOn:FlxSprite;
	var touchC:FlxSprite;
	var touchCOn:FlxSprite;
	var touchMenu:FlxSprite;
	var touchMenuOn:FlxSprite;
	var joyTouchId:Int = -999;
	var debugText:FlxText;
	var evCount:Int = 0;

	// Toques crudos de OpenFL (id -> [x, y] en coordenadas del juego).
	// No dependemos de FlxG.touches ni de controls.UI_* (que en este fork se activan con deslizar).
	var rawTouches:Map<Int, Array<Float>> = new Map();
	var rawJust:Array<Int> = [];
	#end

	// ==================================================================
	override function create()
	{
		// super.create() primero: en este fork MusicBeatState reinicia las cámaras ahí dentro
		super.create();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(Language.getPhrase('eggroom_presence', "Somewhere in between?"), null);
		#end

		#if ACHIEVEMENTS_ALLOWED
		registerAchievement();
		#end

		// --- Cámaras -----------------------------------------------------
		camWorld = FlxG.camera; // cámara por defecto, sin FlxG.cameras.reset()
		camWorld.bgColor = FlxColor.BLACK;

		camHUD = new FlxCamera();
		camHUD.bgColor = FlxColor.TRANSPARENT;

		FlxG.cameras.add(camHUD, false);

		// Cámara fija en (0, -400), como el camFollow del Lua.
		// Se usa follow() (igual que PlayState) porque asignar scroll a mano se perdía.
		camFollow = new FlxObject(0, -400, 1, 1);
		camWorld.follow(camFollow, LOCKON, 1);
		camWorld.zoom = WORLD_ZOOM;
		focusWorldCamera();

		FlxG.mouse.visible = false;

		// --- Progreso guardado -----------------------------------------
		if (FlxG.save.data.eggRoomEggs == null)
			FlxG.save.data.eggRoomEggs = 0;
		eggs = Std.int(FlxG.save.data.eggRoomEggs);

		var dispEggs:Int = eggs + 1;
		var eggCount:String = Language.getPhrase(dispEggs == 1 ? 'eggroom_dia_count_one' : 'eggroom_dia_count_many',
			dispEggs == 1 ? '* ( You now have {1} egg.)' : '* ( You now have {1} eggs.)', [dispEggs]);

		// Índices 1-based igual que en el Lua (el 0 no se usa). Textos en data/en-US.lang
		dialogues = [
			'',
			Language.getPhrase('eggroom_dia_tree_hint', '* ( He is behind the tree.)'),
			Language.getPhrase('eggroom_dia_tree', '* ( It is a tree.)'),
			Language.getPhrase('eggroom_dia_man', '* ( Well, there is a man here.)'),
			Language.getPhrase('eggroom_dia_offer', '* ( He offers you something.)'),
			'',
			Language.getPhrase('eggroom_dia_received', '* ( You received the "Egg".)'),
			eggCount,
			Language.getPhrase('eggroom_dia_no_man', '* ( Well, there is not a man here.)'),
			Language.getPhrase('eggroom_dia_dots', '* ( ...)')
		];

		// --- Música --------------------------------------------------------
		if (FlxG.sound.music != null)
			FlxG.sound.music.pause();
		eggMusic = FlxG.sound.play(Paths.music('eggroom/' + MUSIC[FlxG.random.int(0, MUSIC.length - 1)]), 0.8, true);

		createWorld();
		createCollisions();
		createDialogueUI();

		#if mobile
		createTouchControls();
		#end

	}

	function focusWorldCamera():Void
	{
		if (camWorld == null || camFollow == null || camWorld.scroll == null)
			return;
		camWorld.scroll.set(camFollow.x - camWorld.width * 0.5, camFollow.y - camWorld.height * 0.5);
	}

	// ------------------------------------------------------------------
	//  Construcción
	// ------------------------------------------------------------------
	function pixelSprite(key:String, x:Float, y:Float, scale:Float):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite(x, y).loadGraphic(Paths.image(key));
		spr.scale.set(scale, scale);
		spr.updateHitbox(); // igual que scaleObject(..., true): x/y = esquina superior izquierda
		spr.antialiasing = false;
		return spr;
	}

	function createWorld():Void
	{
		ground = pixelSprite('eggroom/eggRoom', -250, -720, 4);
		add(ground);

		treeStump = pixelSprite('eggroom/treeBot', -170, -805, 4);
		add(treeStump);

		// Kris va entre el tronco y las hojas (la capa se ajusta en updateCharLayer)
		char = new FlxSprite();
		char.frames = Paths.getSparrowAtlas('eggroom/kris');
		char.animation.addByIndices('idle down', 'kris down', [2], '', 1, false);
		char.animation.addByIndices('idle left', 'kris left', [2], '', 1, false);
		char.animation.addByIndices('idle right', 'kris right', [2], '', 1, false);
		char.animation.addByIndices('idle up', 'kris up', [2], '', 1, false);
		char.animation.addByPrefix('walkDown', 'kris down', 8, true);
		char.animation.addByPrefix('walkLeft', 'kris left', 8, true);
		char.animation.addByPrefix('walkRight', 'kris right', 8, true);
		char.animation.addByPrefix('walkUp', 'kris up', 8, true);
		char.animation.play('idle up');
		char.scale.set(4, 4);
		char.updateHitbox();
		char.antialiasing = false;
		add(char);

		treeBrush = pixelSprite('eggroom/treeMid', -170, -805, 4);
		add(treeBrush);

		treeLeaves = pixelSprite('eggroom/treeTop', -170, -805, 4);
		add(treeLeaves);

		treeParticle = pixelSprite('eggroom/treeParticle', 50, -650, 4);
		add(treeParticle);

		charBox = new FlxObject(-38, 30, 60, 30);
		updateCharSprite();
		updateCharLayer();
	}

	function box(x:Float, y:Float, w:Float, h:Float):FlxObject
	{
		return new FlxObject(x, y, w, h);
	}

	function createCollisions():Void
	{
		// Zona de interacción del árbol
		treeBoxTop = box(-62, -514, 140, 20);
		treeBoxBottom = box(-62, -439, 140, 20);
		treeBoxLeft = box(-82, -494, 20, 55);
		treeBoxRight = box(77, -494, 20, 55);

		// Zona de interacción del hombre
		manBoxTop = box(0, -700, 140, 20);
		manBoxLeft = box(-20, -680, 20, 140);
		manBoxBottom = box(0, -540, 140, 20);
		manBoxRight = box(140, -680, 20, 140);
		manBoxFull = box(800, -700, 180, 180);

		exitBox = box(-100, 75, 200, 50);

		// Paredes
		wallsLeft.push(box(-96, -160, 5, 800));
		wallsLeft.push(box(-490, -804, 5, 700));
		wallsLeft.push(box(73, -494, 5, 50));

		wallsRight.push(box(72, -160, 5, 800));
		wallsRight.push(box(472, -804, 5, 700));
		wallsRight.push(box(-62, -494, 5, 50));

		wallsDown.push(box(-490, -160, 400, 5));
		wallsDown.push(box(72, -160, 400, 5));
		wallsDown.push(box(-62, -494, 140, 5));

		wallsUp.push(box(-490, -794, 1000, 5));
		wallsUp.push(box(-62, -444, 140, 5));

		// Paredes alrededor del hombre (se apartan cuando hablas con él)
		var manTop:FlxObject = box(0, -545, 140, 5);
		var manBottom:FlxObject = box(0, -685, 140, 5);
		var manRight:FlxObject = box(0, -685, 5, 140);
		var manLeft:FlxObject = box(135, -685, 5, 140);

		wallsUp.push(manTop);
		wallsDown.push(manBottom);
		wallsRight.push(manRight);
		wallsLeft.push(manLeft);

		manPieces = [manBoxTop, manBoxBottom, manBoxLeft, manBoxRight, manTop, manBottom, manLeft, manRight];
	}

	function createDialogueUI():Void
	{
		var cx:Float = camHUD.width * 0.5;
		var font:String = Paths.font('dtDefault.ttf');

		textBox = new FlxSprite().loadGraphic(Paths.image('eggroom/textBox'));
		textBox.scale.set(2.5, 2.5);
		textBox.updateHitbox();
		textBox.antialiasing = false;
		textBox.x = cx - textBox.width * 0.5;
		textBox.y = camHUD.height - 240;
		textBox.cameras = [camHUD];
		add(textBox);

		boxText = new FlxText(textBox.x + 43, textBox.y + 25, 660, '', TEXT_SIZE);
		boxText.setFormat(font, TEXT_SIZE, FlxColor.WHITE, LEFT);
		boxText.antialiasing = false;
		boxText.cameras = [camHUD];
		add(boxText);

		noText = new FlxText(cx + 170 - 150, textBox.y + 65, 300, Language.getPhrase('No'), TEXT_SIZE);
		noText.setFormat(font, TEXT_SIZE, FlxColor.WHITE, CENTER);
		noText.antialiasing = false;
		noText.cameras = [camHUD];
		add(noText);

		yesText = new FlxText(cx - 170 - 150, textBox.y + 65, 300, Language.getPhrase('Yes'), TEXT_SIZE);
		yesText.setFormat(font, TEXT_SIZE, FlxColor.WHITE, CENTER);
		yesText.antialiasing = false;
		yesText.cameras = [camHUD];
		add(yesText);

		soul = new FlxSprite(cx - 20, textBox.y + 82).loadGraphic(Paths.image('eggroom/soul'));
		soul.scale.set(2, 2);
		soul.updateHitbox();
		soul.antialiasing = false;
		soul.cameras = [camHUD];
		add(soul);

		textBox.visible = false;
		boxText.visible = false;
		yesText.visible = false;
		noText.visible = false;
		soul.visible = false;
	}

	#if mobile
	function createTouchControls():Void
	{
		var W:Float = camHUD.width;
		var H:Float = camHUD.height;

		function touchSprite(key:String, scale:Float):FlxSprite
		{
			var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image('eggroom/touch/' + key));
			spr.scale.set(scale, scale);
			spr.updateHitbox();
			spr.antialiasing = false;
			spr.alpha = 0.85;
			spr.scrollFactor.set();
			spr.cameras = [camHUD];
			return spr;
		}

		// Medidas tomadas de la captura original (700x315):
		//   unidad u = alto_pantalla / 315; las posiciones X van como fracción del ancho.
		var u:Float = H / 315;

		function placeCentered(spr:FlxSprite, fx:Float, fy:Float):Void
		{
			spr.setPosition(W * fx - spr.width * 0.5, H * fy - spr.height * 0.5);
		}

		// Botón de menú (arriba a la izquierda): sale de la sala
		var menuScale:Float = 26 * u / 19;
		touchMenu = touchSprite('menu', menuScale);
		touchMenu.setPosition(W * (101 / 700), H * (3.75 / 315));
		add(touchMenu);
		touchMenuOn = touchSprite('menu_on', menuScale);
		touchMenuOn.setPosition(touchMenu.x, touchMenu.y);
		touchMenuOn.visible = false;
		add(touchMenuOn);

		// Joystick: base de 116 px de ref, centrada en (154, 228)
		var joyScale:Float = 116 * u / 59;
		joyBase = touchSprite('joy_base', joyScale);
		joyBase.alpha = 0.85;
		placeCentered(joyBase, 154 / 700, 228 / 315);
		add(joyBase);

		joyThumb = touchSprite('joy_thumb', joyScale);
		joyThumb.setPosition(joyBase.x + (joyBase.width - joyThumb.width) * 0.5, joyBase.y + (joyBase.height - joyThumb.height) * 0.5);
		add(joyThumb);

		// Z / X / C: 52 px de ref de ancho, casi pegados, en diagonal ascendente
		var bs:Float = 52 * u / 27;

		function makePair(off:String, on:String, fx:Float, fy:Float):Array<FlxSprite>
		{
			var a:FlxSprite = touchSprite(off, bs);
			placeCentered(a, fx, fy);
			add(a);
			var b:FlxSprite = touchSprite(on, bs);
			placeCentered(b, fx, fy);
			b.visible = false;
			add(b);
			return [a, b];
		}

		var zp = makePair('z', 'z_on', 474 / 700, 239.5 / 315);
		touchZ = zp[0];
		touchZOn = zp[1];
		var xp = makePair('x', 'x_on', 527.5 / 700, 214 / 315);
		touchX = xp[0];
		touchXOn = xp[1];
		var cp = makePair('c', 'c_on', 581 / 700, 188.5 / 315);
		touchC = cp[0];
		touchCOn = cp[1];

		if (DEBUG_TOUCH)
		{
			debugText = new FlxText(12, 70, camHUD.width - 24, '', 18);
			debugText.setFormat(null, 18, FlxColor.LIME, LEFT, OUTLINE, FlxColor.BLACK);
			debugText.cameras = [camHUD];
			add(debugText);
		}

		// Entrada táctil directa
		FlxG.stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
		FlxG.stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
		FlxG.stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
	}

	function removeTouchListeners():Void
	{
		if (FlxG.stage == null)
			return;
		FlxG.stage.removeEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
		FlxG.stage.removeEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
		FlxG.stage.removeEventListener(TouchEvent.TOUCH_END, onTouchEnd);
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
	}

	// Pasa de píxeles de ventana a coordenadas del juego (igual que hace Flixel)
	function setRaw(id:Int, stageX:Float, stageY:Float, begin:Bool):Void
	{
		var sx:Float = FlxG.scaleMode.scale.x;
		var sy:Float = FlxG.scaleMode.scale.y;
		if (sx == 0) sx = 1;
		if (sy == 0) sy = 1;
		var gx:Float = (stageX - FlxG.scaleMode.offset.x) / sx;
		var gy:Float = (stageY - FlxG.scaleMode.offset.y) / sy;
		evCount++;
		rawTouches.set(id, [gx, gy]);
		if (begin)
			rawJust.push(id);
	}

	function onTouchBegin(e:TouchEvent):Void setRaw(e.touchPointID, e.stageX, e.stageY, true);
	function onTouchMove(e:TouchEvent):Void
	{
		if (rawTouches.exists(e.touchPointID))
			setRaw(e.touchPointID, e.stageX, e.stageY, false);
	}
	function onTouchEnd(e:TouchEvent):Void rawTouches.remove(e.touchPointID);
	function onMouseDown(e:MouseEvent):Void setRaw(-2, e.stageX, e.stageY, true);
	function onMouseMove(e:MouseEvent):Void
	{
		if (rawTouches.exists(-2))
			setRaw(-2, e.stageX, e.stageY, false);
	}
	function onMouseUp(e:MouseEvent):Void rawTouches.remove(-2);

	function touchHit(spr:FlxSprite, px:Float, py:Float):Bool
	{
		var pad:Float = spr.width * 0.08;
		return px >= spr.x - pad && px <= spr.x + spr.width + pad && py >= spr.y - pad && py <= spr.y + spr.height + pad;
	}

	function updateTouchControls():Void
	{
		// --- Punteros actuales ---
		var px:Array<Float> = [];
		var py:Array<Float> = [];
		var pid:Array<Int> = [];
		var pj:Array<Bool> = [];

		for (id => pos in rawTouches)
		{
			px.push(pos[0]);
			py.push(pos[1]);
			pid.push(id);
			pj.push(rawJust.indexOf(id) >= 0);
		}
		rawJust = [];

		// --- Joystick ---
		var bcx:Float = joyBase.x + joyBase.width * 0.5;
		var bcy:Float = joyBase.y + joyBase.height * 0.5;
		var maxR:Float = joyBase.width * 0.32;
		var grabR:Float = joyBase.width * 0.8;

		var found:Int = -1;
		for (i in 0...px.length)
			if (pid[i] == joyTouchId)
				found = i;

		if (found < 0)
		{
			joyTouchId = -999;
			for (i in 0...px.length)
			{
				var gx:Float = px[i] - bcx;
				var gy:Float = py[i] - bcy;
				if (pj[i] && Math.sqrt(gx * gx + gy * gy) <= grabR)
				{
					joyTouchId = pid[i];
					found = i;
					break;
				}
			}
		}

		var l:Bool = false;
		var r:Bool = false;
		var u:Bool = false;
		var d:Bool = false;
		var thumbX:Float = bcx;
		var thumbY:Float = bcy;

		if (found >= 0)
		{
			var dx:Float = px[found] - bcx;
			var dy:Float = py[found] - bcy;
			var dist:Float = Math.sqrt(dx * dx + dy * dy);

			if (dist > maxR * 0.3)
			{
				var nx:Float = dx / dist;
				var ny:Float = dy / dist;
				// 8 direcciones: sin(22.5°) ≈ 0.38
				r = nx > 0.38;
				l = nx < -0.38;
				d = ny > 0.38;
				u = ny < -0.38;
			}

			var k:Float = (dist > maxR) ? maxR / dist : 1;
			thumbX = bcx + dx * k;
			thumbY = bcy + dy * k;
		}

		joyThumb.setPosition(thumbX - joyThumb.width * 0.5, thumbY - joyThumb.height * 0.5);

		// --- Botones ---
		var zHeld:Bool = false;
		var zJust:Bool = false;
		var xHeld:Bool = false;
		var cHeld:Bool = false;
		var menuHeld:Bool = false;
		var menuJust:Bool = false;

		for (i in 0...px.length)
		{
			if (pid[i] == joyTouchId)
				continue; // ese dedo es del joystick

			if (touchHit(touchZ, px[i], py[i]))
			{
				zHeld = true;
				if (pj[i]) zJust = true;
			}
			if (touchHit(touchX, px[i], py[i])) xHeld = true;
			if (touchHit(touchC, px[i], py[i])) cHeld = true;
			if (touchHit(touchMenu, px[i], py[i]))
			{
				menuHeld = true;
				if (pj[i]) menuJust = true;
			}

			// Tocar la caja de diálogo también avanza el texto
			if (pj[i] && textBox.visible && px[i] >= textBox.x && px[i] <= textBox.x + textBox.width && py[i] >= textBox.y
				&& py[i] <= textBox.y + textBox.height)
				zJust = true;
		}

		tLeft = l;
		tRight = r;
		tUp = u;
		tDown = d;
		tZ = zHeld;
		tZJust = zJust;
		tX = xHeld;
		tMenuJust = menuJust;

		touchZ.visible = !zHeld;
		touchZOn.visible = zHeld;
		touchX.visible = !xHeld;
		touchXOn.visible = xHeld;
		touchC.visible = !cHeld;
		touchCOn.visible = cHeld;
		touchMenu.visible = !menuHeld;
		touchMenuOn.visible = menuHeld;

		if (DEBUG_TOUCH && debugText != null)
		{
			var first:String = (px.length > 0) ? Std.int(px[0]) + ',' + Std.int(py[0]) : '-';
			debugText.text = 'events:' + evCount + ' raw:' + px.length + ' pos:' + first + ' flxTouches:' + FlxG.touches.list.length
				+ ' mouse:' + FlxG.mouse.pressed + '\njoyId:' + joyTouchId + ' L' + (l ? 1 : 0) + ' R' + (r ? 1 : 0) + ' U' + (u ? 1 : 0) + ' D'
				+ (d ? 1 : 0) + ' Z' + (zHeld ? 1 : 0) + '\nscale:' + FlxG.scaleMode.scale.x + ' off:' + FlxG.scaleMode.offset.x + ' hud:'
				+ camHUD.width + 'x' + camHUD.height + ' joy:' + Std.int(joyBase.x) + ',' + Std.int(joyBase.y) + ' ' + Std.int(joyBase.width);
		}
	}
	#end

	// ------------------------------------------------------------------
	//  Utilidades
	// ------------------------------------------------------------------
	static function overlapBox(a:FlxObject, b:FlxObject):Bool
	{
		return a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y;
	}

	function playChar(anim:String):Void
	{
		char.animation.play(anim);
	}

	function updateCharSprite():Void
	{
		// Offsets de Kris del Lua
		char.x = charBox.x - 8;
		char.y = charBox.y - 117;
	}

	/** Kris pasa por detrás del tronco cuando está arriba, y por delante (pero detrás de las hojas) cuando está abajo. */
	function updateCharLayer():Void
	{
		var behind:Bool = (charBox.y + 30) < (treeStump.y + treeStump.height);
		if (charBehindTree == behind)
			return;
		charBehindTree = behind;

		remove(char, true);
		var idx:Int = members.indexOf(behind ? treeStump : treeBrush);
		insert(idx < 0 ? members.length : idx, char);
	}

	function setDialogueVisible(v:Bool):Void
	{
		textBox.visible = v;
		boxText.visible = v;
	}

	function setChoiceVisible(v:Bool):Void
	{
		soul.visible = v;
		yesText.visible = v;
		noText.visible = v;
	}

	function showDialogueLine():Void
	{
		boxText.text = dialogues[dia];
	}

	function openDialogue():Void
	{
		inDialogue = true;
		playChar('idle ' + direction);
		setDialogueVisible(true);
		showDialogueLine();
	}

	function closeDialogue():Void
	{
		setDialogueVisible(false);
		inDialogue = false;
	}

	// ------------------------------------------------------------------
	//  Input unificado (teclado / gamepad / táctil)
	// ------------------------------------------------------------------
	// En mobile NO se usa controls.UI_* (este fork lo activa al deslizar la pantalla):
	// solo el joystick táctil y, si hay, un teclado físico.
	function inLeft():Bool
	{
		#if mobile
		return tLeft; // solo el joystick táctil
		#else
		return controls.UI_LEFT || tLeft;
		#end
	}

	function inRight():Bool
	{
		#if mobile
		return tRight; // solo el joystick táctil
		#else
		return controls.UI_RIGHT || tRight;
		#end
	}

	function inUp():Bool
	{
		#if mobile
		return tUp; // solo el joystick táctil
		#else
		return controls.UI_UP || tUp;
		#end
	}

	function inDown():Bool
	{
		#if mobile
		return tDown; // solo el joystick táctil
		#else
		return controls.UI_DOWN || tDown;
		#end
	}

	function inRun():Bool
	{
		#if mobile
		return tX;
		#else
		return FlxG.keys.pressed.SHIFT || FlxG.keys.pressed.X || tX;
		#end
	}

	// ------------------------------------------------------------------
	//  Update
	// ------------------------------------------------------------------
	override function update(elapsed:Float)
	{
		if (leaving)
		{
			super.update(elapsed);
			return;
		}

		focusWorldCamera();

		#if mobile
		updateTouchControls();
		#end

		var zJust:Bool = tZJust;
		#if !mobile
		zJust = zJust || FlxG.keys.justPressed.Z;
		#end
		var leftJust:Bool = tLeft && !pLeft;
		var rightJust:Bool = tRight && !pRight;
		#if mobile
		zJust = tZJust; // en mobile solo cuenta el botón Z / tocar la caja de texto
		#else
		zJust = zJust || controls.ACCEPT;
		leftJust = leftJust || controls.UI_LEFT_P;
		rightJust = rightJust || controls.UI_RIGHT_P;
		#end

		pZ = tZ;
		pLeft = tLeft;
		pRight = tRight;

		// Salir de emergencia (ESC / botón atrás de Android)
		var back:Bool = tMenuJust;
		#if mobile
		#else
		back = back || controls.BACK;
		#end
		#if android
		back = back || FlxG.android.justReleased.BACK;
		#end
		if (back)
		{
			leave();
			super.update(elapsed);
			return;
		}

		updateMovement(elapsed);

		if (zJust)
			handleAccept();

		handleSelection(leftJust, rightJust);

		updateCharSprite();
		applyWalls(elapsed);

		if (overlapBox(charBox, exitBox))
		{
			canControl = false;
			playChar('idle ' + direction);
			leave();
		}

		updateCharLayer();
		updateTreeAnimation(elapsed);

		super.update(elapsed);
	}

	function updateMovement(elapsed:Float):Void
	{
		if (inDialogue)
		{
			playChar('idle ' + direction); // Kris se queda quieto mientras hay texto
			return;
		}

		if (!canControl)
			return;

		var left:Bool = inLeft();
		var right:Bool = inRight();
		var up:Bool = inUp();
		var down:Bool = inDown();

		var step:Float = moveSpeed * elapsed;

		if (left)
		{
			charBox.x -= step;
			if (!up && !down)
			{
				direction = 'left';
				playChar('walkLeft');
			}
			else if (up)
			{
				charBox.y -= step;
				direction = 'up';
				playChar('walkUp');
			}
			else if (down)
			{
				charBox.y += step;
				direction = 'down';
				playChar('walkDown');
			}
		}
		else if (right)
		{
			charBox.x += step;
			if (!up && !down)
			{
				direction = 'right';
				playChar('walkRight');
			}
			else if (up)
			{
				charBox.y -= step;
				direction = 'up';
				playChar('walkUp');
			}
			else if (down)
			{
				charBox.y += step;
				direction = 'down';
				playChar('walkDown');
			}
		}
		else if (up)
		{
			charBox.y -= step;
			direction = 'up';
			playChar('walkUp');
		}
		else if (down)
		{
			charBox.y += step;
			direction = 'down';
			playChar('walkDown');
		}
		else
		{
			playChar('idle ' + direction);
		}

		moveSpeed = inRun() ? RUN_SPEED : WALK_SPEED;
	}

	function applyWalls(elapsed:Float):Void
	{
		var step:Float = moveSpeed * elapsed;

		for (w in wallsLeft)
			if (overlapBox(charBox, w))
				charBox.x += step;

		for (w in wallsRight)
			if (overlapBox(charBox, w))
				charBox.x -= step;

		for (w in wallsUp)
			if (overlapBox(charBox, w))
				charBox.y += step;

		for (w in wallsDown)
			if (overlapBox(charBox, w))
				charBox.y -= step;
	}

	// ------------------------------------------------------------------
	//  Interacción y diálogos (misma máquina de estados que el Lua)
	// ------------------------------------------------------------------
	function facingTree():Bool
	{
		return (overlapBox(charBox, treeBoxLeft) && direction == 'right')
			|| (overlapBox(charBox, treeBoxRight) && direction == 'left')
			|| (overlapBox(charBox, treeBoxBottom) && direction == 'up')
			|| (overlapBox(charBox, treeBoxTop) && direction == 'down');
	}

	function facingMan():Bool
	{
		return (overlapBox(charBox, manBoxLeft) && direction == 'right')
			|| (overlapBox(charBox, manBoxRight) && direction == 'left')
			|| (overlapBox(charBox, manBoxBottom) && direction == 'up')
			|| (overlapBox(charBox, manBoxTop) && direction == 'down');
	}

	function handleAccept():Void
	{
		if (!inDialogue)
		{
			if (facingTree())
			{
				dia = (spokenTo == 0) ? 1 : 2;
				openDialogue();
			}
			else if (facingMan())
			{
				if (spokenTo == 0)
				{
					dia = 3;
					spokenTo = 1;

					// El hombre "desaparece": se apartan sus paredes y queda solo la caja completa
					for (p in manPieces)
						p.x = 800;
					manBoxFull.x = -20;

					unlockManHere();
				}
				openDialogue();
			}
			else if (overlapBox(charBox, manBoxFull))
			{
				if (spokenTo == 1)
				{
					dia = 8;
					spokenTo = 2;
					openDialogue();
				}
				else if (spokenTo == 2)
				{
					dia = 9;
					openDialogue();
				}
			}
			return;
		}

		// Ya hay un diálogo abierto: avanzar
		if (dia == 1 || dia == 2 || dia == 7 || dia == 8 || dia == 9)
		{
			closeDialogue();
		}
		else if (dia == 4)
		{
			setChoiceVisible(true);
			selecting = true;
		}
		else if (dia == 5)
		{
			selecting = false;
			if (select == 2) // No
			{
				closeDialogue();
				setChoiceVisible(false);
			}
			else if (select == 1) // Yes
			{
				FlxG.sound.play(Paths.sound('eggroom/egg'));
				eggs++;
				setChoiceVisible(false);
			}
			else // todavía no eligió nada
			{
				dia--;
				selecting = true;
			}
		}

		if (spokenTo < 2)
			dia++;

		if (dia >= 0 && dia < dialogues.length)
			showDialogueLine();
	}

	function handleSelection(leftJust:Bool, rightJust:Bool):Void
	{
		if (!selecting)
			return;

		var cx:Float = camHUD.width * 0.5;

		if (leftJust)
		{
			select = 1;
			soul.x = cx - 240;
			yesText.color = FlxColor.YELLOW;
			noText.color = FlxColor.WHITE;
			FlxG.sound.play(Paths.sound('eggroom/move'));
		}

		if (rightJust)
		{
			select = 2;
			soul.x = cx + 110;
			noText.color = FlxColor.YELLOW;
			yesText.color = FlxColor.WHITE;
			FlxG.sound.play(Paths.sound('eggroom/move'));
		}
	}

	function unlockManHere():Void
	{
		#if ACHIEVEMENTS_ALLOWED
		registerAchievement();
		Achievements.unlock(ACHIEVEMENT_ID);
		#end
	}

	// ------------------------------------------------------------------
	//  Animación del árbol
	// ------------------------------------------------------------------
	function jitter(spr:FlxSprite, minX:Float, maxX:Float, minY:Float, maxY:Float):Void
	{
		var amt:Float = 2;
		switch (FlxG.random.int(1, 4))
		{
			case 1: spr.x += amt;
			case 2: spr.x -= amt;
			case 3: spr.y += amt;
			default: spr.y -= amt;
		}
		spr.x = Math.max(minX, Math.min(maxX, spr.x));
		spr.y = Math.max(minY, Math.min(maxY, spr.y));
	}

	function updateTreeAnimation(elapsed:Float):Void
	{
		// Partícula
		particleT -= elapsed;
		if (particleT <= 0)
		{
			if (!particleFlying)
			{
				treeParticle.x = FlxG.random.int(-50, 100);
				treeParticle.y = -650;
				treeParticle.alpha = 1;
				FlxTween.cancelTweensOf(treeParticle);
				FlxTween.tween(treeParticle, {x: treeParticle.x + 300, y: FlxG.random.int(-600, -500)}, 1, {ease: FlxEase.quadInOut});
				particleFlying = true;
				particleT = 0.5;
			}
			else
			{
				FlxTween.tween(treeParticle, {alpha: 0}, 0.25);
				particleFlying = false;
				particleT = FlxG.random.int(1, 2);
			}
		}

		// Ramas
		brushT -= elapsed;
		if (brushT <= 0)
		{
			jitter(treeBrush, -176, -164, -811, -799);
			brushT = FlxG.random.float(0.3, 0.6);
		}

		// Hojas
		leavesT -= elapsed;
		if (leavesT <= 0)
		{
			jitter(treeLeaves, -178, -162, -811, -799);
			leavesT = FlxG.random.float(0.5, 1);
		}
	}

	// ------------------------------------------------------------------
	//  Salida
	// ------------------------------------------------------------------
	function leave():Void
	{
		if (leaving)
			return;
		leaving = true;
		canControl = false;

		FlxG.save.data.eggRoomEggs = eggs;
		FlxG.save.flush();

		if (eggMusic != null)
			eggMusic.fadeOut(0.4, 0);

		// Devolver la música del menú justo donde se quedó
		if (FlxG.sound.music != null)
			FlxG.sound.music.resume();

		MusicBeatState.switchState(new MainMenuState());
	}

	override function destroy()
	{
		#if mobile
		removeTouchListeners();
		#end
		FlxTween.cancelTweensOf(treeParticle);
		eggMusic = null; // FlxG.sound lo destruye solo al cambiar de state
		super.destroy();
	}
}
