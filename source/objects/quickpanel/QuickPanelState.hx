package objects.quickpanel;

import backend.Paths;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import objects.quickpanel.QuickPanelGroup;

/**
 * Overlay del panel rápido. Se añade con `add(new QuickPanelState())` a cualquier state.
 * Tiene su propia cámara, así que se dibuja por encima de todo y no le afecta el scroll del state.
 *
 * Mientras `isBusy()` sea true, el state de debajo debería ignorar su input.
 */
class QuickPanelState extends FlxGroup
{
	public var panelCam:FlxCamera;
	public var bg:FlxSprite;
	public var panel:QuickPanelGroup;

	var circleWipe:CircleWipeShader;
	var descriptionText:FlxText;
	var descriptionPanel:FlxSprite;

	var DESCRIPTION_PANEL_Y:Float = 0;
	var DESCRIPTION_TEXT_Y:Float = 0;
	var DESCRIPTION_OFFSET:Float = 100;

	var paWipe:PanelAnimator;
	var paMiddle:PanelAnimator;

	var wipeSprite:FlxSprite;
	var selectedIcon:FlxSprite;
	var selectedSplash:FlxSprite;

	var left:Bool = false;

	/** @param left true para poner el panel en el borde izquierdo. */
	public function new(left:Bool = false)
	{
		super();
		this.left = left;

		panelCam = new FlxCamera();
		panelCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(panelCam, false);

		bg = new FlxSprite().makeGraphic(FlxG.width * 2, FlxG.height * 2, 0xFF1A1A1A);
		bg.scrollFactor.set(0, 0);
		bg.alpha = 0;
		bg.screenCenter();
		add(bg);

		descriptionPanel = new FlxSprite().makeGraphic(FlxG.width * 2, 60, 0xFF0B0B0B);
		descriptionPanel.scrollFactor.set(0, 0);
		descriptionPanel.screenCenter(X);
		DESCRIPTION_PANEL_Y = FlxG.height - descriptionPanel.height;
		descriptionPanel.y = DESCRIPTION_PANEL_Y + DESCRIPTION_OFFSET;
		add(descriptionPanel);

		descriptionText = new FlxText(0, 0, 800, 'lol', 30);
		descriptionText.setFormat(QuickPanelButton.panelFont(), 30, 0xFFE6E6E6, CENTER);
		descriptionText.scrollFactor.set(0, 0);
		add(descriptionText);

		DESCRIPTION_TEXT_Y = (DESCRIPTION_PANEL_Y + descriptionPanel.height / 2) - descriptionText.height / 2;
		descriptionText.y = DESCRIPTION_TEXT_Y + DESCRIPTION_OFFSET;

		panel = new QuickPanelGroup(this, left);
		add(panel);

		wipeSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0x00FFFFFF);
		wipeSprite.scrollFactor.set(0, 0);
		wipeSprite.visible = false;
		add(wipeSprite);

		circleWipe = new CircleWipeShader();
		wipeSprite.shader = circleWipe;

		selectedIcon = new FlxSprite(0, 0);
		selectedIcon.scrollFactor.set(0, 0);
		selectedIcon.visible = false;
		selectedIcon.color = 0xFFCCCCCC;
		add(selectedIcon);

		selectedSplash = new FlxSprite(0, 0);
		selectedSplash.frames = Paths.getSparrowAtlas('quick-panel/splash');
		selectedSplash.animation.addByPrefix('splash', 'splash0', 24, false);
		selectedSplash.scrollFactor.set(0, 0);
		selectedSplash.screenCenter();
		selectedSplash.scale.set(1.85, 1.85);
		selectedSplash.visible = false;
		selectedSplash.color = 0xFFCCCCCC;
		add(selectedSplash);

		setupAnims();

		forEach(function(obj:flixel.FlxBasic) obj.cameras = [panelCam]);

		repositionSide(left);
	}

	/** El state de debajo debe ignorar su input mientras esto sea true. */
	public function isBusy():Bool
		return panel != null && panel.curState != CLOSED;

	public function repositionSide(_left:Bool = false):Void
	{
		left = _left;

		var descBaseX:Float = left ? FlxG.width + 443 : FlxG.width - 443;
		descriptionText.x = (descBaseX / 2) - descriptionText.width / 2;

		wipeSprite.flipX = left;
		panel.repositionSide(left);
	}

	public function fadeScreen(out:Bool = false):Void
	{
		FlxTween.cancelTweensOf(bg);
		FlxTween.tween(bg, {alpha: out ? 0.0 : 0.6}, 0.3, {ease: FlxEase.expoOut});

		FlxTween.cancelTweensOf(descriptionPanel);
		FlxTween.cancelTweensOf(descriptionText);

		FlxTween.tween(descriptionPanel, {y: out ? DESCRIPTION_PANEL_Y + DESCRIPTION_OFFSET : DESCRIPTION_PANEL_Y}, 0.4, {ease: FlxEase.expoOut});
		FlxTween.tween(descriptionText, {y: out ? DESCRIPTION_TEXT_Y + DESCRIPTION_OFFSET : DESCRIPTION_TEXT_Y}, 0.4, {ease: FlxEase.expoOut});
	}

	function setupAnims():Void
	{
		paWipe = new PanelAnimator();
		paWipe.addAnimation('wipe', 24);
		paWipe.addProperty('wipe', function(v:Dynamic) circleWipe.circleRadius = v, [3.1, 3.8, 4.3, 4.6, 4.8, 10]);

		paMiddle = new PanelAnimator();
		var bump:Array<Dynamic> = [1.4, 1.4, 1.6, 1.6, 1.55, 1.55, 1.1, 1.1, 1.17, 1.17, 1.2];

		paMiddle.addAnimation('bump', 24);
		paMiddle.addProperty('bump', function(v:Dynamic) selectedIcon.scale.x = v, bump);
		paMiddle.addProperty('bump', function(v:Dynamic) selectedIcon.scale.y = v, bump);
		paMiddle.addProperty('bump', function(v:Dynamic) selectedIcon.angle = v, [2, 2, 2.2, 2.2, 1.9, 1.9, 0.5, 0.5, 0.1, 0.1, 0]);
	}

	public function updateDescription(text:String):Void
	{
		descriptionText.text = text;
		// (se recentra porque el ancho cambia si el texto es corto)
		var descBaseX:Float = left ? FlxG.width + 443 : FlxG.width - 443;
		descriptionText.x = (descBaseX / 2) - descriptionText.width / 2;
	}

	public function startTransition(data:QuickPanelButtonData):Void
	{
		selectedIcon.loadGraphic(Paths.image('quick-panel/icons/' + data.icon));
		selectedIcon.scale.set(1.4, 1.4);
		selectedIcon.antialiasing = true;
		selectedIcon.updateHitbox();
		selectedIcon.screenCenter();
		selectedIcon.cameras = [panelCam];

		new FlxTimer().start(6 / 24, function(_)
		{
			wipeSprite.visible = true;
			paWipe.play('wipe');
		});

		new FlxTimer().start(8 / 24, function(_)
		{
			selectedIcon.visible = true;
			paMiddle.play('bump');

			selectedSplash.visible = true;
			selectedSplash.animation.play('splash');
		});

		new FlxTimer().start(22 / 24, function(_) finish());
	}

	function finish():Void
	{
		FlxTween.tween(selectedIcon, {alpha: 0}, 8 / 24, {ease: FlxEase.expoOut});
		panel.currentButton.doCallback();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		paWipe.update(elapsed);
		paMiddle.update(elapsed);
	}

	override public function destroy():Void
	{
		FlxTween.cancelTweensOf(bg);
		FlxTween.cancelTweensOf(descriptionPanel);
		FlxTween.cancelTweensOf(descriptionText);

		super.destroy();

		if (panelCam != null && FlxG.cameras.list.contains(panelCam))
			FlxG.cameras.remove(panelCam);
	}
}
