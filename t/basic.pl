BasicServer->new->run;

package BasicServer;

use base qw/HTTP::Server::Simple::Recorder HTTP::Server::Simple::CGI/;
use HTTP::Server::Simple::Static;

sub recorder_prefix { 'basic_recorded/basic' }

sub handle_request {
    my $self = shift;
    my $cgi = shift;
    unless ($self->serve_static($cgi, 'basic')) {
	print "HTTP/1.1 404 File Not Found\nContent-Length:0\n\n";
    }
    return 1;
} 

