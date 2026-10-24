package states;

import backend.Difficulty;
import backend.Highscore;
import backend.MainMenuData;
import backend.Song;
import objects.Alphabet;
import flixel.text.FlxText;
import objects.HealthIcon;

/**
 * FreePlay custom: data/freeplay_menu.json (se edita en Main Menu Editor > FreePlay).
 * Cada canción: name (carpeta de data/<name>/), icon, color (#RRGGBB), difficulties ("easy,normal,hard") y mod (opcional).
 * IZQ/DER cambia la dificultad, ACEPTAR inicia la canción.
 *
 * Si tu fork cambió Song / Highscore / Difficulty / LoadingState, ajusta startSong().
 */
class CustomFreeplayState extends CustomMenuBase
{
	var songs:Array<Dynamic> = [];
	var icons:Array<HealthIcon> = [];
	var diffText:FlxText;
	var curDiff:Int = 0;
	var colorTween:FlxTween;

	public function new()
	{
		super('freeplay');
	}

	override function entryCount():Int return songs.length;
	override function entryName(i:Int):String return songs[i] != null ? songs[i].name : '';

	function diffsOf(i:Int):Array<String>
	{
		var e:Dynamic = songs[i];
		var raw:String = (e == null || e.difficulties == null) ? '' : Std.string(e.difficulties);
		var out:Array<String> = [];
		for (d in raw.split(','))
		{
			var t:String = d.trim();
			if (t.length > 0) out.push(t.charAt(0).toUpperCase() + t.substr(1)); // Difficulty usa "Normal", "Hard"...
		}
		if (out.length < 1) out.push('Normal');
		return out;
	}

	override function buildEntries()
	{
		var data:Dynamic = MainMenuData.loadCustom('freeplay');
		songs = Reflect.field(data, 'songs').copy();

		var bgImage:String = Reflect.field(data, 'bg');
		if (bgImage != null && bgImage.length > 0 && Paths.fileExists('images/$bgImage.png', IMAGE))
		{
			bg.loadGraphic(Paths.image(bgImage));
			bg.screenCenter();
		}

		for (i => s in songs)
		{
			var text:Alphabet = addAlphabet(Std.string(s.name), true, i, FlxG.width * 0.4);
			var icon:HealthIcon = new HealthIcon(s.icon == null || s.icon == '' ? 'face' : Std.string(s.icon));
			icon.sprTracker = text;
			icon.scrollFactor.set();
			icons.push(icon);
			add(icon);
		}

		diffText = new FlxText(FlxG.width - 330, 20, 310, '', 32);
		diffText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		diffText.scrollFactor.set();
		add(diffText);
	}

	override function onSelectionChanged()
	{
		var e:Dynamic = songs[curSelected];
		if (e == null) return;

		curDiff = Std.int(Math.min(curDiff, diffsOf(curSelected).length - 1));
		refreshDiff();

		for (i => icon in icons) icon.alpha = (i == curSelected) ? 1 : 0.6;

		var target:FlxColor = MainMenuData.parseColor(e.color, 0xFF353535);
		if (colorTween != null) colorTween.cancel();
		colorTween = FlxTween.color(bg, 0.8, bg.color, target, {onComplete: function(_) colorTween = null});
	}

	function refreshDiff()
	{
		var diffs:Array<String> = diffsOf(curSelected);
		diffText.text = diffs.length > 1 ? '< ${diffs[curDiff].toUpperCase()} >' : diffs[curDiff].toUpperCase();
	}

	function changeDiff(change:Int)
	{
		var diffs:Array<String> = diffsOf(curSelected);
		if (diffs.length < 2) return;
		curDiff = FlxMath.wrap(curDiff + change, 0, diffs.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		refreshDiff();
		scripts.call('onDifficultyChange', [diffs[curDiff]]);
	}

	override function update(elapsed:Float)
	{
		if (!leaving)
		{
			if (controls.UI_LEFT_P) changeDiff(-1);
			if (controls.UI_RIGHT_P) changeDiff(1);
		}
		super.update(elapsed);
	}

	override function acceptEntry(i:Int)
	{
		var e:Dynamic = songs[i];
		if (e == null || leaving) return;

		var diffs:Array<String> = diffsOf(i);
		if (scripts.call('onAccept', [i, e.name, diffs[curDiff]])) return;

		startSong(e, diffs);
	}

	function startSong(e:Dynamic, diffs:Array<String>)
	{
		persistentUpdate = false;

		#if MODS_ALLOWED
		var mod:String = e.mod == null ? '' : Std.string(e.mod);
		if (mod.length > 0) Mods.currentModDirectory = mod;
		#end

		var songLowercase:String = Paths.formatToSongPath(Std.string(e.name));
		Difficulty.list = diffs;
		var poop:String = Highscore.formatSong(songLowercase, curDiff);

		try
		{
			Song.loadFromJson(poop, songLowercase);
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = curDiff;
		}
		catch (err:Dynamic)
		{
			trace('No se pudo cargar la canción "$songLowercase" ($poop): $err');
			persistentUpdate = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		leaving = true;
		@:privateAccess
		if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			Paths.freeGraphicsFromMemory();

		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
		FlxG.sound.music.volume = 0;
	}
}
