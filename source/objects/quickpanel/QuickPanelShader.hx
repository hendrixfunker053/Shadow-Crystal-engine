package objects.quickpanel;

import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxAngle;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;

/**
 * Shader del fondo del panel: recolorea el sprite y dibuja la "rebanada" amarilla
 * que sigue al botón seleccionado. (Versión sin el efecto "boil".)
 */
class QuickPanelShader extends FlxShader
{
	public static final START_COLOR_NORMAL:FlxColor = 0xffF3E63A;
	public static final END_COLOR_NORMAL:FlxColor = 0xfff5db33;
	public static final START_COLOR_DISABLED:FlxColor = 0xffc7bfbc;
	public static final END_COLOR_DISABLED:FlxColor = 0xffa7a09d;

	public var doLerp:Bool = true;
	public var sliceColorStart:FlxColor = 0xffF3E63A;
	public var sliceColorEnd:FlxColor = 0xfff5db33;
	public var sliceColor(default, set):FlxColor = 0xffF3E63A;
	public var sliceLerp(default, set):Float = 0;

	function set_sliceLerp(val:Float):Float
	{
		if (!doLerp) return val;

		sliceLerp = val;
		sliceColor = FlxColor.interpolate(sliceColorStart, sliceColorEnd, val);
		return val;
	}

	function set_sliceColor(val:FlxColor):FlxColor
	{
		sliceColor = val;
		sliceCol.value = [val.red / 255, val.green / 255, val.blue / 255];
		return val;
	}

	public var bgColor(default, set):FlxColor = 0;

	function set_bgColor(val:FlxColor):FlxColor
	{
		bgColor = val;
		bgCol.value = [val.red / 255, val.green / 255, val.blue / 255, val.alpha / 255];
		return val;
	}

	public var outlineColor(default, set):FlxColor = 0;

	function set_outlineColor(val:FlxColor):FlxColor
	{
		outlineColor = val;
		outlineCol.value = [val.red / 255, val.green / 255, val.blue / 255, val.alpha / 255];
		return val;
	}

	public var sliceVisible(default, set):Bool = true;

	function set_sliceVisible(val:Bool):Bool
	{
		sliceVisible = val;
		sliceEnabled.value = [val];
		return val;
	}

	public var fat(default, set):Float = 0;

	function set_fat(val:Float):Float
	{
		fat = val;
		angle.value = [val * FlxAngle.TO_RAD];
		return val;
	}

	public var dir(default, set):Float = 0;

	function set_dir(val:Float):Float
	{
		dir = val;
		direction.value = [val * FlxAngle.TO_RAD];
		return val;
	}

	public var dirExtra(default, set):Float = 0;

	function set_dirExtra(val:Float):Float
	{
		dirExtra = val;
		directionExtra.value = [val * FlxAngle.TO_RAD];
		return val;
	}

	public var fatExtra(default, set):Float = 0;

	function set_fatExtra(val:Float):Float
	{
		fatExtra = val;
		angleExtra.value = [val * FlxAngle.TO_RAD];
		return val;
	}

	/** Pasa al shader los UV del frame actual del sprite. */
	public function updateFrameInfo(frame:FlxFrame):Void
	{
		uFrameBounds.value = [frame.uv.left, frame.uv.top, frame.uv.right, frame.uv.bottom];
	}

	@:glFragmentSource('
		#pragma header

		#define PI 3.1415926535897932384626433832795

		uniform float angle;
		uniform float angleExtra;

		uniform float direction;
		uniform float directionExtra;

		uniform vec2 relOffset;

		uniform vec3 sliceCol;
		uniform vec4 bgCol;
		uniform vec4 outlineCol;

		uniform bool sliceEnabled;

		// (frame.left, frame.top, frame.right, frame.bottom)
		uniform vec4 uFrameBounds;

		vec2 correctedCoord(vec2 coord)
		{
			float xScaled = (coord.x - uFrameBounds.x) / (uFrameBounds.z - uFrameBounds.x);
			float yScaled = (coord.y - uFrameBounds.w) / (uFrameBounds.y - uFrameBounds.w);
			return vec2(xScaled, yScaled);
		}

		vec2 correctedRatio()
		{
			return vec2(openfl_TextureSize.x * (uFrameBounds.z - uFrameBounds.x), openfl_TextureSize.y * (uFrameBounds.w - uFrameBounds.y));
		}

		float intersect(float d1, float d2)
		{
			return max(d1, d2);
		}

		float pie(vec2 p, float ang)
		{
			vec2 n = vec2(-cos(ang), sin(ang));
			return p.x * n.x + p.y * n.y;
		}

		vec4 sceneDist(vec2 p, vec4 color)
		{
			vec2 center = correctedRatio() * relOffset;
			p = p - center;

			float fullAngle = angle + angleExtra;

			float cc = 0.0;
			float start = (direction + directionExtra) - (fullAngle / 2.0);
			float circle = length(p) - center.y * 0.9;

			float end = start + fullAngle;

			float c = pie(p, start);
			float c2 = pie(p, end);
			float delta = end - start;

			if (delta < PI)
				cc = intersect(c, 1.0 - c2);
			else
				cc = intersect(circle, cc);

			return mix(color, vec4(sliceCol.rgb, 1.0), clamp(1.0 - cc, 0.0, 1.0));
		}

		void main()
		{
			vec4 textureColor = texture2D(bitmap, openfl_TextureCoordv);
			vec3 unpremultipliedColor = textureColor.a > 0.0 ? textureColor.rgb / textureColor.a : textureColor.rgb;

			vec4 recolored = vec4(0.0);

			recolored.a = (unpremultipliedColor.r * bgCol.a) + (unpremultipliedColor.g * bgCol.a) + (unpremultipliedColor.b * outlineCol.a);
			recolored.rgb = min(unpremultipliedColor.r * bgCol.rgb + unpremultipliedColor.g * bgCol.rgb + unpremultipliedColor.b * outlineCol.rgb, vec3(1.0));

			vec2 correctedPos = correctedCoord(openfl_TextureCoordv.xy) * correctedRatio();

			vec4 slice = sceneDist(correctedPos, recolored);

			vec4 finalColor;

			if (sliceEnabled)
				finalColor = mix(recolored, slice, unpremultipliedColor.r);
			else
				finalColor = recolored;

			gl_FragColor = vec4(finalColor.rgb * (finalColor.a * textureColor.a), (finalColor.a * textureColor.a));
		}
	')
	public function new()
	{
		super();

		sliceColor = 0xffF3E63A;
		bgColor = 0xFF000000;
		outlineColor = 0xFFCCCCCC;

		sliceVisible = true;
		sliceLerp = 0;

		dir = -90;
		dirExtra = 0;
		fat = 1.88;
		fatExtra = 0;
		relOffset.value = [7.17, 0.5];
	}
}
