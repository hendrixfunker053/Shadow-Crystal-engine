package states;

import backend.MainMenuData;
import flixel.text.FlxText;

/**
 * Créditos custom: data/credits_menu.json (se edita en Main Menu Editor > Credits).
 * Cada entrada: name, desc, icon (images/credits/<icon>.png), color (#RRGGBB), url y header (título no seleccionable).
 */
class CustomCreditsState extends CustomMenuBase
{
	var entries:Array<Dynamic> = [];
	var icons:Array<FlxSprite> = [];
	var descBox:FlxSprite;
	var descText:FlxText;
	var colorTween:FlxTween;

	public function new()
	{
		super('credits');
	}

	override function entryCount():Int return entries.length;
	override function entryName(i:Int):String return entries[i] != null ? entries[i].name : '';
	override function isSelectable(i:Int):Bool return entries[i] != null && entries[i].header != true;
	override function backgroundColor():FlxColor return 0xFFFFFFFF;

	override function buildEntries()
	{
		var data:Dynamic = MainMenuData.loadCustom('credits');
		entries = Reflect.field(data, 'entries').copy();

		for (i => e in entries)
		{
			var selectable:Bool = isSelectable(i);
			addAlphabet(Std.string(e.name), !selectable, i, FlxG.width / 2);

			var icon:FlxSprite = null;
			var name:String = e.icon == null ? '' : e.icon;
			if (selectable && name.length > 0)
			{
				var path:String = name.indexOf('/') >= 0 ? name : 'credits/' + name;
				if (Paths.fileExists('images/$path.png', IMAGE))
				{
					icon = new FlxSprite().loadGraphic(Paths.image(path));
					icon.setGraphicSize(Std.int(Math.min(icon.width, 90)), 0);
					icon.updateHitbox();
					icon.antialiasing = ClientPrefs.data.antialiasing;
					icon.scrollFactor.set();
					add(icon);
				}
			}
			icons.push(icon);
		}

		descBox = new FlxSprite(0, FlxG.height - 110).makeGraphic(FlxG.width, 110, FlxColor.BLACK);
		descBox.alpha = 0.6;
		descBox.scrollFactor.set();
		add(descBox);

		descText = new FlxText(40, FlxG.height - 100, FlxG.width - 80, '', 28);
		descText.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		add(descText);
	}

	override function onSelectionChanged()
	{
		var e:Dynamic = entries[curSelected];
		if (e == null) return;

		descText.text = e.desc == null ? '' : Std.string(e.desc);

		var target:FlxColor = MainMenuData.parseColor(e.color, 0xFFFFFFFF);
		if (colorTween != null) colorTween.cancel();
		colorTween = FlxTween.color(bg, 0.8, bg.color, target, {onComplete: function(_) colorTween = null});
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Los iconos siguen a su texto
		for (i => icon in icons)
		{
			if (icon == null) continue;
			var a = grp.members[i];
			if (a == null) continue;
			icon.setPosition(a.x + a.width + 12, a.y + (a.height - icon.height) / 2);
			icon.alpha = a.alpha;
		}
	}

	override function acceptEntry(i:Int)
	{
		var e:Dynamic = entries[i];
		if (e == null || !isSelectable(i)) return;

		var url:String = e.url == null ? '' : Std.string(e.url);
		if (scripts.call('onAccept', [i, e.name, url])) return;

		if (url.length > 0) CoolUtil.browserLoad(url);
		else FlxG.sound.play(Paths.sound('cancelMenu'));
	}
}
