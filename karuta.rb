#!/usr/bin/env ruby

require "wav-file"
require "numo/narray"
require "numo/pocketfft"

def assert(expr, msg)
  unless expr
    raise msg
  end
end

def load_wave_file(path)
  format = nil
  data = nil
  open(path){|f|
    format = WavFile::readFormat(f)
    assert(format.channel == 2, "Unsupported format: channel is not 2")
    assert(format.bitPerSample == 16, "Unsupported format: bitPerSample is not 16")
    dataChunk = WavFile::readDataChunk(f)
    data = Numo::Int16::from_string(dataChunk.data).cast_to(Numo::SFloat) / 32768
  }
  return data, format
end

def get_left(audio)
  audio[(0..-1).step(2)]
end

def nextpow2(n)
  exponent = Numo::NMath::log2(n.abs)
  exponent[exponent.isneginf] = 0
  exponent.ceil
end

def pad(a, num_before, num_after)
  assert(a.shape.length == 1, "pad() supports only 1-dimensional array")
  size = a.shape[0] + num_before + num_after
  type = Numo::NArray::array_type(a)
  new_a = type.zeros(size)
  new_a[num_before...(num_before+a.shape[0])] = a
  return new_a
end

def calc_fft_jingle(jingle_left, fft_len)
  jingle_size = jingle_left.length
  num_pad_before = jingle_size - 1
  num_pad_after = fft_len - (2 * jingle_size ) + 1
  padded = pad(jingle_left, num_pad_before, num_pad_after)
  ret = Numo::Pocketfft::fft(padded)
  return ret
end

def calc_fft_audio(audio_left, fft_len)
  audio_size = audio_left.length
  padded = pad(audio_left, 0, fft_len - audio_size)
  ret = Numo::Pocketfft::fft(padded)
  return ret
end

def calc_similarity(fft_jingle, fft_audio, jingle_size)
  tmp = Numo::Pocketfft::ifft(fft_jingle * fft_audio.conj)
  ret = tmp[0...2*jingle_size].real.max
  return ret
end

def search_jingle(jingle, audio, search_start_idx = 0)
  jingle_size = jingle.length
  audio_size = audio.length
  extract_size = (jingle_size * 1.5).to_i
  fft_len = (2 ** nextpow2(2*extract_size-1)[0]).to_i
  fft_jingle = calc_fft_jingle(jingle, fft_len)

  max_similarity = -1
  found = false
  extract_start_idx = search_start_idx
  prev_progress = -1
  loop do
    extract_end_idx = extract_start_idx + extract_size
    if extract_end_idx >= audio_size
      break
    end
    progress = ((extract_end_idx.to_f / audio_size) * 100).to_i
    if progress != prev_progress
      printf("\r#{progress}%% (#{extract_start_idx}/#{audio_size})")
      $stdout.flush()
    end
    extracted = audio[extract_start_idx...extract_end_idx]
    fft_extracted = calc_fft_audio(extracted, fft_len)
    similarity = calc_similarity(fft_jingle, fft_extracted, jingle_size)
    if similarity > max_similarity
      max_similarity = similarity
      if similarity >= 1000
        printf(" found")
        found = true
        break
      end
    end

    extract_start_idx += jingle_size
    prev_progress = progress
  end
  puts
  ret = found ? extract_start_idx : -1
  return ret
end

def search_segment(start_jingle, end_jingle, in_audio)
  sj_left = get_left(start_jingle)
  ej_left = get_left(end_jingle)
  in_left = get_left(in_audio)

  sj_start_idx = search_jingle(sj_left, in_left)
  search_start_idx = sj_start_idx >= 0 ? sj_start_idx : 0
  sj_start_time = sj_start_idx.to_f / 44100

  ej_start_idx = search_jingle(ej_left, in_left, search_start_idx)
  ej_end_idx = ej_start_idx >= 0 ? ej_start_idx + ej_left.length : -1
  # convert index in mono sound to stereo sound
  return sj_start_idx*2, ej_end_idx*2
end

def save_wave_file(audio, format, path)
  audio_int16 = (audio * 32768).cast_to(Numo::Int16)
  header_file_size = 4 + audio_int16.length*2 + 8
  open(path, "wb"){|f|
    f.write('RIFF' + [header_file_size].pack('V') + 'WAVE')
    f.write('fmt ')
    f.write([format.to_bin.size].pack('V'))
    f.write(format.to_bin)
    f.write('data')
    f.write([audio_int16.length*2].pack('V'))
    f.write(audio_int16.to_binary)
  }
end

unless ARGV.length == 4
  $stderr.puts "Arguments error"
  $stderr.puts "usage: karuta.rb <start_jingle> <end_jingle> <in_audio> <out_audio>"
  exit 1
end

jingle1, jingle1_format = load_wave_file(ARGV[0])
jingle2, jingle2_format = load_wave_file(ARGV[1])
audio, audio_format = load_wave_file(ARGV[2])
start_idx, end_idx = search_segment(jingle1, jingle2, audio)
if start_idx < 0
  $stderr.puts "Error: start jingle not found"
  exit 1
end
if end_idx < 0
  $stderr.puts "Error: end jingle not found"
  exit 1
end
start_time = start_idx.to_f / audio_format.hz
end_time = end_idx.to_f / audio_format.hz
puts "extract idx: #{start_idx} - #{end_idx} (#{start_time} - #{end_time} sec)"
extracted = audio[start_idx...end_idx]
save_wave_file(extracted, audio_format, ARGV[3])
