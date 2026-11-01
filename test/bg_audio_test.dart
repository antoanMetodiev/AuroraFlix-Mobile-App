import 'package:auroraflix/core/bg_audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unpackPacked decodes a p,a,c,k,e,d config', () {
    // A tiny sample in the same shape VidHide serves.
    const page =
        "eval(function(p,a,c,k,e,d){while(c--)if(k[c])p=p.replace(new RegExp('\\b'+c.toString(a)+'\\b','g'),k[c]);return p}"
        "('0 1={\"2\":\"3://4.5/6.7\"};',8,8,'var|links|hls2|https|cdn|com|master|m3u8'.split('|'),0,{}))";
    expect(unpackPacked(page), 'var links={"hls2":"https://cdn.com/master.m3u8"};');
  });

  test('bgPlayerUrl puts the links in the fragment', () {
    final url = bgPlayerUrl('https://cdn.com/master.m3u8?t=a&s=1', subtitleUrl: 'https://x/api/subtitles/1', title: 'Прислужницата');
    final uri = Uri.parse(url);
    expect(uri.path, '/bg-player.html');
    final fragment = Uri.splitQueryString(uri.fragment);
    expect(fragment['master'], 'https://cdn.com/master.m3u8?t=a&s=1');
    expect(fragment['sub'], 'https://x/api/subtitles/1');
    expect(fragment['title'], 'Прислужницата');
  });
}
