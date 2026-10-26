package options;

class ShadowCrystalSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('shadow_crystal_menu', 'Shadow Crystal Options');
		rpcTitle = 'Shadow Crystal Options Menu';

		var option:Option = new Option('Old Story Menu',
			'If checked, Story Mode uses the old menu instead of the new one.',
			'oldStoryMenu',
			BOOL);
		addOption(option);

		var option:Option = new Option('Old Mods Menu',
			'If checked, the Mods menu uses the old layout instead of the current one.',
			'oldModsMenu',
			BOOL);
		addOption(option);

		super();
	}
}
