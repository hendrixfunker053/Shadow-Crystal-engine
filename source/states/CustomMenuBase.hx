package states;

import backend.MainMenuData;
import backend.MenuScripts;
import flixel.FlxObject;
import objects.Alphabet;

/**
 * Base de los menús custom (Options / FreePlay / Credits): lista vertical de Alphabet,
 * navegación por teclado, mouse y toque, y scripts Lua/HScript (scripts/<kind>/).
 *
 * Hooks de script comunes: onCreate, onCreatePost, onUpdate, onUpdatePost, onSelect(index, nombre),
 * onAccept(...) (Function_Stop cancela), onBack (Function_Stop cancela la salida), onDestroy.
 */
class CustomMenuBase extends MusicBeatState
{
	var kind:String;
	var scripts:MenuScripts;
	var bg:FlxSprite;
	var grp:FlxTypedGroup<Alphabet>;
	var curSelected:Int = 0;
	var leaving:Bool = false;

	public function new(kind:String)
	{
		super();
		this.kind = kind;
	}

	// ---- a sobrescribir ----
	function entryCount():Int return 0;
	function entryName(i:Int):String return '';
	function isSelectable(i:Int):Bool return true;
	function buildEntries():Void {}
	function acceptEntry(i:Int):Void {}
	function onSelectionChanged():Void {}
	function goBack():Void MusicBeatState.switchState(new MainMenuState());
	function backgroundColor():FlxColor return 0xFF353535;

	override function create()
	{
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		persistentUpdate = true;

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		bg.screenCenter();
		bg.color = backgroundColor();
		add(bg);

		grp = new FlxTypedGroup<Alphabet>();
		add(grp);

		scripts = new MenuScripts(this, kind);
		scripts.getItems = function() return cast grp.members.copy();
		scripts.getSelected = function() return curSelected;
		scripts.selectItem = function(i:Int) changeSelection(i - curSelected, false);
		scripts.call('onCreate');

		buildEntries();

		#if mobile
		var backButton:mobile.MobileButton = mobile.MobileButton.back(null, false);
		add(backButton);
		#end

		super.create();

		curSelected = 0;
		changeSelection(0, false);
		scripts.call('onCreatePost');
	}

	/** Crea el Alphabet de una entrada ya colocado en la lista (estilo CreditsState). */
	function addAlphabet(text:String, bold:Bool, i:Int, centerX:Float):Alphabet
	{
		var a:Alphabet = new Alphabet(centerX, 300, text, bold);
		a.isMenuItem = true;
		a.targetY = i;
		a.changeX = false;
		a.distancePerItem.y = 100;
		a.x = centerX - a.width / 2;
		a.snapToPosition();
		grp.add(a);
		return a;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		var n:Int = entryCount();
		if (n < 1) return;

		var dir:Int = change < 0 ? -1 : 1;
		curSelected = FlxMath.wrap(curSelected + change, 0, n - 1);

		var guard:Int = 0;
		while (!isSelectable(curSelected) && guard++ < n)
			curSelected = FlxMath.wrap(curSelected + dir, 0, n - 1);

		for (i => item in grp.members)
		{
			item.targetY = i - curSelected;
			item.alpha = (i == curSelected) ? 1 : 0.6;
		}

		if (change != 0 && playSound) FlxG.sound.play(Paths.sound('scrollMenu'));

		onSelectionChanged();
		scripts.call('onSelect', [curSelected, entryName(curSelected)]);
	}

	override function update(elapsed:Float)
	{
		scripts.call('onUpdate', [elapsed]);

		if (!leaving)
		{
			if (controls.UI_UP_P) changeSelection(-1);
			if (controls.UI_DOWN_P) changeSelection(1);
			if (FlxG.mouse.wheel != 0) changeSelection(-FlxG.mouse.wheel);

			#if mobile
			if (mobile.TouchInput.justTapped())
			{
				mobile.TouchInput.consumeTap();
				for (i => item in grp.members)
				{
					if (!mobile.TouchInput.tappedOn(item) || !isSelectable(i)) continue;
					if (i == curSelected) acceptEntry(i);
					else changeSelection(i - curSelected);
					break;
				}
			}
			#else
			if (FlxG.mouse.justPressed)
			{
				for (i => item in grp.members)
				{
					if (!FlxG.mouse.overlaps(item) || !isSelectable(i)) continue;
					if (i == curSelected) acceptEntry(i);
					else changeSelection(i - curSelected);
					break;
				}
			}
			#end

			if (controls.ACCEPT) acceptEntry(curSelected);

			if (controls.BACK && !scripts.call('onBack'))
			{
				leaving = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				goBack();
			}
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
