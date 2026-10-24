package objects.quickpanel;

import backend.Controls;
import backend.MusicBeatState;
import backend.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import options.OptionsState;
import states.FreeplayState;
import states.PlayState;
import states.TitleState;
#if MODS_ALLOWED
import states.ModsMenuState;
#end

enum PanelState
{
	CLOSED;
	OPENING;
	OPEN;
}

typedef QuickPanelButtonData =
{
	/** Texto del botón. */
	var text:Null<String>;

	/** Se llama al confirmar el botón (normalmente cambia de state). */
	var callback:Null<Void->Void>;

	/** Icono: debe existir en images/quick-panel/icons/<icon>.png */
	var icon:Null<String>;

	/** Si es true no se puede seleccionar (sonido de "denegado"). */
	var disabled:Null<Bool>;

	/** Descripción que sale abajo cuando está seleccionado. */
	var description:Null<String>;
}

/**
 * El panel deslizable en sí: fondo, pestaña, botones, hint y toda la lógica de abrir/cerrar/arrastrar.
 */
class QuickPanelGroup extends FlxSpriteGroup
{
	static var shouldDecayTimer:Bool = true;
	static var tabFadeTimer:Float = 0;

	static final TAB_FADE_DELAY:Float = 3.0;
	static final TAB_FADE_DURATION:Float = 1.5;
	public static final TAB_MIN_ALPHA:Float = 0.25;

	/** Distancia que hay que arrastrar para empezar a tirar del panel. */
	static final GRAB_THRESHOLD:Float = 15;

	static final HINT_COLOR_NORMAL:FlxColor = 0xFFEEEEEE;
	static final HINT_COLOR_DARK:FlxColor = 0xFFCCCCCC;

	/** Bloquea el input del panel. */
	public var lock:Bool = false;

	/** true desde que se confirma un botón hasta que cambia el state: no se acepta nada más (ni cerrar, ni cambiar de botón). */
	public var committed:Bool = false;

	/** El botón que se confirmó (el callback se ejecuta sobre ESTE, aunque la selección cambie mientras dura la animación). */
	public var committedButton:QuickPanelButton = null;

	/** Tras abrir, un tiempo en el que se ignora ACCEPT y los toques (el toque que abrió el panel no debe confirmar nada). */
	var openGrace:Float = 0;
	static final OPEN_GRACE:Float = 0.3;

	/** Desbloqueo tras el sonido de "denegado" (antes dependía de onFinish, que otro play() borraba y dejaba el panel trabado). */
	var denyTimer:Float = 0;

	/** true si el panel acepta input de selección ahora mismo. */
	public function inputReady():Bool
		return curState == OPEN && !lock && !committed && openGrace <= 0;

	/** El state de debajo lo pone a true mientras está en transición (no deja abrir el panel). */
	public var blocked:Bool = false;

	/** Si se puede arrastrar la pestaña (móvil). En PC la pestaña se pulsa / TAB. */
	public var canPull:Bool = #if mobile true #else false #end;

	public var rememberedVolume:Float = 1;
	public var curState:PanelState = CLOSED;
	public var inactivityTimer:Float = 0;

	var controls(get, never):Controls;

	inline function get_controls():Controls
		return Controls.instance;

	var quickPanelState:QuickPanelState;

	var screenEdge:Float = 0;
	var tabBaseX:Float = -467;
	var moveTween:FlxTween;

	var curSelected:Int = 0;
	var buttons:Array<QuickPanelButton> = [];

	public var currentButton(get, never):QuickPanelButton;

	function get_currentButton():QuickPanelButton
	{
		if (curSelected < 0 || curSelected >= buttons.length) return null;
		return buttons[curSelected];
	}

	var panel:FlxSprite;
	var panelShader:QuickPanelShader;
	var pullTabHitbox:FlxSprite;
	var pullExtra:FlxSprite;
	var pullHint:FlxText;
	public var pullTabVisual:QuickPanelPullTab;

	var paScroll:PanelAnimator;
	var paColor:PanelAnimator;
	var paHint:PanelAnimator;

	var breatheTimer:Float = 0;
	var hintBreathe:Bool = false;
	var hintOpen:Bool = false;

	var pullAmt:Float = 0;
	var pullLerp:Float = 0;
	var pullOffset:Float = 0;
	var trackDist:Bool = false;
	var trackStartX:Float = 0;
	var touchDist:Float = 0;
	var tickSound:FlxSound;

	var soundDist:Float = 0;
	var prevDist:Float = 0;
	var soundDelay:Float = 0;

	var ducked:Bool = false;
	var left:Bool = true;

	var spamTimer:Float = 0;
	var spamming:Bool = false;

	function buildButtonData():Array<QuickPanelButtonData>
	{
		var list:Array<QuickPanelButtonData> = [];

		list.push({
			text: 'Exit mod',
			callback: function()
			{
				// Menú principal original: sin items del mod, sin panel, sin scripts ni menús custom
				backend.MainMenuData.forceOriginal = true;
				MusicBeatState.switchState(new states.MainMenuState());
			},
			icon: 'back',
			description: "Leave this mod's main menu and go to the original one.",
			disabled: false
		});

		#if MODS_ALLOWED
		list.push({
			text: 'Mods',
			callback: function()
			{
				backend.MainMenuData.goState('ModsMenuState', function() return new ModsMenuState());
			},
			icon: 'mods',
			description: "Add, remove or install custom content for the game.",
			disabled: false
		});
		#end

		list.push({
			text: 'Freeplay',
			callback: function()
			{
				backend.MainMenuData.goState('FreeplayState', function() return new FreeplayState());
			},
			icon: 'freeplay',
			description: "Choose and play any song you've previously unlocked.",
			disabled: false
		});

		list.push({
			text: 'Online',
			callback: function() {},
			icon: 'online',
			description: "Play against friends, or with people around the world.",
			disabled: true
		});

		list.push({
			text: 'Options',
			callback: function()
			{
				backend.MainMenuData.goState('OptionsState', function() return new OptionsState());
				OptionsState.onPlayState = false;

				if (PlayState.SONG != null)
				{
					PlayState.SONG.arrowSkin = null;
					PlayState.SONG.splashSkin = null;
					PlayState.stageUI = 'normal';
				}
			},
			icon: 'options',
			description: "Configure various gameplay and visual settings.",
			disabled: false
		});

		return list;
	}

	public function new(_state:QuickPanelState, _left:Bool = false)
	{
		super();

		quickPanelState = _state;
		left = _left;

		// Relleno negro que tapa lo que queda detrás del panel
		pullExtra = new FlxSprite().makeGraphic(1, 1, 0xFF000000);
		pullExtra.scrollFactor.set(0, 0);
		pullExtra.scale.set(FlxG.width, FlxG.height);
		pullExtra.updateHitbox();
		add(pullExtra);

		pullHint = new FlxText(0, 0, 600, "you're not supposed to see this! if you do, i seriously messed up!", 30);
		pullHint.setFormat(QuickPanelButton.panelFont(), 32, HINT_COLOR_NORMAL, RIGHT);
		pullHint.y = (FlxG.height / 2) - (pullHint.height / 2);
		pullHint.alpha = 0;
		add(pullHint);

		panel = new FlxSprite();
		panel.frames = Paths.getSparrowAtlas('quick-panel/panel-bg');
		panel.animation.addByPrefix('idle', 'thingidle instance 10', 12, true);
		panel.animation.play('idle');
		panel.updateHitbox();
		panel.scrollFactor.set(0, 0);
		panel.antialiasing = true;
		add(panel);

		pullTabVisual = new QuickPanelPullTab(0, 0, #if mobile false #else true #end);
		pullTabVisual.y = (FlxG.height / 2) - (QuickPanelPullTab.TAB_HEIGHT / 2);
		pullTabVisual.playIdle(curState);
		add(pullTabVisual);

		panelShader = new QuickPanelShader();
		panel.shader = panelShader;
		panelShader.updateFrameInfo(panel.frame);

		pullTabHitbox = new FlxSprite().makeGraphic(200, 280, 0xFFFF9191);
		pullTabHitbox.scrollFactor.set(0, 0);
		pullTabHitbox.alpha = 0;
		pullTabHitbox.y = (FlxG.height / 2) - (pullTabHitbox.height / 2);

		tickSound = FlxG.sound.load(Paths.sound('quick-panel/tab-pull'));
		tickSound.volume = 1;

		setupAnims();
		populateButtons();

		add(pullTabHitbox); // siempre encima de todo

		repositionSide(left);
	}

	public function repositionSide(_left:Bool = false):Void
	{
		left = _left;

		screenEdge = left ? 0 : FlxG.width;
		tabBaseX = left ? 467 : -467;

		setLocal(pullTabVisual, left ? 120 - QuickPanelPullTab.TAB_WIDTH : -120, pullTabVisual.y);
		setLocal(pullTabHitbox, left ? 145 - pullTabHitbox.width : -145, pullTabHitbox.y);
		setLocal(panel, left ? -panel.width : 0, 0);
		setLocal(pullExtra, left ? -(pullExtra.width + panel.width) + 5 : panel.width - 5, 0);

		panel.flipX = left;
		pullTabVisual.setFlip(left);

		setLocal(pullHint, left ? 135 : -135 - pullHint.width, pullHint.y);
		pullHint.alignment = left ? LEFT : RIGHT;

		repositionButtons();

		switch (curState)
		{
			case OPEN:
				openPanel(true);
			default:
				closePanel(true);
		}
	}

	/** Coloca un sprite en coordenadas relativas al grupo (el grupo siempre tiene y = 0). */
	inline function setLocal(spr:FlxSprite, lx:Float, ly:Float):Void
	{
		spr.x = this.x + lx;
		spr.y = ly;
	}

	// ---------------------------------------------------------------- animaciones

	function setupAnims():Void
	{
		paHint = new PanelAnimator();

		var slideAlpha:Array<Dynamic> = [0.0, 0.0, 0.5, 0.5, 0.7, 0.7, 0.9, 0.9, 0.95, 0.95, 1.0, 1.0];

		paHint.addAnimation('slideLeft', 30);
		paHint.addProperty('slideLeft', function(v:Dynamic) pullHint.offset.x = v, [-10, -10, -5, -5, -2, -2, -1, -1, -0.05, -0.05, 0, 0]);
		paHint.addProperty('slideLeft', function(v:Dynamic) pullHint.alpha = v, slideAlpha);

		paHint.addAnimation('slideRight', 30);
		paHint.addProperty('slideRight', function(v:Dynamic) pullHint.offset.x = v, [10, 10, 5, 5, 2, 2, 1, 1, 0.05, 0.05, 0, 0]);
		paHint.addProperty('slideRight', function(v:Dynamic) pullHint.alpha = v, slideAlpha);

		paHint.addAnimation('disappear', 30);
		paHint.addProperty('disappear', function(v:Dynamic) pullHint.alpha = v, [1.0, 1.0, 0.95, 0.95, 0.9, 0.9, 0.7, 0.7, 0.5, 0.5, 0.0, 0.0]);

		paScroll = new PanelAnimator();

		var fatBump:Array<Dynamic> = [0.3, 0.3, 0.3, 0.3, 0.3, 0.3, -0.25, -0.25, -0.05, -0.05, 0];

		paScroll.addAnimation('bumpUp', 30);
		paScroll.addProperty('bumpUp', function(v:Dynamic) panelShader.dirExtra = v, [-0.2, -0.2, -0.03, -0.03, -0.01, -0.01, 0]);
		paScroll.addProperty('bumpUp', function(v:Dynamic) panelShader.fatExtra = v, fatBump);

		paScroll.addAnimation('bumpDown', 30);
		paScroll.addProperty('bumpDown', function(v:Dynamic) panelShader.dirExtra = v, [0.2, 0.2, 0.03, 0.03, 0.01, 0.01, 0]);
		paScroll.addProperty('bumpDown', function(v:Dynamic) panelShader.fatExtra = v, fatBump);

		paScroll.addAnimation('bumpNeutral', 30);
		paScroll.addProperty('bumpNeutral', function(v:Dynamic) panelShader.fatExtra = v, fatBump);

		paScroll.addAnimation('accept', 24);
		paScroll.addProperty('accept', function(v:Dynamic) panelShader.fatExtra = v, [1.05, 1.05, 1.1, 1.1, 1, 1, -0.05, -0.05, -0.05, -0.05, 0]);
		paScroll.addProperty('accept', function(v:Dynamic) panelShader.sliceColor = cast(v, Int), [
			0xFFFF596A, 0xFFFF596A, 0xFFF3E63A, 0xFFF3E63A, 0xFFFF596A, 0xFFFF596A, 0xFFF3E63A, 0xFFF3E63A, 0xFFFF596A, 0xFFFF596A, 0xFFF3E63A
		]);

		paScroll.addAnimation('deny', 30);
		paScroll.addProperty('deny', function(v:Dynamic) panelShader.sliceColor = cast(v, Int), [0xFF7C6969, 0xFF7C6969, 0xFF6F6969, 0xFF6F6969]);
		paScroll.addProperty('deny', function(v:Dynamic) panelShader.dirExtra = v, [0.2, 0.2, -0.2, -0.2, 0.1, 0.1, -0.1, -0.1, 0]);

		paColor = new PanelAnimator();
		paColor.addAnimation('breathe', 12, true);
		paColor.addProperty('breathe', function(v:Dynamic) panelShader.sliceLerp = v, [
			0.0, 0.0, 0.1, 0.1, 0.2, 0.2, 0.5, 0.5, 0.8, 0.8, 0.9, 0.9, 1.0, 1.0, 0.9, 0.9, 0.8, 0.8, 0.5, 0.5, 0.2, 0.2, 0.1, 0.1
		]);
		paColor.play('breathe');
	}

	// ---------------------------------------------------------------- botones

	function populateButtons():Void
	{
		for (index => data in buildButtonData())
		{
			var button:QuickPanelButton = new QuickPanelButton(data);
			button.panelGroup = this;
			button.curIndex = index;
			buttons.push(button);
			add(button);
		}
	}

	function repositionButtons():Void
	{
		var count:Int = buttons.length;
		if (count < 1) return;

		var padding:Float = 20;
		var angleRange:Float = 5;
		var angleStep:Float = count > 1 ? (angleRange * 2) / (count - 1) : 0;
		var angleDistance:Float = 20;

		var fullHeight:Float = (QuickPanelButton.ITEM_HEIGHT * count) + (padding * (count - 1));
		var startOffset:Float = (FlxG.height / 2) - (fullHeight / 2);

		for (i in 0...count)
		{
			var button:QuickPanelButton = buttons[i];

			var targetAngle:Float = angleRange - (angleStep * i);
			var dist:Float = Math.abs(Math.cos(targetAngle) * angleDistance);
			var baseX:Float = left ? -panel.width + 58 : 98;

			button.setPosition(this.x + (left ? baseX + dist : baseX - dist), startOffset + ((QuickPanelButton.ITEM_HEIGHT + padding) * i));
			button.angle = left ? -targetAngle : targetAngle;
			button.repositionSide(left);
		}
	}

	function disableButtons():Void
	{
		for (button in buttons)
			button.selected = false;

		panelShader.sliceVisible = false;
	}

	function enableButtons():Void
	{
		panelShader.sliceVisible = true;
		changeSelection();
	}

	/** top = true: la pestaña se dibuja encima del panel. */
	function setTabOrder(top:Bool):Void
	{
		var pi:Int = members.indexOf(panel);
		var ti:Int = members.indexOf(pullTabVisual);
		if (pi < 0 || ti < 0) return;

		var tabIsOnTop:Bool = ti > pi;
		if (tabIsOnTop == top) return;

		members[pi] = pullTabVisual;
		members[ti] = panel;
	}

	// ---------------------------------------------------------------- pestaña / hint

	function handleTabFade(elapsed:Float):Void
	{
		#if mobile
		if (trackDist)
		{
			tabFadeTimer = 0;
			pullTabVisual.alpha = 1.0;
			return;
		}
		#end

		if (curState != CLOSED || hintOpen) return;

		tabFadeTimer += elapsed;

		var fadeStart:Float = TAB_FADE_DELAY;
		var fadeEnd:Float = TAB_FADE_DELAY + TAB_FADE_DURATION;

		if (tabFadeTimer < fadeStart)
			pullTabVisual.alpha = 1.0;
		else if (tabFadeTimer < fadeEnd)
			pullTabVisual.alpha = FlxMath.lerp(1.0, TAB_MIN_ALPHA, (tabFadeTimer - fadeStart) / TAB_FADE_DURATION);
		else
			pullTabVisual.alpha = TAB_MIN_ALPHA;
	}

	function resetTabFade():Void
	{
		tabFadeTimer = 0;
		FlxTween.cancelTweensOf(pullTabVisual);
		FlxTween.tween(pullTabVisual, {alpha: 1.0}, 0.3, {ease: FlxEase.expoOut});
	}

	function resolveHint(panelOpen:Bool):String
	{
		var action:String = #if mobile (canPull ? 'PULL' : 'TAP') #else 'TAB' #end;
		return panelOpen ? '($action) to close quick menu' : '($action) to open quick menu';
	}

	function handleHint(elapsed:Float):Void
	{
		if (inactivityTimer > 0 && shouldDecayTimer)
			inactivityTimer -= elapsed;

		if (FlxG.keys.pressed.ANY || QuickPanelPointer.pressed)
		{
			inactivityTimer = 45;

			if (hintOpen)
			{
				hintOpen = false;
				hintBreathe = false;
				paHint.play('disappear');
			}

			pullHint.color = HINT_COLOR_NORMAL;
		}

		if (inactivityTimer < 0 && !hintOpen)
		{
			shouldDecayTimer = false;
			hintOpen = true;
			resetTabFade();
			pullHint.text = resolveHint(curState == OPEN);
			paHint.play(left ? 'slideRight' : 'slideLeft');
			paHint.onFinish = function() hintBreathe = true;

			breatheTimer = 0;
			pullHint.color = HINT_COLOR_NORMAL;
		}

		if (curState == CLOSED)
		{
			var targetAlpha:Float = hintOpen ? 0.6 : 0;
			quickPanelState.bg.alpha = smoothLerp(quickPanelState.bg.alpha, targetAlpha, elapsed, 1);
		}
	}

	inline function smoothLerp(base:Float, target:Float, elapsed:Float, duration:Float):Float
		return FlxMath.lerp(base, target, 1 - Math.pow(0.01, elapsed / duration));

	// ---------------------------------------------------------------- abrir / cerrar

	function duck():Void
	{
		if (ducked || FlxG.sound.music == null) return;
		rememberedVolume = FlxG.sound.music.volume;
		FlxG.sound.music.volume = rememberedVolume * 0.2;
		ducked = true;
	}

	public function unduck():Void
	{
		if (!ducked) return;
		ducked = false;
		if (FlxG.sound.music != null) FlxG.sound.music.volume = rememberedVolume;
	}

	function snd(name:String, volume:Float = 1):Void
	{
		FlxG.sound.play(Paths.sound('quick-panel/' + name), volume);
	}

	function grabPanel():Void
	{
		pullLerp = (curState == OPEN) ? (left ? screenEdge - tabBaseX : screenEdge + tabBaseX) : screenEdge;

		setTabOrder(true);
		pullTabVisual.grab(curState);
		disableButtons();

		curState = OPENING;
	}

	function openPanel(instant:Bool = false):Void
	{
		curState = OPEN;
		duck();

		openGrace = instant ? 0 : OPEN_GRACE;
		if (!committed)
		{
			lock = false;
			denyTimer = 0;
			// Nunca empezar sobre "Exit mod": un ACCEPT / toque perdido lo confirmaría
			if (buttons.length > 1 && curSelected == 0 && buttons[0].data.text == 'Exit mod') curSelected = 1;
		}

		if (moveTween != null) moveTween.cancel();

		if (instant)
			this.x = screenEdge + tabBaseX;
		else
			moveTween = FlxTween.tween(this, {x: screenEdge + tabBaseX}, 0.4, {ease: FlxEase.expoOut});

		setTabOrder(true);
		pullTabVisual.release(curState);

		enableButtons();
		quickPanelState.fadeScreen();
	}

	function closePanel(instant:Bool = false):Void
	{
		curState = CLOSED;
		unduck();

		if (!committed)
		{
			lock = false;
			denyTimer = 0;
		}

		if (moveTween != null) moveTween.cancel();

		if (instant)
			this.x = screenEdge;
		else
			moveTween = FlxTween.tween(this, {x: screenEdge}, 0.4, {ease: FlxEase.expoOut});

		setTabOrder(true);
		pullTabVisual.playIdle(curState);

		disableButtons();
		quickPanelState.fadeScreen(true);
	}

	function beginTrack():Void
	{
		touchDist = 0;
		prevDist = 0;
		trackStartX = QuickPanelPointer.x;
		pullOffset = QuickPanelPointer.x - this.x;
		trackDist = true;

		setTabOrder(false);
		pullTabVisual.press(curState);
		snd('tab-press');
	}

	// ---------------------------------------------------------------- estado

	function handleState(elapsed:Float):Void
	{
		// Ya se confirmó un botón: el panel se queda quieto hasta que cambie el state
		if (committed)
		{
			trackDist = false;
			return;
		}

		// No dejar abrir el panel mientras el state de debajo está en transición
		if (blocked && curState == CLOSED)
		{
			trackDist = false;
			return;
		}

		var wasTracking:Bool = trackDist;
		if (QuickPanelPointer.justReleased) trackDist = false;

		if (trackDist)
		{
			soundDelay -= elapsed;
			touchDist = Math.abs(QuickPanelPointer.x - trackStartX);
			soundDist += Math.abs(prevDist - touchDist);
			prevDist = touchDist;
		}

		var overTab:Bool = QuickPanelPointer.overlaps(pullTabHitbox);

		switch (curState)
		{
			case CLOSED:
				if (FlxG.keys.justPressed.TAB)
				{
					resetTabFade();
					openPanel();
					snd('open-tab-click');
					return;
				}

				if (QuickPanelPointer.justPressed && overTab) beginTrack();

				if (trackDist && touchDist > GRAB_THRESHOLD && canPull)
				{
					grabPanel();
					snd('tab-release-pull');
					return;
				}

				if (!canPull && trackDist && !overTab)
				{
					trackDist = false;
					setTabOrder(true);
					pullTabVisual.release(curState);
				}

				if (QuickPanelPointer.justReleased && wasTracking && overTab)
				{
					resetTabFade();
					openPanel();
					snd('open-tab-click');
				}

			case OPENING:
				var px:Float = QuickPanelPointer.x;

				if (left)
					pullAmt = -(px - screenEdge) + pullOffset;
				else
					pullAmt = (px - screenEdge) - pullOffset;

				var dist:Float = left ? -tabBaseX : tabBaseX;
				var extraPull:Float = pullAmt * 0.1;

				pullAmt = dist * FlxEase.sineOut(Math.min(pullAmt / dist, 1.0));
				pullAmt += extraPull;

				if (pullAmt > 0) pullAmt = 0;

				var progress:Float = Math.min(pullAmt / dist, 1.0);

				pullLerp = smoothLerp(pullLerp, screenEdge + pullAmt, elapsed, 0.1);
				quickPanelState.bg.alpha = smoothLerp(quickPanelState.bg.alpha, FlxMath.lerp(0, 0.6, progress), elapsed, 0.1);

				this.x = left ? -pullLerp : pullLerp;

				if (soundDist > 40 && soundDelay < 0)
				{
					soundDist = 0;
					soundDelay = 0.08;

					tickSound.pitch = FlxMath.lerp(0.8, 1.25, progress);
					tickSound.pan = FlxMath.lerp(left ? -0.5 : 0.5, 0, progress);
					tickSound.play(true);
				}

				if (QuickPanelPointer.justReleased || !QuickPanelPointer.pressed)
				{
					if (moveTween != null) moveTween.cancel();

					if (pullAmt < dist * 0.55)
					{
						openPanel();
						snd('open-tab-soft');
					}
					else
					{
						closePanel();
						snd('close-tab-soft');
					}
				}

			case OPEN:
				if (FlxG.keys.justPressed.TAB || (controls.BACK && !lock))
				{
					resetTabFade();
					closePanel();
					snd('close-tab-click');
					return;
				}

				if (QuickPanelPointer.justPressed && overTab)
					beginTrack();

				if (trackDist && touchDist > GRAB_THRESHOLD && canPull)
				{
					grabPanel();
					snd('tab-release-pull');
					return;
				}

				if (!canPull && trackDist && !overTab)
				{
					trackDist = false;
					setTabOrder(true);
					pullTabVisual.release(curState);
				}

				if (QuickPanelPointer.justReleased && wasTracking && overTab)
				{
					closePanel();
					snd('close-tab-click');
					return;
				}

				if (!lock && QuickPanelPointer.justPressed && !(overTab || QuickPanelPointer.overlaps(panel)))
				{
					closePanel();
					snd('close-tab-click');
					return;
				}
		}
	}

	override public function update(elapsed:Float):Void
	{
		QuickPanelPointer.update();

		super.update(elapsed);

		paHint.update(elapsed);
		paScroll.update(elapsed);
		paColor.update(elapsed);
		panelShader.updateFrameInfo(panel.frame);

		handleHint(elapsed);
		handleTabFade(elapsed);
		handleState(elapsed);

		if (hintBreathe)
		{
			breatheTimer += elapsed;
			pullHint.color = FlxColor.interpolate(HINT_COLOR_DARK, HINT_COLOR_NORMAL, (Math.cos(breatheTimer * 2) / 2) + 0.5);
		}

		if (openGrace > 0) openGrace -= elapsed;

		if (denyTimer > 0)
		{
			denyTimer -= elapsed;
			if (denyTimer <= 0 && !committed)
			{
				lock = false;
				panelShader.doLerp = true;
			}
		}

		if (lock || committed || curState != OPEN || openGrace > 0) return;

		var upP:Bool = controls.UI_UP_P;
		var downP:Bool = controls.UI_DOWN_P;

		if (controls.ACCEPT)
			clickSelected();

		if (upP || downP)
		{
			spamTimer = 0;
			spamming = false;
			changeSelection(upP ? -1 : 1);
		}
		else if (controls.UI_UP || controls.UI_DOWN)
		{
			// mantener pulsado: repite pasado un rato
			spamTimer += elapsed;
			if (!spamming && spamTimer >= 0.4)
			{
				spamming = true;
				spamTimer = 0.12;
			}

			if (spamming && spamTimer >= 0.12)
			{
				spamTimer = 0;
				changeSelection(controls.UI_UP ? -1 : 1);
			}
		}
		else
		{
			spamming = false;
			spamTimer = 0;
		}
	}

	/**
	 * Cambia el botón seleccionado.
	 * @param change cuánto moverse.
	 * @param overrideSelection si es true, `change` es el índice al que ir (y si ya estaba seleccionado, lo confirma).
	 */
	public function changeSelection(change:Int = 0, ?overrideSelection:Bool = false):Void
	{
		if (curState != OPEN || buttons.length < 1) return;

		panelShader.doLerp = true;

		var prevSelected:Int = curSelected;
		var amount:Int = buttons.length;

		if (overrideSelection)
		{
			curSelected = change;
			snd('menu-scroll');
		}
		else
		{
			if (change != 0) snd('menu-scroll');
			curSelected = FlxMath.wrap(curSelected + change, 0, amount - 1);
		}

		for (index => button in buttons)
			button.selected = index == curSelected;

		var angleRange:Float = 4.45;
		var angleStep:Float = amount > 1 ? (angleRange * 2) / (amount - 1) : 0;
		panelShader.dir = -90 + (angleRange - (angleStep * curSelected));

		quickPanelState.updateDescription(currentButton.data.description != null ? currentButton.data.description : '');

		if (currentButton.data.disabled == true)
		{
			panelShader.sliceColorStart = QuickPanelShader.START_COLOR_DISABLED;
			panelShader.sliceColorEnd = QuickPanelShader.END_COLOR_DISABLED;
		}
		else
		{
			panelShader.sliceColorStart = QuickPanelShader.START_COLOR_NORMAL;
			panelShader.sliceColorEnd = QuickPanelShader.END_COLOR_NORMAL;
		}

		if (overrideSelection)
		{
			if (change == prevSelected)
				clickSelected();
			else
				paScroll.play(prevSelected > change ? 'bumpUp' : 'bumpDown');
		}
		else
		{
			if (prevSelected == curSelected)
				paScroll.play('bumpNeutral');
			else
				paScroll.play(change < 0 ? 'bumpUp' : 'bumpDown');
		}
	}

	/** Confirma el botón actual y le pide al state que haga la transición. */
	function clickSelected():Void
	{
		if (lock || committed || curState != OPEN || currentButton == null) return;

		lock = true;

		if (currentButton.data.disabled == true)
		{
			panelShader.doLerp = false;
			paScroll.play('deny');
			snd('menu-deny');

			denyTimer = 0.35;
			return;
		}

		committed = true;
		committedButton = currentButton;

		paScroll.play('accept');
		FlxG.sound.play(Paths.sound('confirmMenu'));

		panelShader.doLerp = false;

		for (button in buttons)
		{
			if (button.selected)
				button.paScale.play('bumpBig');
			else
				button.paFade.play('fade');
		}

		quickPanelState.startTransition(currentButton.data);
	}

	override function destroy():Void
	{
		unduck();
		if (moveTween != null) moveTween.cancel();
		super.destroy();
	}
}
