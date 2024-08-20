package App::pdfresize;

use 5.014;
use strict;
use warnings;
use Log::ger;

use Exporter qw(import);
use File::chdir;
use File::Temp;
use IPC::System::Options -log=>1, -die=>1, 'system';

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw(pdfsize);

our %SPEC;

$SPEC{pdfsize} = {
    v => 1.1,
    summary => 'Resize each page of PDF file to a new dimension',
    description => <<'MARKDOWN',

This utility first splits a PDF to individual pages (using <prog:pdftk>), then
converts each page to JPEG and resizes it (using ImageMagick's <prog:convert>),
then converts back each page to PDF and reassembles the resized pages to a new
PDF.

MARKDOWN
    args => {
        filename => {
            schema => 'filename*',
            req => 1,
            pos => 0,
        },
        resize => {
            summary => 'ImagaMagick resize notation, e.g. "50%x50%", "x720>"',
            schema => 'filename*',
            req => 1,
            pos => 1,
            description => <<'MARKDOWN',

See ImageMagick documentation (e.g. <prog:convert>) for more details, or the
documentation of <prog:calc-image-resized-size>,
<prog:image-resize-notation-to-human> for lots of examples.

MARKDOWN
        },
        quality => {
            schema => ['int*', min=>1, max=>100],
            cmdline_aliases => {q=>{}},
        },
        output_filename => {
            schema => 'filename*',
            pos => 2,
        },
    },
    examples => [
        {
            summary => 'Shrink PDF dimension to 25% original size (half the width, half the height)',
            argv => ['foo.pdf', '50%x50%'],
            test => 0,
        },
        {
            summary => 'Shrink PDF page height to 720p, and use quality 40, name an output',
            argv => ['foo.pdf', 'x720>', '-q40', 'foo-resized.pdf'],
            test => 0,
        },
    ],
    links => [
        {url=>'prog:imgsize'},
    ],
    deps => {
        all => [
            {prog=>'pdftk'},
            {prog=>'convert'},
        ],
    },
};
sub pdfsize {
    my %args = @_;

    my $tempdir = File::Temp::tempdir(CLEANUP => !is_log_debug());
    log_debug "Temporary directory is $tempdir (not cleaned up, for debugging)";

    my $abs_filename = Cwd::abs_path($args{filename})
        or die "Can't convert $args{filename} to absolute path: $!";

  LOCAL:
    {
        local $CWD = $tempdir;

        log_debug "Splitting PDF to individual pages ...";
        system "pdftk", $abs_filename, "burst";

        my @pdf_pages = glob "*.pdf";
        log_debug "Number of pages: %d", scalar(@pdf_pages);

        log_debug "Converting PDF pages to JPGs and resizing  ...";
        for my $pdf_pages (@pdf_pages) {
            system "convert", ($args{quality} ? ("-q", int($args{quality})) : ()), "-resize", $args{resize}, $pdf_page, "$pdf_page.jpg";
        }

        log_debug "Converting resized JPGs back to PDFs ...";
        for my $pdf_pages (@pdf_pages) {
            system "convert", "$pdf_page.jpg", "$pdf_page.resized.pdf";
        }
    } # LOCAL

    my $output_filename = $args{output_filename} // ($args{filename} =~ s/(\.pdf)?$/-resized.pdf/ir);
    log_debug "Merging individual PDFs to output ...";
    system "pdftk", (map {Cwd::abs_path("$_.resized.pdf")} @pdf_pages), "cat", "output", $output_filename;

    [200];
}

1;
#ABSTRACT:

=head1 SYNOPSIS

 # Use via pdfsize CLI script

=cut
