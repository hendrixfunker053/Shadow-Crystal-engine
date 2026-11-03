package states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.text.FlxText.FlxTextBorderStyle;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
#if mobile
import mobile.MobileFileReference as FileReference;
#else
import openfl.net.FileReference;
#end

/**
 * Crystal HUD Studio
 * Visual HUD layout editor with draggable objects, editable properties
 * and Lua export. Designed for the Shadow Crystal / Psych Engine fork.
 */
class CrystalHUDStudioState extends MusicBeatState
{
    static inline var FONT:String = "FunkinOptions.otf";

    var purple:FlxColor = 0xFF914DFF;
    var categories:Array<String> = ["EVENTS", "OBJECTS", "PROPERTIES", "ANIMATIONS", "LOGIC", "VARIABLES", "GAME DATA"];
    var blockData:Array<Array<String>> = [
        ["When song starts", "When step hits", "When beat hits", "When song ends"],
        ["Create text", "Create sprite", "Remove object", "Add to HUD", "Import image"],
        ["Set position", "Set scale", "Set alpha", "Set visibility"],
        ["Tween X", "Tween Y", "Tween Alpha", "Tween Scale"],
        ["If", "If / Else", "Repeat", "Forever"],
        ["Set variable", "Change variable", "Get variable"],
        ["Get score", "Get combo", "Get misses", "Get health", "Get song position"]
    ];

    var categoryButtons:Array<FlxText> = [];
    var headerButtons:Array<FlxText> = [];
    var toolboxItems:FlxTypedGroup<FlxSprite>;
    var toolboxLabels:FlxTypedGroup<FlxText>;
    var objects:FlxTypedGroup<FlxSprite>;
    var objectLabels:FlxTypedGroup<FlxText>;
    var selection:FlxSprite;

    var selectedCategory:Int = 0;
    var selectedObject:Int = -1;
    var dragging:Bool = false;
    var dragOffsetX:Float = 0;
    var dragOffsetY:Float = 0;
    var previewVisible:Bool = true;
    var codeVisible:Bool = false;

    var previewPanel:FlxSprite;
    var previewTitle:FlxText;
    var propertiesText:FlxText;
    var statusText:FlxText;
    var codeBg:FlxSprite;
    var codeText:FlxText;
    var closeCode:FlxText;

    var file:FileReference;
    #if mobile
    var pickingImage:Bool = false;
    #end

    // Metadata kept parallel to objects/labels.
    var objectNames:Array<String> = [];
    var objectKinds:Array<String> = [];
    var objectAssets:Array<String> = [];
    var objectAlpha:Array<Float> = [];
    var objectScale:Array<Float> = [];

    override function create()
    {
        super.create();
        FlxG.camera.bgColor = 0xFF08070C;
        FlxG.mouse.visible = true;

        addRect(0, 0, FlxG.width, FlxG.height, 0xFF08070C);
        addRect(0, 0, FlxG.width, 54, 0xFF15121D);
        addRect(0, 53, FlxG.width, 2, purple);

        addText(14, 12, 330, "CRYSTAL HUD STUDIO", 23, FlxColor.WHITE);
        addHeader("PREVIEW", FlxG.width - 350);
        addHeader("IMPORT IMAGE", FlxG.width - 245);
        addHeader("EXPORT LUA", FlxG.width - 130);

        // Left category panel and toolbox.
        addRect(0, 55, 178, FlxG.height - 55, 0xFF121019);
        addRect(177, 55, 2, FlxG.height - 55, purple);
        addText(12, 68, 155, "CATEGORIES", 16, purple);
        for (i in 0...categories.length)
        {
            var t = addText(12, 101 + i * 34, 155, categories[i], 13, FlxColor.WHITE);
            t.ID = i;
            categoryButtons.push(t);
        }

        addText(12, 355, 155, "BLOCKS", 16, purple);
        toolboxItems = new FlxTypedGroup<FlxSprite>();
        toolboxLabels = new FlxTypedGroup<FlxText>();
        add(toolboxItems);
        add(toolboxLabels);

        // Workspace.
        addRect(179, 55, Std.int(FlxG.width * 0.39), FlxG.height - 55, 0xFF1A1721);
        addRect(Std.int(FlxG.width * 0.39) + 178, 55, 2, FlxG.height - 55, purple);
        addText(195, 68, 250, "WORKSPACE", 17, purple);
        addText(195, 91, 400, "Add blocks from the left. Drag HUD objects in the preview.", 11, 0xFFAAA3B4);

        objects = new FlxTypedGroup<FlxSprite>();
        objectLabels = new FlxTypedGroup<FlxText>();
        add(objects);
        add(objectLabels);

        // Right preview and properties.
        var rightX:Int = Std.int(FlxG.width * 0.59);
        var rightW:Int = FlxG.width - rightX;
        addRect(rightX, 55, rightW, Std.int(FlxG.height * 0.52), 0xFF08080B);
        addText(rightX + 12, 68, rightW - 20, "HUD PREVIEW", 17, purple);
        previewPanel = new FlxSprite(rightX + 12, 105).makeGraphic(rightW - 24, Std.int(FlxG.height * 0.52) - 120, 0xFF171923);
        add(previewPanel);
        previewTitle = addText(rightX + 25, 116, rightW - 50, "FRIDAY NIGHT FUNKIN'  |  HUD MOCKUP", 10, 0xFFBEB8C9);

        // Preview guide elements, deliberately visual rather than a static score-only label.
        var score = addText(rightX + 28, 150, rightW - 56, "SCORE: 000000     MISSES: 0", 14, FlxColor.WHITE);
        score.alignment = CENTER;
        var healthBg = new FlxSprite(rightX + 35, 180).makeGraphic(rightW - 70, 8, 0xFF39313F);
        add(healthBg);
        var health = new FlxSprite(rightX + 35, 180).makeGraphic(Std.int((rightW - 70) * 0.65), 8, 0xFF914DFF);
        add(health);
        var combo = addText(rightX + 25, 198, rightW - 50, "COMBO  012", 17, 0xFFFFD966);
        combo.alignment = CENTER;

        var propY:Int = Std.int(FlxG.height * 0.59);
        addRect(rightX, propY, rightW, FlxG.height - propY, 0xFF121019);
        addRect(rightX, propY, rightW, 2, purple);
        addText(rightX + 12, propY + 10, rightW - 24, "PROPERTIES", 17, purple);
        propertiesText = addText(rightX + 12, propY + 40, rightW - 24,
            "No object selected.\nSelect a HUD object to edit it.\n\nControls: arrows = move, +/- = scale, [ ] = alpha, Delete = remove.",
            12, FlxColor.WHITE);
        statusText = addText(190, FlxG.height - 24, Std.int(FlxG.width * 0.38), "Ready.", 10, 0xFFAAA3B4);

        selection = new FlxSprite().makeGraphic(1, 1, 0x00FFFFFF);
        selection.visible = false;
        selection.scrollFactor.set();
        add(selection);

        changeCategory(0);
        #if mobile
        add(mobile.MobileButton.back());
        #end
    }

    function addRect(x:Float, y:Float, w:Int, h:Int, color:FlxColor):FlxSprite
    {
        var s = new FlxSprite(x, y).makeGraphic(w, h, color);
        s.scrollFactor.set();
        add(s);
        return s;
    }

    function addText(x:Float, y:Float, w:Float, value:String, size:Int, color:FlxColor):FlxText
    {
        var t = new FlxText(x, y, w, value, size);
        t.setFormat(Paths.font(FONT), size, color, LEFT, OUTLINE, 0xFF000000);
        t.scrollFactor.set();
        add(t);
        return t;
    }

    function addHeader(label:String, x:Float):Void
    {
        var t = addText(x, 18, 105, label, 12, 0xFFE3D5FF);
        t.alignment = CENTER;
        t.borderStyle = FlxTextBorderStyle.OUTLINE;
        t.borderColor = 0xFF6132A0;
        headerButtons.push(t);
    }

    function changeCategory(index:Int):Void
    {
        if (index < 0 || index >= categories.length) return;
        selectedCategory = index;
        for (t in categoryButtons) t.color = (t.ID == index ? purple : FlxColor.WHITE);
        clearGroup(toolboxItems);
        clearGroup(toolboxLabels);

        for (i in 0...blockData[index].length)
        {
            var y:Float = 382 + i * 34;
            if (y > FlxG.height - 35) break;
            var b = new FlxSprite(9, y).makeGraphic(158, 27, categoryColor(index));
            toolboxItems.add(b);
            var label = new FlxText(16, y + 6, 146, blockData[index][i], 11);
            label.setFormat(Paths.font(FONT), 11, FlxColor.WHITE, LEFT);
            label.ID = i;
            label.scrollFactor.set();
            toolboxLabels.add(label);
        }
    }

    function clearGroup<T:FlxSprite>(group:FlxTypedGroup<T>):Void
    {
        for (member in group.members.copy())
        {
            if (member != null)
            {
                group.remove(member, true);
                member.destroy();
            }
        }
    }

    function categoryColor(index:Int):FlxColor
    {
        return switch (index)
        {
            case 0: 0xFFB38B26;
            case 1: 0xFF269C55;
            case 2: 0xFF287BC0;
            case 3: 0xFFD77B26;
            case 4: 0xFF8544C5;
            case 5: 0xFFCC6630;
            default: 0xFF2789B9;
        };
    }

    function addWorkspaceBlock(name:String):Void
    {
        var x:Float = 205;
        var y:Float = 125 + objects.length * 42;
        if (y > FlxG.height - 55) y = 125;
        var block = new FlxSprite(x, y).makeGraphic(Std.int(FlxG.width * 0.34), 31, categoryColor(selectedCategory));
        objects.add(block);
        var label = new FlxText(x + 8, y + 8, block.width - 16, name, 11);
        label.setFormat(Paths.font(FONT), 11, FlxColor.WHITE, LEFT);
        label.scrollFactor.set();
        objectLabels.add(label);

        objectNames.push(name);
        objectKinds.push(name == "Create text" ? "text" : "block");
        objectAssets.push("");
        objectAlpha.push(1);
        objectScale.push(1);
        selectedObject = objects.length - 1;
        status("Added: " + name);
        updateProperties();
    }

    function addPreviewObject(name:String, sprite:FlxSprite, asset:String = ""):Void
    {
        objects.add(sprite);
        var label = new FlxText(sprite.x, sprite.y - 16, 180, name, 10);
        label.setFormat(Paths.font(FONT), 10, FlxColor.WHITE, LEFT);
        label.scrollFactor.set();
        objectLabels.add(label);
        objectNames.push(name);
        objectKinds.push("sprite");
        objectAssets.push(asset);
        objectAlpha.push(sprite.alpha);
        objectScale.push(sprite.scale.x);
        selectedObject = objects.length - 1;
        updateProperties();
    }

    function selectObject(index:Int):Void
    {
        if (index < 0 || index >= objects.length) return;
        selectedObject = index;
        updateProperties();
    }

    function updateProperties():Void
    {
        if (propertiesText == null) return;
        if (selectedObject < 0 || selectedObject >= objects.length)
        {
            propertiesText.text = "No object selected.\nSelect a HUD object to edit it.";
            selection.visible = false;
            return;
        }
        var s = objects.members[selectedObject];
        if (s == null) return;
        propertiesText.text = "Name: " + objectNames[selectedObject]
            + "\nType: " + objectKinds[selectedObject]
            + "\nX: " + Std.int(s.x) + "    Y: " + Std.int(s.y)
            + "\nScale: " + objectScale[selectedObject]
            + "\nAlpha: " + objectAlpha[selectedObject]
            + "\nVisible: " + s.visible
            + "\n\nArrows: move | +/-: scale\n[ ]: alpha | Delete: remove";
        selection.x = s.x - 2;
        selection.y = s.y - 2;
        selection.setGraphicSize(Std.int(Math.max(4, s.width * s.scale.x + 4)), Std.int(Math.max(4, s.height * s.scale.y + 4)));
        selection.updateHitbox();
        selection.color = purple;
        selection.alpha = 0.85;
        selection.visible = true;
    }

    function removeSelected():Void
    {
        if (selectedObject < 0 || selectedObject >= objects.length) return;
        var s = objects.members[selectedObject];
        var label = objectLabels.members[selectedObject];
        if (s != null) { objects.remove(s, true); s.destroy(); }
        if (label != null) { objectLabels.remove(label, true); label.destroy(); }
        objectNames.splice(selectedObject, 1);
        objectKinds.splice(selectedObject, 1);
        objectAssets.splice(selectedObject, 1);
        objectAlpha.splice(selectedObject, 1);
        objectScale.splice(selectedObject, 1);
        // Rebuild groups so indices remain aligned after deletion.
        compactObjects();
        selectedObject = -1;
        updateProperties();
        status("Object removed.");
    }

    function compactObjects():Void
    {
        var oldSprites = objects.members.copy();
        var oldLabels = objectLabels.members.copy();
        objects.clear();
        objectLabels.clear();
        for (i in 0...oldSprites.length)
        {
            if (oldSprites[i] != null) objects.add(oldSprites[i]);
            if (oldLabels[i] != null) objectLabels.add(oldLabels[i]);
        }
    }

    function status(message:String):Void
    {
        if (statusText != null) statusText.text = message;
    }

    function importImage():Void
    {
        if (file != null) return;
        #if mobile
        if (pickingImage) return;
        pickingImage = true;
        mobile.StageImageImport.pick(function(path:String)
        {
            pickingImage = false;
            try
            {
                var sprite = new FlxSprite(Std.int(FlxG.width * 0.64), 245);
                sprite.loadGraphic(path);
                sprite.setGraphicSize(Std.int(Math.min(sprite.width, 150)));
                sprite.updateHitbox();
                addPreviewObject("Imported image", sprite, path);
                status("Image imported.");
            }
            catch (e:Dynamic) status("Could not load image: " + Std.string(e));
        }, function(message:String)
        {
            pickingImage = false;
            status("Import error: " + message);
        }, function()
        {
            pickingImage = false;
            status("Image selection cancelled.");
        });
        #else
        file = new FileReference();
        file.addEventListener(Event.SELECT, onImageSelected);
        file.addEventListener(Event.CANCEL, onImageCancelled);
        file.addEventListener(IOErrorEvent.IO_ERROR, onImageError);
        file.browse([new FileFilter("Images", "*.png;*.jpg;*.jpeg")]);
        #end
    }

    #if !mobile
    function onImageSelected(_):Void
    {
        if (file == null) return;
        file.removeEventListener(Event.SELECT, onImageSelected);
        file.addEventListener(Event.COMPLETE, onImageLoaded);
        file.load();
    }

    function onImageLoaded(_):Void
    {
        if (file == null) return;
        try
        {
            var bitmap = BitmapData.fromBytes(file.data);
            var sprite = new FlxSprite(Std.int(FlxG.width * 0.64), 245);
            sprite.loadGraphic(bitmap);
            sprite.setGraphicSize(Std.int(Math.min(sprite.width, 150)));
            sprite.updateHitbox();
            addPreviewObject("Imported image", sprite);
            status("Image imported into preview.");
        }
        catch (e:Dynamic) status("Could not decode image: " + Std.string(e));
        cleanupFile();
    }

    function onImageCancelled(_):Void { cleanupFile(); status("Image selection cancelled."); }
    function onImageError(_):Void { cleanupFile(); status("Image import failed."); }

    function cleanupFile():Void
    {
        if (file == null) return;
        file.removeEventListener(Event.SELECT, onImageSelected);
        file.removeEventListener(Event.COMPLETE, onImageLoaded);
        file.removeEventListener(Event.CANCEL, onImageCancelled);
        file.removeEventListener(IOErrorEvent.IO_ERROR, onImageError);
        file = null;
    }
    #end

    function togglePreview():Void
    {
        previewVisible = !previewVisible;
        previewPanel.visible = previewVisible;
        previewTitle.visible = previewVisible;
        for (i in 0...objects.length)
        {
            var s = objects.members[i];
            if (s != null) s.visible = previewVisible && s.visible;
        }
        status(previewVisible ? "Preview shown." : "Preview hidden.");
    }

    function generateLua():String
    {
        var out = "-- Crystal HUD Studio - generated script\n\n";
        var create = "";
        var step = "";
        var beat = "";
        var ending = "";
        var event = "create";

        for (i in 0...objectNames.length)
        {
            var name = objectNames[i];
            switch (name)
            {
                case "When song starts": event = "create";
                case "When step hits": event = "step";
                case "When beat hits": event = "beat";
                case "When song ends": event = "end";
                case "Create text":
                    create += "makeLuaText('studioText" + i + "', 'Hello!', 220, 100, 100)\nsetTextSize('studioText" + i + "', 24)\nsetObjectCamera('studioText" + i + "', 'hud')\naddLuaText('studioText" + i + "')\n";
                case "Set position":
                    create += "-- Set position using the selected object's X/Y values in the editor.\n";
                case "Get score": create += "local score = getProperty('songScore')\n";
                case "Get combo": create += "local combo = getProperty('combo')\n";
                case "Get misses": create += "local misses = getProperty('songMisses')\n";
                case "Get health": create += "local health = getProperty('health')\n";
                case "Get song position": create += "local songPosition = getSongPosition()\n";
                default:
                    create += "-- " + name + " (configure this action in your script)\n";
            }
        }
        if (create.length > 0) out += "function onCreatePost()\n" + create + "end\n\n";
        if (step.length > 0) out += "function onStepHit()\n" + step + "end\n\n";
        if (beat.length > 0) out += "function onBeatHit()\n" + beat + "end\n\n";
        if (ending.length > 0) out += "function onEndSong()\n" + ending + "end\n\n";

        for (i in 0...objects.length)
        {
            var s = objects.members[i];
            if (s == null || objectKinds[i] != "sprite") continue;
            out += "-- Imported object " + i + ": " + objectNames[i] + "\n";
            out += "-- Image asset must be placed in the mod's images folder before use.\n";
            out += "makeLuaSprite('studioImage" + i + "', 'REPLACE_WITH_IMAGE_PATH', " + Std.int(s.x) + ", " + Std.int(s.y) + ")\n";
            out += "scaleObject('studioImage" + i + "', " + objectScale[i] + ", " + objectScale[i] + ")\n";
            out += "setProperty('studioImage" + i + ".alpha', " + objectAlpha[i] + ")\n";
            out += "setObjectCamera('studioImage" + i + "', 'hud')\naddLuaSprite('studioImage" + i + "', true)\n\n";
        }
        return out;
    }

    function showCode():Void
    {
        if (codeVisible) return;
        codeVisible = true;
        codeBg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xF208070C);
        add(codeBg);
        codeText = new FlxText(24, 68, FlxG.width - 48, generateLua(), 12);
        codeText.setFormat(Paths.font(FONT), 12, FlxColor.WHITE, LEFT);
        codeText.scrollFactor.set();
        add(codeText);
        closeCode = addText(FlxG.width - 130, 22, 110, "CLOSE [ESC]", 13, purple);
    }

    function hideCode():Void
    {
        if (!codeVisible) return;
        codeVisible = false;
        if (codeBg != null) { remove(codeBg); codeBg.destroy(); codeBg = null; }
        if (codeText != null) { remove(codeText); codeText.destroy(); codeText = null; }
        if (closeCode != null) { remove(closeCode); closeCode.destroy(); closeCode = null; }
    }

    override function update(elapsed:Float):Void
    {
        super.update(elapsed);

        if (codeVisible)
        {
            if (FlxG.keys.justPressed.ESCAPE || (FlxG.mouse.justPressed && closeCode != null && FlxG.mouse.overlaps(closeCode)))
                hideCode();
            return;
        }

        if (FlxG.mouse.justPressed)
        {
            for (i in 0...headerButtons.length)
            {
                if (FlxG.mouse.overlaps(headerButtons[i]))
                {
                    switch (i)
                    {
                        case 0: togglePreview();
                        case 1: importImage();
                        case 2: showCode();
                    }
                    return;
                }
            }

            for (t in categoryButtons)
            {
                if (FlxG.mouse.overlaps(t)) { changeCategory(t.ID); return; }
            }

            for (i in 0...toolboxItems.length)
            {
                var b = toolboxItems.members[i];
                if (b != null && FlxG.mouse.overlaps(b))
                {
                    addWorkspaceBlock(blockData[selectedCategory][i]);
                    return;
                }
            }

            for (i in 0...objects.length)
            {
                var s = objects.members[i];
                if (s != null && FlxG.mouse.overlaps(s))
                {
                    selectObject(i);
                    dragging = true;
                    dragOffsetX = FlxG.mouse.x - s.x;
                    dragOffsetY = FlxG.mouse.y - s.y;
                    return;
                }
            }
            selectedObject = -1;
            updateProperties();
        }

        if (dragging && selectedObject >= 0 && selectedObject < objects.length)
        {
            var s = objects.members[selectedObject];
            var label = objectLabels.members[selectedObject];
            if (s != null && FlxG.mouse.pressed)
            {
                s.x = FlxG.mouse.x - dragOffsetX;
                s.y = FlxG.mouse.y - dragOffsetY;
                if (label != null) { label.x = s.x; label.y = s.y - 16; }
                updateProperties();
            }
            if (FlxG.mouse.justReleased) dragging = false;
        }

        if (selectedObject >= 0 && selectedObject < objects.length)
        {
            var s = objects.members[selectedObject];
            if (s != null)
            {
                var moved = false;
                if (FlxG.keys.pressed.LEFT) { s.x -= 2; moved = true; }
                if (FlxG.keys.pressed.RIGHT) { s.x += 2; moved = true; }
                if (FlxG.keys.pressed.UP) { s.y -= 2; moved = true; }
                if (FlxG.keys.pressed.DOWN) { s.y += 2; moved = true; }
                if (FlxG.keys.justPressed.PLUS || FlxG.keys.justPressed.NUMPADPLUS)
                {
                    objectScale[selectedObject] = Math.min(5, objectScale[selectedObject] + 0.1);
                    s.scale.set(objectScale[selectedObject], objectScale[selectedObject]); s.updateHitbox(); moved = true;
                }
                if (FlxG.keys.justPressed.MINUS || FlxG.keys.justPressed.NUMPADMINUS)
                {
                    objectScale[selectedObject] = Math.max(0.1, objectScale[selectedObject] - 0.1);
                    s.scale.set(objectScale[selectedObject], objectScale[selectedObject]); s.updateHitbox(); moved = true;
                }
                if (FlxG.keys.justPressed.LBRACKET)
                {
                    objectAlpha[selectedObject] = Math.max(0, objectAlpha[selectedObject] - 0.1);
                    s.alpha = objectAlpha[selectedObject]; moved = true;
                }
                if (FlxG.keys.justPressed.RBRACKET)
                {
                    objectAlpha[selectedObject] = Math.min(1, objectAlpha[selectedObject] + 0.1);
                    s.alpha = objectAlpha[selectedObject]; moved = true;
                }
                if (moved)
                {
                    var label = objectLabels.members[selectedObject];
                    if (label != null) { label.x = s.x; label.y = s.y - 16; }
                    updateProperties();
                }
            }
        }

        if (FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE) removeSelected();
        if (FlxG.keys.justPressed.ESCAPE || controls.BACK)
        {
            MusicBeatState.switchState(new MasterEditorMenu());
            return;
        }
    }

    override function destroy():Void
    {
        cleanupOnDestroy();
        FlxG.mouse.visible = false;
        super.destroy();
    }

    function cleanupOnDestroy():Void
    {
        #if !mobile
        cleanupFile();
        #end
    }
}
