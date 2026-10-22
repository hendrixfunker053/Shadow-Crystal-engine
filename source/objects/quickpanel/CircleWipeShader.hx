package objects.quickpanel;

import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;

/**
 * Círculo negro gigante que "barre" la pantalla al elegir un botón.
 * (Versión sin el efecto "boil", que requería boil_texture.png.)
 */
class CircleWipeShader extends FlxShader
{
	public var circleColor(default, set):FlxColor = 0;

	function set_circleColor(val:FlxColor):FlxColor
	{
		circleColor = val;
		circleCol.value = [val.red / 255, val.green / 255, val.blue / 255, val.alpha / 255];
		return val;
	}

	public var relativeX(default, set):Float = 0;

	function set_relativeX(val:Float):Float
	{
		relativeX = val;
		relOffset.value = [relativeX, relativeY];
		return val;
	}

	public var relativeY(default, set):Float = 0;

	function set_relativeY(val:Float):Float
	{
		relativeY = val;
		relOffset.value = [relativeX, relativeY];
		return val;
	}

	public var circleRadius(default, set):Float = 0;

	function set_circleRadius(val:Float):Float
	{
		circleRadius = val;
		radius.value = [val];
		return val;
	}

	@:glFragmentSource('
		#pragma header

		uniform vec2 relOffset;
		uniform vec4 circleCol;
		uniform float radius;

		float circle(vec2 uv, vec2 pos, float rad)
		{
			float d = length(pos - uv) - rad;
			float t = clamp(d, 0.0, 1.0);
			return 1.0 - t;
		}

		void main()
		{
			vec4 textureColor = texture2D(bitmap, openfl_TextureCoordv);
			vec2 pos = openfl_TextureCoordv * openfl_TextureSize;
			vec4 finalColor = mix(textureColor, circleCol, circle(pos, relOffset * openfl_TextureSize, radius * openfl_TextureSize.y));
			gl_FragColor = finalColor;
		}
	')
	public function new()
	{
		super();
		relOffset.value = [2.6, 0.5];
		circleColor = 0xFF000000;
		relativeX = 2.6;
		relativeY = 0.5;
		circleRadius = 2.9;
	}
}
