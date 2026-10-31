import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

FAMILIES = {
    'Onest': 'Onest[wght].ttf',
}
WEIGHTS = {400: 'Regular', 500: 'Medium', 600: 'SemiBold', 700: 'Bold'}
RANGES = '20-7E,A0-FF,131,152-153,2C6,2DC,400-4FF,2010-2015,2018-201E,2020-2022,2026,2030,2039-203A,20AC,20BD,2116,2122,2190-2193,2212,2215,2248,2260-2265'
FEATURES = ['kern', 'tnum', 'lnum', 'pnum', 'liga', 'ccmp', 'locl', 'mark', 'mkmk']

def unicodes():
    result = []
    for part in RANGES.split(','):
        low, _, high = part.partition('-')
        result.extend(range(int(low, 16), int(high or low, 16) + 1))
    return result

def build(source_dir, out_dir):
    options = subset.Options()
    options.layout_features = FEATURES
    options.notdef_outline = True
    options.name_IDs = [1, 2, 3, 4, 5, 6, 0, 13, 14]
    for family, file_name in FAMILIES.items():
        for weight, label in WEIGHTS.items():
            font = TTFont(os.path.join(source_dir, file_name))
            axis = font['fvar'].axes[0]
            clamped = min(max(weight, axis.minValue), axis.maxValue)
            instance = instancer.instantiateVariableFont(font, {'wght': clamped})
            subsetter = subset.Subsetter(options)
            subsetter.populate(unicodes=unicodes())
            subsetter.subset(instance)
            target = os.path.join(out_dir, '%s_%d%s.ttf' % (family, weight, label))
            subset.save_font(instance, target, options)
            print(os.path.basename(target), os.path.getsize(target))

if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2])
