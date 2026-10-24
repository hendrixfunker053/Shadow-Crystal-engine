package states;

import backend.FreeplaySongs;
import backend.MainMenuData;
import backend.MenuScripts;

/**
 * State propio hecho 100% con scripts: scripts/states/<nombre>.lua | .hx (y scripts/states/<nombre>/*).
 * Se abre con un item del menú principal (acción "state", args = nombre) o con switchState('<nombre>') desde un script.
 *
 * Hooks: onCreate, onCreatePost, onUpdate(elapsed), onUpdatePost(elapsed), onBack (Function_Stop evita volver al menú principal),
 * onDestroy, onTweenCompleted(tag), onTimerCompleted(tag, loops, loopsLeft).
 * Si se llama igual que un state original (TitleState, MainMenuState, StoryMenuState, FreeplayState, CreditsState,
 * OptionsState, ModsMenuState) lo REEMPLAZA. ATRÁS: MainMenuState vuelve al Title, TitleState no vuelve, el resto al menú principal.
 * Funciones propias: closeState() y las de canciones de FreeplaySongs (loadFreeplaySongs, getSongName...).
 */
class ScriptedState extends MusicBeatState
{
	public var scriptName:String;
	public var scripts:MenuScripts;
	var bg:FlxSprite;

	public function new(name:String)
	{
		super();
		scriptName = name;
	}

	override function create()
	{
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		persistentUpdate = true;
		FlxG.mouse.visible = true;

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		bg.screenCenter();
		bg.color = 0xFF353535;
		add(bg);

		scripts = new MenuScripts(this, 'states', scriptName);
		scripts.registerObject('bg', bg);
		scripts.extras.set('closeState', function() goBack());
		scripts.extras.set('closeSubState', function() closeSubState());
		FreeplaySongs.registerExtras(scripts.extras);
		scripts.load();

		if (MainMenuData.stateScriptFiles('states', scriptName).length < 1)
			trace('ScriptedState: no hay scripts para "$scriptName" en scripts/states/');

		scripts.call('onCreate');

		#if mobile
		var backButton:mobile.MobileButton = mobile.MobileButton.back(null, false);
		add(backButton);
		#end

		super.create();
		scripts.call('onCreatePost');
	}

	/** A dónde vuelve ATRÁS: MainMenuState -> Title; cualquier otro -> menú principal (TitleState no vuelve). */
	function goBack()
	{
		switch (scriptName)
		{
			case 'TitleState':
			case 'MainMenuState':
				MusicBeatState.switchState(new TitleState());
			default:
				MusicBeatState.switchState(new MainMenuState());
		}
	}

	override function update(elapsed:Float)
	{
		scripts.call('onUpdate', [elapsed]);

		if (scriptName != 'TitleState' && controls.BACK && !scripts.call('onBack'))
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			goBack();
		}

		super.update(elapsed);
		scripts.call('onUpdatePost', [elapsed]);
	}

	override function destroy()
	{
		if (scripts != null)
		{
			scripts.destroy();
			scripts = null;
		}
		super.destroy();
	}
}
