package backend.vslice;

import haxe.Json;
import backend.Conductor;
import states.PlayState;
import backend.StageData;
import flixel.FlxG;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import backend.vslice.VSliceMods.g;

/**
 * Ejecuta en PlayState los eventos V-Slice que ChartConverter dejó como `vslice:<Nombre>`.
 * El valor llega en `value1` como JSON. Los eventos que no se manejan aquí siguen
 * llegando a los scripts via `onEvent` (PlayState ya lo hace después).
 */
class VSliceEvents
{
	public static function handle(ps:PlayState, name:String, raw:String):Void
	{
		var v:Dynamic = null;
		try
		{
			v = Json.parse(raw);
		}
		catch (e:Dynamic) {}

		switch (name)
		{
			case 'FocusCamera':
				focusCamera(ps, v);
			case 'ZoomCamera':
				zoomCamera(ps, v);
			case 'SetCameraBop':
				ps.camZoomingMult = g(v, 'intensity', 1.0);
			case 'ScrollSpeed':
				scrollSpeed(ps, v);
		}
	}

	static inline function stepsToSeconds(steps:Float):Float
		return steps * Conductor.stepCrochet / 1000;

	static function getEase(name:String):Dynamic
	{
		if (name == null || name == 'linear') return FlxEase.linear;
		var f:Dynamic = Reflect.field(FlxEase, name);
		return (f != null) ? f : FlxEase.linear;
	}

	static function focusCamera(ps:PlayState, v:Dynamic):Void
	{
		if (ps.camFollow == null) return;

		var who:Int = Std.isOfType(v, Int) ? v : Std.int(g(v, 'char', 0));
		var ox:Float = Std.isOfType(v, Int) ? 0 : g(v, 'x', 0);
		var oy:Float = Std.isOfType(v, Int) ? 0 : g(v, 'y', 0);

		if (who < 0)
		{
			// Sin personaje: x/y son coordenadas absolutas del mundo.
			ps.camFollow.setPosition(ox, oy);
			return;
		}

		switch (who)
		{
			case 2:
				if (ps.gf != null) ps.moveCameraToGirlfriend();
			case 1:
				ps.moveCamera(true);
			default:
				ps.moveCamera(false);
		}
		ps.camFollow.x += ox;
		ps.camFollow.y += oy;
	}

	static function zoomCamera(ps:PlayState, v:Dynamic):Void
	{
		var zoom:Float = g(v, 'zoom', 1.0);
		var mode:String = g(v, 'mode', 'direct');
		var steps:Float = g(v, 'duration', 4.0);
		var ease:String = g(v, 'ease', 'linear');

		var target:Float = zoom;
		if (mode == 'stage')
			target = zoom * StageData.getStageFile(PlayState.curStage).defaultZoom;

		if (ease == 'INSTANT' || steps <= 0)
		{
			ps.defaultCamZoom = target;
			if (mode == 'direct') FlxG.camera.zoom = target;
			return;
		}

		FlxTween.tween(ps, {defaultCamZoom: target}, stepsToSeconds(steps) / ps.playbackRate, {ease: getEase(ease)});
	}

	static function scrollSpeed(ps:PlayState, v:Dynamic):Void
	{
		var scroll:Float = g(v, 'scroll', 1.0);
		var absolute:Bool = g(v, 'absolute', false);
		var steps:Float = g(v, 'duration', 4.0);
		if (g(v, 'ease', 'linear') == 'INSTANT') steps = 0;

		// "Change Scroll Speed" de Psych espera un multiplicador sobre la velocidad del chart.
		var mult:Float = absolute ? scroll / PlayState.SONG.speed : scroll;
		ps.triggerEvent('Change Scroll Speed', Std.string(mult), Std.string(stepsToSeconds(steps)), 0);
	}
}
