package options;

class MobileSettingsSubState extends BaseOptionsMenu
{
	#if android
	var initialStorage:String;
	#end
	var initialScreenStyle:String;

	public function new()
	{
		initialScreenStyle = ClientPrefs.data.screenStyle;
		title = Language.getPhrase('mobile_menu', 'Mobile Options');
		rpcTitle = 'Mobile Options Menu';

		var option:Option = new Option('Mobile Controls',
			'Preview and customize the hitbox: style, colors and opacity.',
			null,
			BUTTON);
		option.onChange = function()
		{
			ClientPrefs.saveSettings();
			MusicBeatState.switchState(new options.MobileControlsState());
		};
		addOption(option);

		var option:Option = new Option('Hitbox Mode:',
			'Four Lanes: the screen is split into four touch lanes.\nArrows: tap the arrows at the bottom of the screen, opponent notes are hidden.',
			'hitboxMode',
			STRING,
			['Four Lanes', 'Arrows']);
		addOption(option);

		var option:Option = new Option('Touch Cursor',
			'If checked, a circle shows where your fingers are touching the screen.',
			'touchCursor',
			BOOL);
		addOption(option);

		var option:Option = new Option('Invisible Hitbox',
			'If checked, the hitbox lanes are hidden during gameplay.\nThey still work while hidden.',
			'hitboxInvisible',
			BOOL);
		addOption(option);

		var option:Option = new Option('Hitbox Opacity',
			'How visible the hitbox lanes are when you touch them.',
			'hitboxOpacity',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.1;
		option.maxValue = 1;
		option.changeValue = 0.05;
		option.decimals = 2;
		addOption(option);

		var option:Option = new Option('Invisible Pause Button',
			'If checked, the pause button is hidden during gameplay.\nYou can still tap its corner to pause.',
			'pauseButtonInvisible',
			BOOL);
		addOption(option);

		var option:Option = new Option('Chart Editor in Pause',
			'If checked, the pause menu shows a "Chart Editor" option\nright after "Restart Song".',
			'pauseChartEditor',
			BOOL);
		addOption(option);

		var option:Option = new Option('Screen Style:',
			'Original: the classic 16:9 screen with black bars on wide phones.\nFull: fills the whole screen without stretching, showing more of the game on the sides.',
			'screenStyle',
			STRING,
			['Original', 'Full']);
		addOption(option);
		option.onChange = mobile.ScreenStyle.apply;

		#if android
		ClientPrefs.data.storageType = mobile.StorageUtil.getStorageType();
		initialStorage = ClientPrefs.data.storageType;
		var option:Option = new Option('Storage Type:',
			'Data: Android/data. Media: Android/media. Obb: Android/obb (all deleted on uninstall).\nExternal: /storage/emulated/0/.ShadowCrystal, kept after uninstalling.',
			'storageType',
			STRING,
			mobile.StorageUtil.TYPES);
		addOption(option);
		option.onChange = onChangeStorage;
		#end

		super();
	}

	#if android
	function onChangeStorage()
	{
		if (ClientPrefs.data.storageType == 'External' && !mobile.StorageUtil.hasAccess())
			mobile.StorageUtil.requestAccess();
	}

	function closeStorage():Bool
	{
		if (ClientPrefs.data.storageType == initialStorage) return false;

		var oldDir:String = mobile.StorageUtil.getGameDir();
		mobile.StorageUtil.setStorageType(ClientPrefs.data.storageType);
		ClientPrefs.saveSettings();
		var newDir:String = mobile.StorageUtil.getGameDir();
		if (newDir == oldDir) return false;

		mobile.StorageUtil.ensureFolders(newDir);
		mobile.StorageUtil.migrate(oldDir, newDir);
		mobile.StorageUtil.applyGameDir();
		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();
		if (mobile.CopyState.needsCopy())
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.switchState(new mobile.CopyState());
			return true;
		}
		return false;
	}
	#end

	override function close()
	{
		super.close();
		#if android
		if (closeStorage()) return;
		#end
		if (ClientPrefs.data.screenStyle != initialScreenStyle)
		{
			ClientPrefs.saveSettings();
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.resetState();
		}
	}
}
