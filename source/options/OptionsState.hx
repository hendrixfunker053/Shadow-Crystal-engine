package options;

import states.MainMenuState;
import backend.StageData;

class OptionsState extends MusicBeatState
{
	var options:Array<String> = [
		'Note Colors',
		#if !mobile
		'Controls',
		'Adjust Delay and Combo',
		#end
		'Graphics',
		'Visuals',
		'Gameplay',
		#if desktop
		'Extra Settings'
		#else
		'Mobile Options'
		#end
		#if TRANSLATIONS_ALLOWED , 'Language' #end
		#if mobile , 'Open Data Folder' #end
	];
	private var grpOptions:FlxTypedGroup<Alphabet>;
	private static var curSelected:Int = 0;
	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;
	public static var reopenMobileOptions:Bool = false;

	function openSelectedSubstate(label:String) {
		switch(label)
		{
			case 'Note Colors':
				openSubState(new options.NotesColorSubState());
			case 'Controls':
				openSubState(new options.ControlsSubState());
			case 'Graphics':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Visuals':
				openSubState(new options.VisualsSettingsSubState());
			case 'Gameplay':
				openSubState(new options.GameplaySettingsSubState());
			case 'Adjust Delay and Combo':
				MusicBeatState.switchState(new options.NoteOffsetState());
			case 'Language':
				openSubState(new options.LanguageSubState());
			case 'Extra Settings', 'Mobile Options':
				openSubState(new options.MobileSettingsSubState());
			#if mobile
			case 'Open Data Folder':
				mobile.DataFolder.open();
			#end
		}
	}

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFea71fd;
		bg.updateHitbox();

		bg.screenCenter();
		add(bg);
		mobile.WideScreen.fit(bg);

		#if android
		if (!showDataFolder()) options.remove('Open Data Folder');
		#end

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (num => option in options)
		{
			var optionText:Alphabet = new Alphabet(0, 0, Language.getPhrase('options_$option', option), true);
			optionText.screenCenter();
			optionText.y += (92 * (num - (options.length / 2))) + 45;
			grpOptions.add(optionText);
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		add(selectorLeft);
		selectorRight = new Alphabet(0, 0, '<', true);
		add(selectorRight);

		changeSelection();
		ClientPrefs.saveSettings();

		#if mobile
		add(mobile.MobileButton.back());
		#end

		super.create();

		if (reopenMobileOptions)
		{
			reopenMobileOptions = false;
			var targetOpt:String = #if desktop 'Extra Settings' #else 'Mobile Options' #end;
			curSelected = options.indexOf(targetOpt);
			if (curSelected < 0) curSelected = 0;
			changeSelection();
			openSelectedSubstate(targetOpt);
		}
	}

	#if android
	static function showDataFolder():Bool
		return mobile.StorageUtil.isAppOwned();
	#end

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		#if android
		if (options.contains('Open Data Folder') != showDataFolder())
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.resetState();
			return;
		}
		#end
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		var touchAccept:Bool = false;
		#if mobile
		if (subState == null)
		{
			var tapped:Int = mobile.TouchInput.tappedRow(cast grpOptions.members);
			mobile.TouchInput.consumeTap();
			if (tapped > -1)
			{
				if (tapped == curSelected) touchAccept = true;
				else changeSelection(tapped - curSelected);
			}
		}
		#end

		if (controls.UI_UP_P)
			changeSelection(-1);
		if (controls.UI_DOWN_P)
			changeSelection(1);

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			if(onPlayState)
			{
				StageData.loadDirectory(PlayState.SONG);
				LoadingState.loadAndSwitchState(new PlayState());
				FlxG.sound.music.volume = 0;
			}
			else MusicBeatState.switchState(new MainMenuState());
		}
		else if (controls.ACCEPT || touchAccept) openSelectedSubstate(options[curSelected]);
	}
	
	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);

		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
				selectorLeft.x = item.x - 63;
				selectorLeft.y = item.y;
				selectorRight.x = item.x + item.width + 15;
				selectorRight.y = item.y;
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}
