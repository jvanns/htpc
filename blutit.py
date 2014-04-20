#!/usr/bin/python

# Small tool to correctly identify the main feature on a bluray disc

import re
from pprint import pprint
from optparse import OptionParser
from sys import exit, stderr, stdin

# Global lookup table of functors given a unit;
# It reduces the argument down to the raw #bytes
normaliser = {
   'MB': lambda x: x * float(2**20),
   'GB': lambda x: x * float(2**30)
}

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

    parser.add_option('-v', '--verbose', action='store_true',
                      dest='verbose',
                      default=False,
                      help="""be verbose -- print out title information
                              [default: %default]""")

    return parser.parse_args()


def choose_title(current, preferred, options):
    assert len(current) > 0
    if len(preferred) == 0:
        return current

    choice = preferred

    if options.use_size:
        size, unit = current['size'].split(' ')
        s1 = normaliser[unit](float(size))
        size, unit = preferred['size'].split(' ')
        s2 = normaliser[unit](float(size))

        if s1 > s2:
            choice = current
    else:
        h, m, s = (int(n) for n in current['duration'].split(':'))
        d1 = (h * 3600) + (60 * m) + s
        h, m, s = (int(n) for n in preferred['duration'].split(':'))
        d2 = (h * 3600) + (60 * m) + s

        if d1 > d2:
            choice = current

    try:
        if choice['lang'] != options.lang:
            choice = preferred
    except KeyError:
        pass # Language isn't always present in title info

    return choice


def lines(file_stream):
    for l in file_stream:
        yield l.strip()


if __name__ == '__main__':
    fs = stdin
    ignore = True
    preferred_title = {}
    current_title = {'title': 0}
    exp = re.compile(r'(^[^:]+):(.*)$')
    section_mapper = {1: 'type', 2: 'name', 5: 'codec',
                      8: 'chapters', 9: 'duration', 10: 'size',
                      13: 'bitrate', 14: 'channels', 29: 'lang'}
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
        old_tid = current_title['title']
        if old_tid != new_tid:
            preferred_title = choose_title(current_title,\
                                           preferred_title, options)
            if options.verbose:
                pprint(current_title, stream=stderr, width=-1)
            current_title = {'title': new_tid} # Start a new record

        if info[2] != 0:
            continue

        try:
            current_title[section_mapper[info[1]]] = info[-1].strip('"')
        except KeyError:
            pass # We're not interested in this field

    print preferred_title['title']
