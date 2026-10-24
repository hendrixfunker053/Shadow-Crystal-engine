package objects.quickpanel;

import flixel.FlxG;
import flixel.FlxObject;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;
import openfl.geom.Point;

/**
 * Puntero unificado (ratón + toque). Se actualiza una vez por frame desde QuickPanelGroup.
 * Usa coordenadas de pantalla del juego (la cámara del panel no tiene zoom ni scroll).
 *
 * Además de FlxG.mouse / FlxG.touches escucha los eventos crudos del stage (MouseEvent y TouchEvent),
 * porque en algunos forks de Android Flixel no recibe el toque y la pestaña no respondía.
 */
class QuickPanelPointer
{
	public static var x:Float = 0;
	public static var y:Float = 0;
	public static var justPressed:Bool = false;
	public static var justReleased:Bool = false;
	public static var pressed:Bool = false;

	// Estado de los eventos crudos
	static var inited:Bool = false;
	static var rawDown:Bool = false;
	static var rawPressedNow:Bool = false;
	static var rawReleased:Bool = false;
	static var rawX:Float = 0;
	static var rawY:Float = 0;
	static var touchId:Int = -1;

	// Anti-duplicados: el mismo toque puede llegar por FlxG.mouse, FlxG.touches y los eventos crudos en frames distintos
	static var frameCount:Int = 0;
	static var lastPressFrame:Int = -100;
	static var lastReleaseFrame:Int = -100;
	static final DUP_FRAMES:Int = 3;

	static function init():Void
	{
		if (inited || FlxG.stage == null) return;
		inited = true;

		FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 100);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove, false, 100);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, 100);
		FlxG.stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin, false, 100);
		FlxG.stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove, false, 100);
		FlxG.stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd, false, 100);
	}

	/** Coordenadas del stage -> coordenadas del juego. */
	static function toGame(stageX:Float, stageY:Float):Void
	{
		var p:Point = FlxG.game.globalToLocal(new Point(stageX, stageY));
		rawX = p.x / FlxG.scaleMode.scale.x;
		rawY = p.y / FlxG.scaleMode.scale.y;
	}

	static function onMouseDown(e:MouseEvent):Void
	{
		toGame(e.stageX, e.stageY);
		rawDown = true;
		rawPressedNow = true;
	}

	static function onMouseMove(e:MouseEvent):Void
	{
		if (rawDown) toGame(e.stageX, e.stageY);
	}

	static function onMouseUp(e:MouseEvent):Void
	{
		toGame(e.stageX, e.stageY);
		rawDown = false;
		rawReleased = true;
	}

	static function onTouchBegin(e:TouchEvent):Void
	{
		if (touchId != -1) return; // solo el primer dedo
		touchId = e.touchPointID;
		toGame(e.stageX, e.stageY);
		rawDown = true;
		rawPressedNow = true;
	}

	static function onTouchMove(e:TouchEvent):Void
	{
		if (e.touchPointID == touchId) toGame(e.stageX, e.stageY);
	}

	static function onTouchEnd(e:TouchEvent):Void
	{
		if (e.touchPointID != touchId) return;
		toGame(e.stageX, e.stageY);
		touchId = -1;
		rawDown = false;
		rawReleased = true;
	}

	public static function update():Void
	{
		init();

		justPressed = FlxG.mouse.justPressed;
		justReleased = FlxG.mouse.justReleased;
		pressed = FlxG.mouse.pressed;
		x = FlxG.mouse.screenX;
		y = FlxG.mouse.screenY;

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed) justPressed = true;
			if (touch.justReleased) justReleased = true;
			if (touch.pressed) pressed = true;
			if (touch.pressed || touch.justPressed || touch.justReleased)
			{
				x = touch.screenX;
				y = touch.screenY;
			}
		}
		#end

		// Eventos crudos (se fusionan con lo anterior)
		if (rawPressedNow) justPressed = true;
		if (rawReleased) justReleased = true;
		if (rawDown) pressed = true;
		if (rawPressedNow || rawReleased || rawDown)
		{
			x = rawX;
			y = rawY;
		}

		frameCount++;
		if (justPressed)
		{
			if (frameCount - lastPressFrame <= DUP_FRAMES) justPressed = false;
			lastPressFrame = frameCount;
		}
		if (justReleased)
		{
			if (frameCount - lastReleaseFrame <= DUP_FRAMES) justReleased = false;
			lastReleaseFrame = frameCount;
		}

		if (justPressed) trace('QuickPanel pointer: toque en (${Std.int(x)}, ${Std.int(y)})');

		rawPressedNow = false;
		rawReleased = false;
	}

	public static function overlaps(obj:FlxObject):Bool
	{
		return x >= obj.x && x <= obj.x + obj.width && y >= obj.y && y <= obj.y + obj.height;
	}
}
