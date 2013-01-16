package ru.redspell.rasterizer.models {
    public class ClassProfile {
        private var _checked:Boolean;
        private var _animated:Boolean;
        public var scale:Number;
        public var profileLabel:String;
        public var cls:SwfClass;
        public var profile:Profile;

        public function ClassProfile(checked:Boolean, animated:Boolean, scale:Number, profileLabel:String, cls:SwfClass, profile:Profile) {
            _checked = checked;
            _animated = animated;
            this.scale = scale;
            this.profileLabel = profileLabel;
            this.cls = cls;
            this.profile = profile;
        }

        public function get checked():Boolean {
            return _checked;
        }

        public function set checked(value:Boolean):void {
            _checked = value;

            if (!value && !cls.checks.hasOwnProperty(profileLabel)) {
                cls.checks[profileLabel] = false;
            }

            if (value && cls.checks.hasOwnProperty(profileLabel)) {
                delete cls.checks[profileLabel];
            }
        }

        public function get animated():Boolean {
            return _animated;
        }

        public function set animated(value:Boolean):void {
            _animated = value;

            if (!value && !cls.anims.hasOwnProperty(profileLabel)) {
                cls.anims[profileLabel] = false;
            }

            if (value && cls.anims.hasOwnProperty(profileLabel)) {
                delete cls.anims[profileLabel];
            }
        }
    }
}