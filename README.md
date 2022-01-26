# karuta: Extract segment from radio with jingle detection

## What's this?

karuta.rb extracts segment from radio by specifying start jingle and end jingle which indicate the start and the end of the segment.

## How to use

### Prerequisites

* Ruby (3.0 was used to develop, but older versions are probably ok)
* Dependent libraries:
  * wav-file (`gem install wav-file`)
  * Numo::NArray (`gem install numo-narray`)
  * Numo::Pocketfft (`gem install numo-pocketfft`)
* Optional
  * ffmpeg: To convert mp3<->wav
  * Audacity: To create jingle.wav

### Create jingle files

1. Convert compressed radio file (mp3, flac, etc.) to wav (`ffmpeg -i radio1.mp3 -vn -ac 2 -ar 44100 -acodec pcm_s16le -f wav radio1.wav`)
2. Extract start/end jingle and save them as `jingle-start.wav` and `jingle-end.wav` (Audacity can be used)
3. Run: `./karuta.rb jingle-start.wav jingle-end.wav radio2.wav out.wav` to extract segment starts from `jingle-start.wav` and ends with `jingle-end.wav` in radio2.wav. The extracted part is saved to `out.wav`

### License

MIT License
