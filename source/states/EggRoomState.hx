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

/**
 * Easter egg: "The Egg Room" (port nativo del mod Lua a Haxe).
 *
 * Se abre desde MainMenuState tocando 17 veces el texto "Shadow Crystal Engine".
 * Solo se usa a Kris. En mobile se muestran controles táctiles (D-pad + Z + X).
 *
 * Controles:
 *   Flechas / WASD (UI)  -> moverse
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
	static inline var TEXT_SIZE:Int = 32; // tamaño del texto de los diálogos
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

	#if mobile
	var touchDpad:FlxSprite;
	var touchZ:FlxSprite;
	var touchZOn:FlxSprite;
	var touchX:FlxSprite;
	var touchXOn:FlxSprite;
	#end

	// ==================================================================
	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Somewhere in between?", null);
		#end

		#if ACHIEVEMENTS_ALLOWED
		registerAchievement();
		#end

		// --- Cámaras -----------------------------------------------------
		camWorld = new FlxCamera();
		camWorld.bgColor = FlxColor.BLACK;

		camHUD = new FlxCamera();
		camHUD.bgColor = FlxColor.TRANSPARENT;

		FlxG.cameras.reset(camWorld);
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
		var eggWord:String = (dispEggs == 1) ? 'egg' : 'eggs';

		// Índices 1-based igual que en el Lua (el 0 no se usa)
		dialogues = [
			'',
			'* ( He is behind the tree.)',
			'* ( It is a tree.)',
			'* ( Well, there is a man here.)',
			'* ( He offers you something.)',
			'',
			'* ( You received the "Egg".)',
			'* ( You now have $dispEggs $eggWord.)',
			'* ( Well, there is not a man here.)',
			'* ( ...)'
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

		super.create();

		// Por si MusicBeatState / el fork tocó las cámaras en super.create()
		camWorld.zoom = WORLD_ZOOM;
		focusWorldCamera();
	}

	function focusWorldCamera():Void
	{
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

		noText = new FlxText(cx + 170 - 150, textBox.y + 65, 300, 'No', TEXT_SIZE);
		noText.setFormat(font, TEXT_SIZE, FlxColor.WHITE, CENTER);
		noText.antialiasing = false;
		noText.cameras = [camHUD];
		add(noText);

		yesText = new FlxText(cx - 170 - 150, textBox.y + 65, 300, 'Yes', TEXT_SIZE);
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
		var margin:Float = 36;
		var W:Float = camHUD.width;
		var H:Float = camHUD.height;

		function touchSprite(key:String, scale:Float):FlxSprite
		{
			var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image('eggroom/touch/' + key));
			spr.scale.set(scale, scale);
			spr.updateHitbox();
			spr.antialiasing = false;
			spr.alpha = 0.8;
			spr.scrollFactor.set();
			spr.cameras = [camHUD];
			return spr;
		}

		touchDpad = touchSprite('dpad', 3);
		touchDpad.setPosition(margin, H - touchDpad.height - margin);
		add(touchDpad);

		touchZ = touchSprite('z', 3.5);
		touchZ.setPosition(W - touchZ.width - margin, H - touchZ.height - margin);
		add(touchZ);

		touchZOn = touchSprite('z_on', 3.5);
		touchZOn.setPosition(touchZ.x, touchZ.y);
		touchZOn.visible = false;
		add(touchZOn);

		touchX = touchSprite('x', 3.5);
		touchX.setPosition(touchZ.x, touchZ.y - touchX.height - 24);
		add(touchX);

		touchXOn = touchSprite('x_on', 3.5);
		touchXOn.setPosition(touchX.x, touchX.y);
		touchXOn.visible = false;
		add(touchXOn);
	}

	function touchHit(spr:FlxSprite, px:Float, py:Float):Bool
	{
		var pad:Float = spr.width * 0.15;
		return px >= spr.x - pad && px <= spr.x + spr.width + pad && py >= spr.y - pad && py <= spr.y + spr.height + pad;
	}

	function updateTouchControls():Void
	{
		var l:Bool = false;
		var r:Bool = false;
		var u:Bool = false;
		var d:Bool = false;
		var z:Bool = false;
		var x:Bool = false;

		var dcx:Float = touchDpad.x + touchDpad.width * 0.5;
		var dcy:Float = touchDpad.y + touchDpad.height * 0.5;
		var reach:Float = touchDpad.width * 0.75;
		var dead:Float = touchDpad.width * 0.12;

		for (t in FlxG.touches.list)
		{
			if (!t.pressed)
				continue;

			var px:Float = t.screenX;
			var py:Float = t.screenY;

			var dx:Float = px - dcx;
			var dy:Float = py - dcy;
			var dist:Float = Math.sqrt(dx * dx + dy * dy);

			if (dist <= reach && dist > dead)
			{
				// 8 direcciones: sin(22.5°) ≈ 0.38
				if (dx / dist > 0.38) r = true;
				else if (dx / dist < -0.38) l = true;

				if (dy / dist > 0.38) d = true;
				else if (dy / dist < -0.38) u = true;
			}

			if (touchHit(touchZ, px, py)) z = true;
			if (touchHit(touchX, px, py)) x = true;
		}

		tLeft = l;
		tRight = r;
		tUp = u;
		tDown = d;
		tZ = z;
		tX = x;

		touchZ.visible = !z;
		touchZOn.visible = z;
		touchX.visible = !x;
		touchXOn.visible = x;
		touchDpad.color = (l || r || u || d) ? 0xFFFFE066 : FlxColor.WHITE;
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
	inline function inLeft():Bool return controls.UI_LEFT || tLeft;
	inline function inRight():Bool return controls.UI_RIGHT || tRight;
	inline function inUp():Bool return controls.UI_UP || tUp;
	inline function inDown():Bool return controls.UI_DOWN || tDown;

	inline function inRun():Bool return FlxG.keys.pressed.SHIFT || FlxG.keys.pressed.X || tX;

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

		var zJust:Bool = FlxG.keys.justPressed.Z || controls.ACCEPT || (tZ && !pZ);
		var leftJust:Bool = controls.UI_LEFT_P || (tLeft && !pLeft);
		var rightJust:Bool = controls.UI_RIGHT_P || (tRight && !pRight);

		pZ = tZ;
		pLeft = tLeft;
		pRight = tRight;

		// Salir de emergencia (ESC / botón atrás de Android)
		var back:Bool = controls.BACK;
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
		if (!canControl || inDialogue)
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
		FlxTween.cancelTweensOf(treeParticle);
		eggMusic = null; // FlxG.sound lo destruye solo al cambiar de state
		super.destroy();
	}
}
