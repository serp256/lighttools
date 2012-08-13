package ru.redspell.rasterizer.commands {
	import ru.nazarov.asmvc.command.AbstractCommand;
	import ru.redspell.rasterizer.models.SwfsPack;
	import ru.redspell.rasterizer.utils.Utils;

	public class RefreshPackMetaCommand extends SavePackMetaRunnerCommand {
		public function RefreshPackMetaCommand(pack:SwfsPack, save:Boolean = true) {
			super(pack, save);
		}

		override public function unsafeExecute():void {
            trace('ok', _pack.checked, _pack.scales);

			var meta:Object = Facade.proj.meta;

			if (!meta.hasOwnProperty(_pack.name)) {
				meta[_pack.name] = {};
			}

			var packMeta:Object = meta[_pack.name];

			if (_pack.checked) {
                trace('ok');
				delete packMeta.checked;
			} else {
				packMeta.checked = false;
			}

            if (Utils.objIsEmpty(_pack.scales)) {
                trace('ok1');
                delete packMeta.scales;
            } else {
                packMeta.scales = _pack.scales;
            }

            for (var key:String in packMeta) {
                trace(key, packMeta[key]);
            }

            if (Utils.objIsEmpty(packMeta)) {
                trace('ok2');
                delete meta[_pack.name];
            }

            super.unsafeExecute();
		}
	}
}