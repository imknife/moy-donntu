import json
import os
import re
import sys

from fontTools import subset

NAMES = [
    'clock', 'chevron-right', 'chevron-left', 'chevron-down', 'check', 'x', 'arrow-left', 'coffee', 'user-round', 'notebook-pen',
    'university', 'graduation-cap', 'clipboard-check', 'calendar-range', 'hourglass', 'building', 'building-2', 'footprints', 'settings',
    'palette', 'shield-check', 'layout-dashboard', 'smartphone', 'library-big', 'message-square-warning', 'refresh-cw', 'star', 'plus',
    'trash-2', 'list-checks', 'pencil', 'sun', 'moon', 'monitor', 'users', 'map', 'id-card', 'log-out', 'ellipsis', 'circle-help',
    'eye', 'eye-off', 'lock', 'map-pin', 'route', 'locate-fixed', 'minus', 'maximize', 'arrow-up-down', 'external-link', 'flag',
    'upload', 'download', 'paperclip', 'image', 'camera', 'share-2', 'copy', 'calendar-plus', 'users-round', 'file-text', 'search',
    'bell', 'house', 'calendar', 'layout-grid', 'user', 'book-open', 'flask-conical', 'lock-keyhole', 'triangle-alert', 'info',
    'chart-column', 'door-open', 'folder-open', 'book-check', 'newspaper', 'contact-round', 'type', 'scroll-text', 'megaphone', 'link', 'school',
]

def camel(name):
    parts = name.split('-')
    return parts[0] + ''.join(p[:1].upper() + p[1:] for p in parts[1:])

def main(package_dir, out_font, out_dart):
    codepoints = json.load(open(os.path.join(package_dir, 'assets', 'codepoints.json'), encoding='utf-8'))
    missing = [n for n in NAMES if n not in codepoints]
    if missing:
        sys.exit('нет значков: ' + ', '.join(missing))
    options = subset.Options()
    options.glyph_names = True
    options.layout_features = []
    options.notdef_outline = True
    font = subset.load_font(os.path.join(package_dir, 'assets', 'lucide.ttf'), options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=[codepoints[n] for n in NAMES])
    subsetter.subset(font)
    subset.save_font(font, out_font, options)
    lines = ["import 'package:flutter/widgets.dart';", '', 'class Lucide {']
    for n in NAMES:
        lines.append("  static const IconData %s = IconData(0x%x, fontFamily: 'LucideSubset');" % (camel(n), codepoints[n]))
    lines.append('}')
    open(out_dart, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
    print(len(NAMES), 'значков,', os.path.getsize(out_font), 'байт')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
