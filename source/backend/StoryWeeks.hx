package backend;

import flixel.util.FlxTimer;
import states.LoadingState;
import states.PlayState;
import states.StoryMenuState;
import states.FreeplayState;

typedef StoryWeek =
{
	file:String, // nombre del archivo de la week (weeks/<file>.json)
	name:String, // título de la week
	songs:Array<String>,
	difficulties:String, // "Easy,Normal,Hard"
	folder:String, // carpeta del mod ('' = juego base)
	locked:Bool,
	data:WeekData
}

/**
 * Weeks de Story Mode para states propios por script (mismo flujo que StoryMenuState.selectWeek de Psych 1.0.x).
 * Si tu fork cambió Song / Highscore / Difficulty / LoadingState / StageData, ajusta start().
 */
class StoryWeeks
{
	static function isLocked(w:WeekData):Bool
	{
		return (!w.startUnlocked && w.weekBefore != null && w.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(w.weekBefore) || !StoryMenuState.weekCompleted.get(w.weekBefore)));
	}

	public static function load():Array<StoryWeek>
	{
		var out:Array<StoryWeek> = [];
		var currentMod:String = Mods.currentModDirectory == null ? '' : Mods.currentModDirectory;

		WeekData.reloadWeekFiles(true);
		for (i in 0...WeekData.weeksList.length)
		{
			var w:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			if (w == null) continue;

			var locked:Bool = isLocked(w);
			if (locked && w.hiddenUntilUnlocked) continue;

			var songs:Array<String> = [];
			for (s in w.songs) songs.push(Std.string(s[0]));

			var diffs:String = (w.difficulties != null && w.difficulties.trim().length > 0) ? w.difficulties.trim() : FreeplaySongs.DEFAULT_DIFFICULTIES;

			out.push({
				file: w.fileName,
				name: Language.getPhrase('storyname_${w.fileName}', w.storyName),
				songs: songs,
				difficulties: diffs,
				folder: w.folder == null ? '' : w.folder,
				locked: locked,
				data: w
			});
		}

		Mods.currentModDirectory = currentMod; // reloadWeekFiles puede cambiarlo
		return out;
	}

	/** Inicia la week. Devuelve false si está bloqueada o no se pudo cargar. La carga ocurre 1 s después (como el original). */
	public static function start(w:StoryWeek, diffIndex:Int):Bool
	{
		if (w == null || w.locked || w.songs.length < 1) return false;

		var diffs:Array<String> = FreeplaySongs.diffList(w.difficulties);
		if (diffIndex < 0 || diffIndex >= diffs.length) diffIndex = FreeplaySongs.defaultDiff(diffs);

		WeekData.setDirectoryFromWeek(w.data);
		Difficulty.list = diffs;

		try
		{
			var diffic:String = Difficulty.getFilePath(diffIndex);
			if (diffic == null) diffic = '';

			PlayState.storyPlaylist = w.songs.copy();
			PlayState.isStoryMode = true;
			PlayState.storyDifficulty = diffIndex;

			var first:String = PlayState.storyPlaylist[0].toLowerCase();
			Song.loadFromJson(first + diffic, first);
			PlayState.campaignScore = 0;
			PlayState.campaignMisses = 0;
		}
		catch (err:Dynamic)
		{
			trace('No se pudo cargar la week "${w.file}": $err');
			return false;
		}

		var directory = StageData.forceNextDirectory;
		LoadingState.loadNextDirectory();
		StageData.forceNextDirectory = directory;

		@:privateAccess
		if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			Paths.freeGraphicsFromMemory();

		LoadingState.prepareToSong();
		new FlxTimer().start(1, function(tmr:FlxTimer)
		{
			#if !SHOW_LOADING_SCREEN
			FlxG.sound.music.stop();
			#end
			LoadingState.loadAndSwitchState(new PlayState(), true);
			FreeplayState.destroyFreeplayVocals();
		});

		#if (MODS_ALLOWED && DISCORD_ALLOWED)
		DiscordClient.loadModRPC();
		#end
		return true;
	}

	/**
	 * Funciones de Story para scripts de states propios (Lua y HScript):
	 * loadStoryWeeks() -> cantidad, getWeekCount(), getWeekName(i), getWeekFile(i), getWeekSongs(i) ("a,b,c"),
	 * getWeekDifficulties(i), getWeekFolder(i), isWeekLocked(i), getWeekScore(i, dificultad), startWeek(i, dificultad).
	 */
	public static function registerExtras(x:Map<String, Dynamic>):Void
	{
		var weeks:Array<StoryWeek> = [];
		var ok = function(i:Int) return i >= 0 && i < weeks.length;

		x.set('loadStoryWeeks', function() {
			weeks = load();
			return weeks.length;
		});
		x.set('getWeekCount', function() return weeks.length);
		x.set('getWeekName', function(i:Int) return ok(i) ? weeks[i].name : '');
		x.set('getWeekFile', function(i:Int) return ok(i) ? weeks[i].file : '');
		x.set('getWeekSongs', function(i:Int) return ok(i) ? weeks[i].songs.join(',') : '');
		x.set('getWeekDifficulties', function(i:Int) return ok(i) ? FreeplaySongs.diffList(weeks[i].difficulties).join(',') : '');
		x.set('getWeekFolder', function(i:Int) return ok(i) ? weeks[i].folder : '');
		x.set('isWeekLocked', function(i:Int) return ok(i) ? weeks[i].locked : true);
		x.set('getWeekScore', function(i:Int, diff:Int = 0) return ok(i) ? Highscore.getWeekScore(weeks[i].file, diff) : 0);
		x.set('startWeek', function(i:Int, diff:Int = -1) return ok(i) ? start(weeks[i], diff) : false);
	}
}
