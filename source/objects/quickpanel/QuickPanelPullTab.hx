package objects.quickpanel;

import backend.Paths;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import objects.quickpanel.QuickPanelGroup;

/**
 * La pestaña que se tira / pulsa para abrir el panel.
 * Usa el atlas de Animate (quick-panel/tabSquare). Si el atlas no carga,
 * dibuja un rectángulo para que el panel siga siendo usable.
 */
class QuickPanelPullTab extends FlxSpriteGroup
{
	public static final TAB_WIDTH:Float = 170;
	public static final TAB_HEIGHT:Float = 250;

	// Si la pestaña sale descentrada respecto al hitbox, ajusta estos dos valores.
	static final ATLAS_OFFSET_X:Float = 0;
	static final ATLAS_OFFSET_Y:Float = 0;

	var sprite:FlxSprite = null; // atlas Sparrow aplanado (quick-panel/tab_square.xml)
	var fallback:FlxSprite = null;
	var curAnim:String = '';

	static final ANIMS:Array<Array<Dynamic>> = [
		['idleLeft', 24, true], ['idleRight', 24, true], ['held', 30, true],
		['release', 30, false], ['pressRight', 24, false], ['pressLeft', 24, false]
	];

	public function new(x:Float, y:Float, keyboard:Bool = false)
	{
		super(x, y);

		var sparrow:String = 'quick-panel/' + (keyboard ? 'tab_square_keyboard' : 'tab_square');

		try
		{
			if (Paths.fileExists('images/$sparrow.xml', TEXT))
			{
				// Versión plana en XML Sparrow: no depende de flxanimate
				sprite = new FlxSprite(ATLAS_OFFSET_X, ATLAS_OFFSET_Y);
				sprite.frames = Paths.getSparrowAtlas(sparrow);
				for (a in ANIMS)
					sprite.animation.addByPrefix(a[0], a[0], a[1], a[2]);
				sprite.antialiasing = true;
				add(sprite);
			}
			else
			{
				trace('QuickPanel: falta images/$sparrow.xml');
				fallback = new FlxSprite(0, 0).makeGraphic(Std.int(TAB_WIDTH), Std.int(TAB_HEIGHT), 0xFF1A1A1A);
				add(fallback);
			}
		}
		catch (e:Dynamic)
		{
			trace('QuickPanel: no se pudo cargar el atlas de la pestaña: $e');
			sprite = null;
			fallback = new FlxSprite(0, 0).makeGraphic(Std.int(TAB_WIDTH), Std.int(TAB_HEIGHT), 0xFF1A1A1A);
			add(fallback);
		}
	}

	public function setFlip(value:Bool):Void
	{
		if (sprite != null) sprite.flipX = value;
		if (fallback != null) fallback.flipX = value;
	}

	public function playAnimation(name:String):Void
	{
		curAnim = name;
		if (sprite != null) sprite.animation.play(name, true);
	}

	public function press(state:PanelState):Void
	{
		switch (state)
		{
			case CLOSED:
				playAnimation('pressLeft');
			case OPEN:
				playAnimation('pressRight');
			default:
		}
	}

	public function grab(state:PanelState):Void
	{
		playAnimation('held');
	}

	public function release(state:PanelState):Void
	{
		switch (state)
		{
			case OPEN:
				playAnimation('release');
			default:
				playAnimation('idleLeft');
		}
	}

	public function playIdle(state:PanelState):Void
	{
		switch (state)
		{
			case CLOSED:
				playAnimation('idleLeft');
			case OPENING:
				playAnimation('held');
			case OPEN:
				playAnimation('idleRight');
		}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Al terminar 'release' pasamos a idleRight
		if (curAnim == 'release' && (sprite != null && sprite.animation.finished))
			playIdle(OPEN);
	}
}
