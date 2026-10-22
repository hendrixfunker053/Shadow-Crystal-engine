
package substates;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.util.FlxStringUtil;

import states.StoryMenuState;
import states.FreeplayState;
import options.OptionsState;

class PauseSubState extends MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<Alphabet>;

	var menuItems:Array<String> = [];
	var menuItemsOG:Array<String> = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];
	var difficultyChoices:Array<String> = [];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;
	var practiceText:FlxText;
	var skipTimeText:FlxText;
	var skipTimeTracker:Alphabet;
	var curTime:Float = Math.max(0, Conductor.songPosition);

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	public static var songName:String = null;

	var customDifficultyChoices:Array<String> = [];
	var showingDifficultyMenu:Bool = false;

	override function create()
	{
		menuItemsOG = ['Resume', 'Restart Song', 'Change Difficulty', 'Options', 'Exit to menu'];

		if (Difficulty.list.length < 2)
			menuItemsOG.remove('Change Difficulty');

		if (PlayState.chartingMode)
		{
			menuItemsOG.insert(2, 'Leave Charting Mode');

			var num:Int = 0;
			if (!PlayState.instance.startingSong)
			{
				num = 1;
				menuItemsOG.insert(3, 'Skip Time');
			}

			menuItemsOG.insert(3 + num, 'End Song');
			menuItemsOG.insert(4 + num, 'Toggle Practice Mode');
			menuItemsOG.insert(5 + num, 'Toggle Botplay');
		}
		else if (PlayState.instance.practiceMode && !PlayState.instance.startingSong)
		{
			menuItemsOG.insert(3, 'Skip Time');
		}

		#if mobile
		if (ClientPrefs.data.pauseChartEditor)
			menuItemsOG.insert(menuItemsOG.indexOf('Restart Song') + 1, 'Chart Editor');
		#end

		menuItems = menuItemsOG;

		buildDifficultyChoices();

		pauseMusic = new FlxSound();

		try
		{
			var pauseSong:String = getPauseSong();
			if (pauseSong != null)
				pauseMusic.loadEmbedded(Paths.music(pauseSong), true, true);
		}
		catch (e:Dynamic) {}

		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));
		FlxG.sound.list.add(pauseMusic);

		var bg:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var levelInfo:FlxText = new FlxText(20, 15, 0, PlayState.SONG.song, 32);
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32);
		levelInfo.updateHitbox();
		add(levelInfo);

		var displayedDifficulty:String = Difficulty.getString().toUpperCase();

		if (FreeplayState.currentCustomDifficulty != null)
			displayedDifficulty = FreeplayState.currentCustomDifficulty.toUpperCase();

		var levelDifficulty:FlxText = new FlxText(20, 15 + 32, 0, displayedDifficulty, 32);
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 32);
		levelDifficulty.updateHitbox();
		add(levelDifficulty);

		var blueballedTxt:FlxText = new FlxText(
			20,
			15 + 64,
			0,
			Language.getPhrase("blueballed", "Blueballed: {1}", [PlayState.deathCounter]),
			32
		);
		blueballedTxt.scrollFactor.set();
		blueballedTxt.setFormat(Paths.font('vcr.ttf'), 32);
		blueballedTxt.updateHitbox();
		add(blueballedTxt);

		practiceText = new FlxText(20, 15 + 101, 0, Language.getPhrase("Practice Mode").toUpperCase(), 32);
		practiceText.scrollFactor.set();
		practiceText.setFormat(Paths.font('vcr.ttf'), 32);
		practiceText.x = FlxG.width - (practiceText.width + 20);
		practiceText.updateHitbox();
		practiceText.visible = PlayState.instance.practiceMode;
		add(practiceText);

		var chartingText:FlxText = new FlxText(20, 15 + 101, 0, Language.getPhrase("Charting Mode").toUpperCase(), 32);
		chartingText.scrollFactor.set();
		chartingText.setFormat(Paths.font('vcr.ttf'), 32);
		chartingText.x = FlxG.width - (chartingText.width + 20);
		chartingText.y = FlxG.height - (chartingText.height + 20);
		chartingText.updateHitbox();
		chartingText.visible = PlayState.chartingMode;
		add(chartingText);

		blueballedTxt.alpha = 0;
		levelDifficulty.alpha = 0;
		levelInfo.alpha = 0;

		levelInfo.x = FlxG.width - (levelInfo.width + 20);
		levelDifficulty.x = FlxG.width - (levelDifficulty.width + 20);
		blueballedTxt.x = FlxG.width - (blueballedTxt.width + 20);

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {
			ease: FlxEase.quartInOut,
			startDelay: 0.3
		});
		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {
			ease: FlxEase.quartInOut,
			startDelay: 0.5
		});
		FlxTween.tween(blueballedTxt, {alpha: 1, y: blueballedTxt.y + 5}, 0.4, {
			ease: FlxEase.quartInOut,
			startDelay: 0.7
		});

		grpMenuShit = new FlxTypedGroup<Alphabet>();
		add(grpMenuShit);

		missingTextBG = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		missingTextBG.scale.set(FlxG.width, FlxG.height);
		missingTextBG.updateHitbox();
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

		regenMenu();

		#if mobile
		backButton = mobile.MobileButton.back();
		add(backButton);
		#end

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		super.create();
	}

	function buildDifficultyChoices():Void
	{
		difficultyChoices = [];

		for (i in 0...Difficulty.list.length)
			difficultyChoices.push(Difficulty.getString(i));

		customDifficultyChoices = [];

		if (FreeplayState.currentCustomDifficulty != null)
		{
			var current:String = FreeplayState.currentCustomDifficulty.toLowerCase();

			if (current == 'erect' || current == 'nightmare')
			{
				customDifficultyChoices.push('ERECT');
				customDifficultyChoices.push('NIGHTMARE');
			}
		}

		for (customDiff in customDifficultyChoices)
		{
			if (!difficultyChoices.contains(customDiff))
				difficultyChoices.push(customDiff);
		}

		difficultyChoices.push('BACK');
	}

	function getPauseSong()
	{
		var formattedSongName:String = (songName != null ? Paths.formatToSongPath(songName) : '');
		var formattedPauseMusic:String = Paths.formatToSongPath(ClientPrefs.data.pauseMusic);

		if (formattedSongName == 'none' || (formattedSongName != 'none' && formattedPauseMusic == 'none'))
			return null;

		return (formattedSongName != '') ? formattedSongName : formattedPauseMusic;
	}

	#if mobile
	var backButton:mobile.MobileButton;
	#end

	var holdTime:Float = 0;
	var cantUnpause:Float = 0.1;

	override function update(elapsed:Float)
	{
		cantUnpause -= elapsed;

		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);

		if (controls.BACK)
		{
			if (showingDifficultyMenu)
				returnToPauseMenu();
			else
				close();

			return;
		}

		if (FlxG.keys.justPressed.F5)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			PlayState.nextReloadAll = true;
			MusicBeatState.resetState();
		}

		updateSkipTextStuff();

		var touchAccept:Bool = false;

		#if mobile
		var tapped:Int = mobile.TouchInput.tappedRow(cast grpMenuShit.members);
		mobile.TouchInput.consumeTap();

		if (tapped > -1)
		{
			if (tapped == curSelected)
				touchAccept = true;
			else
				changeSelection(tapped - curSelected);
		}
		#end

		if (controls.UI_UP_P)
			changeSelection(-1);

		if (controls.UI_DOWN_P)
			changeSelection(1);

		var daSelected:String = menuItems[curSelected];

		if (daSelected == 'Skip Time')
		{
			if (controls.UI_LEFT_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				curTime -= 1000;
				holdTime = 0;
			}

			if (controls.UI_RIGHT_P)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				curTime += 1000;
				holdTime = 0;
			}

			if (controls.UI_LEFT || controls.UI_RIGHT)
			{
				holdTime += elapsed;

				if (holdTime > 0.5)
					curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1);

				if (curTime >= FlxG.sound.music.length)
					curTime -= FlxG.sound.music.length;
				else if (curTime < 0)
					curTime += FlxG.sound.music.length;

				updateSkipTimeText();
			}
		}

		if ((controls.ACCEPT || touchAccept) && (cantUnpause <= 0 || !controls.controllerMode))
		{
			if (showingDifficultyMenu)
			{
				if (daSelected == 'BACK')
				{
					returnToPauseMenu();
					return;
				}

				loadChosenDifficulty(daSelected);
				return;
			}

			switch (daSelected)
			{
				case "Resume":
					close();

				case 'Change Difficulty':
					showingDifficultyMenu = true;
					menuItems = difficultyChoices;
					deleteSkipTimeText();
					regenMenu();

				case 'Toggle Practice Mode':
					PlayState.instance.practiceMode = !PlayState.instance.practiceMode;
					PlayState.changedDifficulty = true;
					practiceText.visible = PlayState.instance.practiceMode;

				case "Restart Song":
					restartSong();

				#if mobile
				case 'Chart Editor':
					PlayState.instance.canResync = false;
					@:privateAccess PlayState.instance.openChartEditor();
				#end

				case "Leave Charting Mode":
					restartSong();
					PlayState.chartingMode = false;

				case 'Skip Time':
					if (curTime < Conductor.songPosition)
					{
						PlayState.startOnTime = curTime;
						restartSong(true);
					}
					else
					{
						if (curTime != Conductor.songPosition)
						{
							PlayState.instance.clearNotesBefore(curTime);
							PlayState.instance.setSongTime(curTime);
						}
						close();
					}

				case 'End Song':
					close();
					PlayState.instance.notes.clear();
					PlayState.instance.unspawnNotes = [];
					PlayState.instance.finishSong(true);

				case 'Toggle Botplay':
					PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
					PlayState.changedDifficulty = true;
					PlayState.instance.botplayTxt.visible = PlayState.instance.cpuControlled;
					PlayState.instance.botplayTxt.alpha = 1;
					PlayState.instance.botplaySine = 0;

				case 'Options':
					PlayState.instance.paused = true;
					PlayState.instance.vocals.volume = 0;
					PlayState.instance.canResync = false;

					MusicBeatState.switchState(new OptionsState());

					if (ClientPrefs.data.pauseMusic != 'None')
					{
						FlxG.sound.playMusic(
							Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)),
							pauseMusic.volume
						);
						FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
						FlxG.sound.music.time = pauseMusic.time;
					}

					OptionsState.onPlayState = true;

				case "Exit to menu":
					#if DISCORD_ALLOWED
					DiscordClient.resetClientID();
					#end

					PlayState.deathCounter = 0;
					PlayState.seenCutscene = false;
					PlayState.instance.canResync = false;
					Mods.loadTopMod();

					if (PlayState.isStoryMode)
						MusicBeatState.switchState(new StoryMenuState());
					else
						MusicBeatState.switchState(new FreeplayState());

					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					PlayState.changedDifficulty = false;
					PlayState.chartingMode = false;
					FlxG.camera.followLerp = 0;
			}
		}
	}

	/**
	 * Obtiene el nombre base de la canción para evitar que una chart personalizada
	 * convierta "song-hard" en "song-erect-hard".
	 *
	 * Solo elimina los sufijos de variante si el estado actual indica que se está
	 * jugando una dificultad personalizada.
	 */
	function getBaseSongName():String
	{
		var baseSong:String = Paths.formatToSongPath(PlayState.SONG.song);

		if (FreeplayState.currentCustomDifficulty != null)
		{
			var customChart:String = FreeplayState.currentCustomChart;

			if (customChart != null && customChart != '')
			{
				var normalizedChart:String = Paths.formatToSongPath(customChart);

				// Elimina únicamente el sufijo de dificultad personalizado conocido.
				if (StringTools.endsWith(normalizedChart, '-erect-nightmare'))
					baseSong = normalizedChart.substr(0, normalizedChart.length - '-erect-nightmare'.length);
				else if (StringTools.endsWith(normalizedChart, '-erect-erect'))
					baseSong = normalizedChart.substr(0, normalizedChart.length - '-erect-erect'.length);
				else if (StringTools.endsWith(normalizedChart, '-nightmare'))
					baseSong = normalizedChart.substr(0, normalizedChart.length - '-nightmare'.length);
				else if (StringTools.endsWith(normalizedChart, '-erect'))
					baseSong = normalizedChart.substr(0, normalizedChart.length - '-erect'.length);
			}
			else
			{
				if (StringTools.endsWith(baseSong, '-erect'))
					baseSong = baseSong.substr(0, baseSong.length - '-erect'.length);
				else if (StringTools.endsWith(baseSong, '-nightmare'))
					baseSong = baseSong.substr(0, baseSong.length - '-nightmare'.length);
			}
		}

		return baseSong;
	}

	function loadChosenDifficulty(selected:String):Bool
	{
		var songLowercase:String = getBaseSongName();

		try
		{
			if (selected == 'ERECT' || selected == 'NIGHTMARE')
			{
				var customName:String = selected.toLowerCase();
				var chartCandidates:Array<String> = [];
				var folderCandidates:Array<String> = [];

				if (customName == 'erect')
				{
					chartCandidates = [
						songLowercase + '-erect-erect',
						songLowercase + '-erect'
					];
				}
				else
				{
					chartCandidates = [
						songLowercase + '-erect-nightmare',
						songLowercase + '-nightmare'
					];
				}

				if (FreeplayState.currentCustomFolder != null
					&& FreeplayState.currentCustomFolder != '')
				{
					folderCandidates.push(FreeplayState.currentCustomFolder);
				}

				folderCandidates.push(PlayState.SONG.song + ' erect');
				folderCandidates.push(songLowercase + ' erect');
				folderCandidates.push(songLowercase + '-erect');
				folderCandidates.push(songLowercase);

				var loaded:Bool = false;
				var lastError:Dynamic = null;

				for (chart in chartCandidates)
				{
					if (loaded)
						break;

					for (folder in folderCandidates)
					{
						try
						{
							Song.loadFromJson(chart, folder);

							FreeplayState.currentCustomDifficulty = customName;
							FreeplayState.currentCustomChart = chart;
							FreeplayState.currentCustomFolder = folder;

							loaded = true;
							break;
						}
						catch (e:Dynamic)
						{
							lastError = e;
						}
					}
				}

				if (!loaded)
					throw (lastError != null ? lastError : 'No se encontró la chart $selected');

				PlayState.storyDifficulty = Difficulty.list.length - 1;
			}
			else
			{
				var selectedIndex:Int = -1;

				for (i in 0...Difficulty.list.length)
				{
					if (Difficulty.getString(i) == selected)
					{
						selectedIndex = i;
						break;
					}
				}

				if (selectedIndex < 0)
					throw 'Dificultad desconocida: $selected';

				// Usar el nombre base, no el nombre de la variante Erect/Nightmare.
				var chartName:String = Highscore.formatSong(songLowercase, selectedIndex);
				Song.loadFromJson(chartName, songLowercase);

				PlayState.storyDifficulty = selectedIndex;

				FreeplayState.currentCustomDifficulty = null;
				FreeplayState.currentCustomChart = null;
				FreeplayState.currentCustomFolder = null;
			}

			PlayState.changedDifficulty = true;
			PlayState.chartingMode = false;
			FlxG.sound.music.volume = 0;
			MusicBeatState.resetState();

			return true;
		}
		catch (e:Dynamic)
		{
			trace('ERROR AL CARGAR DIFICULTAD: $e');

			var errorStr:String = Std.string(e);

			missingText.text = 'ERROR WHILE LOADING CHART:\n' + errorStr;
			missingText.screenCenter(Y);
			missingText.visible = true;
			missingTextBG.visible = true;

			FlxG.sound.play(Paths.sound('cancelMenu'));
			return false;
		}
	}

	function returnToPauseMenu():Void
	{
		showingDifficultyMenu = false;
		menuItems = menuItemsOG;
		deleteSkipTimeText();
		regenMenu();
	}

	function deleteSkipTimeText()
	{
		if (skipTimeText != null)
		{
			skipTimeText.kill();
			remove(skipTimeText);
			skipTimeText.destroy();
		}

		skipTimeText = null;
		skipTimeTracker = null;
	}

	public static function restartSong(noTrans:Bool = false)
	{
		PlayState.instance.paused = true;
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		if (noTrans)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}

		MusicBeatState.resetState();
	}

	override function destroy()
	{
		if (pauseMusic != null)
			pauseMusic.destroy();

		super.destroy();
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);

		for (num => item in grpMenuShit.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;

				if (item == skipTimeTracker)
				{
					curTime = Math.max(0, Conductor.songPosition);
					updateSkipTimeText();
				}
			}
		}

		missingText.visible = false;
		missingTextBG.visible = false;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function regenMenu():Void
	{
		while (grpMenuShit.members.length > 0)
		{
			var obj:Alphabet = grpMenuShit.members[0];
			obj.kill();
			grpMenuShit.remove(obj, true);
			obj.destroy();
		}

		for (num => str in menuItems)
		{
			var item = new Alphabet(90, 320, Language.getPhrase('pause_$str', str), true);
			item.isMenuItem = true;
			item.targetY = num;
			grpMenuShit.add(item);

			if (str == 'Skip Time')
			{
				skipTimeText = new FlxText(0, 0, 0, '', 64);
				skipTimeText.setFormat(
					Paths.font("vcr.ttf"),
					64,
					FlxColor.WHITE,
					CENTER,
					FlxTextBorderStyle.OUTLINE,
					FlxColor.BLACK
				);
				skipTimeText.scrollFactor.set();
				skipTimeText.borderSize = 2;
				skipTimeTracker = item;
				add(skipTimeText);

				updateSkipTextStuff();
				updateSkipTimeText();
			}
		}

		curSelected = 0;
		changeSelection();
	}

	function updateSkipTextStuff()
	{
		if (skipTimeText == null || skipTimeTracker == null)
			return;

		skipTimeText.x = skipTimeTracker.x + skipTimeTracker.width + 60;
		skipTimeText.y = skipTimeTracker.y;
		skipTimeText.visible = (skipTimeTracker.alpha >= 1);
	}

	function updateSkipTimeText()
	{
		if (skipTimeText == null)
			return;

		skipTimeText.text =
			FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false)
			+ ' / '
			+ FlxStringUtil.formatTime(
				Math.max(0, Math.floor(FlxG.sound.music.length / 1000)),
				false
			);
	}
}
