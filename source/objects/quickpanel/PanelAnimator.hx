package objects.quickpanel;

private typedef PanelTrack =
{
	var setter:Dynamic->Void;
	var values:Array<Dynamic>;
}

private typedef PanelClip =
{
	var fps:Float;
	var loop:Bool;
	var tracks:Array<PanelTrack>;
	var length:Int;
}

/**
 * Sustituto ligero del PropertyAnimator de Funkin.
 * Cada "pista" es un setter + una lista de valores (uno por frame a los fps del clip).
 * Al terminar, el último valor se queda puesto.
 */
class PanelAnimator
{
	public var onFinish:Void->Void = null;
	public var playing(default, null):Bool = false;
	public var currentName(default, null):String = null;

	var clips:Map<String, PanelClip> = new Map();
	var current:PanelClip = null;
	var time:Float = 0;
	var lastFrame:Int = -1;

	public function new() {}

	public function addAnimation(name:String, fps:Float, loop:Bool = false):Void
	{
		clips.set(name, {fps: fps, loop: loop, tracks: [], length: 0});
	}

	public function addProperty(name:String, setter:Dynamic->Void, values:Array<Dynamic>):Void
	{
		var clip:PanelClip = clips.get(name);
		if (clip == null) return;
		clip.tracks.push({setter: setter, values: values});
		if (values.length > clip.length) clip.length = values.length;
	}

	public function play(name:String):Void
	{
		var clip:PanelClip = clips.get(name);
		if (clip == null) return;

		onFinish = null;
		current = clip;
		currentName = name;
		time = 0;
		lastFrame = 0;
		playing = true;
		apply(clip, 0);
	}

	public function stop():Void
	{
		playing = false;
	}

	public function update(elapsed:Float):Void
	{
		if (!playing || current == null || current.length <= 0) return;

		time += elapsed;
		var frame:Int = Std.int(time * current.fps);

		if (frame >= current.length)
		{
			if (current.loop)
			{
				time = time % (current.length / current.fps);
				frame = Std.int(time * current.fps);
				if (frame >= current.length) frame = current.length - 1;
			}
			else
			{
				apply(current, current.length - 1);
				playing = false;
				var cb:Void->Void = onFinish;
				onFinish = null;
				if (cb != null) cb();
				return;
			}
		}

		if (frame != lastFrame)
		{
			lastFrame = frame;
			apply(current, frame);
		}
	}

	function apply(clip:PanelClip, frame:Int):Void
	{
		for (track in clip.tracks)
		{
			if (track.values.length == 0) continue;
			var i:Int = frame < track.values.length ? frame : track.values.length - 1;
			track.setter(track.values[i]);
		}
	}
}
