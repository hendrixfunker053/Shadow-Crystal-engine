package flxanimate;

#if sys
import sys.io.File;
#end
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flxanimate.frames.FlxAnimateFrames;
import flxanimate.data.AnimationData;
import flxanimate.FlxAnimate as OriginalFlxAnimate;
import haxe.xml.Access;
import openfl.geom.Rectangle;

using StringTools;

class PsychFlxAnimate extends OriginalFlxAnimate
{
	public function loadAtlasEx(img:FlxGraphicAsset, pathOrStr:String = null, myJson:Dynamic = null)
	{
		var animJson:AnimAtlas = null;

		if(myJson is String)
		{
			#if sys
			var trimmedJson:String = cast(myJson, String).trim();
			trimmedJson = trimmedJson.substr(trimmedJson.length - 5).toLowerCase();
			if(trimmedJson == '.json') myJson = File.getContent(myJson); //is a path
			#end

			animJson = cast haxe.Json.parse(_removeBOM(myJson));
		}
		else animJson = cast myJson;

		var isXml:Null<Bool> = null;
		var myData:Dynamic = pathOrStr;

		var trimmed:String = pathOrStr.trim();
		trimmed = trimmed.substr(trimmed.length - 5).toLowerCase();

		#if sys
		if(trimmed == '.json') //Path is json
		{
			myData = File.getContent(pathOrStr);
			isXml = false;
		}
		else if (trimmed.substr(1) == '.xml') //Path is xml
		{
			myData = File.getContent(pathOrStr);
			isXml = true;
		}
		#end

		myData = _removeBOM(myData);

		// Automatic if everything else fails
		switch(isXml)
		{
			case true:
				myData = Xml.parse(myData);
			case false:
				myData = haxe.Json.parse(myData);
			case null:
				try
				{
					myData = haxe.Json.parse(myData);
					isXml = false;
					//trace('JSON parsed successfully!');
				}
				catch(e)
				{
					myData = Xml.parse(myData);
					isXml = true;
					//trace('XML parsed successfully!');
				}
		}

		//? At this point "myData" contains a parsed data (NOT A PATH TO IT)
		anim._loadAtlas(animJson);
		if(!isXml) frames = FlxAnimateFrames.fromSpriteMap(cast myData, img);
		else frames = _framesFromSparrow(img, cast myData);
		origin = anim.curInstance.symbol.transformationPoint;
	}

	// Parser de Sparrow/Starling integrado aquí (copia de FlxAnimateFrames.fromSparrowDirect),
	// así este archivo no depende de que ese método sea privado ni de que exista en tu FlxAnimate.
	static function _framesFromSparrow(img:FlxGraphicAsset, xml:Xml):FlxAtlasFrames
	{
		if(xml.nodeType == Xml.Document) xml = xml.firstElement();

		for(node in xml.elements()) // soporte de w/h abreviados
		{
			if(node.exists("w")) { node.set("width", node.get("w")); node.remove("w"); }
			if(node.exists("h")) { node.set("height", node.get("h")); node.remove("h"); }
		}

		var graphic:FlxGraphic = FlxG.bitmap.add(img);
		var frames = new FlxAtlasFrames(graphic);
		var data:Access = new Access(xml);

		for(texture in data.nodes.SubTexture)
		{
			var name = texture.att.name;
			var trimmed = texture.has.frameX;
			var rotated = (texture.has.rotated && texture.att.rotated == "true");
			var flipX = (texture.has.flipX && texture.att.flipX == "true");
			var flipY = (texture.has.flipY && texture.att.flipY == "true");
			var pivotX = (texture.has.pivotX ? Std.parseFloat(texture.att.pivotX) : 0);
			var pivotY = (texture.has.pivotY ? Std.parseFloat(texture.att.pivotY) : 0);
			var rect = FlxRect.get(Std.parseFloat(texture.att.x), Std.parseFloat(texture.att.y),
				Std.parseFloat(texture.att.width), Std.parseFloat(texture.att.height));

			var size = if(trimmed)
				new Rectangle(Std.parseInt(texture.att.frameX), Std.parseInt(texture.att.frameY),
					Std.parseInt(texture.att.frameWidth), Std.parseInt(texture.att.frameHeight));
			else
				new Rectangle(0, 0, rect.width, rect.height);

			var angle = rotated ? FlxFrameAngle.ANGLE_NEG_90 : FlxFrameAngle.ANGLE_0;

			var offset = FlxPoint.get(-size.left, -size.top);
			var sourceSize = FlxPoint.get(size.width, size.height);

			offset.subtract(pivotX, pivotY);
			if(rotated && !trimmed)
				sourceSize.set(size.height, size.width);

			frames.addAtlasFrame(rect, sourceSize, offset, name, angle, flipX, flipY);
		}

		return frames;
	}

	override function draw()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		super.draw();
	}

	override function destroy()
	{
		try
		{
			super.destroy();
		}
		catch(e:haxe.Exception)
		{
			anim.curInstance = FlxDestroyUtil.destroy(anim.curInstance);
			anim.stageInstance = FlxDestroyUtil.destroy(anim.stageInstance);
			//anim.metadata = FlxDestroyUtil.destroy(anim.metadata);
			anim.metadata.destroy();
			anim.symbolDictionary = null;
		}
	}

	function _removeBOM(str:String) //Removes BOM byte order indicator
	{
		if (str.charCodeAt(0) == 0xFEFF) str = str.substr(1); //myData = myData.substr(2);
		return str;
	}

	public function pauseAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.pause();
	}
	public function resumeAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.play();
	}
}
