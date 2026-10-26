package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.group.FlxGroup;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxStringUtil;
import flixel.FlxBasic;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;

import objects.MenuItem;
import objects.MenuCharacter;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import backend.StageData;

/**
	New Story Mode menu (layout based on a 2400x1080 design).
	If "Old Story Menu" is enabled in Shadow Crystal Options, it redirects to OldStoryMenuState.
**/
class StoryMenuState extends MusicBeatState
{
	public static var weekCompleted:Map<String, Bool> = new Map<String, Bool>();

	// Design resolution of the layout art. Everything is positioned in these pixels and scaled to the game.
	static inline var DW:Float = 2400;
	static inline var DH:Float = 1080;

	var S:Float; // design px -> game px
	var ox:Float; // x origin of the design canvas (centered, works with wide screens)

	inline function dx(v:Float):Float return ox + v * S;
	inline function dy(v:Float):Float return v * S;

	var scoreText:FlxText;

	private static var lastDifficultyName:String = '';
	var curDifficulty:Int = 1;

	var txtWeekTitle:FlxText;
	var bgSprite:FlxSprite;

	private static var curWeek:Int = 0;

	var txtTracksHeader:FlxText;
	var txtTracklist:FlxText;

	var grpWeekText:FlxTypedGroup<MenuItem>;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	var grpLocks:FlxTypedGroup<FlxSprite>;
	// Center window (game px). Week items are clipped to this rect.
	var listX:Float;
	var listY:Float;
	var listW:Float;
	var listH:Float;
	var visW:Float; // visible width of the screen (game px)

	var difficultySelectors:FlxGroup;
	var sprDifficulty:FlxSprite;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;

	var hsLabel:FlxSprite;
	var digitSprites:Array<FlxSprite> = [];

	var switchSpr:FlxSprite;
	var txtPlayingAs:FlxText;
	var playAsOpponent:Bool = false;
	// Disabled for now (it will be used to switch to Pico mixes later)
	var switchEnabled:Bool = false;

	var loadedWeeks:Array<WeekData> = [];
	var redirected:Bool = false; // true when this state only forwards to OldStoryMenuState

	override function create()
	{
		// Toggle: old menu
		if (ClientPrefs.data.oldStoryMenu)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			redirected = true;
			MusicBeatState.switchState(new OldStoryMenuState());
			return;
		}

		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		persistentUpdate = persistentDraw = true;
		PlayState.isStoryMode = true;
		WeekData.reloadWeekFiles(true);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR STORY MODE\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		if(curWeek >= WeekData.weeksList.length) curWeek = 0;

		S = FlxG.height / DH;
		ox = (FlxG.initialWidth - DW * S) / 2 + mobile.WideScreen.offset;
		visW = FlxG.initialWidth + mobile.WideScreen.offset * 2;

		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		var wideW:Int = Std.int(FlxG.width + 1200);

		// --- Backgrounds ---
		var bgYellow:FlxSprite = new FlxSprite(-600, dy(84)).makeGraphic(wideW, Std.int(dy(636)), 0xFFF9CF51);
		add(bgYellow);

		bgSprite = new FlxSprite(0, dy(84));
		add(bgSprite);

		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();
		add(grpWeekCharacters);

		// black behind the transparent "windows" of the layout art (tracks, week list, difficulty, highscore)
		addBlack(535, 745, 790, 1005);
		addBlack(868, 684, 1532, 1085);
		addBlack(1615, 722, 2115, 868);
		addBlack(1670, 880, 2065, 1050);

		// --- Week list (clipped to the center window through its own camera) ---
		listX = dx(875);
		listY = dy(690);
		listW = 650 * S;
		listH = FlxG.height - listY;

		grpWeekText = new FlxTypedGroup<MenuItem>();
		add(grpWeekText);

		grpLocks = new FlxTypedGroup<FlxSprite>();
		add(grpLocks);

		var num:Int = 0;
		var itemTargetY:Float = 0;
		for (i in 0...WeekData.weeksList.length)
		{
			var weekFile:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var isLocked:Bool = weekIsLocked(WeekData.weeksList[i]);
			if(!isLocked || !weekFile.hiddenUntilUnlocked)
			{
				loadedWeeks.push(weekFile);
				WeekData.setDirectoryFromWeek(weekFile);
				var weekThing:MenuItem = new MenuItem(0, 0, WeekData.weeksList[i]);
				weekThing.ID = num;

				// shrink to fit the window if needed
				var k:Float = Math.min(1, (listW - 6) / weekThing.width);
				weekThing.scale.set(k, k);
				weekThing.updateHitbox();

				weekThing.x = listX + (listW - weekThing.width) / 2;
				weekThing.y = listY + 60 + itemTargetY;
				weekThing.targetY = itemTargetY;
				itemTargetY += Math.max(weekThing.height, 80) + 10;
				grpWeekText.add(weekThing);

				if (isLocked)
				{
					var lock:FlxSprite = new FlxSprite();
					lock.antialiasing = ClientPrefs.data.antialiasing;
					lock.frames = ui_tex;
					lock.animation.addByPrefix('lock', 'lock');
					lock.animation.play('lock');
					lock.ID = i;
					lock.x = weekThing.x + weekThing.width - lock.width - 4;
					grpLocks.add(lock);
				}
				num++;
			}
		}

		// --- Characters: slot order comes from weekCharacters in the week .json (same positions as the old menu) ---
		WeekData.setDirectoryFromWeek(loadedWeeks[0]);
		var charArray:Array<String> = loadedWeeks[0].weekCharacters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.initialWidth * 0.25) * (1 + char) - 150 + mobile.WideScreen.offset, charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		// --- Layout art (panel with the windows) ---
		var layout:FlxSprite = new FlxSprite().loadGraphic(Paths.image('newstory/layout'));
		layout.antialiasing = ClientPrefs.data.antialiasing;
		layout.scale.set(S, S);
		layout.updateHitbox();
		layout.setPosition(ox, 0);
		add(layout);

		// --- Switch character button (top right) ---
		switchSpr = new FlxSprite().loadGraphic(Paths.image('newstory/switch_char'));
		switchSpr.antialiasing = ClientPrefs.data.antialiasing;
		switchSpr.scale.set(S, S);
		switchSpr.updateHitbox();
		switchSpr.setPosition(ox, 0);
		add(switchSpr);

		if (switchEnabled)
			playAsOpponent = (ClientPrefs.data.gameplaySettings.get('opponentplay') == true);

		txtPlayingAs = new FlxText(dx(1900), dy(400), 460 * S, '', 20);
		txtPlayingAs.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.BLACK, CENTER);
		txtPlayingAs.alpha = 0.75;
		add(txtPlayingAs);
		updatePlayingAs();
		txtPlayingAs.visible = switchEnabled;

		// --- Difficulty selector ---
		difficultySelectors = new FlxGroup();
		add(difficultySelectors);

		var selTex = Paths.getSparrowAtlas('newstory/MainSelector');

		leftArrow = new FlxSprite(dx(1632), dy(735));
		leftArrow.antialiasing = ClientPrefs.data.antialiasing;
		leftArrow.frames = selTex;
		leftArrow.animation.addByPrefix('idle', 'arrow pointer loop', 12, true);
		leftArrow.animation.play('idle');
		leftArrow.scale.set(0.82, 0.82);
		leftArrow.updateHitbox();
		difficultySelectors.add(leftArrow);

		Difficulty.resetList();
		if(lastDifficultyName == '')
			lastDifficultyName = Difficulty.getDefault();
		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		sprDifficulty = new FlxSprite(0, dy(795));
		sprDifficulty.antialiasing = ClientPrefs.data.antialiasing;
		difficultySelectors.add(sprDifficulty);

		rightArrow = new FlxSprite(dx(2040), dy(735));
		rightArrow.antialiasing = ClientPrefs.data.antialiasing;
		rightArrow.frames = selTex;
		rightArrow.animation.addByPrefix('idle', 'arrow pointer loop', 12, true);
		rightArrow.animation.play('idle');
		rightArrow.flipX = true;
		rightArrow.scale.set(0.82, 0.82);
		rightArrow.updateHitbox();
		difficultySelectors.add(rightArrow);

		// --- Highscore (label + 6 digital digits) ---
		hsLabel = new FlxSprite(dx(1685), dy(905));
		hsLabel.antialiasing = ClientPrefs.data.antialiasing;
		hsLabel.frames = Paths.getSparrowAtlas('newstory/highscore');
		hsLabel.animation.addByPrefix('idle', 'highscore small instance 1', 24, true);
		hsLabel.animation.play('idle');
		var hk:Float = (360 * S) / 289;
		hsLabel.scale.set(hk, hk);
		hsLabel.updateHitbox();
		add(hsLabel);

		var digitNames:Array<String> = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE'];
		var digitTex = Paths.getSparrowAtlas('newstory/digital_numbers');
		for (i in 0...6)
		{
			var d:FlxSprite = new FlxSprite(dx(1713 + i * 49), dy(962));
			d.antialiasing = ClientPrefs.data.antialiasing;
			d.frames = digitTex;
			for (n in 0...10)
				d.animation.addByPrefix(Std.string(n), digitNames[n] + ' DIGITAL', 24, true);
			d.animation.play('0');
			d.scale.set(0.226, 0.226);
			d.updateHitbox();
			add(d);
			digitSprites.push(d);
		}

		// --- Tracks ---
		txtTracksHeader = new FlxText(0, dy(772), 0, Language.getPhrase('story_tracks', 'TRACKS'), 28);
		txtTracksHeader.setFormat(Paths.font("vcr.ttf"), 28, 0xFFe55777, CENTER);
		txtTracksHeader.x = dx(645) - txtTracksHeader.width / 2;
		add(txtTracksHeader);

		txtTracklist = new FlxText(0, dy(850), 0, "", 28);
		txtTracklist.setFormat(Paths.font("vcr.ttf"), 28, 0xFFe55777, CENTER);
		add(txtTracklist);

		// --- Top bar ---
		var blackBarThingie:FlxSprite = new FlxSprite(-600, 0).makeGraphic(wideW, Std.int(dy(84)), FlxColor.BLACK);
		add(blackBarThingie);

		scoreText = new FlxText(Math.max(dx(95), 14), 10, 0, Language.getPhrase('level_score', 'LEVEL SCORE: {1}', [FlxStringUtil.formatMoney(lerpScore, false)]), 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32);
		add(scoreText);

		txtWeekTitle = new FlxText(0, 10, 0, "", 32);
		txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;
		add(txtWeekTitle);

		changeWeek();
		changeDifficulty();

		#if mobile
		var backBtn:FlxBasic = mobile.MobileButton.back();
		add(backBtn);
		// Widescreen off: the back button (bottom right) covers the HIGHSCORE window, so move it to the free bottom-left corner
		if (mobile.WideScreen.offset <= 0 && Std.isOfType(backBtn, FlxSprite))
		{
			var sp:FlxSprite = cast backBtn;
			sp.x = 12;
			sp.y = FlxG.height - sp.height - 12;
		}
		#end
		super.create();
	}

	override function closeSubState() {
		persistentUpdate = true;
		changeWeek();
		super.closeSubState();
	}

	function addBlack(x1:Float, y1:Float, x2:Float, y2:Float):Void
	{
		var b:FlxSprite = new FlxSprite(dx(x1), dy(y1)).makeGraphic(Std.int((x2 - x1) * S) + 1, Std.int((y2 - y1) * S) + 1, FlxColor.BLACK);
		add(b);
	}

	function overSwitch(gx:Float, gy:Float):Bool
	{
		var px:Float = (gx - ox) / S;
		var py:Float = gy / S;
		return px >= 1981 && px <= 2285 && py >= 169 && py <= 390;
	}

	// Tap/click position (game coords) this frame, or null. Does not use mobile.TouchInput.
	function getTapPoint():FlxPoint
	{
		#if FLX_TOUCH
		for (t in FlxG.touches.list)
			if (t.justPressed)
				return FlxPoint.get(t.x, t.y);
		#end
		if (FlxG.mouse.justPressed)
			return FlxPoint.get(FlxG.mouse.x, FlxG.mouse.y);
		return null;
	}

	function hitSprite(spr:FlxSprite, p:FlxPoint, pad:Float):Bool
	{
		return p.x >= spr.x - pad && p.x <= spr.x + spr.width + pad && p.y >= spr.y - pad && p.y <= spr.y + spr.height + pad;
	}

	// Clips a sprite to the center window (clipRect is in graphic pixels, so divide by scale)
	function clipToList(spr:FlxSprite):Void
	{
		var left:Float = listX;
		var top:Float = listY;
		var right:Float = listX + listW;
		var bottom:Float = listY + listH;
		if (spr.x + spr.width <= left || spr.x >= right || spr.y + spr.height <= top || spr.y >= bottom)
		{
			spr.visible = false;
			return;
		}
		spr.visible = true;
		var k:Float = spr.scale.x;
		if (k <= 0) k = 1;
		var cx:Float = Math.max(0, left - spr.x) / k;
		var cy:Float = Math.max(0, top - spr.y) / k;
		var cr:Float = Math.min(spr.width, right - spr.x) / k;
		var cb:Float = Math.min(spr.height, bottom - spr.y) / k;
		spr.clipRect = new FlxRect(cx, cy, cr - cx, cb - cy);
	}

	function toggleSwitchChar():Void
	{
		if (!switchEnabled) return;
		playAsOpponent = !playAsOpponent;
		ClientPrefs.data.gameplaySettings.set('opponentplay', playAsOpponent);
		FlxG.sound.play(Paths.sound('scrollMenu'));
		updatePlayingAs();
		switchSpr.alpha = 0.4;
		FlxTween.cancelTweensOf(switchSpr);
		FlxTween.tween(switchSpr, {alpha: 1}, 0.2);
	}

	function updatePlayingAs():Void
	{
		txtPlayingAs.text = Language.getPhrase(playAsOpponent ? 'story_playing_opponent' : 'story_playing_bf',
			playAsOpponent ? 'PLAYING AS: OPPONENT' : 'PLAYING AS: BOYFRIEND');
	}

	var lastDigits:String = '';
	function updateDigits(value:Int):Void
	{
		var s:String = StringTools.lpad(Std.string(Std.int(Math.min(value, 999999))), '0', 6);
		if (s == lastDigits) return;
		lastDigits = s;
		for (i in 0...6)
		{
			var c:String = s.charAt(i);
			if (digitSprites[i].animation.name != c)
				digitSprites[i].animation.play(c);
		}
	}

	override function update(elapsed:Float)
	{
		// create() returned early, nothing was built: don't touch any sprite
		if (redirected)
		{
			super.update(elapsed);
			return;
		}

		if(WeekData.weeksList.length < 1)
		{
			if (controls.BACK && !movedBack && !selectedWeek)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				movedBack = true;
				MusicBeatState.switchState(new MainMenuState());
			}
			super.update(elapsed);
			return;
		}

		if(intendedScore != lerpScore)
		{
			lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 30)));
			if(Math.abs(intendedScore - lerpScore) < 10) lerpScore = intendedScore;

			scoreText.text = Language.getPhrase('level_score', 'LEVEL SCORE: {1}', [FlxStringUtil.formatMoney(lerpScore, false)]);
		}
		updateDigits(lerpScore);

		if (!movedBack && !selectedWeek)
		{
			var changeDiff = false;
			var touchAccept:Bool = false;

			var tap:FlxPoint = getTapPoint();
			if (tap != null)
			{
				if (switchEnabled && overSwitch(tap.x, tap.y))
					toggleSwitchChar();
				else if (hitSprite(leftArrow, tap, 0))
					changeDifficulty(-1);
				else if (hitSprite(rightArrow, tap, 0))
					changeDifficulty(1);
				else if (tap.x >= listX && tap.x <= listX + listW && tap.y >= listY) // only inside the center window
				{
					for (num => item in grpWeekText.members)
					{
						if (item.visible && hitSprite(item, tap, 0))
						{
							if (num == curWeek) touchAccept = true;
							else
							{
								changeWeek(num - curWeek);
								FlxG.sound.play(Paths.sound('scrollMenu'));
								changeDiff = true;
							}
							break;
						}
					}
				}
				tap.put();
			}

			if (controls.UI_UP_P)
			{
				changeWeek(-1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeDiff = true;
			}

			if (controls.UI_DOWN_P)
			{
				changeWeek(1);
				FlxG.sound.play(Paths.sound('scrollMenu'));
				changeDiff = true;
			}

			if(FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
				changeWeek(-FlxG.mouse.wheel);
				changeDifficulty();
			}

			// pressed feedback: arrows shrink while held
			var rs:Float = controls.UI_RIGHT ? 0.7 : 0.82;
			var ls:Float = controls.UI_LEFT ? 0.7 : 0.82;
			rightArrow.scale.set(rs, rs);
			leftArrow.scale.set(ls, ls);

			if (controls.UI_RIGHT_P)
				changeDifficulty(1);
			else if (controls.UI_LEFT_P)
				changeDifficulty(-1);
			else if (changeDiff)
				changeDifficulty();

			if(FlxG.keys.justPressed.CONTROL)
			{
				persistentUpdate = false;
				openSubState(new GameplayChangersSubstate());
			}
			else if(controls.RESET)
			{
				persistentUpdate = false;
				openSubState(new ResetScoreSubState('', curDifficulty, '', curWeek));
			}
			else if (controls.ACCEPT || touchAccept)
				selectWeek();
		}

		if (controls.BACK && !movedBack && !selectedWeek)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			movedBack = true;
			MusicBeatState.switchState(new MainMenuState());
		}

		super.update(elapsed);

		// week list scroll (items are clipped to the center window)
		var offY:Float = grpWeekText.members[curWeek].targetY;
		for (num => item in grpWeekText.members)
		{
			item.y = FlxMath.lerp(item.targetY - offY + listY + 60, item.y, Math.exp(-elapsed * 10.2));
			clipToList(item);
		}

		for (num => lock in grpLocks.members)
		{
			var owner:MenuItem = grpWeekText.members[lock.ID];
			lock.y = owner.y + owner.height/2 - lock.height/2;
			clipToList(lock);
		}
	}

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;
	var stopspamming:Bool = false;

	function selectWeek()
	{
		if (!weekIsLocked(loadedWeeks[curWeek].fileName))
		{
			var songArray:Array<String> = [];
			var leWeek:Array<Dynamic> = loadedWeeks[curWeek].songs;
			for (i in 0...leWeek.length) {
				songArray.push(leWeek[i][0]);
			}

			try
			{
				PlayState.storyPlaylist = songArray;
				PlayState.isStoryMode = true;
				selectedWeek = true;

				var diffic = Difficulty.getFilePath(curDifficulty);
				if(diffic == null) diffic = '';

				PlayState.storyDifficulty = curDifficulty;

				Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
				PlayState.campaignScore = 0;
				PlayState.campaignMisses = 0;
			}
			catch(e:Dynamic)
			{
				trace('ERROR! $e');
				return;
			}

			if (stopspamming == false)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));

				grpWeekText.members[curWeek].isFlashing = true;
				for (char in grpWeekCharacters.members)
				{
					if (char.character != '' && char.hasConfirmAnimation)
					{
						char.animation.play('confirm');
					}
				}
				stopspamming = true;
			}

			var directory = StageData.forceNextDirectory;
			LoadingState.loadNextDirectory();
			StageData.forceNextDirectory = directory;

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			new FlxTimer().start(1, function(tmr:FlxTimer)
			{
				#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
				LoadingState.loadAndSwitchState(new PlayState(), true);
				FreeplayState.destroyFreeplayVocals();
			});

			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else FlxG.sound.play(Paths.sound('cancelMenu'));
	}

	function changeDifficulty(change:Int = 0):Void
	{
		curDifficulty += change;

		if (curDifficulty < 0)
			curDifficulty = Difficulty.list.length-1;
		if (curDifficulty >= Difficulty.list.length)
			curDifficulty = 0;

		WeekData.setDirectoryFromWeek(loadedWeeks[curWeek]);

		var diff:String = Difficulty.getString(curDifficulty, false);
		var newImage:FlxGraphic = Paths.image('menudifficulties/' + Paths.formatToSongPath(diff));

		if(sprDifficulty.graphic != newImage)
		{
			sprDifficulty.loadGraphic(newImage);
			// shrink to fit between the arrows (e.g. NORMAL is wider than HARD)
			sprDifficulty.scale.set(1, 1);
			sprDifficulty.updateHitbox();
			var fit:Float = Math.min(1, Math.min((320 * S) / sprDifficulty.width, (105 * S) / sprDifficulty.height));
			sprDifficulty.scale.set(fit, fit);
			sprDifficulty.updateHitbox();
			sprDifficulty.x = dx(1865) - sprDifficulty.width / 2;
			var targetY:Float = dy(795) - sprDifficulty.height / 2;
			sprDifficulty.alpha = 0;
			sprDifficulty.y = targetY - 15;

			FlxTween.cancelTweensOf(sprDifficulty);
			FlxTween.tween(sprDifficulty, {y: targetY, alpha: 1}, 0.07);
		}
		lastDifficultyName = diff;

		#if !switch
		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
		#end
	}

	var lerpScore:Int = 0;
	var intendedScore:Int = 0;

	function changeWeek(change:Int = 0):Void
	{
		curWeek += change;

		if (curWeek >= loadedWeeks.length)
			curWeek = 0;
		if (curWeek < 0)
			curWeek = loadedWeeks.length - 1;

		var leWeek:WeekData = loadedWeeks[curWeek];
		WeekData.setDirectoryFromWeek(leWeek);

		var leName:String = Language.getPhrase('storyname_${leWeek.fileName}', leWeek.storyName);
		txtWeekTitle.text = leName.toUpperCase();
		txtWeekTitle.x = Math.min(dx(2300), visW - 14) - txtWeekTitle.width;

		var unlocked:Bool = !weekIsLocked(leWeek.fileName);
		for (num => item in grpWeekText.members)
		{
			item.alpha = 0.6;
			if (num - curWeek == 0 && unlocked)
				item.alpha = 1;
		}

		bgSprite.visible = true;
		var assetName:String = leWeek.weekBackground;
		if(assetName == null || assetName.length < 1) {
			bgSprite.visible = false;
		} else {
			bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_' + assetName));
			bgSprite.x = (FlxG.width - bgSprite.width) / 2;
		}
		PlayState.storyWeek = curWeek;

		Difficulty.loadFromWeek();
		difficultySelectors.visible = unlocked;
		hsLabel.visible = unlocked;
		for (d in digitSprites) d.visible = unlocked;

		if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		var newPos:Int = Difficulty.list.indexOf(lastDifficultyName);
		if(newPos > -1)
		{
			curDifficulty = newPos;
		}
		updateText();
	}

	function weekIsLocked(name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!weekCompleted.exists(leWeek.weekBefore) || !weekCompleted.get(leWeek.weekBefore)));
	}

	function updateText()
	{
		var weekArray:Array<String> = loadedWeeks[curWeek].weekCharacters;
		for (i in 0...grpWeekCharacters.length) {
			grpWeekCharacters.members[i].changeCharacter(weekArray[i]);
		}

		var leWeek:WeekData = loadedWeeks[curWeek];
		var stringThing:Array<String> = [];
		for (i in 0...leWeek.songs.length) {
			stringThing.push(leWeek.songs[i][0]);
		}

		txtTracklist.text = stringThing.join('\n');
		txtTracklist.x = dx(645) - txtTracklist.width / 2;

		#if !switch
		intendedScore = Highscore.getWeekScore(loadedWeeks[curWeek].fileName, curDifficulty);
		#end
	}
}
