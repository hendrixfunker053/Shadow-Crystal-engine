package options;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.touch.FlxTouch;
import flixel.math.FlxMath;

import objects.Character;

import options.Option.OptionType;

class ModSettingsSubState extends BaseOptionsMenu
{
	var save:Map<String, Dynamic> = new Map<String, Dynamic>();
	var folder:String;
	private var _crashed:Bool = false;

	// --- Touch controls ---
	var activeTouch:FlxTouch = null;
	var lastTX:Float = 0;
	var lastTY:Float = 0;
	var totalTX:Float = 0;
	var totalTY:Float = 0;
	var accumX:Float = 0;
	var accumY:Float = 0;
	var dragAxis:Int = 0; // 0 = nada, 1 = vertical, 2 = horizontal
	static inline var TAP_DIST:Float = 20;
	static inline var STEP_Y:Float = 45;
	static inline var STEP_X:Float = 50;

	public function new(options:Array<Dynamic>, folder:String, name:String)
	{
		this.folder = folder;

		title = '';
		//title = name;
		rpcTitle = 'Mod Settings ($name)'; //for Discord Rich Presence

		if(FlxG.save.data.modSettings == null) FlxG.save.data.modSettings = new Map<String, Dynamic>();
		else
		{
			var saveMap:Map<String, Dynamic> = FlxG.save.data.modSettings;
			save = saveMap[folder] != null ? saveMap[folder] : [];
		}

		//save = []; //reset for debug purposes
		try
		{
			for (option in options)
			{
				var newOption = new Option(
					option.name != null ? option.name : option.save,
					option.description != null ? option.description : 'No description provided.',
					option.save,
					convertType(option.type),
					option.options,
					option.translation_key
				);

				switch(newOption.type)
				{
					case KEYBIND:
						//Defaulting and error checking
						var keyboardStr:String = option.keyboard;
						var gamepadStr:String = option.gamepad;
						if(keyboardStr == null) keyboardStr = 'NONE';
						if(gamepadStr == null) gamepadStr = 'NONE';

						newOption.defaultKeys.keyboard = keyboardStr;
						newOption.defaultKeys.gamepad = gamepadStr;
						if(save.get(option.save) == null)
						{
							newOption.keys.keyboard = newOption.defaultKeys.keyboard;
							newOption.keys.gamepad = newOption.defaultKeys.gamepad;
							save.set(option.save, newOption.keys);
						}

						// getting inputs and checking
						var keyboardKey:FlxKey = cast FlxKey.fromString(keyboardStr);
						var gamepadKey:FlxGamepadInputID = cast FlxGamepadInputID.fromString(gamepadStr);
						//trace('${keyboardStr}: $keyboardKey, ${gamepadStr}: $gamepadKey');

						@:privateAccess
						{
							newOption.getValue = function() {
								var data = save.get(newOption.variable);
								if(data == null) return 'NONE';
								return !Controls.instance.controllerMode ? data.keyboard : data.gamepad;
							};
							newOption.setValue = function(value:Dynamic) {
								var data = save.get(newOption.variable);
								if(data == null) data = {keyboard: 'NONE', gamepad: 'NONE'};

								if(!controls.controllerMode) data.keyboard = value;
								else data.gamepad = value;
								save.set(newOption.variable, data);
							};
						}

					default:
						if(option.value != null)
							newOption.defaultValue = option.value;

						@:privateAccess
						{
							newOption.getValue = function() return save.get(newOption.variable);
							newOption.setValue = function(value:Dynamic) save.set(newOption.variable, value);
						}
				}

				if(option.type != KEYBIND)
				{
					if(option.format != null) newOption.displayFormat = option.format;
					if(option.min != null) newOption.minValue = option.min;
					if(option.max != null) newOption.maxValue = option.max;
					if(option.step != null) newOption.changeValue = option.step;

					if(option.scroll != null) newOption.scrollSpeed = option.scroll;
					if(option.decimals != null) newOption.decimals = option.decimals;

					var myValue:Dynamic = null;
					if(save.get(option.save) != null)
					{
						myValue = save.get(option.save);
						if(newOption.type != KEYBIND) newOption.setValue(myValue);
						else newOption.setValue(!Controls.instance.controllerMode ? myValue.keyboard : myValue.gamepad);
					}
					else
					{
						myValue = newOption.getValue();
						if(myValue == null) myValue = newOption.defaultValue;
					}
	
					switch(newOption.type)
					{
						case STRING:
							var num:Int = newOption.options.indexOf(myValue);
							if(num > -1) newOption.curOption = num;

						default:
					}
	
					save.set(option.save, myValue);
				}
				addOption(newOption);
				//updateTextFrom(newOption);
			}
		}
		catch(e:Dynamic)
		{
			var errorTitle = 'Mod name: ' + folder;
			var errorMsg = 'An error occurred: $e';
			#if windows
			lime.app.Application.current.window.alert(errorMsg, errorTitle);
			#end
			trace('$errorTitle - $errorMsg');

			_crashed = true;
			close();
			return;
		}

		super();

		bg.alpha = 0.75;
		bg.color = FlxColor.WHITE;
		reloadCheckboxes();

		#if mobile
		var backButton:mobile.MobileButton = mobile.MobileButton.back(null, true);
		add(backButton);
		#end
	}

	private function convertType(str:String):OptionType
	{
		switch(str.toLowerCase().trim())
		{
			case 'bool':
				return BOOL;
			case 'int', 'integer':
				return INT;
			case 'float', 'fl':
				return FLOAT;
			case 'percent':
				return PERCENT;
			case 'string', 'str':
				return STRING;
			case 'keybind', 'key':
				return KEYBIND;
		}
		FlxG.log.error("Could not find option type: " + str);
		return BOOL;
	}

	override public function update(elapsed:Float)
	{
		if(_crashed)
		{
			close();
			return;
		}
		super.update(elapsed);
		updateTouch();
	}

	// ------------------------------------------------------------
	// Touch controls
	// ------------------------------------------------------------
	function updateTouch()
	{
		if(curOption == null) return;

		if(activeTouch == null)
		{
			for(t in FlxG.touches.list)
			{
				if(t.justPressed)
				{
					activeTouch = t;
					lastTX = t.screenX;
					lastTY = t.screenY;
					totalTX = totalTY = accumX = accumY = 0;
					dragAxis = 0;
					break;
				}
			}
			return;
		}

		var t = activeTouch;
		if(t.pressed)
		{
			var dx = t.screenX - lastTX;
			var dy = t.screenY - lastTY;
			lastTX = t.screenX;
			lastTY = t.screenY;
			totalTX += dx;
			totalTY += dy;

			// decide el eje una vez que el dedo se movió lo suficiente
			if(dragAxis == 0 && (Math.abs(totalTX) > TAP_DIST || Math.abs(totalTY) > TAP_DIST))
				dragAxis = Math.abs(totalTX) > Math.abs(totalTY) ? 2 : 1;

			if(dragAxis == 1)
			{
				accumY += dy;
				while(accumY <= -STEP_Y) { accumY += STEP_Y; changeSelection(1); }
				while(accumY >= STEP_Y) { accumY -= STEP_Y; changeSelection(-1); }
			}
			else if(dragAxis == 2)
			{
				accumX += dx;
				while(accumX <= -STEP_X) { accumX += STEP_X; changeValueTouch(-1); }
				while(accumX >= STEP_X) { accumX -= STEP_X; changeValueTouch(1); }
			}
		}
		else if(t.justReleased)
		{
			if(dragAxis == 0) handleTap(t);
			activeTouch = null;
			dragAxis = 0;
		}
	}

	function handleTap(t:FlxTouch)
	{
		for(i in 0...grpOptions.members.length)
		{
			var item = grpOptions.members[i];
			if(item != null && t.overlaps(item, item.camera))
			{
				if(i != curSelected) changeSelection(i - curSelected);
				else if(curOption.type == BOOL) toggleBoolTouch();
				return;
			}
		}
	}

	function toggleBoolTouch()
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));
		curOption.setValue(curOption.getValue() == true ? false : true);
		curOption.change();
		reloadCheckboxes();
	}

	function changeValueTouch(dir:Int)
	{
		switch(curOption.type)
		{
			case BOOL:
				toggleBoolTouch();
				return;
			case INT, FLOAT, PERCENT:
				var val:Float = curOption.getValue() + (dir * curOption.changeValue);
				val = FlxMath.bound(val, curOption.minValue, curOption.maxValue);
				if(curOption.type == INT) val = Math.round(val);
				else val = FlxMath.roundDecimal(val, curOption.decimals);
				curOption.setValue(val);
			case STRING:
				var num:Int = curOption.curOption + dir;
				if(num < 0) num = curOption.options.length - 1;
				else if(num >= curOption.options.length) num = 0;
				curOption.curOption = num;
				curOption.setValue(curOption.options[num]);
			default:
				return; // KEYBIND no se maneja por touch
		}
		updateTextFrom(curOption);
		curOption.change();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	override public function close()
	{
		FlxG.save.data.modSettings.set(folder, save);
		FlxG.save.flush();
		super.close();
	}
}
