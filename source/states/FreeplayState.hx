
package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;
import haxe.Json;

#if sys
import sys.FileSystem;
#end

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var selectedDifficulties:Array<FreeplayDifficulty> = [];

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	var bg:FlxSprite;
	var intendedColor:Int;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	var instPlaying:Int = -1;
	var instPlayingChart:String = null;

	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;

	// -------------------------------------------------------------------------
	// INFORMACIÓN COMPARTIDA CON PAUSESUBSTATE
	// -------------------------------------------------------------------------

	public static var currentCustomDifficulty:String = null;
	public static var currentCustomChart:String = null;
	public static var currentCustomFolder:String = null;
	public static var currentFreeplaySong:String = null;

	// Información completa de las dificultades detectadas para la canción.
	public static var pauseDifficultyNames:Array<String> = [];
	public static var pauseDifficultyCharts:Array<String> = [];
	public static var pauseDifficultyFolders:Array<String> = [];
	public static var pauseDifficultyCustom:Array<Bool> = [];
	public static var pauseDifficultyBase:Array<Int> = [];

	public static var pauseCurrentDifficulty:Int = 0;
	public static var pauseModDirectory:String = "";

	var holdTime:Float = 0;
	var stopMusicPlay:Bool = false;

	override function create()
	{
		persistentUpdate = true;
		PlayState.isStoryMode = false;

		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		if (WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;

			MusicBeatState.switchState(new states.ErrorState(
				"NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())
			));
			return;
		}

		for (i in 0...WeekData.weeksList.length)
		{
			if (weekIsLocked(WeekData.weeksList[i]))
				continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);

			WeekData.setDirectoryFromWeek(leWeek);

			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];

				if (colors == null || colors.length < 3)
					colors = [146, 113, 253];

				addSong(
					song[0],
					i,
					song[1],
					FlxColor.fromRGB(colors[0], colors[1], colors[2])
				);
			}
		}

		// Oculta una entrada Erect duplicada si existe la canción base.
		// No oculta canciones Erect independientes sin canción base.
		var baseSongNames:Array<String> = [];

		for (song in songs)
			baseSongNames.push(Paths.formatToSongPath(song.songName));

		var filteredSongs:Array<SongMetadata> = [];

		for (song in songs)
		{
			var songPath:String = Paths.formatToSongPath(song.songName);

			if (songPath.endsWith("-erect"))
			{
				var baseName:String = songPath.substr(
					0,
					songPath.length - "-erect".length
				);

				if (baseSongNames.contains(baseName))
					continue;
			}

			filteredSongs.push(song);
		}

		songs = filteredSongs;

		Mods.loadTopMod();

		if (songs.length == 0)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;

			MusicBeatState.switchState(new states.ErrorState(
				"No songs available for Freeplay.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())
			));
			return;
		}

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();
		mobile.WideScreen.fit(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.targetY = i;
			grpSongs.add(songText);

			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;

			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			songText.visible = songText.active = songText.isMenuItem = false;
			icon.visible = icon.active = false;

			iconArray.push(icon);
			add(icon);
		}

		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		missingTextBG = new FlxSprite().makeGraphic(
			FlxG.width,
			FlxG.height,
			FlxColor.BLACK
		);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);

		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(
			Paths.font("vcr.ttf"),
			24,
			FlxColor.WHITE,
			CENTER,
			FlxTextBorderStyle.OUTLINE,
			FlxColor.BLACK
		);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if (curSelected >= songs.length || curSelected < 0)
			curSelected = 0;

		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(
			Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName))
		);

		bottomBG = new FlxSprite(0, FlxG.height - 26)
			.makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		#if mobile
		var leText:String = Language.getPhrase(
			"freeplay_tip_mobile",
			"Tap a song to select it, tap again to play / Drag to scroll / Swipe sideways or tap the difficulty to change it."
		);
		#else
		var leText:String = Language.getPhrase(
			"freeplay_tip",
			"Press SPACE to listen to the Song / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy."
		);
		#end

		bottomString = leText;

		var size:Int = 16;
		bottomText = new FlxText(
			bottomBG.x,
			bottomBG.y + 4,
			FlxG.width,
			leText,
			size
		);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);

		player = new MusicPlayer(this);
		add(player);

		#if mobile
		createTouchButtons();
		#end

		changeSelection(0, false);
		updateTexts();

		super.create();
	}

	// -------------------------------------------------------------------------
	// DIFICULTADES PERSONALIZADAS
	// -------------------------------------------------------------------------

	function chartExists(folder:String, chart:String):Bool
	{
		if (folder == null || folder.length == 0 || chart == null || chart.length == 0)
			return false;

		var path:String = Paths.getPath('data/$folder/$chart.json', TEXT);

		#if sys
		if (FileSystem.exists(path))
			return true;
		#end

		return Assets.exists(path);
	}

	function findVariant(
		displayName:String,
		charts:Array<String>,
		folders:Array<String>,
		baseDifficulty:Int
	):FreeplayDifficulty
	{
		for (folder in folders)
		{
			for (chart in charts)
			{
				if (chartExists(folder, chart))
				{
					return new FreeplayDifficulty(
						displayName,
						chart,
						folder,
						baseDifficulty,
						true,
						displayName
					);
				}
			}
		}

		return null;
	}

	function buildSongDifficulties():Void
	{
		selectedDifficulties = [];

		var songLowercase:String =
			Paths.formatToSongPath(songs[curSelected].songName);

		var defaultDifficulty:Int =
			Difficulty.defaultList.indexOf(Difficulty.getDefault());

		if (defaultDifficulty < 0 || defaultDifficulty >= Difficulty.list.length)
			defaultDifficulty = 0;

		// Dificultades estándar de Psych Engine.
		for (i in 0...Difficulty.list.length)
		{
			var chart:String = Highscore.formatSong(songLowercase, i);

			selectedDifficulties.push(new FreeplayDifficulty(
				Difficulty.getString(i),
				chart,
				songLowercase,
				i,
				false,
				Difficulty.getString(i, false)
			));
		}

		var erectFolders:Array<String> = [
			songs[curSelected].songName + " erect",
			songLowercase + " erect",
			songLowercase + "-erect",
			songLowercase
		];

		var erect:FreeplayDifficulty = findVariant(
			"Erect",
			[
				songLowercase + "-erect-erect",
				songLowercase + "-erect"
			],
			erectFolders,
			defaultDifficulty
		);

		if (erect != null)
			selectedDifficulties.push(erect);

		var nightmare:FreeplayDifficulty = findVariant(
			"Nightmare",
			[
				songLowercase + "-erect-nightmare"
			],
			erectFolders,
			defaultDifficulty
		);

		if (nightmare != null)
			selectedDifficulties.push(nightmare);

		if (selectedDifficulties.length == 0)
		{
			selectedDifficulties.push(new FreeplayDifficulty(
				Difficulty.getDefault(),
				songLowercase,
				songLowercase,
				0,
				false
			));
		}
	}

	function getSelectedDifficulty():FreeplayDifficulty
	{
		if (selectedDifficulties == null || selectedDifficulties.length == 0)
		{
			var songLowercase:String =
				Paths.formatToSongPath(songs[curSelected].songName);

			return new FreeplayDifficulty(
				"Normal",
				songLowercase,
				songLowercase,
				0,
				false
			);
		}

		curDifficulty = FlxMath.wrap(
			curDifficulty,
			0,
			selectedDifficulties.length - 1
		);

		return selectedDifficulties[curDifficulty];
	}

	function loadSelectedChart():Void
	{
		var selected:FreeplayDifficulty = getSelectedDifficulty();

		Mods.currentModDirectory = songs[curSelected].folder;

		Song.loadFromJson(selected.chart, selected.folder);
	}

	function getScoreDifficulty():Int
	{
		var selected:FreeplayDifficulty = getSelectedDifficulty();

		if (selected.baseDifficulty < 0 || selected.baseDifficulty >= Difficulty.list.length)
			return 0;

		return selected.baseDifficulty;
	}

	function getPreviewChartKey():String
	{
		var selected:FreeplayDifficulty = getSelectedDifficulty();
		return selected.folder + "/" + selected.chart;
	}

	// Copia las dificultades actuales para que PauseSubState pueda usarlas.
	function syncPauseDifficulties():Void
	{
		pauseDifficultyNames = [];
		pauseDifficultyCharts = [];
		pauseDifficultyFolders = [];
		pauseDifficultyCustom = [];
		pauseDifficultyBase = [];

		for (difficulty in selectedDifficulties)
		{
			pauseDifficultyNames.push(difficulty.name);
			pauseDifficultyCharts.push(difficulty.chart);
			pauseDifficultyFolders.push(difficulty.folder);
			pauseDifficultyCustom.push(difficulty.custom);
			pauseDifficultyBase.push(difficulty.baseDifficulty);
		}

		pauseCurrentDifficulty = curDifficulty;
		pauseModDirectory = songs[curSelected].folder;
	}

	// -------------------------------------------------------------------------
	// CONTROLES TÁCTILES
	// -------------------------------------------------------------------------

	#if mobile
	var backButton:mobile.MobileButton;
	var previewButton:mobile.TouchButton;
	var changersButton:mobile.TouchButton;
	var resetButton:mobile.TouchButton;
	var dragAccum:Float = 0;

	function createTouchButtons()
	{
		backButton = mobile.MobileButton.back();
		add(backButton);

		var buttonY:Float = bottomBG.y - 56;

		resetButton = makeTouchButton(
			Language.getPhrase('freeplay_touch_reset', 'RESET'),
			'reset',
			backButton.x - 170,
			buttonY
		);

		changersButton = makeTouchButton(
			Language.getPhrase('freeplay_touch_changers', 'MODIFIERS'),
			'modifiers',
			resetButton.x - 170,
			buttonY
		);

		previewButton = makeTouchButton(
			Language.getPhrase('freeplay_touch_preview', 'LISTEN'),
			'listen',
			changersButton.x - 170,
			buttonY
		);
	}

	function makeTouchButton(
		label:String,
		image:String,
		x:Float,
		y:Float
	):mobile.TouchButton
	{
		var button:mobile.TouchButton = new mobile.TouchButton(x, y, label);
		button.useImage(Paths.image('mobile/freeplay/$image'));
		add(button);
		return button;
	}

	function updateTouch()
	{
		touchAccept = touchPreview = touchChangers = touchReset = false;

		mobile.TouchInput.blockGestures = !player.playingMusic;

		changersButton.visible = resetButton.visible = !player.playingMusic;

		if (previewButton.justTapped)
		{
			touchPreview = true;
			return;
		}

		if (player.playingMusic)
		{
			dragAccum = 0;
			return;
		}

		if (changersButton.justTapped)
		{
			touchChangers = true;
			return;
		}

		if (resetButton.justTapped)
		{
			touchReset = true;
			return;
		}

		if (
			mobile.TouchInput.justSwiped('ui_left')
			|| mobile.TouchInput.justSwiped('ui_right')
		)
		{
			changeDiff(mobile.TouchInput.justSwiped('ui_left') ? -1 : 1);
			_updateSongLastDifficulty();
		}

		if (songs.length > 1 && mobile.TouchInput.isDragging())
		{
			var step:Float = 100;
			dragAccum += mobile.TouchInput.dragDeltaY();

			while (dragAccum >= step)
			{
				dragAccum -= step;
				changeSelection(-1);
			}

			while (dragAccum <= -step)
			{
				dragAccum += step;
				changeSelection(1);
			}
		}
		else
		{
			dragAccum = 0;
		}

		if (!mobile.TouchInput.justTapped())
			return;

		var tapX:Float = mobile.TouchInput.tapX;
		var tapY:Float = mobile.TouchInput.tapY;

		if (tapX >= scoreText.x - 6 && tapY <= scoreBG.y + scoreBG.height)
		{
			changeDiff(tapX < diffText.x + diffText.width / 2 ? -1 : 1);
			_updateSongLastDifficulty();
			return;
		}

		for (i in _lastVisibles)
		{
			if (
				mobile.TouchInput.overlapsScreen(grpSongs.members[i], tapX, tapY, null, 10)
				|| mobile.TouchInput.overlapsScreen(iconArray[i], tapX, tapY)
			)
			{
				if (i == curSelected)
					touchAccept = true;
				else
					changeSelection(i - curSelected);

				break;
			}
		}
	}

	override function openSubState(subState:flixel.FlxSubState)
	{
		mobile.TouchInput.blockGestures = false;
		super.openSubState(subState);
	}
	#end

	var touchAccept:Bool = false;
	var touchPreview:Bool = false;
	var touchChangers:Bool = false;
	var touchReset:Bool = false;

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(
		songName:String,
		weekNum:Int,
		songCharacter:String,
		color:Int
	)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);

		return (
			!leWeek.startUnlocked
			&& leWeek.weekBefore.length > 0
			&& (
				!StoryMenuState.weekCompleted.exists(leWeek.weekBefore)
				|| !StoryMenuState.weekCompleted.get(leWeek.weekBefore)
			)
		);
	}

	override function update(elapsed:Float)
	{
		if (WeekData.weeksList.length < 1)
			return;

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(
			FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24))
		);
		lerpRating = FlxMath.lerp(
			intendedRating,
			lerpRating,
			Math.exp(-elapsed * 12)
		);

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;

		#if mobile
		if (subState == null)
			updateTouch();
		#end

		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(
			CoolUtil.floorDecimal(lerpRating * 100, 2)
		).split('.');

		if (ratingSplit.length < 2)
			ratingSplit.push('');

		while (ratingSplit[1].length < 2)
			ratingSplit[1] += '0';

		var shiftMult:Int = 1;

		if (FlxG.keys.pressed.SHIFT)
			shiftMult = 3;

		if (!player.playingMusic)
		{
			scoreText.text = Language.getPhrase(
				'personal_best',
				'PERSONAL BEST: {1} ({2}%)',
				[lerpScore, ratingSplit.join('.')]
			);

			positionHighscore();

			if (songs.length > 1)
			{
				if (FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection(0);
					holdTime = 0;
				}
				else if (FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection(0);
					holdTime = 0;
				}

				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					{
						changeSelection(
							(checkNewHold - checkLastHold)
							* (controls.UI_UP ? -shiftMult : shiftMult)
						);
					}
				}

				if (FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;
				instPlayingChart = null;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
		}

		if (
			(FlxG.keys.justPressed.CONTROL || touchChangers)
			&& !player.playingMusic
		)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if (FlxG.keys.justPressed.SPACE || touchPreview)
		{
			var previewKey:String = getPreviewChartKey();

			if (instPlayingChart != previewKey && !player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;

				try
				{
					loadSelectedChart();

					if (PlayState.SONG.needsVoices)
					{
						vocals = new FlxSound();

						try
						{
							var playerVocals:String =
								getVocalFromCharacter(PlayState.SONG.player1);

							var loadedVocals = Paths.voices(
								PlayState.SONG.song,
								(playerVocals != null && playerVocals.length > 0)
									? playerVocals
									: 'Player'
							);

							if (loadedVocals == null)
								loadedVocals = Paths.voices(PlayState.SONG.song);

							if (loadedVocals != null && loadedVocals.length > 0)
							{
								vocals.loadEmbedded(loadedVocals);
								FlxG.sound.list.add(vocals);
								vocals.persist = vocals.looped = true;
								vocals.volume = 0.8;
								vocals.play();
								vocals.pause();
							}
							else
							{
								vocals = FlxDestroyUtil.destroy(vocals);
							}
						}
						catch (e:Dynamic)
						{
							vocals = FlxDestroyUtil.destroy(vocals);
						}

						opponentVocals = new FlxSound();

						try
						{
							var oppVocals:String =
								getVocalFromCharacter(PlayState.SONG.player2);

							var loadedVocals = Paths.voices(
								PlayState.SONG.song,
								(oppVocals != null && oppVocals.length > 0)
									? oppVocals
									: 'Opponent'
							);

							if (loadedVocals != null && loadedVocals.length > 0)
							{
								opponentVocals.loadEmbedded(loadedVocals);
								FlxG.sound.list.add(opponentVocals);
								opponentVocals.persist = opponentVocals.looped = true;
								opponentVocals.volume = 0.8;
								opponentVocals.play();
								opponentVocals.pause();
							}
							else
							{
								opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
							}
						}
						catch (e:Dynamic)
						{
							opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
						}
					}

					FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
					FlxG.sound.music.pause();

					instPlaying = curSelected;
					instPlayingChart = previewKey;

					player.playingMusic = true;
					player.curTime = 0;
					player.switchPlayMusic();
					player.pauseOrResume(true);
				}
				catch (e:Dynamic)
				{
					destroyFreeplayVocals();

					missingText.text =
						'ERROR WHILE LOADING PREVIEW:\n' + Std.string(e);
					missingText.screenCenter(Y);
					missingText.visible = true;
					missingTextBG.visible = true;

					FlxG.sound.play(Paths.sound('cancelMenu'));
				}
			}
			else if (instPlayingChart == previewKey && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if ((controls.ACCEPT || touchAccept) && !player.playingMusic)
		{
			persistentUpdate = false;

			try
			{
				Mods.currentModDirectory = songs[curSelected].folder;

				loadSelectedChart();

				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = getScoreDifficulty();

				// Guarda el chart elegido para el menú de pausa.
				var selected:FreeplayDifficulty = getSelectedDifficulty();

				currentCustomDifficulty = selected.custom ? selected.saveName : null;
				currentCustomChart = selected.custom ? selected.chart : null;
				currentCustomFolder = selected.custom ? selected.folder : null;
				currentFreeplaySong = songs[curSelected].songName;

				// El menú de pausa recibirá también todas las dificultades disponibles.
				syncPauseDifficulties();

				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
			}
			catch (e:Dynamic)
			{
				trace('ERROR! ${Std.string(e)}');

				var errorStr:String = Std.string(e);

				if (errorStr.contains('There is no TEXT asset with an ID of'))
				{
					var songLowercase:String =
						Paths.formatToSongPath(songs[curSelected].songName);

					var startIndex:Int = errorStr.indexOf(songLowercase);

					if (startIndex >= 0)
						errorStr = 'Missing file: ' + errorStr.substring(startIndex);
				}

				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;

				FlxG.sound.play(Paths.sound('cancelMenu'));

				persistentUpdate = true;
				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}

			@:privateAccess
			if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}

			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());

			#if !SHOW_LOADING_SCREEN
			FlxG.sound.music.stop();
			#end

			stopMusicPlay = true;

			destroyFreeplayVocals();

			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else if ((controls.RESET || touchReset) && !player.playingMusic)
		{
			persistentUpdate = false;

			openSubState(new ResetScoreSubState(
				songs[curSelected].songName,
				getScoreDifficulty(),
				songs[curSelected].songCharacter
			));

			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		updateTexts(elapsed);
		super.update(elapsed);
	}

	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);

			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end

			return character.vocals_file;
		}
		catch (e:Dynamic) {}

		return null;
	}

	public static function destroyFreeplayVocals()
	{
		if (vocals != null)
			vocals.stop();

		vocals = FlxDestroyUtil.destroy(vocals);

		if (opponentVocals != null)
			opponentVocals.stop();

		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	// -------------------------------------------------------------------------
	// CAMBIO DE DIFICULTAD
	// -------------------------------------------------------------------------

	function changeDiff(change:Int = 0)
	{
		if (
			player.playingMusic
			|| selectedDifficulties == null
			|| selectedDifficulties.length == 0
		)
			return;

		curDifficulty = FlxMath.wrap(
			curDifficulty + change,
			0,
			selectedDifficulties.length - 1
		);

		var selected:FreeplayDifficulty = getSelectedDifficulty();
		var scoreDiff:Int = getScoreDifficulty();

		// Mantiene actualizada la lista de dificultades del pause.
		syncPauseDifficulties();

		#if !switch
		if (selected.custom)
		{
			intendedScore = Highscore.getCustomScore(
				songs[curSelected].songName,
				selected.saveName
			);

			intendedRating = Highscore.getCustomRating(
				songs[curSelected].songName,
				selected.saveName
			);
		}
		else
		{
			intendedScore = Highscore.getScore(
				songs[curSelected].songName,
				scoreDiff
			);

			intendedRating = Highscore.getRating(
				songs[curSelected].songName,
				scoreDiff
			);
		}
		#end

		lastDifficultyName = selected.name;

		var displayDiff:String = selected.name;

		if (selectedDifficulties.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();

		positionHighscore();

		missingText.visible = false;
		missingTextBG.visible = false;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic || songs.length == 0)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);

		if (playSound)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var newColor:Int = songs[curSelected].color;

		if (newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpSongs.members)
		{
			var icon:HealthIcon = iconArray[num];

			item.alpha = 0.6;
			icon.alpha = 0.6;

			if (item.targetY == curSelected)
			{
				item.alpha = 1;
				icon.alpha = 1;
			}
		}

		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;

		Difficulty.loadFromWeek();

		buildSongDifficulties();

		var savedDiff:String = songs[curSelected].lastDifficulty;
		var foundDifficulty:Bool = false;

		if (savedDiff != null)
		{
			for (i in 0...selectedDifficulties.length)
			{
				if (
					selectedDifficulties[i].name == savedDiff
					|| selectedDifficulties[i].saveName == savedDiff
				)
				{
					curDifficulty = i;
					foundDifficulty = true;
					break;
				}
			}
		}

		if (!foundDifficulty && lastDifficultyName != null)
		{
			for (i in 0...selectedDifficulties.length)
			{
				if (
					selectedDifficulties[i].name == lastDifficultyName
					|| selectedDifficulties[i].saveName == lastDifficultyName
				)
				{
					curDifficulty = i;
					foundDifficulty = true;
					break;
				}
			}
		}

		if (!foundDifficulty)
		{
			curDifficulty = 0;

			for (i in 0...selectedDifficulties.length)
			{
				if (
					selectedDifficulties[i].saveName == Difficulty.getDefault()
					|| selectedDifficulties[i].name == Difficulty.getDefault()
				)
				{
					curDifficulty = i;
					break;
				}
			}
		}

		changeDiff(0);
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
	{
		if (selectedDifficulties != null && selectedDifficulties.length > 0)
		{
			var selected:FreeplayDifficulty = getSelectedDifficulty();

			songs[curSelected].lastDifficulty = selected.saveName;
			lastDifficultyName = selected.name;

			syncPauseDifficulties();
		}
	}

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];

	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(
			curSelected,
			lerpSelected,
			Math.exp(-elapsed * 9.6)
		);

		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
			iconArray[i].visible = iconArray[i].active = false;
		}

		_lastVisibles = [];

		var min:Int = Math.round(
			Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance))
		);

		var max:Int = Math.round(
			Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance))
		);

		for (i in min...max)
		{
			var item:Alphabet = grpSongs.members[i];

			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x)
				+ item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y)
				+ item.startPosition.y;

			var icon:HealthIcon = iconArray[i];
			icon.visible = icon.active = true;

			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		#if mobile
		mobile.TouchInput.blockGestures = false;
		#end

		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;

		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}
}

// -----------------------------------------------------------------------------
// DATOS DE DIFICULTAD PARA FREEPLAY
// -----------------------------------------------------------------------------

class FreeplayDifficulty
{
	public var name:String;
	public var chart:String;
	public var folder:String;
	public var baseDifficulty:Int;
	public var custom:Bool;
	public var saveName:String;

	public function new(
		name:String,
		chart:String,
		folder:String,
		baseDifficulty:Int,
		custom:Bool = false,
		saveName:String = null
	)
	{
		this.name = name;
		this.chart = chart;
		this.folder = folder;
		this.baseDifficulty = baseDifficulty;
		this.custom = custom;
		this.saveName = saveName == null ? name : saveName;
	}
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(
		song:String,
		week:Int,
		songCharacter:String,
		color:Int
	)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;

		if (this.folder == null)
			this.folder = '';
	}
}
