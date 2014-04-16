#!/usr/bin/python

# Small tool to consolidate n directories each containing p files
# adhereing to the nameing convention of <name>.<number>.mkv where
# the number typically represents the title ID from the DVD it was 
# ripped from. The input is taken from all the directories and are
# renamed (moved) to reflect the correct broadcast order defined
# on tvdb.org. You may specifiy an alternative starting episode and
# a skiplist (A CSV of integers) for any missing episodes you may not
# have (i.e. were not present on the DVD).

from sys import exit, stderr
from optparse import OptionParser

from os.path import isfile, join
from os import sep, listdir, rename, mkdir, rmdir, access, R_OK, F_OK

def parse_command_line():
    parser = OptionParser(version='%prog 0.1')

    parser.add_option('-d', '--dry-run', action='store_true',
                      dest='dryrun',
                      default=False,
                      help="""don't rename files, just print the action
                              [default: %default]""")

    parser.add_option('-s', '--series', action='store', type='int',
                      dest='series',
                      metavar='SERIES#',
                      default=1,
                      help="""the series in which all episodes feature
                              [default: %default]""")

    parser.add_option('-e', '--episode', action='store', type='int',
                      dest='episode',
                      metavar='EPISODE#',
                      default=1,
                      help="""start episode counting at this number
                              [default: %default]""")

    parser.add_option('-l', '--limit', action='store', type='int',
                      dest='limit',
                      metavar='EPISODE#',
                      default=None,
                      help="""terminate when this upper limit is reached
                              [default: %default]""")

    parser.add_option('-k', '--skip', action='store', type='str',
                      dest='skiplist',
                      metavar='CSV',
                      default='',
                      help="""skip over these (missing) episodes -- CSV format
                              [default: %default]""")

    parser.add_option('-r', '--re-route', action='store', type='str',
                      dest='reroute',
                      metavar='CSV',
                      default='',
                      help="""swap title-episode pairs -- CSV format
                              [default: %default]""")

    return parser.parse_args()


# Takes an input file of the form name.<number>.ext
def order_files(name):
    return int(name.split('.')[1])


if __name__ == '__main__':
    options, arguments = parse_command_line()

    if len(arguments) < 2:
        print >> stderr, 'Provide a show name and at least 1 input directory'
        exit(1)

    show = arguments[0]
    i = int(options.episode)
    series = int(options.series)
    skip = sorted([int(x) for x in options.skiplist.split(',') if len(x) > 0])
    reroute = dict([x.split('-') for x in options.reroute.split(',') if len(x) > 0])
    
    # Create the target output directory first
    if not options.dryrun and not access(show, F_OK):
        mkdir(show, 0755)

    terminate = False
    for d in arguments[1:]:
        if not access(d, R_OK):
            print >> stderr, 'Cannot access directory %s' % d
            exit(1)
        
        files = (f for f in listdir(d) if isfile(join(d, f))) # Generator exp
        order = sorted(files, key=lambda name: int(name.split('.')[1]))

        for f in order:
            x, title, ext = f.split('.')

            while i in skip:
                i += 1

            if str(title) in reroute:
                j = int(reroute[str(title)])
            else:
                j = i

            if options.limit and j > options.limit:
                terminate = True
                break
                
            src = d + sep + f
            dst = '%s%c%s.s%de%d.%s' % (show, sep, show, series, j, ext)

            if options.dryrun:
                print 'Rename \'%s\' to \'%s\'' % (src, dst)
            else:
                rename(src, dst)
            i += 1

        if not options.dryrun:
            rmdir(d)

        if terminate:
            break

