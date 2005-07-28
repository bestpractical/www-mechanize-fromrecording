package WWW::Mechanize::FromRecording;

our $VERSION = '0.01';

use warnings;
use strict;
use Carp;

use base qw/Class::Accessor/;

use HTTP::Response;
use HTTP::Request;
use File::Basename ();
use IO::Dir;

=head1 NAME

WWW::Mechanize::FromRecording - Generate WWW::Mechanize scripts from a recorded HTTP session


=head1 SYNOPSIS

    use HTTP::Recorder::PostMortem;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 METHODS

=cut

=head2 new $prefix

Creates a new L<WWW::Mechanize::FromRecording> object.  Sets the C<recorder_prefix>
to C<$prefix>.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    my $prefix = shift;
    my $base_url = shift;
    $self->recorder_prefix($prefix);
    $self->mech_class('WWW::Mechanize');
    return $self;
} 

=head2 recorder_prefix [$prefix]

Gets or sets the root file name of the recorder logs.  For example,
L<HTTP::Server::Simple::Recorder> uses C</tmp/http-server-simple-recorder> by
default.  The log filenames have the form

  I<recorder_prefix>.I<serial>.I<direction>

where I<serial> is a 1-based serial number and I<direction> is either C<in> (for
requests) or C<out> (for reponses).

=head2 mech_class [$mech_class]

Gets or sets the Mech class used in the output.  Defaults to C<WWW::Mechanize>, but
you may want C<Test::WWW::Mechanize>, for example.

=cut

__PACKAGE__->mk_accessors(qw/recorder_prefix mech_class/);

=head2 mech_script

Returns a mech script that attempts to replicate the recorded actions.

=cut

sub mech_script {
    my $self = shift;
    my $script = <<END_HEAD;
my \$mech = @{[ $self->mech_class ]}->new;

END_HEAD

    my $last_real_URL;

    for my $messages ($self->_messages) {
	my $request = $messages->{'request'};
	my $response = $messages->{'response'};

	my $URL = "http://" . $request->header('Host') . $request->uri;

	my $line = qq(\$mech->get(q{$URL}););

	my $comment = sub { $line .= "\n# ($_[0])" };
	my $comment_out = sub { $line = "# $line"; $comment->(@_) };

	my $ct = $response->content_type;

	unless ($request->method eq 'GET') {
	    $comment_out->("method was " . $request->method . ", not GET");
	} elsif ($response->code != 200) {
	    $comment_out->("response code was " . $response->code . ", not 200");
	} elsif (not defined $ct or not length $ct) {
	    $comment_out->("no content-type returned");
	} elsif ($ct ne "text/html") {
	    $comment_out->("content-type was $ct, not text/html");
	} else {
	    # Looks good.  What else can we glean?
	    
	    my $referer = $request->header('Referer');
	    if (defined $referer and length $referer) {
		$comment->("looks like we got here from $referer");

		$comment->("hey, that's the last page we went to. maybe we clicked a link.")
		    if $last_real_URL and $referer eq $last_real_URL;
	    } 

	    $last_real_URL = $URL;
	} 

	$script .= "$line\n\n";
    } 

    return $script;
} 

=begin private

=head2 _messages

Returns a list of hashes with keys C<response> and C<request> corresponded
to the recorded messages, in order; the values are L<HTTP::Response> and L<HTTP::Request>
objects.

The first time you call C<_messages>, it automatically calls C<_get_messages> to construct
this list.

=end private

=cut

sub _messages {
    my $self = shift;
    $self->_get_messages unless $self->{'_messages'};
    @{ $self->{'_messages'} };
} 

=begin private

=head2 _get_messages

Reads the recorded logs at C<recorder_prefix> and creates the structure returned by C<_messages>

=end private

=cut

sub _get_messages {
    my $self = shift;
    my @messages;
    for my $message_pair ($self->_message_file_names) {
	push @messages, {
	    request => HTTP::Request->parse($self->_slurp($message_pair->[0])),
	    response => HTTP::Response->parse($self->_slurp($message_pair->[1])),
	};
    } 

    $self->{'_messages'} = \@messages;
} 

=begin private

=head2 _message_file_names

Returns a list of two-element arrays, with each pair containing the input and output file names
of the recorded files.

=end private

=cut

sub _message_file_names {
    my $self = shift;

    my($prefix, $dir) = File::Basename::fileparse($self->recorder_prefix);

    my $dh = IO::Dir->new($dir) or die "Couldn't open directory '$dir': $!";

    my %found;
    $found{'in'} = []; $found{'out'} = [];

    # breaks if file names have leading 0s
    for my $f ($dh->read) {
	next unless $f =~ qr/^\Q$prefix\E\.(\d+)\.(in|out)$/;

	$found{$2}[$1] = 1;
    } 

    die "Highest-numbered input and output files don't match!" unless @{ $found{'in'} }== @{ $found{'out'} };

    shift @{ $found{'in'} }; shift @{ $found{'out'} };

    die "Missing some input file(s)!" if grep !defined, @{ $found{'in'} };
    die "Missing some output file(s)!" if grep !defined, @{ $found{'out'} };

    return map { [$self->recorder_prefix . ".$_.in", $self->recorder_prefix . ".$_.out" ]}
	1..@{ $found{'in'} };
} 


=begin private

=head2 _slurp $filename

Slurps the file. You know the drill.  Dies on error.

=end private

=cut

sub _slurp {
    my $self = shift;
    my $filename = shift;
    open my $fh, '<', $filename or die "Can't open $filename: $!";

    local $/;
    my $slurped = <$fh>;
    return $slurped;
} 

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
WWW::Mechanize::FromRecording requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-http-recorder-postmortem@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

=head1 SEE ALSO

L<HTTP::Server::Simple::Recorder> creates files in the appropriate format from
L<HTTP::Server::Simple> applications.

L<HTTP::Recorder> is an inspiration for this module, but it is not actually
related.

=head1 AUTHOR

David Glasser  C<< <glasser@bestpractical.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2005, Best Practical Solutions, LLC.  All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;
