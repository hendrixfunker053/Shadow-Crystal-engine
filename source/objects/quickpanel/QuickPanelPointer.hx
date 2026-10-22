package objects.quickpanel;

import flixel.FlxG;
import flixel.FlxObject;

/**
 * Puntero unificado (ratón + primer toque). Se actualiza una vez por frame
 * desde QuickPanelGroup. Usa coordenadas de pantalla (la cámara del panel no tiene zoom ni scroll).
 */
class QuickPanelPointer
{
	public static var x:Float = 0;
	public static var y:Float = 0;
	public static var justPressed:Bool = false;
	public static var justReleased:Bool = false;
	public static var pressed:Bool = false;

	public static function update():Void
	{
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
	}

	public static function overlaps(obj:FlxObject):Bool
	{
		return x >= obj.x && x <= obj.x + obj.width && y >= obj.y && y <= obj.y + obj.height;
	}
}
