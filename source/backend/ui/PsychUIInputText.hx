package backend.ui;

import flixel.FlxObject;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxDestroyUtil;
import flash.events.KeyboardEvent;
import lime.system.Clipboard;

enum abstract AccentCode(Int) from Int from UInt to Int to UInt
{
	var NONE = -1;
	var GRAVE = 0;
	var ACUTE = 1;
	var CIRCUMFLEX = 2;
	var TILDE = 3;
}

enum abstract FilterMode(Int) from Int from UInt to Int to UInt
{
	var NO_FILTER:Int = 0;
	var ONLY_ALPHA:Int = 1;
	var ONLY_NUMERIC:Int = 2;
	var ONLY_ALPHANUMERIC:Int = 3;
	var ONLY_HEXADECIMAL:Int = 4;
	var CUSTOM_FILTER:Int = 5;
}

enum abstract CaseMode(Int) from Int from UInt to Int to UInt
{
	var ALL_CASES:Int = 0;
	var UPPER_CASE:Int = 1;
	var LOWER_CASE:Int = 2;
}

class PsychUIInputText extends FlxSpriteGroup
{
	public static final CHANGE_EVENT = "inputtext_change";

	static final KEY_TILDE = 126;
	static final KEY_ACUTE = 180;

	public static var focusOn(default, set):PsychUIInputText = null;

	public var name:String;
	public var bg:FlxSprite;
	public var behindText:FlxSprite;
	public var selection:FlxSprite;
	public var textObj:FlxText;
	public var caret:FlxSprite;
	public var onChange:String->String->Void;

	public var fieldWidth(default, set):Int = 0;
	public var maxLength(default, set):Int = 0;
	public var passwordMask(default, set):Bool = false;
	public var text(default, set):String = null;

	public var forceCase(default, set):CaseMode = ALL_CASES;
	public var filterMode(default, set):FilterMode = NO_FILTER;
	public var customFilterPattern(default, set):EReg;

	public var selectedFormat:FlxTextFormat;

	public function new(x:Float = 0, y:Float = 0, wid:Int = 100, ?text:String = '', size:Int = 8)
	{
		super(x, y);

		try
		{
			this.selectedFormat = new FlxTextFormat(FlxColor.WHITE);
		}
		catch (e:Dynamic) {}

		this.bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		this.behindText = new FlxSprite(1, 1).makeGraphic(1, 1, FlxColor.WHITE);
		this.selection = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		this.textObj = new FlxText(1, 1, Math.max(1, wid - 2), '', size);
		this.caret = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);

		add(this.bg);
		add(this.behindText);
		add(this.selection);
		add(this.textObj);
		add(this.caret);

		this.textObj.color = FlxColor.BLACK;
		if (this.textObj.textField != null)
		{
			this.textObj.textField.selectable = false;
			this.textObj.textField.wordWrap = false;
			this.textObj.textField.multiline = false;
		}
		this.selection.color = FlxColor.BLUE;

		@:bypassAccessor fieldWidth = wid;
		setGraphicSize(wid + 2, this.textObj.height + 2);
		updateHitbox();

		this.text = text;

		if (FlxG.stage != null)
		{
			try
			{
				FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			}
			catch (e:Dynamic) {}
		}
	}

	#if mobile
	static final mobileKeys:Array<FlxKey> = [
		LEFT, RIGHT, HOME, END, INSERT, BACKSPACE, DELETE, ENTER, ESCAPE
	];

	function onTextInput(input:String)
	{
		if (focusOn != this || input == null)
			return;

		for (code in new haxe.iterators.StringIteratorUnicode(input))
			_typeLetter(code);

		updateCaret();
	}
	#end

	public var selectIndex:Int = -1;
	public var caretIndex(default, set):Int = -1;
	var _caretTime:Float = 0;

	var _nextAccent:AccentCode = NONE;
	public var inInsertMode:Bool = false;

	function onKeyDown(e:KeyboardEvent)
	{
		if (focusOn != this)
			return;

		var keyCode:Int = e.keyCode;
		var charCode:Int = e.charCode;
		var flxKey:FlxKey = cast keyCode;

		switch (keyCode)
		{
			case 231:
				charCode = e.shiftKey ? 0xC7 : 0xE7;
		}

		if (e.controlKey)
		{
			switch (flxKey)
			{
				case A:
					selectIndex = 0;
					caretIndex = text == null ? 0 : text.length;

				case X, C:
					if (caretIndex >= 0 && selectIndex >= 0 && caretIndex != selectIndex)
					{
						var start:Int = Std.int(Math.min(caretIndex, selectIndex));
						var end:Int = Std.int(Math.max(caretIndex, selectIndex));
						try { Clipboard.text = text.substring(start, end); } catch (e:Dynamic) {}

						if (flxKey == X)
							deleteSelection();
					}

				case V:
					try
					{
						if (Clipboard.text == null)
							return;

						if (text == null)
							text = "";

						caretIndex = Std.int(Math.max(0, Math.min(caretIndex, text.length)));

						var lastText:String = text;
						var pasteText:String = filter(Clipboard.text);

						if (selectIndex >= 0 && selectIndex != caretIndex)
						{
							var start:Int = Std.int(Math.min(selectIndex, caretIndex));
							var end:Int = Std.int(Math.max(selectIndex, caretIndex));

							text = text.substring(0, start) + text.substring(end);
							caretIndex = start;
							selectIndex = -1;
						}

						if (maxLength > 0)
						{
							var available:Int = maxLength - text.length;
							if (available < 0) available = 0;
							pasteText = pasteText.substr(0, available);
						}

						text = text.substring(0, caretIndex) + pasteText + text.substring(caretIndex);
						caretIndex += pasteText.length;
						selectIndex = -1;

						if (onChange != null)
							onChange(lastText, text);

						if (broadcastInputTextEvent)
							PsychUIEventHandler.event(CHANGE_EVENT, this);
					}
					catch (e:Dynamic) {}

				case BACKSPACE:
					if (selectIndex < 0 || selectIndex == caretIndex)
					{
						if (caretIndex <= 0)
							return;

						var lastText:String = text;
						text = text.substring(0, caretIndex - 1) + text.substring(caretIndex);
						caretIndex--;
						selectIndex = -1;

						if (onChange != null)
							onChange(lastText, text);

						if (broadcastInputTextEvent)
							PsychUIEventHandler.event(CHANGE_EVENT, this);
					}
					else
						deleteSelection();

				case DELETE:
					if (selectIndex < 0 || selectIndex == caretIndex)
					{
						if (caretIndex >= text.length)
							return;

						var lastText:String = text;
						text = text.substring(0, caretIndex) + text.substring(caretIndex + 1);

						if (onChange != null)
							onChange(lastText, text);

						if (broadcastInputTextEvent)
							PsychUIEventHandler.event(CHANGE_EVENT, this);
					}
					else
						deleteSelection();

				default:
			}

			updateCaret();
			return;
		}

		static final ignored:Array<FlxKey> = [SHIFT, CONTROL, ESCAPE];
		if (ignored.contains(flxKey))
			return;

		#if mobile
		if (!mobileKeys.contains(flxKey))
			return;
		#end

		switch (flxKey)
		{
			case LEFT:
				if (!FlxG.keys.pressed.SHIFT)
					selectIndex = -1;
				else if (selectIndex == -1)
					selectIndex = caretIndex;
				caretIndex = Std.int(Math.max(0, caretIndex - 1));

			case RIGHT:
				if (!FlxG.keys.pressed.SHIFT)
					selectIndex = -1;
				else if (selectIndex == -1)
					selectIndex = caretIndex;
				caretIndex = Std.int(Math.min(text.length, caretIndex + 1));

			case HOME:
				if (!FlxG.keys.pressed.SHIFT)
					selectIndex = -1;
				else if (selectIndex == -1)
					selectIndex = caretIndex;
				caretIndex = 0;

			case END:
				if (!FlxG.keys.pressed.SHIFT)
					selectIndex = -1;
				else if (selectIndex == -1)
					selectIndex = caretIndex;
				caretIndex = text.length;

			case INSERT:
				inInsertMode = !inInsertMode;

			case BACKSPACE:
				if (text == null || text.length <= 0)
					return;

				if (selectIndex > -1 && selectIndex != caretIndex)
				{
					deleteSelection();
				}
				else if (caretIndex > 0)
				{
					var lastText:String = text;
					caretIndex = Std.int(Math.max(0, Math.min(caretIndex, text.length)));
					text = text.substring(0, caretIndex - 1) + text.substring(caretIndex);
					caretIndex--;

					if (onChange != null)
						onChange(lastText, text);

					if (broadcastInputTextEvent)
						PsychUIEventHandler.event(CHANGE_EVENT, this);
				}

			case DELETE:
				if (text == null || text.length <= 0)
					return;

				if (selectIndex > -1 && selectIndex != caretIndex)
				{
					deleteSelection();
					updateCaret();
					return;
				}

				if (caretIndex >= text.length)
					return;

				var lastText:String = text;
				caretIndex = Std.int(Math.max(0, Math.min(caretIndex, text.length)));
				text = text.substring(0, caretIndex) + text.substring(caretIndex + 1);

				if (onChange != null)
					onChange(lastText, text);

				if (broadcastInputTextEvent)
					PsychUIEventHandler.event(CHANGE_EVENT, this);

			case SPACE:
				_typeLetter(charCode);

			case ESCAPE:
				focusOn = null;

			case ENTER:
				onPressEnter(e);

			default:
				_typeLetter(charCode);
		}

		updateCaret();
	}

	public dynamic function onPressEnter(e:KeyboardEvent)
	{
		focusOn = null;
	}

	public var unfocus:Void->Void;

	public static function set_focusOn(v:PsychUIInputText)
	{
		if (focusOn != null && focusOn != v && focusOn.exists)
		{
			if (focusOn.unfocus != null)
				focusOn.unfocus();

			focusOn.resetCaret();
		}

		return (focusOn = v);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(behindText, camera))
			{
				if (!FlxG.keys.pressed.SHIFT)
					selectIndex = -1;
				else if (selectIndex == -1)
					selectIndex = caretIndex;

				focusOn = this;
				caretIndex = 0;

				var lastBound:Float = 0;
				var textObjX:Float = textObj.getScreenPosition(camera).x;
				var mousePosX:Float = FlxG.mouse.getScreenPosition(camera).x;
				var txtX:Float = textObjX - (textObj.textField != null ? textObj.textField.scrollH : 0);

				for (i => bound in _boundaries)
				{
					if (mousePosX >= txtX
