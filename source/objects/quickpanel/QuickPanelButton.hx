package objects.quickpanel;

import backend.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import objects.quickpanel.QuickPanelGroup;

/**
 * Un botón del panel: icono + texto.
 */
class QuickPanelButton extends FlxSpriteGroup
{
	public static final ITEM_WIDTH:Int = 320;
	public static final ITEM_HEIGHT:Int = 100;
	public static final ICON_WIDTH:Int = 100;

	/** Datos asignados a este botón. */
	public var data:QuickPanelButtonData;

	public var selected(default, set):Bool = false;

	function set_selected(value:Bool):Bool
	{
		selected = value;
		updateSelected();
		return selected;
	}

	/** Hitbox del botón. */
	public var guide:FlxSprite;

	public var buttonText:FlxText;
	public var icon:FlxSprite;
	public var paScale:PanelAnimator;
	public var paFade:PanelAnimator;

	/** Índice del botón (para seleccionarlo al tocarlo). */
	public var curIndex:Int = 0;

	public var panelGroup:QuickPanelGroup;

	var iconScale:Float = 1;
	var left:Bool = true;
	var alphaMultiplier:Float = 1;

	public function new(_data:QuickPanelButtonData)
	{
		super();

		data = _data;
		alphaMultiplier = data.disabled == true ? 0.5 : 1.0;

		guide = new FlxSprite(0, 0).makeGraphic(ITEM_WIDTH, ITEM_HEIGHT, 0x00D1D1D1);
		add(guide);

		buttonText = new FlxText(0, 0, ITEM_WIDTH - (ICON_WIDTH + 20), data.text != null ? data.text : 'NO TEXT', 38);
		buttonText.setFormat(Paths.font('vcr.ttf'), 38, 0xFFCCCCCC, LEFT);
		buttonText.x = ICON_WIDTH + 20;
		buttonText.y = (ITEM_HEIGHT / 2) - (buttonText.height / 2);
		add(buttonText);

		icon = new FlxSprite(0, 0).loadGraphic(Paths.image('quick-panel/icons/' + data.icon));
		icon.antialiasing = true;
		icon.setGraphicSize(ICON_WIDTH, ICON_WIDTH);
		icon.updateHitbox();
		iconScale = icon.scale.x;
		add(icon);

		setupAnims();
		updateSelected();

		alpha = alphaMultiplier;
	}

	public function repositionSide(_left:Bool = false):Void
	{
		left = _left;

		buttonText.x = x + (left ? guide.width - (ICON_WIDTH + buttonText.width + 20) : ICON_WIDTH + 20);
		icon.x = x + (left ? guide.width - ICON_WIDTH : 0);
		buttonText.alignment = left ? RIGHT : LEFT;
	}

	function setupAnims():Void
	{
		paFade = new PanelAnimator();

		paFade.addAnimation('fade', 24);
		paFade.addProperty('fade', function(v:Dynamic) alpha = v * alphaMultiplier, [1.0, 0.5, 0.2, 0.1, 0.1, 0.0]);

		paFade.addAnimation('press', 24);
		paFade.addProperty('press', function(v:Dynamic) alpha = v * alphaMultiplier, [0.7]);

		paFade.addAnimation('release', 24);
		paFade.addProperty('release', function(v:Dynamic) alpha = v * alphaMultiplier, [1.0]);

		paScale = new PanelAnimator();

		paScale.addAnimation('bump', 30);
		paScale.addProperty('bump', function(v:Dynamic) icon.scale.set(v, v), [
			iconScale + 0.05, iconScale + 0.05, iconScale + 0.02, iconScale + 0.02, iconScale + 0.02, iconScale + 0.02,
			iconScale - 0.01, iconScale - 0.01, iconScale - 0.01, iconScale - 0.01, iconScale
		]);

		paScale.addAnimation('bumpBig', 30);
		paScale.addProperty('bumpBig', function(v:Dynamic) icon.scale.set(v, v), [
			iconScale + 0.15, iconScale + 0.15, iconScale + 0.08, iconScale + 0.08, iconScale + 0.04, iconScale + 0.04,
			iconScale - 0.03, iconScale - 0.03, iconScale - 0.02, iconScale - 0.02, iconScale
		]);
	}

	function updateSelected():Void
	{
		icon.color = selected ? FlxColor.BLACK : 0xFFCCCCCC;
		buttonText.color = selected ? FlxColor.BLACK : 0xFFCCCCCC;

		if (paScale != null)
		{
			paScale.stop();
			icon.scale.set(iconScale, iconScale);

			if (selected) paScale.play('bump');
		}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		paFade.update(elapsed);
		paScale.update(elapsed);

		if (panelGroup != null && panelGroup.curState == OPEN && !panelGroup.lock)
		{
			if (QuickPanelPointer.justPressed && QuickPanelPointer.overlaps(guide))
			{
				paFade.play('press');
				FlxG.sound.play(Paths.sound('quick-panel/menu-press'), 0.1);
			}

			if (QuickPanelPointer.justReleased)
			{
				paFade.play('release');

				if (QuickPanelPointer.overlaps(guide))
					panelGroup.changeSelection(curIndex, true);
			}
		}
	}

	/** Llama al callback del botón, si existe. */
	public function doCallback():Void
	{
		if (data.callback != null) data.callback();
	}

	override function destroy():Void
	{
		FlxTween.cancelTweensOf(this);
		super.destroy();
	}
}
