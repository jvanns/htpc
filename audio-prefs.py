#!/usr/bin/python

# Small tool to aid in identifying preferred audio stream

from pprint import pprint
from optparse import OptionParser
from sys import exit, stderr, stdin

def parse_command_line():
    parser = OptionParser(version='%prog 0.1')

    parser.add_option('-l', '--language', action='store', type='str',
                      dest='lang',
                      metavar='LANGUAGE',
                      default='en',
                      help="""look for the stream encoded in this language
                              [default: %default]""")

    parser.add_option('-c', '--channels', action='store', type='int',
                      dest='channels',
                      metavar='NUMBER',
                      default=6,
                      help="""prefer the N-channel audio stream 
                              [default: %default]""")

    parser.add_option('-f', '--format', action='store', type='str',
                      dest='format',
                      metavar='FORMAT',
                      default='dtshd',
                      help="""prefer the audio stream encoded in this format
                              [default: %default]""")

    parser.add_option('-k', '--handbrake', action='store_true',
                      dest='handbrake',
                      default=False,
                      help="""write out HandBrakeCLI options instead of ID
                              [default: %default]""")

    parser.add_option('-v', '--verbose', action='store_true',
                      dest='verbose',
                      default=False,
                      help="""be verbose -- print out title information
                              [default: %default]""")

    return parser.parse_args()


def choose_stream(current, preferred, options):
    assert len(current) > 0
    if len(preferred) == 0:
        return current

    cur_score = 0
    pref_score = 0

    key = 'lang'
    if current[key] == getattr(options, key):
        cur_score += 2
    if preferred[key] == getattr(options, key):
        pref_score += 2

    key = 'format'
    if current[key] == getattr(options, key):
        cur_score += 1
    if preferred[key] == getattr(options, key):
        pref_score += 1

    key = 'channels'
    if current[key] == getattr(options, key):
        cur_score += 1
    if preferred[key] == getattr(options, key):
        pref_score += 1

    if cur_score == pref_score:
        if current['bit-rate'] > preferred['bit-rate']:
            cur_score += 1
        if current['bit-depth'] > preferred['bit-depth']:
            cur_score += 1

    current['score'] = cur_score
    preferred['score'] = pref_score

    if cur_score > pref_score:
        return current

    return preferred


def lines(file_stream):
    for l in file_stream:
        yield l.strip()


def map_keys(keys, values):
    return dict(zip(keys, values))


def to_hb_codec(codec):
    names = {
       'ac-3': 'ac3',
    }
    try:
        return names[codec]
    except KeyError:
        return codec


if __name__ == '__main__':
    fs = stdin
    keys = (
        'format',
        'lang',
        'channels',
        'bit-depth',
        'bit-rate',
        'audio-id',
        'stream-id'
    )
    preferred_stream = {}

    options, arguments = parse_command_line()
    if len(arguments) >= 1:
        fs = open(arguments[0], 'r')

    first = True
    for l in lines(fs):
        if first:
            first = False
            continue
        elif l is None or len(l) == 0:
            continue
        
        # We expect a format of;
        # format,lang,channels,bit depth,bit rate,audio id, stream id
        csv = l.split(',')
        csv[3:-1] = [int(x) for x in csv[3:-1]]

        # Sometimes the number of channels may be
        # split such as 6/7 rather than just 2 or 6
        if len(csv[2]) == 1:
            csv[2] = int(csv[2])

        csv[1] = csv[1].lower()
        csv[0] = csv[0].lower()

        current_stream = map_keys(keys, csv)
        preferred_stream = choose_stream(current_stream,
                                         preferred_stream, options)
        if options.verbose:
            pprint(current_stream, stream=stderr, width=-1)

    if not options.handbrake:
        print preferred_stream[keys[-2]]
    else:
         print '-E copy:%s -a %d' \
             % (to_hb_codec(preferred_stream[keys[0]]),\
                preferred_stream[keys[-2]] + 1)
