package states;

import backend.FreeplaySongs;
import backend.MainMenuData;
import backend.MenuScripts;

/**
 * SubState propio hecho 100% con scripts: scripts/substates/<nombre>.lua | .hx (y scripts/substates/<nombre>/*).
 * Se abre con un item del menú principal (acción "substate", args = nombre) o con openSubState('<nombre>') desde un script.
 *
 * Mismos hooks que ScriptedState. closeState() cierra el substate; onBack (sin Function_Stop) también lo cierra.
 * El objeto "bg" es una capa negra semitransparente.
 */
class ScriptedSubState extends MusicBeatSubstate
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
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.6;
		bg.scrollFactor.set();
		add(bg);

		scripts = new MenuScripts(this, 'substates', scriptName);
		scripts.registerObject('bg', bg);
		scripts.extras.set('closeState', function() close());
		FreeplaySongs.registerExtras(scripts.extras);
		scripts.load();

		if (MainMenuData.stateScriptFiles('substates', scriptName).length < 1)
			trace('ScriptedSubState: no hay scripts para "$scriptName" en scripts/substates/');

		scripts.call('onCreate');
		super.create();
		scripts.call('onCreatePost');
	}

	override function update(elapsed:Float)
	{
		scripts.call('onUpdate', [elapsed]);

		if (controls.BACK && !scripts.call('onBack'))
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			close();
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
