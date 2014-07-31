#!/usr/bin/python

# Small tool to correctly identify the main feature on a bluray disc

import re
import sys
from math import sqrt
from optparse import OptionParser
from sys import exit, stderr, stdin

# Global lookup table of functors given a unit;
# It reduces the argument down to the raw #bytes
MB = float(1L << 20)
GB = float(1L << 30)

def parse_command_line():
    parser = OptionParser(version='%prog 0.1')

    parser.add_option('-l', '--language', action='store', type='str',
                      dest='lang',
                      metavar='LANGUAGE',
                      default='English',
                      help="""look for the stream encoded in this language
                              [default: %default]""")

    parser.add_option('-s', '--use-size', action='store_true',
                      dest='use_size',
                      default=False,
                      help="""instead of duration, use stream size as the key
                              [default: %default]""")

    parser.add_option('-n', '--print-name', action='store_true',
                      dest='print_name',
                      default=False,
                      help="""instead of title indices, print the title name
                              [default: %default]""")

    parser.add_option('-e', '--episodes', action='store_true',
                      dest='episodes',
                      default=False,
                      help="""detect a set of episodes instead of main feature
                              [default: %default]""")

    parser.add_option('-m', '--min-duration', action='store', type='int',
                      dest='min',
                      default=900, # 15mins
                      help="""minimum duration of an episode in seconds
                              [default: %default]""")

    parser.add_option('-M', '--max-duration', action='store', type='int',
                      dest='max',
                      default=4500, # 1h15mins
                      help="""maximum duration of an episode in seconds
                              [default: %default]""")

    parser.add_option('-d', '--deviations', action='store', type='float',
                      dest='deviations',
                      default=1.5,
                      help="""the number of deviations from the mean to accept
                              [default: %default]""")

    parser.add_option('-v', '--verbose', action='store_true',
                      dest='verbose',
                      default=False,
                      help="""be verbose -- print out title information
                              [default: %default]""")

    return parser.parse_args()


def augment_title(title):
    h, m, s = (int(n) for n in title['duration'].split(':'))
    title['raw_duration'] = (h * 3600) + (60 * m) + s
    title['gigabytes'] = title['size'] / GB


def choose_title(current, preferred, options):
    assert len(current) > 0
    if len(preferred) == 0:
        return current

    choice = preferred

    if options.use_size:
        if current['size'] > preferred['size']:
            choice = current
    else:
        if current['raw_duration'] > preferred['raw_duration']:
            choice = current

    try:
        if choice['lang'] != options.lang:
            choice = preferred
    except KeyError:
        pass # Language isn't always present in title info

    return choice


def pick_preferred(all_titles, options):
    preferred_title = {}
    for t in all_titles:
        preferred_title = choose_title(t, preferred_title, options)
    return preferred_title


def lines(file_stream):
    for l in file_stream:
        yield l.strip()


def mean(a):
    return sum(a) / float(len(a))


def stddev(a):
    m = mean(a)
    return sqrt(sum((x - m)**2 for x in a) / float(len(a)))


def filter_title_lengths(titles, minimum, maximum):
    f = lambda x: x > minimum and x < maximum
    return filter(f, map(lambda x: x['raw_duration'], titles))


def calculate_bounds(lengths, options):
    m = mean(lengths) # Average duration
    s = stddev(lengths) # Standard deviation of average duration
    bounds = (m - (s * options.deviations), m + (s * options.deviations))

    if options.verbose:
        print >> sys.stderr, 'Mean duration:      %.2f seconds' % (m)
        print >> sys.stderr, 'Standard deviation: %.2f seconds' % (s)
        print >> sys.stderr, 'Lower bound:        %.2f seconds' % (bounds[0])
        print >> sys.stderr, 'Upper bound:        %.2f seconds' % (bounds[1])

    return bounds


def detect_episodes(all_titles, options):
    lengths = filter_title_lengths(all_titles, options.min, options.max)
    bounds = calculate_bounds(lengths, options)
    episodes = []

    for t in all_titles:
        duration = t['raw_duration']
        if duration >= bounds[0] and duration <= bounds[1]:
            episodes.append(t)
            if options.verbose:
                print >> sys.stderr, 'Selected title %d: %d seconds' % \
                (t['index'], duration)
        elif options.verbose:
            print >> sys.stderr, 'Eliminated title %d: %d seconds' % \
            (t['index'], duration)

    return episodes


def print_title(title, stream):
    for k, v in sorted(title.iteritems(), key=lambda (k, v): k):
        print >> stream, k + ':%s' % (' ' * (16 - (len(k) + 1))), v
    print >> stream


if __name__ == '__main__':
    fs = stdin
    ignore = True
    all_titles = []
    current_title = {'index': 0}
    exp = re.compile(r'(^[^:]+):(.*)$')
    section_mapper = {1: 'type', 2: 'name', 5: 'codec',
                      8: 'chapters', 9: 'duration', 11: 'size',
                      13: 'bitrate', 14: 'channels', 24: 'title', 29: 'lang'}
    reverse_mapper = dict((v, k) for k, v in section_mapper.iteritems())

    options, arguments = parse_command_line()
    if len(arguments) >= 1:
        fs = open(arguments[0], 'r')

    for l in lines(fs):
        tag, csv_data = l.split(':', 1)

        # Initially ignore the first N lines as they contain nothing useful
        if ignore:
            if tag == 'TCOUNT':
                ignore = False
            continue

        if tag != 'TINFO':
            continue

        # Cast IDs to integers leaving strings intact
        info = csv_data.split(',', 3)
        info[0:-1] = [int(x) for x in info[0:-1]]

        new_tid = info[0]
        old_tid = current_title['index']
        if old_tid != new_tid:
            augment_title(current_title)
            all_titles.append(current_title)
            current_title = {'index': new_tid} # Start a new record

        if info[2] != 0:
            continue

        try:
            v = info[-1].strip('"')
            try:
                v = int(v)
            except ValueError:
                pass
            current_title[section_mapper[info[1]]] = v
        except KeyError:
            pass # We're not interested in this field

    augment_title(current_title)
    all_titles.append(current_title)

    if options.episodes:
        preferred_titles = detect_episodes(all_titles, options)
    else:
        preferred_titles = [pick_preferred(all_titles, options)]

    if len(preferred_titles) == 0:
        sys.exit(1)

    if options.verbose:
        for t in sorted(all_titles, key=lambda k: k['duration'], reverse=1):
            print_title(t, sys.stderr)

    if options.print_name:
        r = 0
        try:
            print preferred_titles[0]['name']
        except KeyError:
            r = 1
        sys.exit(r)

    for i, t in enumerate(preferred_titles):
        if i > 0:
            print ' %d' % (t['index']),
        else:
            print t['index'],
    print
    sys.exit(0)

