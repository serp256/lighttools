package ru.redspell.rasterizer.utils {
    import ru.redspell.rasterizer.flatten.FlattenMovieClip;

    public class MovieClipExporter {
        protected var _clip:FlattenMovieClip;

        public function MovieClipExporter(clip:FlattenMovieClip) {
            _clip = clip;
        }
    }
}