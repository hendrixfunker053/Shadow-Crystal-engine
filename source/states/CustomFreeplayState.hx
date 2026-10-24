package states;

import backend.Difficulty;
import backend.FreeplaySongs;
import backend.Highscore;
import backend.MainMenuData;
import backend.Song;
import flixel.text.FlxText;
import objects.Alphabet;
import objects.HealthIcon;

/**
 * FreePlay custom. Las canciones NO se escriben a mano: se detectan de las weeks (igual que el FreePlay original).
 * data/freeplay_menu.json:
 *   enabled          usar este FreePlay en lugar del original
 *   includeOtherMods false = solo canciones del mod actual; true = también otros mods y el juego base
 *   defaultUI        true = lista con iconos y dificultad; false = tu script (scripts/freeplay/) dibuja todo
 *   exclude          canciones a ocultar, separadas por coma
 *   bg               imagen de fondo opcional (images/<bg>.png)
 *
 * Con defaultUI=false los scripts usan: getSongCount, getSongName(i), getSongIcon(i), getSongColor(i),
 * getSongFolder(i), getSongDifficulties(i), getDifficultyName, changeDifficulty(n), setSelectedItem(i), startSelectedSong.
 * IZQ/DER cambia la dificultad y ACEPTAR inicia la canción en ambos modos.
 *
 * Si tu fork cambió Song / Highscore / Difficulty / LoadingState, ajusta startSong().
 */
class CustomFreeplayState extends CustomMenuBase
{
	var songs:Array<FreeplaySong> = [];
	var settings:Dynamic;
	var defaultUI:Bool = true;
	var icons:Array<HealthIcon> = [];
	var diffText:FlxText;
	var emptyText:FlxText;
	var curDiff:Int = 0;
	var colorTween:FlxTween;

	public function new()
	{
		super('freeplay');
	}

	override function entryCount():Int return songs.length;
	override function entryName(i:Int):String return (i >= 0 && i < songs.length) ? songs[i].name : '';

	function diffsOf(i:Int):Array<String>
		return FreeplaySongs.diffList((i >= 0 && i < songs.length) ? songs[i].difficulties : '');

	override function prepare()
	{
		settings = MainMenuData.loadCustom('freeplay');
		defaultUI = Reflect.field(settings, 'defaultUI') != false;
		songs = FreeplaySongs.load(Reflect.field(settings, 'includeOtherMods') == true, Std.string(Reflect.field(settings, 'exclude')));
	}

	function inRange(i:Int):Bool return i >= 0 && i < songs.length;

	override function registerScriptFunctions()
	{
		var x:Map<String, Dynamic> = scripts.extras;
		x.set('getSongCount', function() return songs.length);
		x.set('getSongName', function(i:Int) return inRange(i) ? songs[i].name : '');
		x.set('getSongIcon', function(i:Int) return inRange(i) ? songs[i].icon : '');
		x.set('getSongColor', function(i:Int) return inRange(i) ? FreeplaySongs.hex(songs[i].color) : '#FFFFFF');
		x.set('getSongFolder', function(i:Int) return inRange(i) ? songs[i].folder : '');
		x.set('getSongDifficulties', function(i:Int) return inRange(i) ? diffsOf(i).join(',') : '');
		x.set('getDifficultyName', function() return inRange(curSelected) ? diffsOf(curSelected)[curDiff] : '');
		x.set('changeDifficulty', function(n:Int) changeDiff(n));
		x.set('startSelectedSong', function() startSelected());
	}

	override function buildEntries()
	{
		var bgImage:String = Reflect.field(settings, 'bg');
		if (bgImage != null && bgImage.length > 0 && Paths.fileExists('images/$bgImage.png', IMAGE))
		{
			bg.loadGraphic(Paths.image(bgImage));
			bg.screenCenter();
		}

		if (songs.length < 1)
		{
			emptyText = new FlxText(0, FlxG.height / 2 - 40, FlxG.width, 'No hay canciones para mostrar.\nRevisa las weeks del mod o activa "includeOtherMods".', 28);
			emptyText.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			emptyText.scrollFactor.set();
			add(emptyText);
			return;
		}

		curDiff = FreeplaySongs.defaultDiff(diffsOf(0));
		if (!defaultUI) return; // el script se encarga del diseño

		for (i => s in songs)
		{
			var text:Alphabet = addAlphabet(s.name, true, i, FlxG.width * 0.4);
			var icon:HealthIcon = new HealthIcon(s.icon == null || s.icon == '' ? 'face' : s.icon);
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
		if (!inRange(curSelected)) return;

		var diffs:Array<String> = diffsOf(curSelected);
		if (curDiff >= diffs.length) curDiff = FreeplaySongs.defaultDiff(diffs);

		if (!defaultUI) return;

		refreshDiff();
		for (i => icon in icons) icon.alpha = (i == curSelected) ? 1 : 0.6;

		if (colorTween != null) colorTween.cancel();
		colorTween = FlxTween.color(bg, 0.8, bg.color, songs[curSelected].color, {onComplete: function(_) colorTween = null});
	}

	function refreshDiff()
	{
		if (diffText == null || !inRange(curSelected)) return;
		var diffs:Array<String> = diffsOf(curSelected);
		diffText.text = diffs.length > 1 ? '< ${diffs[curDiff].toUpperCase()} >' : diffs[curDiff].toUpperCase();
	}

	function changeDiff(change:Int)
	{
		if (!inRange(curSelected)) return;
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
		if (!inRange(i) || leaving) return;

		var diffs:Array<String> = diffsOf(i);
		if (scripts.call('onAccept', [i, songs[i].name, diffs[curDiff]])) return;

		startSong(songs[i], diffs);
	}

	/** Inicia la canción seleccionada (para scripts con diseño propio). */
	function startSelected()
	{
		if (!inRange(curSelected) || leaving) return;
		startSong(songs[curSelected], diffsOf(curSelected));
	}

	function startSong(s:FreeplaySong, diffs:Array<String>)
	{
		persistentUpdate = false;

		#if MODS_ALLOWED
		Mods.currentModDirectory = s.folder; // '' para el juego base
		#end

		var songLowercase:String = Paths.formatToSongPath(s.name);
		Difficulty.list = diffs;
		PlayState.storyWeek = s.week;
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
