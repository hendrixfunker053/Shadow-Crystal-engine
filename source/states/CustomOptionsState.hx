package states;

import backend.MainMenuData;
import options.OptionsState;

/**
 * Options custom: lista de data/options_menu.json (se edita en Main Menu Editor > Options).
 * Acciones: notes, controls, adjust_delay, graphics, visuals, gameplay, mobile, state, substate, url, script.
 * Las entradas cuyo substate/state no exista en tu build se omiten.
 */
class CustomOptionsState extends CustomMenuBase
{
	var entries:Array<Dynamic> = [];

	public function new()
	{
		super('options');
	}

	override function entryCount():Int return entries.length;
	override function entryName(i:Int):String return entries[i] != null ? entries[i].label : '';

	override function buildEntries()
	{
		var data:Dynamic = MainMenuData.loadCustom('options');
		var raw:Array<Dynamic> = Reflect.field(data, 'entries');
		for (e in raw)
		{
			if (!actionAvailable(e)) continue;
			entries.push(e);
		}

		for (i => e in entries)
			addAlphabet(Std.string(e.label), true, i, FlxG.width / 2);
	}

	function actionAvailable(e:Dynamic):Bool
	{
		var action:String = e.action;
		if (action == 'notes' || action == 'controls' || action == 'adjust_delay' || action == 'graphics' || action == 'visuals' || action == 'gameplay' || action == 'mobile')
			return MainMenuData.resolveClassAny(MainMenuData.OPTION_CLASSES.get(action)) != null;
		return true;
	}

	static function isSubState(cls:Class<Dynamic>):Bool
	{
		var c:Class<Dynamic> = cls;
		while (c != null)
		{
			if (c == flixel.FlxSubState) return true;
			c = Type.getSuperClass(c);
		}
		return false;
	}

	override function acceptEntry(i:Int)
	{
		var e:Dynamic = entries[i];
		if (e == null || leaving) return;

		var action:String = e.action;
		var args:String = e.args == null ? '' : e.args;
		if (scripts.call('onAccept', [i, action, args])) return;

		switch (action)
		{
			case 'script':
				scripts.call('onMenuAction', [args, e.label]);

			case 'url':
				CoolUtil.browserLoad(args);

			case 'state' | 'substate':
				openClass(MainMenuData.resolveClassAny([args]));

			default:
				var names:Array<String> = MainMenuData.OPTION_CLASSES.get(action);
				if (names != null) openClass(MainMenuData.resolveClassAny(names));
		}
	}

	function openClass(cls:Class<Dynamic>)
	{
		if (cls == null)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			trace('Clase no encontrada para la opción.');
			return;
		}

		if (isSubState(cls))
		{
			persistentUpdate = false;
			openSubState(cast Type.createInstance(cls, []));
		}
		else
		{
			leaving = true;
			MusicBeatState.switchState(cast Type.createInstance(cls, []));
		}
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		ClientPrefs.loadPrefs();
		persistentUpdate = true;
	}

	override function goBack()
	{
		if (OptionsState.onPlayState)
		{
			StageData.loadDirectory(PlayState.SONG);
			LoadingState.loadAndSwitchState(new PlayState());
			FlxG.sound.music.volume = 0;
		}
		else
			MusicBeatState.switchState(new MainMenuState());
	}
}
